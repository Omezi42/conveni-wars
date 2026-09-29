# 4章 シーン構成

| シーン | スクリプト | 責務 |
|---|---|---|
| `scenes/title.tscn` | `scripts/ui/title_screen.gd` | タイトル |
| `scenes/manager_select.tscn` | `scripts/ui/manager_select_screen.gd` | 店長の選択(GameDesign.md 7章) |
| `scenes/match.tscn` | `scripts/ui/match/match_controller.gd` | `MatchState` を持ち、進行させ、子の表示へ渡す |
| `scenes/result.tscn` | `scripts/ui/result_screen.gd` | 結果(9.4節) |

## 4.1 試合画面の部品(GameDesign.md 9.2節・9.3節)

各部品は `MatchState` を受け取って表示し、操作はコマンドとして呼ぶだけにする。

| 部品 | 内容 |
|---|---|
| `HudBar` | 店の時計・残り時間・時間帯・両店の売上 |
| `ForecastPanel` | 次の時間帯の客層予報と、突発イベントの予告 |
| `ShelfView` | 3×3の棚。自店は操作可、相手は表示だけ(同じ部品を使い分ける) |
| `PriceMenu` | 値段の3段階のボタン |
| `InventoryView` | 在庫一覧。商品ごとのカードに在庫数・棚に出ているか・廃棄までの残り秒数・発注中と、発注ボタン。カードから棚へドラッグする(またはタップで選ぶ) |
| `BonusBoard` | 自店の棚の横の、成立しているボーナスの一覧とボーナスの見方 |
| `VisitCounter` | 客層ごとの来店数と取り逃した客の数(両店ぶん) |
| `SkillButton` | アクティブスキル |
| `StoreFrame` | 店の建物(看板と帯・床・入口)。棚はこの上に重ねる。相手の店は `compact` で小さく描く |
| `CustomerFlow` | 2軒のあいだの通りと、両店の入口へ流れ込む人の流れ・取り逃した客の吹き出し(1人ずつは描かない) |
| `FxLayer` | 「+¥160」の飛び出し・時間帯のカットイン・「大口獲得!」・逆転の表示 |

画面間の受け渡し(選んだ店長・試合結果)は autoload の `GameSession` が持つ。

## 4.2 見た目の部品(GameDesign.md 9.5節)

UIクロームはすべてコードで描く。色・文字の大きさ・線の太さは `UiPalette`、描き方は `UiDraw` の1か所に集める。

| 部品 | 内容 |
|---|---|
| `UiPalette` | 色・文字の大きさ・輪郭線の太さ・影をずらす量 |
| `UiDraw` | 輪郭線と影のあるパネル(`card`)・縁取りした文字・幅に収める文字の大きさ(`fit_size`)・グラデーション・縞・商品と客層の仮アイコン・空の小窓・硬貨・注意の印・吹き出し・光の筋 |
| `PopButton` | 輪郭線と影のあるボタン。押すと沈み、`chosen` でチェックを付ける。`caption` で上に小さな1行 |
| `SkyBackdrop` | 背景の空。試合中は `set_band()` で時間帯の空へ移る。空だけを描く `paint()` はタイトル・店長選択・結果も使う |

- イラスト(商品・客層・店長)が届いたら、データの `icon` / `portrait` を入れるだけで仮アイコンと差し替わる
- フォントに無い記号(✓ ⚠ など)は文字で書かず `UiDraw` で形を描く(Pitfalls.md)
