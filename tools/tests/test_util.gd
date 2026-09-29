extends RefCounted
## テストで使う試合の組み立て。


static func db() -> GameDatabase:
	return GameDatabase.get_default()


static func new_match(
	manager_a: StringName = &"veteran", manager_b: StringName = &"veteran", seed_value := 1
) -> MatchState:
	var ids: Array[StringName] = [manager_a, manager_b]
	return MatchState.new(db(), ids, seed_value)


## 開店準備を飛ばして開店した直後にする
static func open(match_state: MatchState) -> void:
	match_state.advance(match_state.prep_remaining())


## 在庫を入れてマスへ置く
static func stock_slot(
	match_state: MatchState, store_index: int, product_id: StringName, slot: int, count := 30
) -> void:
	match_state.deliver(store_index, product_id, count)
	match_state.assign(store_index, product_id, slot)


static func customer(id: StringName) -> CustomerTypeData:
	return db().customer_type(id)


static func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
