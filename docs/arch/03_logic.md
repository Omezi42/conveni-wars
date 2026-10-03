# 3章 ロジック層

## 3.1 クラス

| クラス | 責務 |
|---|---|
| `MatchState` | 試合の唯一の状態。時計・時間帯・両店・乱数・客の到着・イベント。コマンドとシグナルの窓口 |
| `StoreState` | 1店ぶんの状態。資金・売上・仕入れに払った額(`spent`。利益 = 売上 − `spent`)・客層ごとの来店数・取り逃した客の数・廃棄数・棚(マス9つぶんの商品id。空は `&""`)・商品ごとの在庫・発注中・値段段階・値段の冷却・店長・スキルの効果時間 |
| `Attraction` | 魅力度の計算(静的関数だけ)。店と客層を受け取り、棚の倍率・値段補正・パッシブを掛けた点を返す(GameDesign.md 2.4節・4章・5.2節) |
| `ShelfBonus` | 棚の倍率の計算(静的関数だけ)。目玉・コーナー・セットを判定し、マスごとの倍率と成立したボーナスの一覧を返す |
| `EventScheduler` | 突発イベントの抽選・予告・客の到着(GameDesign.md 11章)。`MatchState` が持つ |
| `MatchHistory` | 試合の記録(GameDesign.md 9.4節のふりかえり)。`BalanceConfig.history_interval` 秒ごとの両店の利益と、突発イベントの開始時刻・id・店ごとの客数を持つ。`MatchState` が `history` として持ち、`MatchResult.history` で結果画面へ渡す |
| `MatchRecord` | 試合の再生に要るもの(GameDesign.md 10章):種・両店の店長・CPUの強さ・1tickの秒数・プレイヤーのコマンドの列(何tick目・種類・商品id・マスか値段段階)と、時間帯の始まりごとのスナップショット(3.5節)。`MatchState` が `record` として持ち、`MatchResult.record` で結果画面へ渡す |
| `MatchRunner` | 1tickの進め方を1か所にまとめる:そのtickの記録済みコマンドを流す(再生のときだけ)→ `advance` → CPUを順に `update` → 時間帯が変わったらスナップショット。試合画面・再生・計算し直しが同じ順で進むようにするため |
| `CpuReview` | 結果画面の「CPUならどうしたか」(9.4節)。時間帯ごとにスナップショットから計算し直し、差の大きい時間帯の文を作る。`process(usec)` で時間の予算ぶんだけ進め、終わったら true を返す |
| `ManagerSkills` | パッシブの補正値の問い合わせ(発注の原価・魅力度・安売りの効き・予報・配送の秒数)と、アクティブの発動・効果時間の管理(7章)。値札ロック中の強気の売値は `StoreState.sell_price()` が問い合わせる |

- 試合の開始時に、両店へ `BalanceConfig.opening_shelf` を割り当て、その商品の在庫を無料のロットとして入れる(1.6節)。
  `spent` に数えないので利益は0から始まる
- `StoreState` は時間帯ごとの来店数と、時間帯ごと・カテゴリごとの取り逃した客の数を持つ(9.3節の時間帯の成績)
- 在庫はマスではなく `StoreState` が商品ごとに持つ(GameDesign.md 6.2節)。マスは商品idだけを持つ
- 商品ごとの在庫は、届いた時刻の古い順に並べたロットの列(個数と廃棄時刻)で持つ。売るときは先頭から減らし、
  廃棄時刻を過ぎたロットを捨てる(6.4節)。日持ちしない商品でなければ廃棄時刻は持たない
- 値段補正は相手の店の同じカテゴリの値段と比べる(GameDesign.md 5.2節)。`StoreState.rival` で相手を持ち、
  どちらかの店のキャッシュを捨てるときは相手のキャッシュも捨てる
- `StoreState` は時間帯ごと・商品ごとに、在庫ありで棚に並んでいた秒数を持つ(9.4節の「CPUならどうしたか」の商品名)
- 棚の倍率と客層ごとの魅力度は、棚・在庫の有無・値段・スキルの効果が変わったときだけ計算し直してキャッシュする
  (1秒に最大9人来るため、客ごとに棚全体を計算し直さない)

## 3.2 コマンド

画面とCPUは次だけを呼ぶ。成否を `bool` で返し、失敗時は状態を変えない。

- `order(store_index, product_id)` 発注(資金不足なら失敗)
- `assign(store_index, product_id, slot_index)` マスへ商品を割り当てる(入れ替えを含む)
- `unassign(store_index, slot_index)` マスの割り当てを外す
- `set_price_step(store_index, product_id, step)` 値段(冷却中・値札ロック中なら失敗)
- `use_active(store_index)` アクティブスキル(使用済みなら失敗)

## 3.3 進行

`MatchState.advance(delta)` を `MatchController`(画面側のNode)が `_physics_process` から呼ぶ。1回の中で順に:

1. 時計を進め、時間帯の切り替わりを判定する
2. 発注の残り時間を減らし、0になったものを在庫へ加える。廃棄時刻を過ぎたロットを捨てる
3. 値段の冷却とスキルの効果時間を減らす
4. `EventScheduler` を進める(予告・開始・イベント客の生成)
5. 到着間隔(時間帯の `duration / customer_count`)ぶんの時間が溜まっただけ客を生成する。
   1回の `advance` で複数人になることがある。客ごとに店を選び、買い物を処理し、取り逃した客を数える(2.6節)
6. 在庫ありで棚に並んでいる商品の秒数を、いまの時間帯へ足す
7. `MatchHistory` に利益を記録する(記録の間隔ごと。試合の終わりの値も必ず1つ記録する)
8. 試合時間を過ぎたら終了する

`advance` を呼んだ回数を `tick` として数える。

## 3.4 シグナル

`band_changed(band_id)` `delivery_arrived(store_index, product_id, count)`
`customer_arrived(type_id, store_index, is_event, first_product_id)`(帰った客は store_index が -1。
`first_product_id` は最初に買った商品で、買わなかったら `&""`。見える客の吹き出しに使う) `customer_lost(store_index, category_id)`
`purchased(store_index, product_id, count, amount)` `wasted(store_index, product_id, count)` `ordered(store_index, product_id)`
`price_changed(store_index, product_id, step)` `event_announced(event_id, store_index)`(店長によって予告の早さが違うため店ごと)
`event_started(event_id)` `event_ended(event_id, store_counts)` `skill_used(store_index)` `skill_ended(store_index)` `match_ended(result)`。
画面はこれを受けて表示を更新し、演出を出す。
`customer_arrived` などは1秒に最大9回出るため、画面側は受けたものを溜めて、人の流れの演出にまとめて反映する。

## 3.5 記録・再生・計算し直し

- コマンドが成功したら、`MatchRecord.store_index` の店のものだけを、いまの `tick` と一緒に記録する(既定はプレイヤーの店0)。
  画面の操作は物理tickのあいだに入るため、記録した `tick` のコマンドはその tick の `advance` の前に流せば元と同じ順になる
- `MatchRunner.step(delta)` の順:記録済みコマンド(再生のときだけ)→ `advance` → CPUの `update`(店の番号の順)→
  時間帯が変わった tick の終わりにスナップショット。開店の瞬間(tick 0)にも1つ撮る
- スナップショットは `MatchState.duplicate_state()`(両店・突発イベント・乱数の `state` を写し、記録と `MatchHistory` は空にする)と、
  相手のCPUの `CpuPlayer.duplicate_for(match_state)`。シグナルはつながない
- `CpuReview` は時間帯 k のスナップショットを写し、プレイヤーの店をスキルを使わない `CpuPlayer`(相手と同じ強さ)に任せて、
  次のスナップショットの tick(最後の時間帯は試合の終わり)まで進める。その間のプレイヤーのコマンドはアクティブスキルだけ流す。
  比べる元の値は次のスナップショット(最後は試合の結果)の状態。
  店の値 = 利益 + 手元の在庫と発注中の商品を仕入れ値で数えた額
- 計算し直す時間帯の順は時間帯の順。1つ終わるたびに文を作り直す
