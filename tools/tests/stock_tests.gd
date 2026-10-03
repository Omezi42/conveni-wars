extends RefCounted
## 発注・配送・廃棄・棚の割り当て・値段のコマンド(GameDesign.md 5章・6章)。

const T = preload("res://tools/tests/test_util.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_opening_shelf_is_stocked_for_free()
	_test_order_pays_and_arrives_after_delivery_time()
	_test_analyst_orders_arrive_sooner()
	_test_order_fails_without_funds()
	_test_veteran_pays_less()
	_test_perishable_lot_is_wasted_after_waste_time()
	_test_sales_take_the_oldest_lot_first()
	_test_assign_replaces_and_unassign_clears()
	_test_price_change_has_a_cooldown()
	_test_price_command_rejects_bad_input()


## 両店とも開店時の棚で始まり、在庫は無料で利益は0(GameDesign.md 1.6節)
func _test_opening_shelf_is_stocked_for_free() -> void:
	var ids: Array[StringName] = [&"veteran", &"idol"]
	var m := MatchState.new(T.db(), ids, 1)
	var shelf := m.balance.opening_shelf
	for store in m.stores:
		_assert.call(store.shelf == shelf, "the store opens with the opening shelf")
		_assert.call(store.stock(&"green_tea") == 30, "one free lot per opening product")
		_assert.call(store.profit() == 0 and store.funds == 30000, "the opening stock is free")
		_assert.call(store.shelf[StoreState.SLOT_COUNT - 1] == StoreState.EMPTY, "bottom row empty")
	var onigiri := m.stores[0].oldest_lot(&"salmon_onigiri")
	_assert.call(
		T.near(onigiri.expires_at, m.balance.waste_seconds),
		"opening stock spoils counted from the opening"
	)
	m.advance(1.0)
	_assert.call(m.stores[0].sales + m.stores[1].sales > 0, "customers buy from the first second")


func _test_order_pays_and_arrives_after_delivery_time() -> void:
	var m := T.new_match(&"idol", &"idol")
	var store := m.stores[0]
	_assert.call(m.order(0, &"salmon_onigiri"), "order succeeds")
	_assert.call(store.funds == 30000 - 90 * 30, "pays cost x 30 at once")
	_assert.call(
		store.spent == 90 * 30 and store.profit() == -90 * 30, "the cost counts against profit"
	)
	_assert.call(store.pending_count(&"salmon_onigiri") == 30, "30 on the way")
	m.advance(4.9)
	_assert.call(store.stock(&"salmon_onigiri") == 0, "not yet delivered at 4.9s")
	m.advance(0.2)
	_assert.call(store.stock(&"salmon_onigiri") == 30, "delivered after 5s")
	_assert.call(store.pending.is_empty(), "no longer pending")


func _test_analyst_orders_arrive_sooner() -> void:
	var m := T.new_match(&"analyst", &"idol")
	m.order(0, &"salmon_onigiri")
	m.order(1, &"salmon_onigiri")
	m.advance(2.1)
	_assert.call(m.stores[0].stock(&"salmon_onigiri") == 30, "the analyst's lot arrives after 2s")
	_assert.call(m.stores[1].stock(&"salmon_onigiri") == 0, "others still wait")


func _test_order_fails_without_funds() -> void:
	var m := T.new_match()
	m.stores[0].funds = 100
	_assert.call(not m.order(0, &"nori_bento"), "cannot order without funds")
	_assert.call(m.stores[0].funds == 100 and m.stores[0].pending.is_empty(), "nothing changes")


func _test_veteran_pays_less() -> void:
	var m := T.new_match(&"veteran", &"idol")
	_assert.call(m.lot_cost(0, &"salmon_onigiri") == 2646, "veteran lot is 2% off")
	_assert.call(m.lot_cost(1, &"salmon_onigiri") == 2700, "others pay the full cost")


func _test_perishable_lot_is_wasted_after_waste_time() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	m.deliver(0, &"salmon_onigiri", 30)
	m.deliver(0, &"green_tea", 30)
	var wasted := [0]
	m.wasted.connect(func(_s: int, _p: StringName, count: int) -> void: wasted[0] += count)
	var waste_seconds := m.balance.waste_seconds
	m.advance(waste_seconds - 0.1)
	_assert.call(store.stock(&"salmon_onigiri") == 30, "still on hand just before waste time")
	m.advance(0.2)
	_assert.call(store.stock(&"salmon_onigiri") == 0, "wasted after waste time")
	_assert.call(store.wasted_count == 30 and wasted[0] == 30, "wasted count is recorded")
	_assert.call(store.stock(&"green_tea") == 30, "drinks do not go bad")


func _test_sales_take_the_oldest_lot_first() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	m.deliver(0, &"salmon_onigiri", 30)
	m.advance(30.0)
	m.deliver(0, &"salmon_onigiri", 30)
	_assert.call(store.take(&"salmon_onigiri", 35) == 35, "takes across lots")
	var oldest := store.oldest_lot(&"salmon_onigiri")
	_assert.call(oldest.count == 25, "the first lot is used up first")
	_assert.call(
		T.near(oldest.expires_at, m.elapsed + m.balance.waste_seconds),
		"the remaining lot is the newer one"
	)


func _test_assign_replaces_and_unassign_clears() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	_assert.call(m.assign(0, &"cola", 2), "assign even before stock arrives")
	_assert.call(m.assign(0, &"beer", 2), "assigning over another product replaces it")
	_assert.call(store.shelf[2] == &"beer", "slot now holds beer")
	_assert.call(m.unassign(0, 2), "unassign")
	_assert.call(store.shelf[2] == StoreState.EMPTY, "slot is empty")
	_assert.call(not m.unassign(0, 2), "unassigning an empty slot fails")
	_assert.call(not m.assign(0, &"cola", 9), "slot out of range fails")
	_assert.call(not m.assign(0, &"nothing", 0), "unknown product fails")


func _test_price_change_has_a_cooldown() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	_assert.call(m.set_price_step(0, &"cola", 2), "raise price")
	_assert.call(store.sell_price(&"cola") == 190, "price follows the step")
	_assert.call(not m.set_price_step(0, &"cola", 0), "cannot change again within 10s")
	_assert.call(m.set_price_step(0, &"green_tea", 0), "other products are not blocked")
	m.advance(10.1)
	_assert.call(m.set_price_step(0, &"cola", 0), "can change again after 10s")


func _test_price_command_rejects_bad_input() -> void:
	var m := T.new_match()
	_assert.call(not m.set_price_step(0, &"cola", 1), "same step is not a change")
	_assert.call(not m.set_price_step(0, &"cola", 3), "no fourth step")
	_assert.call(m.stores[0].price_cooldown(&"cola") == 0.0, "failed change starts no cooldown")
