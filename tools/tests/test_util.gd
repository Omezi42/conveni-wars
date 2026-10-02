extends RefCounted
## テストで使う試合の組み立て。


static func db() -> GameDatabase:
	return GameDatabase.get_default()


static func new_match(
	manager_a: StringName = &"veteran", manager_b: StringName = &"veteran", seed_value := 1
) -> MatchState:
	var ids: Array[StringName] = [manager_a, manager_b]
	var match_state := MatchState.new(db(), ids, seed_value)
	for store in match_state.stores:
		clear_store(match_state, store.index)
	return match_state


## 開店時の棚と在庫を外し、空の店にする(棚と在庫を自分で組むテスト用)
static func clear_store(match_state: MatchState, store_index: int) -> void:
	for slot in StoreState.SLOT_COUNT:
		match_state.unassign(store_index, slot)
	match_state.stores[store_index]._lots.clear()
	match_state.stores[store_index].mark_dirty()


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
