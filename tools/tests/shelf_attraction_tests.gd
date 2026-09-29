extends RefCounted
## 棚の倍率(GameDesign.md 4章)と魅力度・値段補正(2.4節・5章・7章のパッシブ)。

const T = preload("res://tools/tests/test_util.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_center_bonus_needs_stock()
	_test_corner_needs_a_full_column_of_one_category()
	_test_combo_counts_once_per_slot_and_not_diagonally()
	_test_attraction_sums_products_and_counts_duplicates_once()
	_test_unassigned_stock_does_not_count()
	_test_price_modifier_examples()
	_test_price_rounding()
	_test_saver_passive_boosts_only_sales()
	_test_idol_passive_targets_students_and_youth()
	_test_choose_store_follows_the_square_of_attraction()


func _test_center_bonus_needs_stock() -> void:
	var m := T.new_match()
	m.assign(0, &"salmon_onigiri", 4)
	_assert.call(T.near(m.stores[0].shelf_bonus().multipliers[4], 1.0), "no stock, no center bonus")
	m.deliver(0, &"salmon_onigiri", 30)
	var result := m.stores[0].shelf_bonus()
	_assert.call(T.near(result.multipliers[4], 1.5), "center slot is x1.5")
	_assert.call(result.bonuses_at(4)[0].kind == ShelfBonus.Kind.CENTER, "center bonus is listed")


func _test_corner_needs_a_full_column_of_one_category() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"salmon_onigiri", 0)
	T.stock_slot(m, 0, &"tunamayo_onigiri", 3)
	m.assign(0, &"salmon_onigiri", 6)
	var result := m.stores[0].shelf_bonus()
	for slot in [0, 3, 6]:
		_assert.call(T.near(result.multipliers[slot], 1.3), "corner slot %d is x1.3" % slot)
	var names := result.bonuses.map(func(b: ShelfBonus.Bonus) -> String: return b.display_name)
	_assert.call(names.has("おにぎりコーナー"), "corner is named after the category")

	m.assign(0, &"green_tea", 6)
	result = m.stores[0].shelf_bonus()
	_assert.call(
		T.near(result.multipliers[0], 1.0), "a column with no stock in one slot is no corner"
	)


func _test_combo_counts_once_per_slot_and_not_diagonally() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"salmon_onigiri", 0)
	T.stock_slot(m, 0, &"green_tea", 1)
	T.stock_slot(m, 0, &"cola", 3)
	var result := m.stores[0].shelf_bonus()
	_assert.call(T.near(result.multipliers[0], 1.3), "two combos on one slot still give x1.3")
	_assert.call(T.near(result.multipliers[1], 1.3), "combo partner (right) is x1.3")
	_assert.call(T.near(result.multipliers[3], 1.3), "combo partner (below) is x1.3")

	var diagonal := T.new_match()
	T.stock_slot(diagonal, 0, &"salmon_onigiri", 0)
	T.stock_slot(diagonal, 0, &"green_tea", 4)
	result = diagonal.stores[0].shelf_bonus()
	_assert.call(T.near(result.multipliers[0], 1.0), "diagonal slots are not a combo")
	_assert.call(T.near(result.multipliers[4], 1.5), "diagonal slot keeps only the center bonus")


func _test_attraction_sums_products_and_counts_duplicates_once() -> void:
	var m := T.new_match()
	var office := T.customer(&"office")
	T.stock_slot(m, 0, &"nori_bento", 0)
	_assert.call(T.near(m.stores[0].evaluation(office).score, 3.0), "bento weight 3")
	T.stock_slot(m, 0, &"hot_coffee", 2)
	_assert.call(T.near(m.stores[0].evaluation(office).score, 6.0), "bento 3 + coffee 3")
	m.assign(0, &"nori_bento", 4)
	_assert.call(
		T.near(m.stores[0].evaluation(office).score, 7.5),
		"the same bento in two slots counts only the best slot (center 4.5) + coffee 3"
	)
	T.stock_slot(m, 0, &"potato_chips", 8)
	_assert.call(T.near(m.stores[0].evaluation(office).score, 7.5), "unwanted category adds 0")


func _test_unassigned_stock_does_not_count() -> void:
	var m := T.new_match()
	m.deliver(0, &"nori_bento", 30)
	_assert.call(
		T.near(m.stores[0].evaluation(T.customer(&"office")).score, 0.0),
		"stock that is not on the shelf does not attract"
	)


func _test_price_modifier_examples() -> void:
	var factor := T.db().balance.price_effect_factor
	_assert.call(T.near(Attraction.price_modifier(0.9, -0.2, factor), 1.45), "student sale x1.45")
	_assert.call(T.near(Attraction.price_modifier(0.9, 0.2, factor), 0.55), "student high x0.55")
	_assert.call(T.near(Attraction.price_modifier(0.3, -0.2, factor), 1.15), "office sale x1.15")
	_assert.call(T.near(Attraction.price_modifier(0.3, 0.2, factor), 0.85), "office high x0.85")

	var m := T.new_match()
	T.stock_slot(m, 0, &"potato_chips", 0)
	m.set_price_step(0, &"potato_chips", 0)
	_assert.call(
		T.near(m.stores[0].evaluation(T.customer(&"student")).score, 3.0 * 1.45),
		"sale price raises the student's score"
	)


func _test_price_rounding() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	_assert.call(store.price_for_step(&"cola", 0) == 130, "160 x 0.8 = 128 -> 130")
	_assert.call(store.price_for_step(&"cola", 2) == 190, "160 x 1.2 = 192 -> 190")
	_assert.call(store.price_for_step(&"hot_coffee", 0) == 100, "120 x 0.8 = 96 -> 100")
	_assert.call(store.price_for_step(&"karaage_bento", 1) == 550, "list price")


func _test_saver_passive_boosts_only_sales() -> void:
	var m := T.new_match(&"saver", &"veteran")
	var student := T.customer(&"student")
	T.stock_slot(m, 0, &"potato_chips", 0)
	m.set_price_step(0, &"potato_chips", 0)
	_assert.call(
		T.near(m.stores[0].evaluation(student).score, 3.0 * 1.675), "sale works 1.5x (3.75)"
	)
	var high := T.new_match(&"saver", &"veteran")
	T.stock_slot(high, 0, &"potato_chips", 0)
	high.set_price_step(0, &"potato_chips", 2)
	_assert.call(
		T.near(high.stores[0].evaluation(student).score, 3.0 * 0.55), "high price is unchanged"
	)


func _test_idol_passive_targets_students_and_youth() -> void:
	var m := T.new_match(&"idol", &"veteran")
	T.stock_slot(m, 0, &"green_tea", 0)
	_assert.call(
		T.near(m.stores[0].evaluation(T.customer(&"student")).score, 2.0 * 1.2), "student x1.2"
	)
	_assert.call(
		T.near(m.stores[0].evaluation(T.customer(&"youth")).score, 3.0 * 1.2), "youth x1.2"
	)
	_assert.call(
		T.near(m.stores[0].evaluation(T.customer(&"homemaker")).score, 1.0), "homemaker x1"
	)


func _test_choose_store_follows_the_square_of_attraction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var scores: Array[float] = [2.0, 1.0]
	var picks := [0, 0]
	var trials := 20000
	for i in trials:
		picks[Attraction.choose_store(scores, 2.0, rng)] += 1
	var share := float(picks[0]) / trials
	_assert.call(absf(share - 0.8) < 0.02, "2:1 attraction gives about 4:1 customers (%f)" % share)
	var zeros: Array[float] = [0.0, 0.0]
	_assert.call(Attraction.choose_store(zeros, 2.0, rng) == -1, "nobody enters two empty stores")
	var one_sided: Array[float] = [0.0, 1.0]
	_assert.call(Attraction.choose_store(one_sided, 2.0, rng) == 1, "only the store with stock")
