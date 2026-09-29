# 6章 テストと検証

- `bash tools/check.sh` で gdformat → gdlint → ヘッドレステスト → 起動スモーク を順に回す
- ヘッドレステストは `tools/tests/run_tests.gd`。ロジック層(3章)を種固定の乱数で動かし、魅力度・ボーナス・
  買い物・発注・スキルの結果を確かめる
- `tools/simulate.gd` で CPU 対 CPU を多数回まわし、店長ごとの勝率と売上の分布を出す(バランス調整用)
- UI(`scripts/ui/`)はテストが読まないため、起動スモークでパースエラーを拾う
