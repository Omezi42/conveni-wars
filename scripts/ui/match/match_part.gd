class_name MatchPart
extends Control
## 試合画面の部品の共通部分(Architecture.md 4.1節)。MatchState を読んで毎フレーム描き直し、
## 操作はコマンドとして呼ぶだけにする。

## 点滅の速さ(1秒あたりの回数)
const BLINK_HZ := 2.5

var match_state: MatchState
var store_index := 0


func setup(state: MatchState, index: int) -> void:
	match_state = state
	store_index = index


func _process(_delta: float) -> void:
	if match_state != null:
		queue_redraw()


func store() -> StoreState:
	return match_state.stores[store_index]


func db() -> GameDatabase:
	return match_state.db


## 点滅の明るさ(0〜1)
static func blink() -> float:
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * BLINK_HZ)
