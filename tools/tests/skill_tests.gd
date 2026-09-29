extends RefCounted
## 店長のアクティブスキル(GameDesign.md 7章)。

const T = preload("res://tools/tests/test_util.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_active_is_once_and_not_during_prep()
	_test_bulk_order_delivers_a_free_lot_per_shelf_product()
	_test_handshake_pulls_every_customer_that_wants_something()
	_test_time_sale_prices_everything_as_sale_while_running()
	_test_price_lock_blocks_only_the_opponent()


func _test_active_is_once_and_not_during_prep() -> void:
	var m := T.new_match()
	_assert.call(not m.use_active(0), "not during prep")
	T.open(m)
	_assert.call(m.use_active(0), "usable after opening")
	_assert.call(not m.use_active(0), "only once")


func _test_bulk_order_delivers_a_free_lot_per_shelf_product() -> void:
	var m := T.new_match(&"veteran", &"idol")
	m.assign(0, &"nori_bento", 0)
	m.assign(0, &"green_tea", 1)
	m.assign(0, &"green_tea", 2)
	T.open(m)
	var funds := m.stores[0].funds
	m.use_active(0)
	_assert.call(m.stores[0].stock(&"nori_bento") == 30, "bento +30")
	_assert.call(m.stores[0].stock(&"green_tea") == 30, "tea +30 once, not per slot")
	_assert.call(m.stores[0].stock(&"cola") == 0, "products off the shelf get nothing")
	_assert.call(m.stores[0].funds == funds, "free")


func _test_handshake_pulls_every_customer_that_wants_something() -> void:
	var m := T.new_match(&"idol", &"veteran")
	T.stock_slot(m, 0, &"ice_bar", 0, 500)
	T.stock_slot(m, 1, &"potato_chips", 4, 500)
	T.stock_slot(m, 1, &"karaage_stick", 1, 500)
	T.open(m)
	m.use_active(0)
	var chosen := {0: 0, 1: 0}
	for i in 30:
		chosen[m._serve_customer(T.customer(&"student"), false)] += 1
	_assert.call(chosen[0] == 30, "every student goes to the idol's store")
	_assert.call(
		m._serve_customer(T.customer(&"office"), false) == -1,
		"a customer who wants nothing in either store still leaves"
	)
	m.advance(10.1)
	chosen = {0: 0, 1: 0}
	for i in 30:
		chosen[m._serve_customer(T.customer(&"student"), false)] += 1
	_assert.call(chosen[1] > 0, "after 10s customers choose by attraction again")


func _test_time_sale_prices_everything_as_sale_while_running() -> void:
	var m := T.new_match(&"saver", &"veteran")
	var student := T.customer(&"student")
	T.stock_slot(m, 0, &"potato_chips", 0, 1000)
	m.set_price_step(0, &"potato_chips", 2)
	T.open(m)
	var sold_price := m.stores[0].sell_price(&"potato_chips")
	m.use_active(0)
	_assert.call(
		T.near(m.stores[0].evaluation(student).score, 3.0 * 1.675), "scored as a (boosted) sale"
	)
	_assert.call(m.stores[0].sell_price(&"potato_chips") == sold_price, "the price is unchanged")
	m.advance(15.1)
	_assert.call(T.near(m.stores[0].evaluation(student).score, 3.0 * 0.55), "back after 15s")


func _test_price_lock_blocks_only_the_opponent() -> void:
	var m := T.new_match(&"veteran", &"analyst")
	T.open(m)
	m.use_active(1)
	_assert.call(not m.set_price_step(0, &"cola", 0), "the opponent cannot change prices")
	_assert.call(m.set_price_step(1, &"cola", 0), "the analyst still can")
	m.advance(20.1)
	_assert.call(m.set_price_step(0, &"cola", 0), "unlocked after 20s")
