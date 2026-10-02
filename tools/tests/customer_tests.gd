extends RefCounted
## 来店・買い物・取り逃した客・時計・勝敗(GameDesign.md 1章・2章)。

const T = preload("res://tools/tests/test_util.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_shopping_follows_weight_then_score()
	_test_customer_pays_the_current_price()
	_test_lost_customers_are_counted_only_when_attraction_is_zero()
	_test_arrival_names_the_first_product_bought()
	_test_band_customers_arrive_in_exact_numbers()
	_test_same_seed_gives_the_same_match()
	_test_store_clock()
	_test_winner_by_profit_then_visitors()
	_test_forecast_shows_the_next_band()
	_test_band_report_numbers()


func _test_shopping_follows_weight_then_score() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"salmon_onigiri", 0)
	T.stock_slot(m, 0, &"nori_bento", 2)
	T.stock_slot(m, 0, &"hot_coffee", 4)
	var store := m.stores[0]
	var chosen := m._serve_customer(T.customer(&"office"), false)
	_assert.call(chosen == 0, "the only store with stock is chosen")
	_assert.call(store.stock(&"hot_coffee") == 29, "coffee (weight 3, center x1.5) bought first")
	_assert.call(store.stock(&"nori_bento") == 29, "bento (weight 3) bought second")
	_assert.call(store.stock(&"salmon_onigiri") == 30, "onigiri (weight 2) not bought: 2 items")
	_assert.call(store.sales == 120 + 450, "sales are the sum of the prices")
	_assert.call(store.funds == 30000 + 570, "sales go straight into funds")
	_assert.call(store.visitors[&"office"] == 1 and store.visitor_total == 1, "visit counted")


func _test_customer_pays_the_current_price() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", 0)
	m.set_price_step(0, &"nori_bento", 2)
	m._serve_customer(T.customer(&"office"), false)
	_assert.call(m.stores[0].sales == 540, "450 x 1.2 = 540")


func _test_lost_customers_are_counted_only_when_attraction_is_zero() -> void:
	var m := T.new_match()
	T.stock_slot(m, 1, &"potato_chips", 0)
	var lost: Array[StringName] = []
	m.customer_lost.connect(
		func(s: int, c: StringName) -> void: lost.append(StringName("%d:%s" % [s, c]))
	)
	_assert.call(m._serve_customer(T.customer(&"student"), false) == 1, "student goes to store 1")
	_assert.call(m.stores[0].lost_total == 1, "store 0 had nothing the student wanted")
	_assert.call(m.stores[1].lost_total == 0, "store 1 served the student")

	T.stock_slot(m, 0, &"ice_bar", 1)
	var before := m.stores[0].lost_total
	for i in 50:
		m._serve_customer(T.customer(&"student"), false)
	_assert.call(m.stores[0].lost_total == before, "losing on attraction is not a lost customer")

	var empty := T.new_match()
	_assert.call(empty._serve_customer(T.customer(&"office"), false) == -1, "both empty: leaves")
	_assert.call(
		empty.stores[0].lost_total == 1 and empty.stores[1].lost_total == 1, "both stores lose"
	)
	_assert.call(lost[0] == &"0:hot_snack", "the bubble names the top wanted category")


func _test_arrival_names_the_first_product_bought() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", 2)
	T.stock_slot(m, 0, &"hot_coffee", 4)
	var firsts: Array[StringName] = []
	m.customer_arrived.connect(
		func(_type: StringName, _store: int, _event: bool, product: StringName) -> void:
			firsts.append(product)
	)
	m._serve_customer(T.customer(&"office"), false)
	_assert.call(firsts[0] == &"hot_coffee", "the bubble shows the first product bought")
	var empty := T.new_match()
	empty.customer_arrived.connect(
		func(_type: StringName, _store: int, _event: bool, product: StringName) -> void:
			firsts.append(product)
	)
	empty._serve_customer(T.customer(&"office"), false)
	_assert.call(firsts[1] == &"", "a customer who bought nothing has no product")


func _test_band_customers_arrive_in_exact_numbers() -> void:
	var m := T.new_match()
	var counts := {}
	# 時間帯の境目では前の時間帯の残りが先に来るため、切り替わりはシグナルで追う
	var band := [&""]
	m.band_changed.connect(func(id: StringName) -> void: band[0] = id)
	m.customer_arrived.connect(
		func(_type: StringName, _store: int, is_event: bool, _product: StringName) -> void:
			if not is_event:
				counts[band[0]] = int(counts.get(band[0], 0)) + 1
	)
	while not m.finished:
		m.advance(1.0 / 60.0)
	_assert.call(counts.get(&"morning") == 550, "morning 550 (%s)" % counts.get(&"morning"))
	_assert.call(counts.get(&"noon") == 650, "noon 650 (%s)" % counts.get(&"noon"))
	_assert.call(counts.get(&"evening") == 500, "evening 500 (%s)" % counts.get(&"evening"))
	_assert.call(counts.get(&"night") == 300, "night 300 (%s)" % counts.get(&"night"))


func _test_same_seed_gives_the_same_match() -> void:
	var sales: Array[int] = []
	for run_index in 2:
		var m := T.new_match(&"veteran", &"idol", 42)
		for slot in 3:
			var product: StringName = [&"nori_bento", &"hot_coffee", &"potato_chips"][slot]
			T.stock_slot(m, 0, product, slot, 500)
			T.stock_slot(m, 1, product, slot + 3, 500)
		while not m.finished:
			m.advance(1.0 / 30.0)
		sales.append(m.stores[0].sales * 10000000 + m.stores[1].sales)
	_assert.call(sales[0] == sales[1], "same seed and moves give the same result")


func _test_store_clock() -> void:
	var m := T.new_match()
	_assert.call(m.clock_minutes() == 6 * 60, "the match starts at 6:00")
	m.advance(37.5)
	_assert.call(m.clock_minutes() == 8 * 60, "halfway through the morning is 8:00")
	m.advance(37.5 + 37.5)
	_assert.call(m.clock_minutes() == 12 * 60, "halfway through noon is 12:00")


func _test_winner_by_profit_then_visitors() -> void:
	var m := T.new_match()
	m.stores[0].sales = 300
	m.stores[0].spent = 200
	m.stores[1].sales = 200
	_assert.call(m._decide_winner() == 1, "more profit wins even with less sales")
	m.stores[0].spent = 100
	m.stores[0].visitor_total = 5
	m.stores[1].visitor_total = 3
	_assert.call(m._decide_winner() == 0, "same profit: more visitors wins")
	m.stores[1].visitor_total = 5
	_assert.call(m._decide_winner() == MatchResult.DRAW, "same profit and visitors: draw")


func _test_forecast_shows_the_next_band() -> void:
	var m := T.new_match(&"veteran", &"analyst")
	var normal := m.forecast_bands(0)
	var analyst := m.forecast_bands(1)
	_assert.call(normal.size() == 1 and normal[0].id == &"noon", "morning forecasts noon")
	_assert.call(
		analyst.size() == 2 and analyst[1].id == &"evening", "analyst also sees the band after"
	)
	m.advance(299.0)
	_assert.call(m.forecast_bands(1).is_empty(), "nothing after the night")


func _test_band_report_numbers() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	_assert.call(store.band_share(&"morning") < 0.0, "no visitors yet: no share")
	store.record_visit(&"office", &"morning")
	store.record_visit(&"office", &"morning")
	store.record_visit(&"office", &"morning")
	m.stores[1].record_visit(&"office", &"morning")
	_assert.call(is_equal_approx(store.band_share(&"morning"), 0.75), "3 of 4 visitors is 75%")
	_assert.call(store.most_lost_category(&"morning") == &"", "nothing lost: no category")
	store.record_lost(&"morning", &"bento")
	store.record_lost(&"morning", &"coffee")
	store.record_lost(&"morning", &"coffee")
	_assert.call(store.most_lost_category(&"morning") == &"coffee", "the most lost category")
	_assert.call(store.lost_in_band(&"morning") == 3, "lost customers are still counted")
	T.stock_slot(m, 0, &"hot_coffee", 0)
	_assert.call(store.is_category_stocked(&"coffee"), "coffee on the shelf with stock")
	_assert.call(not store.is_category_stocked(&"bento"), "bento not on the shelf")
