# 6章 テストと検証

- `bash tools/check.sh` で gdformat → gdlint → フォントの字の確認 → ヘッドレステスト → 起動スモーク を順に回す
- ヘッドレステストは `tools/tests/run_tests.gd`。ロジック層(3章)を種固定の乱数で動かし、魅力度・ボーナス・
  買い物・発注・スキルの結果を確かめる
- `tools/tests/replay_tests.gd` は、プレイヤーの店をCPUに動かさせた試合の `MatchRecord` を再生して両店の成績が完全に一致するか、
  途中のスナップショットから進めた試合が元と一致するか、`CpuReview` が文を作れるかを確かめる
- `tools/simulate.gd` で CPU 対 CPU を多数回まわし、店長ごとの勝率・利益の分布・イベントの売上の割合・戦略ごとの勝率を出し、
  GameDesign.md 1.5節の調整の目標を満たすかを OK / NG で出す(バランス調整用。集計と表示は `tools/sim_report.gd`)
  - 店長は異なる2人の組み合わせごとに `games`(既定100)試合。席を入れ替えて半分ずつ、どちらも同じシードの一覧
    (`SEED_BASE` からの連番)で回す。同じ店長どうしの試合は回さない。変更前後は同じ試合群で比べられる
  - 勝率には95%信頼区間(Wilson)を添える。合否は点推定で出し、区間が目標をまたぐときは印を `~` にする
  - `jobs`(既定はCPUのコア数)個の Godot プロセスへ試合の一覧を分けて並列に回し、`logs/sim/` に書いた記録を集める
  - `save=名前` で記録を残し、`compare=名前` でその記録と店長の勝率を並べる。`set=店長.active.キー=値` / `set=balance.キー=値` で
    `.tres` を書き換えずにスキルや balance の数値を試せる
  - 店長だけを測るときは `managers` を付ける(1回およそ5分)
  - 天気(GameDesign.md 12章)は `weather=天気id` で1つに絞れる。付けなければ天気ごとに回して、天気ごとに判定する
- UI(`scripts/ui/`)は `tools/tests/screen_flow_smoke.gd` が実際のシーンを起こし、タイトル →(戦績なしは店長選択を飛ばす)店長選択 → ヒント →
  試合(両店ともCPUに操作させて早回し)→ 結果 を通す。最後に起動スモークでパースエラーを拾う
- 画面の見た目は `godot --path . --script res://tools/capture_screens.gd -- <出力フォルダ>` でスクリーンショットを撮り、人が見る
  (ウィンドウを開くため `--headless` では撮れない)
- テストとスクリーンショットは本物の戦績に触れないよう、`GameSession.save` をテスト用のファイル(`user://test_save.cfg`)に
  差し替え、終わったら消す
- Web版は `bash tools/export_web.sh` で `build/web/` へ書き出し、書き出したpckでヘッドレステストを回してから、
  ファイルごとの大きさ(そのまま / gzip)を出す。`build/` と `logs/` には `.gdignore` を置き、書き出しやスクリーンショットの絵がpckへ入らないようにする
- unityroom へ上げる物(pck・サムネイルのGIF・スクリーンショット・投稿文)は `tools/unityroom/README.md` にまとめる。
  サムネイルは `tools/unityroom/thumbnail_art.gd` が描くループの絵を `record_icon.gd` が2倍の大きさでコマに書き出す。
  紹介用の動きとスクリーンショットは `record_thumbnail.gd` が両店をCPUに遊ばせた試合を `--fixed-fps` で書き出す。
  どちらも `tools/unityroom/make_thumbnails.sh` が ImageMagick でGIFにする
- フォント(GameDesign.md 10章)は、元の `tools/font_src/ZenKakuGothicNew-Bold.ttf`(`.gdignore` で書き出しから外す)を
  `python tools/subset_font.py` で絞り、`assets/fonts/` の同じ名前へ書く。残す字は ASCII・かな・全角英数・記号の一揃いと、
  `scripts/` `data/` `scenes/` の文字列に出てくる字。check.sh はその字がフォントにあるかを確かめ、足りなければ NG にする
  (文言を足して NG が出たら `subset_font.py` を回し直す)
- Webの読み込み中の絵(GameDesign.md 10章)は `application/boot_splash/image` の `assets/boot_splash.png`。
  タイトルからボタンと歩く客を除いて `godot --path . --script res://tools/capture_boot_splash.gd` で撮る。タイトルの絵を変えたら撮り直す
