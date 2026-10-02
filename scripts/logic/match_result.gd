class_name MatchResult
extends RefCounted
## 試合の結果(GameDesign.md 1.4節・9.4節)。

const DRAW := -1

## 勝った店の番号。引き分けは DRAW
var winner: int = DRAW
var stores: Array[StoreState] = []
var history: MatchHistory
