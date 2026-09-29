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
| `HudBar` | 左=時計・時間帯・1日の進み・残り時間の1枚の札、右=両店の売上の綱引きと客数の細いバー |
| `ForecastPanel` | 次の時間帯に欲しがられるカテゴリ(客層の割合×欲しい重みの合計の大きい順)と来る客層。突発イベントの予告中は枠全体を予告に切り替える |
| `ShelfView` | 3×3の棚。自店は操作可で名前・ボーナスの札と、右の列に在庫数・廃棄バー・入荷待ち・発注ボタンまで出す。相手は表示だけ(同じ部品を使い分ける) |
| `PriceMenu` | 値段の3段階のボタン |
| `CatalogView` | 品ぞろえの帯。全商品の小さな札をカテゴリ順に並べる。棚に出ていない商品は在庫数・廃棄バー・入荷待ち・発注ボタン、出ている商品は「陳列中」と薄く。札から棚へドラッグする(またはタップで選ぶ) |
| `StockGauge` | 廃棄バー・入荷待ちの札・発注ボタンの描き方と、発注ボタンの乗せた・押した・成否の光りの状態(RefCounted)。`ShelfView` と `CatalogView` が1つずつ持つ |
| `BonusHelp` | 自店の看板の「?」。乗せるか押すと棚の上にボーナスの見方を重ねる |
| `SkillButton` | アクティブスキル |
| `StoreFrame` | 店の建物(看板と帯・床・入口)。棚はこの上に重ねる。自店は看板に取り逃した客の数の札を出す。相手の店は `compact` で小さく描く |
| `CustomerFlow` | 2軒のあいだの通りと、両店の入口へ流れ込む人の流れ・取り逃した客の吹き出し(1人ずつは描かない) |
| `FxLayer` | 自店の「+¥160」の飛び出し・時間帯のカットイン・「大口獲得!」・逆転の表示 |

画面間の受け渡し(選んだ店長・CPUの強さ・試合結果・ガイドを出すか)は autoload の `GameSession` が持つ。

## 4.3 保存・音・ガイド(GameDesign.md 9.7節・9.8節)

| 部品 | 内容 |
|---|---|
| `SaveData`(`scripts/save_data.gd`、RefCounted) | 戦績(勝ち・負け・引き分け・店長ごとの自己ベスト・最後のCPUの強さ)と設定(音量2つ)を `user://save.cfg` に `ConfigFile` で読み書きする。`GameSession` が1つ持つ |
| `AudioDirector`(autoload) | BGMの再生と切り替え・速さ、効果音の再生。効果音は id → `AudioStream` の表を持ち、同じ音は0.1秒に1回までに間引く。Master・BGM・SE の3つのバスの音量を設定から反映する |
| `MatchSounds`(`scripts/ui/match/match_sounds.gd`、Node) | 試合のシグナルを受けて `AudioDirector` に効果音を頼む。売上の音程の上がり方もここで持つ |
| `GuideOverlay`(`scripts/ui/match/guide_overlay.gd`) | 初回ガイド。黒い幕と、指す部品の矩形の穴、説明の札と「次へ」「とばす」。出ている間は `MatchController` が開店準備の時計を止める |
| `SettingsPanel`(`scripts/ui/settings_panel.gd`) | タイトルに重ねる設定の札(音量2つ・全画面) |

- 音の素材は `assets/audio/{bgm,se}/`。出典は `assets/audio/CREDITS.md`
- 効果音の id と素材の対応は `AudioDirector` の表の1か所にまとめる(素材を差し替えるときはファイルを上書きするだけで済むよう、ファイル名は id と同じにする)

## 4.2 見た目の部品(GameDesign.md 9.5節)

UIクロームはすべてコードで描く。色・文字の大きさ・線の太さは `UiPalette`、描き方は `UiDraw` の1か所に集める。

| 部品 | 内容 |
|---|---|
| `UiPalette` | 色・文字の大きさ・輪郭線の太さ・影をずらす量 |
| `UiDraw` | 輪郭線と影のあるパネル(`card`)・縁取りした文字・幅に収める文字の大きさ(`fit_size`)・グラデーション・縞・商品/カテゴリ/客層の絵(足もとの影つき。絵が無いときは仮アイコン)・空の小窓・硬貨・注意の印・吹き出し・光の筋 |
| `PopButton` | 輪郭線と影のあるボタン。押すと沈み、`chosen` でチェックを付ける。`caption` で上に小さな1行 |
| `SkyBackdrop` | 背景の空。試合中は `set_band()` で時間帯の空へ移る。空だけを描く `paint()` はタイトル・店長選択・結果も使う |

- 商品・客層・店長の絵は `assets/icons/{products,customers,managers}/<データのid>.png`(256px・背景は透明)。同じ名前で上書きすれば差し替わる
- 生成AIで作った「無地の背景に絵を格子状に並べた1枚」は `python tools/slice_sheet.py` で切り分けて背景を抜く。
  輪郭の外に白い縁が付いた画像は `--rim 14` を付ける。背景の色は絵に使わない色(絵が緑なら背景はピンク)にする
  データの `icon` / `portrait` に入れる。空なら仮アイコンを描く
- 絵は256pxを小さく描くため、取り込みで mipmap を作り、画面の既定のフィルタを「Linear Mipmap」にしている(Pitfalls.md)
- フォントに無い記号(✓ ⚠ など)は文字で書かず `UiDraw` で形を描く(Pitfalls.md)
