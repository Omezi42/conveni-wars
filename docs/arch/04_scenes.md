# 4章 シーン構成

| シーン | スクリプト | 責務 |
|---|---|---|
| `scenes/title.tscn` | `scripts/ui/title_screen.gd` | タイトル |
| `scenes/manager_select.tscn` | `scripts/ui/manager_select_screen.gd` | 店長の選択(GameDesign.md 7章) |
| `scenes/match.tscn` | `scripts/ui/match_controller.gd` | `MatchState` を持ち、進行させ、子の表示へ渡す |
| `scenes/result.tscn` | `scripts/ui/result_screen.gd` | 結果(9.3節) |

## 4.1 試合画面の部品(GameDesign.md 9.2節)

各部品は `MatchState` を受け取って表示し、操作はコマンドとして呼ぶだけにする。

| 部品 | 内容 |
|---|---|
| `HudBar` | 店の時計・残り時間・時間帯・両店の売上 |
| `ForecastPanel` | 次の時間帯の客層予報 |
| `ShelfView` | 3×3の棚。自店は操作可、相手は表示だけ(同じ部品を使い分ける) |
| `PriceMenu` | 値段の5段階メニュー |
| `OrderPanel` | 発注 |
| `InventoryView` | 商品ごとの在庫数と発注中。ここから棚へドラッグする |
| `VisitCounter` | 客層ごとの来店数(両店ぶん) |
| `SkillButton` | アクティブスキル |
| `CustomerFlow` | 両店の入口へ流れ込む人の流れの演出(1人ずつは描かない) |

画面間の受け渡し(選んだ店長・試合結果)は autoload の `GameSession` が持つ。
