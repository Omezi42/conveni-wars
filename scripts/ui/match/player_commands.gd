class_name PlayerCommands
extends RefCounted
## 画面の操作の窓口(Architecture.md 4.1節・7.2節)。CPU戦はそのまま MatchState のコマンドを呼ぶ。
## オンライン対戦は Lockstep へ予約し、押した直後の手応えのために、いまの状態で通るかどうかを返す。

var match_state: MatchState
## null なら CPU戦
var lockstep: Lockstep


func _init(state: MatchState, net: Lockstep = null) -> void:
	match_state = state
	lockstep = net


func order(store_index: int, product_id: StringName) -> bool:
	if lockstep == null:
		return match_state.order(store_index, product_id)
	return _defer(
		match_state.can_order(store_index, product_id), MatchRecord.Kind.ORDER, product_id, 0
	)


func assign(store_index: int, product_id: StringName, slot: int) -> bool:
	if lockstep == null:
		return match_state.assign(store_index, product_id, slot)
	return _defer(true, MatchRecord.Kind.ASSIGN, product_id, slot)


func unassign(store_index: int, slot: int) -> bool:
	if lockstep == null:
		return match_state.unassign(store_index, slot)
	return _defer(true, MatchRecord.Kind.UNASSIGN, &"", slot)


func set_auto_order(store_index: int, product_id: StringName, on: bool) -> bool:
	if lockstep == null:
		return match_state.set_auto_order(store_index, product_id, on)
	return _defer(true, MatchRecord.Kind.AUTO_ORDER, product_id, int(on))


func set_price_step(store_index: int, product_id: StringName, step: int) -> bool:
	if lockstep == null:
		return match_state.set_price_step(store_index, product_id, step)
	return _defer(
		match_state.can_set_price(store_index, product_id), MatchRecord.Kind.PRICE, product_id, step
	)


func use_active(store_index: int) -> bool:
	if lockstep == null:
		return match_state.use_active(store_index)
	return _defer(match_state.can_use_active(store_index), MatchRecord.Kind.ACTIVE, &"", 0)


func _defer(ok: bool, kind: MatchRecord.Kind, product_id: StringName, value: int) -> bool:
	if ok:
		lockstep.submit(kind, product_id, value)
	return ok
