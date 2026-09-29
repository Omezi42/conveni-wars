# 4章 シーン構成

| シーン | スクリプト | 責務 |
|---|---|---|
| `scenes/title.tscn` | `scripts/ui/title_screen.gd` | タイトル |
| `scenes/manager_select.tscn` | `scripts/ui/manager_select_screen.gd` | 店長の選択(GameDesign.md 7章) |
| `scenes/match.tscn` | `scripts/ui/match_controller.gd` | `MatchState` を持ち、進行させ、子の表示へ渡す |
| `scenes/result.tscn` | `scripts/ui/result_screen.gd` | 結果(9.4節) |

## 4.1 試合画面の部品(GameDesign.md 9.2節・9.3節)

各部品は `MatchState` を受け取って表示し、操作はコマンドとして呼ぶだけにする。

| 部品 | 内容 |
|---|---|
| `HudBar` | 両店の名前と売上・売上の取り分の帯、中央に時間帯・店の時計・残り時間 |
| `ProductGrid` | 商品タイル(在庫数・廃棄までの残り秒数・入荷・発注ボタン)。タップで選び、ドラッグで棚へ置く |
| `SkillButton` | 資金と、店長の顔つきのアクティブスキル |
| `ForecastPanel` | 客層予報(いまと次を横に並べる) |
| `CustomerFlow` | 背景の2軒の扉へ流れ込む人の流れと、取り逃した客の吹き出し(1人ずつは描かない) |
| `EventBanner` | 突発イベントの予告と発生中の帯 |
| `StoreFrame` + `ShelfView` | 3×3の棚とその枠。自店は操作可、相手は表示だけ(同じ部品を大きさを変えて使う) |
| `PricePanel` | 値付けパネル(値段の3段階・棚から外す) |
| `BonusPanel` | 目玉・コーナー・セットの一覧と、成立しているもの |
| `VisitCounter` | 客層ごとの来店数と取り逃した客の数(両店ぶん) |
| `FxLayer` | 「+¥160」の飛び出し・時間帯のカットイン・「大口獲得!」・逆転の表示 |

- 部品は `MatchPart` を継ぎ、毎フレーム `MatchState` を読んで描き直す
- 選択の状態は `UiSelection` が持つ。`product_id` は次にタップした棚のマスへ置く商品、
  `focus_product` / `focus_slot` は値付けパネルに出している商品とそのマス(タイルから選んだら -1)
- 背景は `TextureRect` に `assets/backgrounds/street.svg`。扉の位置は `MatchController.DOORS` に絵の座標で持つ
  (絵を差し替えたらここを合わせる)
- 色と文字の大きさは `UiPalette`、パネル・ボタン・アイコンの描き方は `UiDraw` に集める

画面間の受け渡し(選んだ店長・試合結果)は autoload の `GameSession` が持つ。
