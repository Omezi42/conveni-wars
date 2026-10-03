extends RefCounted
## 自動発注(GameDesign.md 6.5節)。

const T = preload("res://tools/tests/test_util.gd")
const TEA: StringName = &"green_tea"
const STEP := 0.01

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_only_shelf_products_can_be_turned_on()
	_test_orders_one_lot_when_low_counting_pending()
	_test_waits_for_funds_and_stays_on()
	_test_turns_off_when_the_product_leaves_the_shelf()


func _test_only_shelf_products_can_be_turned_on() -> void:
	var m := T.new_match()
	_assert.call(not m.set_auto_order(0, TEA, true), "an off-shelf product cannot be turned on")
	m.assign(0, TEA, 0)
	_assert.call(m.set_auto_order(0, TEA, true), "a shelf product can be turned on")
	_assert.call(m.stores[0].auto_orders.has(TEA), "it is on")
	_assert.call(not m.set_auto_order(0, TEA, true), "turning on twice fails")
	_assert.call(not m.stores[1].auto_orders.has(TEA), "the rival is not affected")
	_assert.call(m.set_auto_order(0, TEA, false), "it can be turned off")
	_assert.call(not m.stores[0].auto_orders.has(TEA), "it is off")


func _test_orders_one_lot_when_low_counting_pending() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	var threshold := m.balance.auto_order_threshold
	m.assign(0, TEA, 0)
	m.deliver(0, TEA, threshold + 1)
	m.set_auto_order(0, TEA, true)
	m.advance(STEP)
	_assert.call(store.pending.is_empty(), "no order while above the threshold")
	store.take(TEA, 1)
	m.advance(STEP)
	_assert.call(store.pending_count(TEA) == m.balance.lot_size, "one lot ordered at the threshold")
	_assert.call(store.order_count == 1, "counted as an order")
	m.advance(STEP)
	_assert.call(store.pending_count(TEA) == m.balance.lot_size, "pending counts, no double order")


func _test_waits_for_funds_and_stays_on() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	m.assign(0, TEA, 0)
	m.set_auto_order(0, TEA, true)
	store.funds = 0
	m.advance(STEP)
	_assert.call(store.pending.is_empty(), "no order without funds")
	_assert.call(store.auto_orders.has(TEA), "it stays on")
	store.funds = m.lot_cost(0, TEA)
	m.advance(STEP)
	_assert.call(store.pending_count(TEA) == m.balance.lot_size, "orders once funds are enough")
	_assert.call(store.funds == 0, "pays the same as a manual order")


func _test_turns_off_when_the_product_leaves_the_shelf() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	m.assign(0, TEA, 0)
	m.assign(0, TEA, 1)
	m.set_auto_order(0, TEA, true)
	m.unassign(0, 0)
	_assert.call(store.auto_orders.has(TEA), "still on while another slot has it")
	m.assign(0, &"cola", 1)
	_assert.call(not store.auto_orders.has(TEA), "off once replaced on the last slot")
	m.set_auto_order(0, &"cola", true)
	m.unassign(0, 1)
	_assert.call(not store.auto_orders.has(&"cola"), "off once unassigned from the last slot")
