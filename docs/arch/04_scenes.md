# 4章 シーン構成

| シーン | スクリプト | 責務 |
|---|---|---|
| `scenes/title.tscn` | `scripts/ui/title_screen.gd` | タイトル。背景で `TitleStreet` が CPU どうしの `MatchState` を回し、見える客を2軒の店へ歩かせる |
| `scenes/manager_select.tscn` | `scripts/ui/manager_select_screen.gd` | 店長の選択(GameDesign.md 7章) |
| `scenes/match.tscn` | `scripts/ui/match/match_controller.gd` | `MatchState` を持ち、進行させ、子の表示へ渡す |
| `scenes/online_lobby.tscn` | `scripts/ui/online_lobby_screen.gd` | オンライン対戦の部屋(7.3節) |
| `scenes/result.tscn` | `scripts/ui/result_screen.gd` | 結果(9.4節)。2枚のレシートのあいだに `ProfitChart`(`scripts/ui/profit_chart.gd`)を置く。時間帯ごとの割合の下に、`StoreState` が数えた負けた理由のうち最多のものを出す。`_process` で `CpuReview` を1フレームの予算ぶん進め、できた文を `ProfitChart` の下段に出す。共有ボタンの処理は `ResultShare`(`scripts/ui/result_share.gd`)へ分ける(4.4節) |

## 4.1 試合画面の部品(GameDesign.md 9.2節・9.3節)

各部品は `MatchPart`(`setup(match_state, store_index)` と毎フレームの描き直しを持つ Control)を継承し、
`MatchState` を受け取って表示し、操作は `commands`(`PlayerCommands`。7.2節)のコマンドとして呼ぶだけにする。
自店の番号と店の色・呼び名は `ViewSide` で引く(オンライン対戦で部屋に入った側は自店が店1のため。7.2節)。
品ぞろえでタップして選んだ商品は `UiSelection`(RefCounted)に持ち、`CatalogView` と `ShelfView` で共有する。

| 部品 | 内容 |
|---|---|
| `HudBar` | 左=時間帯・天気の絵と名前・1日の進み・残り時間の1枚の札、右=両店の利益の綱引きと、その下にいまの時間帯の自店の客の割合の札 |
| `ForecastPanel` | 次の時間帯に欲しがられるカテゴリ(`MatchState.band_mix` の割合×欲しい重みの合計の大きい順)を商品の絵とカテゴリ名で。自店の棚に在庫ありで並ぶカテゴリにチェック。突発イベントの予告中は枠全体を予告に切り替える |
| `ShelfView` | 3×3の棚。自店は操作可でボーナスの札と、右の列に在庫数・廃棄バー・入荷待ち・発注ボタンまで出す。マスを別のマスへドラッグすると同じ商品を写す。相手は絵と値札だけの表示(同じ部品を使い分ける) |
| `PriceMenu` | 値段の3段階のボタン・棚から外す・自動発注の切り替え |
| `CatalogView` | 品ぞろえの帯。棚に出ていない商品の札だけをカテゴリ順に並べ、在庫数・廃棄バー・入荷待ち・発注ボタンを出す。札の幅は並べる数で帯を割る。札から棚へドラッグする(またはタップで選ぶ) |
| `StockGauge` | 廃棄バー・入荷待ちの札・発注ボタンの描き方と、発注ボタンの乗せた・押した・成否の光りの状態(RefCounted)。自動発注がオンの商品は「自動」と緑の枠で描く。`ShelfView` と `CatalogView` が1つずつ持つ |
| `BonusHelp` | 自店の看板の「?」。乗せるか押すと棚の上にボーナスの見方を重ねる |
| `SkillButton` | アクティブスキルと、その左の資金の硬貨 |
| `StoreFrame` | 店の建物(看板と帯・床・入口)。棚はこの上に重ねる。自店は看板に取り逃した客の数の札を出す。相手の店は `compact` で小さく描く |
| `CustomerFlow` | 2軒のあいだの通りと、両店の入口へ流れ込む人の流れ。`customer_arrived` を間引いて「見える客」(客層の絵と欲しい物の吹き出し)を歩かせ、自店へ入ったら `ShelfView` のそのマスを光らせる。自店が取り逃した客は優先して見える客にする |
| `PauseMenu` | 一時停止(9.9節)。画面全体を覆う幕と「続ける」「やり直す」「タイトルへ」。開いている間 `MatchController` は `advance` とCPUを呼ばない。上端の右端の `PopButton`・Esc・窓から離れたとき(`NOTIFICATION_APPLICATION_FOCUS_OUT`)に開く |
| `FxLayer` | 自店の「+¥160」の飛び出し・時間帯のカットインと終わった時間帯の成績(1行の文言は `MatchController` が `StoreState` の負けた理由から作る)・「大口獲得!」・利益の逆転の表示 |

画面間の受け渡し(選んだ店長・CPUの強さ・試合結果・自己ベストと勝ち星が増えたか)は autoload の `GameSession` が持つ。
戦績が無いときのタイトルの「はじめる」は、`GameSession` が既定の店長(`FIRST_MANAGER_ID`)で試合を用意して、店長選択を飛ばす。
天気は `GameSession.weather_id` で `MatchState` へ渡す。戦績が無ければ `FIRST_WEATHER_ID`(晴れ)、あれば空(種から引く)。

## 4.3 保存・音・ヒント(GameDesign.md 9.7節・9.8節)

| 部品 | 内容 |
|---|---|
| `SaveData`(`scripts/save_data.gd`、RefCounted) | 戦績(勝ち・負け・引き分け・店長ごとの自己ベスト・店長ごとの勝ち星=勝ったCPUの強さのidの列・最後のCPUの強さ・出したヒントのid)と設定(音量2つ)を `user://save.cfg` に `ConfigFile` で読み書きする。`GameSession` が1つ持つ |
| `AudioDirector`(autoload) | BGMの再生と切り替え・速さ、効果音の再生。効果音は id → `AudioStream` の表を持ち、同じ音は0.1秒に1回までに間引く。Master・BGM・SE の3つのバスの音量を設定から反映する |
| `MatchSounds`(`scripts/ui/match/match_sounds.gd`、Node) | 試合のシグナルを受けて `AudioDirector` に効果音を頼む。売上の音程の上がり方もここで持つ |
| `HintLayer`(`scripts/ui/match/hint_layer.gd`) | ヒント。試合のシグナルからきっかけを判定し、まだ出していないヒントを1つずつ、指す部品の矩形へ向けた吹き出しで出す。試合も入力も止めない(`mouse_filter` は IGNORE)。出したら `SaveData` に記録する |
| `SettingsPanel`(`scripts/ui/settings_panel.gd`) | タイトルに重ねる設定の札(音量2つ・全画面) |

- 音の素材は `assets/audio/{bgm,se}/`。出典は `assets/audio/CREDITS.md`
- 効果音の id と素材の対応は `AudioDirector` の表の1か所にまとめる(素材を差し替えるときはファイルを上書きするだけで済むよう、ファイル名は id と同じにする)

## 4.2 見た目の部品(GameDesign.md 9.5節)

UIクロームはすべてコードで描く。色・文字の大きさ・線の太さは `UiPalette`、描き方は `UiDraw` の1か所に集める。

| 部品 | 内容 |
|---|---|
| `UiPalette` | 色・文字の大きさ(最小 `FONT_SMALL` = 16px。9.5節)・輪郭線の太さ・影をずらす量 |
| `UiDraw` | 輪郭線と影のあるパネル(`card`)・縁取りした文字・幅に収める文字の大きさ(`fit_size`)・グラデーション・縞・商品/カテゴリ/客層の絵(足もとの影つき。絵が無いときは仮アイコン)・空の小窓・硬貨・注意の印・吹き出し・光の筋・緑のチェックの札 |
| `PopButton` | 輪郭線と影のあるボタン。押すと沈み、`chosen` でチェックを付ける。`caption` で上に小さな1行 |
| `VisibleCustomers`(RefCounted) | 見える客(9.2節)。来店を1秒に1人ほどに間引き(`priority_store` の店が取り逃した客は別の間隔で優先)、客層の絵と吹き出しを曲線に沿って歩かせる。道は呼ぶ側(`CustomerFlow`・`TitleStreet`)が付ける。`customer_lost` は `customer_arrived` より先に届くので、`note_lost` で控えて次の来店に付ける |
| `SkyBackdrop` | 背景の空。試合中は `set_band()` で時間帯の空(天気の `sky_tint` を混ぜた色)へ移る。空だけを描く `paint()` はタイトル・店長選択・結果も使う |

- 商品・客層・店長・天気の絵は `assets/icons/{products,customers,managers,weather}/<データのid>.png`(256px・背景は透明)。同じ名前で上書きすれば差し替わる
- 生成AIで作った「無地の背景に絵を格子状に並べた1枚」は `python tools/slice_sheet.py` で切り分けて背景を抜く。
  輪郭の外に白い縁が付いた画像は `--rim 14` を付ける。背景の色は絵に使わない色(絵が緑なら背景はピンク)にする
  データの `icon` / `portrait` に入れる。空なら仮アイコンを描く
- 絵は256pxを小さく描くため、取り込みで mipmap を作り、画面の既定のフィルタを「Linear Mipmap」にしている(Pitfalls.md)
- フォントに無い記号(✓ ⚠ など)は文字で書かず `UiDraw` で形を描く(Pitfalls.md)

## 4.4 結果の共有(GameDesign.md 9.4節)

`ResultShare`(RefCounted)が、撮影・ファイル名・共有する文・保存先の振り分けを持つ。`ResultScreen` はボタンを押されたら
`_sharing` を立てて1フレーム描き直し(ボタンを隠し、下の帯に題字とCPUの強さを描く)、`RenderingServer.frame_post_draw` を待ってから
`ResultShare.capture()` を呼ぶ。共有ボタンは `CpuReview` が終わるまで `disabled` にする。

- 撮影:ルートのビューポートの画像から、`get_final_transform()` で求めた1280×720の範囲(黒帯を除く)を切り抜き、1280×720へ拡縮する
- 振り分け:`OS.has_feature("web")` なら `JavaScriptBridge.eval` で `pointer: coarse` と `navigator.canShare({files})` を確かめ、
  両方満たせば `navigator.share` に画像(base64から作った `File`)・文・`location.href` を渡す。それ以外は `JavaScriptBridge.download_buffer`。
  デスクトップは `OS.get_system_dir(SYSTEM_DIR_PICTURES)` の下の「コンビニウォーズ」へ `Image.save_png`
- `navigator.share` は押した操作の直後(数秒以内)でないと断られるため、撮影は押した次のフレームで済ませる
