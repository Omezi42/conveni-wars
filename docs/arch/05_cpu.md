# 5章 CPUの実装

- `CpuPlayer`(`scripts/cpu/cpu_player.gd`、`RefCounted`)が `MatchState` と自店の番号を持つ
- `MatchController` が `advance()` のあとに `CpuPlayer.update(delta)` を呼ぶ。判断の間隔(GameDesign.md 8.2節)が
  来たら、発注 → 配置 → 値付け → スキルの順に判断し、3.2節のコマンドだけを呼ぶ
- CPUが読む情報はプレイヤーの画面に出ているものに限る(客層予報・イベントの予告・相手の棚と値段)。
  `MatchState` の内部(次のイベントの抽選結果など)は読まない
- 強さの段階(8.3節)は `CpuProfile`(Resource、`data/cpu/{easy,standard,hard}.tres`)で持つ。予告への反応の遅れ・読み違える確率などの数値をここに置く。
  並び順は `order`
- `tools/simulate.gd` は `CpuPlayer` を継承した戦略(`tools/sim_strategies.gd`:固定の棚・常に強気・常に安売り・買い溜め)を
  ふつうのCPUと戦わせ、1.5節の調整の目標を満たすかを出す
- CPUは `MatchState` の乱数を使う(試合の再現性を保つため)
- `use_skill` を false にするとアクティブスキルを使わない(結果画面の計算し直しでプレイヤーの代わりに動かすとき。3.5節)。
  `duplicate_for(match_state)` は判断の間隔・予告の読みなどの内部の状態ごと写す(スナップショット用)
- 需要の見積もり(`estimate_demand`):いまと予報の時間帯の来店数 × 自店へ来ると見込む割合を、客層ごとに
  「1つのカテゴリに1商品を置く前提で、重い順に買う個数を割り振る」やり方でカテゴリへ配る。予告を見て反応の秒数がたったら、
  イベントの客(読み違えを含む)のぶんを足す。在庫と発注中の合計がこれに足りないカテゴリを発注し、
  日持ちしない商品は廃棄までの秒数ぶんの見込みを上限にする
