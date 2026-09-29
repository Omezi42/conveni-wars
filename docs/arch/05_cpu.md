# 5章 CPUの実装

- `CpuPlayer`(`scripts/cpu/cpu_player.gd`、`RefCounted`)が `MatchState` と自店の番号を持つ
- `MatchController` が `advance()` のあとに `CpuPlayer.update(delta)` を呼ぶ。判断の間隔(GameDesign.md 8.2節)が
  来たら、発注 → 配置 → 値付け → スキルの順に判断し、3.2節のコマンドだけを呼ぶ
- CPUが読む情報はプレイヤーの画面に出ているものに限る(客層予報・イベントの予告・相手の棚と値段)。
  `MatchState` の内部(次のイベントの抽選結果など)は読まない
- 強さの段階(8.3節)は `CpuProfile`(Resource)で持つ。予告への反応の遅れ・読み違える確率などの数値をここに置く
- CPUは `MatchState` の乱数を使う(試合の再現性を保つため)
