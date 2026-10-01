# 6章 テストと検証

- `bash tools/check.sh` で gdformat → gdlint → ヘッドレステスト → 起動スモーク を順に回す
- ヘッドレステストは `tools/tests/run_tests.gd`。ロジック層(3章)を種固定の乱数で動かし、魅力度・ボーナス・
  買い物・発注・スキルの結果を確かめる
- `tools/simulate.gd` で CPU 対 CPU を多数回まわし、店長ごとの勝率・利益の分布・イベントの売上の割合・戦略ごとの勝率を出し、
  GameDesign.md 1.5節の調整の目標を満たすかを OK / NG で出す(バランス調整用)
- UI(`scripts/ui/`)は `tools/tests/screen_flow_smoke.gd` が実際のシーンを起こし、タイトル →(戦績なしは店長選択を飛ばす)店長選択 → ヒント →
  試合(両店ともCPUに操作させて早回し)→ 結果 を通す。最後に起動スモークでパースエラーを拾う
- 画面の見た目は `godot --path . --script res://tools/capture_screens.gd -- <出力フォルダ>` でスクリーンショットを撮り、人が見る
  (ウィンドウを開くため `--headless` では撮れない)
- テストとスクリーンショットは本物の戦績に触れないよう、`GameSession.save` をテスト用のファイル(`user://test_save.cfg`)に
  差し替え、終わったら消す
