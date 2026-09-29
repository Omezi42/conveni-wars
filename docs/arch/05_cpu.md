# 5章 CPUの実装

- `CpuPlayer`(`scripts/cpu/cpu_player.gd`、`RefCounted`)が `MatchState` と自店の番号を持つ
- `MatchController` が `advance()` のあとに `CpuPlayer.update(delta)` を呼ぶ。判断の間隔(GameDesign.md 8.2節)が
  来たら、発注 → 陳列 → 値付け → スキルの順に判断し、3.2節のコマンドだけを呼ぶ
- CPUは `MatchState` の乱数を使う(試合の再現性を保つため)
- 間隔などの数値は `BalanceConfig` に持つ
