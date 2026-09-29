# 3章 ロジック層

## 3.1 クラス

| クラス | 責務 |
|---|---|
| `MatchState` | 試合の唯一の状態。時計・時間帯・両店・乱数・客の到着。コマンドとシグナルの窓口 |
| `StoreState` | 1店ぶんの状態。資金・売上・客層ごとの来店数・棚(マス9つぶんの商品id。空は `&""`)・商品ごとの在庫数・発注中・値段段階・値段の冷却・店長・スキルの効果時間 |
| `Attraction` | 魅力度の計算(静的関数だけ)。店と客層を受け取り、棚の倍率・値段補正・パッシブを掛けた点を返す(GameDesign.md 2.4節・4章・5.2節) |
| `ShelfBonus` | 棚の倍率の計算(静的関数だけ)。目玉・コーナー・セットを判定し、マスごとの倍率と成立したボーナスの一覧を返す |
| `ManagerSkills` | パッシブの補正値の問い合わせと、アクティブの発動・効果時間の管理(7章) |

- 在庫はマスではなく `StoreState` が商品ごとに持つ(GameDesign.md 6.2節)。マスは商品idだけを持つ
- 棚の倍率と客層ごとの魅力度は、棚・在庫の有無・値段・スキルの効果が変わったときだけ計算し直してキャッシュする
  (1秒に最大9人来るため、客ごとに棚全体を計算し直さない)

## 3.2 コマンド

画面とCPUは次だけを呼ぶ。成否を `bool` で返し、失敗時は状態を変えない。

- `order(store_index, product_id)` 発注(資金不足なら失敗)
- `assign(store_index, product_id, slot_index)` マスへ商品を割り当てる(入れ替えを含む)
- `unassign(store_index, slot_index)` マスの割り当てを外す
- `set_price_step(store_index, product_id, step)` 値段(冷却中・値札ロック中なら失敗)
- `use_active(store_index)` アクティブスキル(使用済み・開店準備中なら失敗)

## 3.3 進行

`MatchState.advance(delta)` を `MatchController`(画面側のNode)が `_physics_process` から呼ぶ。1回の中で順に:

1. 時計を進め、時間帯の切り替わりを判定する
2. 発注の残り時間を減らし、0になったものを在庫へ加える
3. 値段の冷却とスキルの効果時間を減らす
4. 到着間隔(時間帯の `duration / customer_count`)ぶんの時間が溜まっただけ客を生成する。
   1回の `advance` で複数人になることがある。客ごとに店を選び、買い物を処理する
5. 試合時間を過ぎたら終了する

## 3.4 シグナル

`band_changed` `delivery_arrived` `customer_arrived(type_id, store_index)` `purchased(store_index, product_id, price)`
`price_changed` `skill_used` `match_ended(result)`。画面はこれを受けて表示を更新し、演出を出す。
`customer_arrived` は1秒に最大9回出るため、画面側は受けたものを溜めて、人の流れの演出にまとめて反映する。
