# 3章 ロジック層

## 3.1 クラス

| クラス | 責務 |
|---|---|
| `MatchState` | 試合の唯一の状態。時計・時間帯・両店・乱数・客の到着。コマンドとシグナルの窓口 |
| `StoreState` | 1店ぶんの状態。資金・売上・来店数・棚(`SlotState` ×9)・倉庫・発注中・値段段階・値段の冷却・店長・スキルの効果時間 |
| `SlotState` | 1マス。商品idと在庫数 |
| `Attraction` | 魅力度の計算(静的関数だけ)。店と客層を受け取り、棚の倍率・値段補正・パッシブを掛けた点を返す(GameDesign.md 2.4節・4章・5.2節) |
| `ShelfBonus` | 棚の倍率の計算(静的関数だけ)。目玉・コーナー・セットを判定し、マスごとの倍率と成立したボーナスの一覧を返す |
| `ManagerSkills` | パッシブの補正値の問い合わせと、アクティブの発動・効果時間の管理(7章) |

## 3.2 コマンド

画面とCPUは次だけを呼ぶ。成否を `bool` で返し、失敗時は状態を変えない。

- `order(store_index, product_id)` 発注(資金不足なら失敗)
- `place(store_index, product_id, slot_index)` 倉庫→棚
- `unplace(store_index, slot_index)` 棚→倉庫
- `set_price_step(store_index, product_id, step)` 値段(冷却中・値札ロック中なら失敗)
- `use_active(store_index)` アクティブスキル(使用済み・開店準備中なら失敗)

## 3.3 進行

`MatchState.advance(delta)` を `MatchController`(画面側のNode)が `_physics_process` から呼ぶ。1回の中で順に:

1. 時計を進め、時間帯の切り替わりを判定する
2. 発注の残り時間を減らし、0になったものを倉庫へ入れる
3. 値段の冷却とスキルの効果時間を減らす
4. 客の到着間隔を満たしたら客を1人生成し、店を選び、買い物を処理する
5. 試合時間を過ぎたら終了する

## 3.4 シグナル

`band_changed` `delivery_arrived` `customer_arrived(type_id, store_index)` `purchased(store_index, product_id, price)`
`price_changed` `skill_used` `match_ended(result)`。画面はこれを受けて表示を更新し、演出を出す。
