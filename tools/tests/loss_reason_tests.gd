extends RefCounted
## 負けた理由の判定と集計、カットインの1行(GameDesign.md 2.7節・9.3節)。

const T = preload("res://tools/tests/test_util.gd")
const SIDE_SLOT := 0
const OTHER_SLOT := 2

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_out_of_stock()
	_test_ahead_is_not_counted()
	_test_price()
	_test_bonus()
	_test_assortment()
	_test_tally_ties_follow_kind_order()
	_test_serving_records_losses_by_band()
	_test_advice_lines()


func _classify(m: MatchState, type_id: StringName) -> LossReason.Loss:
	var customer_type := T.customer(type_id)
	return LossReason.classify(
		m.stores[0].evaluation(customer_type),
		m.stores[1].evaluation(customer_type),
		customer_type,
		m.db
	)


func _test_out_of_stock() -> void:
	var m := T.new_match()
	T.stock_slot(m, 1, &"hot_coffee", SIDE_SLOT)
	var loss := _classify(m, &"office")
	_assert.call(loss.kind == LossReason.Kind.OUT_OF_STOCK, "nothing wanted on the shelf")
	_assert.call(loss.category_id == &"bento", "out of stock names the top wanted category")


func _test_ahead_is_not_counted() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 0, &"hot_coffee", OTHER_SLOT)
	T.stock_slot(m, 1, &"nori_bento", SIDE_SLOT)
	_assert.call(_classify(m, &"office") == null, "own attraction is higher: just chance")


func _test_price() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 1, &"nori_bento", SIDE_SLOT)
	m.set_price_step(0, &"nori_bento", 2)
	var loss := _classify(m, &"office")
	_assert.call(loss.kind == LossReason.Kind.PRICE, "same shelf, higher price: price")
	_assert.call(loss.category_id == &"bento", "price names the category that cost the points")


func _test_bonus() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 1, &"nori_bento", m.balance.center_slot)
	var loss := _classify(m, &"office")
	_assert.call(loss.kind == LossReason.Kind.BONUS, "same product, rival in the center: bonus")
	_assert.call(loss.category_id == &"", "bonus has no category")


func _test_assortment() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 1, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 1, &"hot_coffee", OTHER_SLOT)
	var loss := _classify(m, &"office")
	_assert.call(loss.kind == LossReason.Kind.ASSORTMENT, "rival has more wanted products")
	_assert.call(
		loss.category_id == &"coffee", "assortment names the category the rival had more of"
	)


func _test_tally_ties_follow_kind_order() -> void:
	var tally := LossReason.Tally.new()
	_assert.call(tally.top_kind() < 0, "empty tally has no top reason")
	tally.add(LossReason.Loss.new(LossReason.Kind.BONUS, &""))
	tally.add(LossReason.Loss.new(LossReason.Kind.PRICE, &"bento"))
	_assert.call(tally.top_kind() == LossReason.Kind.PRICE, "a tie goes to the earlier reason")
	tally.add(LossReason.Loss.new(LossReason.Kind.BONUS, &""))
	_assert.call(tally.top_kind() == LossReason.Kind.BONUS, "more customers wins")
	_assert.call(tally.total == 3 and tally.count(LossReason.Kind.BONUS) == 2, "counts add up")
	_assert.call(tally.top_category(LossReason.Kind.PRICE) == &"bento", "category per reason")


func _test_serving_records_losses_by_band() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"nori_bento", SIDE_SLOT)
	T.stock_slot(m, 1, &"nori_bento", m.balance.center_slot)
	var lost: Array[int] = []
	m.customer_lost.connect(func(s: int, _c: StringName) -> void: lost.append(s))
	for i in 40:
		m._serve_customer(T.customer(&"office"), false)
	var own := m.stores[0]
	var bonus_losses := own.losses_in_band(&"morning").count(LossReason.Kind.BONUS)
	_assert.call(bonus_losses > 0, "customers lost to the center bonus are counted")
	_assert.call(bonus_losses == own.losses.total, "the band and the match agree")
	_assert.call(m.stores[1].losses.total == 0, "the store ahead records nothing")
	_assert.call(own.lost_total == 0 and lost.is_empty(), "losing on bonus is not a lost customer")

	var empty := T.new_match()
	empty._serve_customer(T.customer(&"office"), false)
	for store in empty.stores:
		var tally := store.losses_in_band(&"morning")
		_assert.call(
			tally.count(LossReason.Kind.OUT_OF_STOCK) == 1, "both empty: both out of stock"
		)
		_assert.call(store.lost_total == 1, "out of stock is still a lost customer")


func _test_advice_lines() -> void:
	var m := T.new_match()
	var store := m.stores[0]
	var tally := LossReason.Tally.new()
	_assert.call(LossText.advice(tally, store, m.db) == "", "nothing lost: no line")
	tally.add(LossReason.Loss.new(LossReason.Kind.ASSORTMENT, &"coffee"))
	var coffee := m.db.category(&"coffee").display_name
	_assert.call(
		LossText.advice(tally, store, m.db) == "次は%sを並べよう" % coffee, "missing category: place it"
	)
	T.stock_slot(m, 0, &"hot_coffee", SIDE_SLOT)
	_assert.call(
		LossText.advice(tally, store, m.db) == "次は%sを増やそう" % coffee, "stocked category: add more"
	)
	tally.add(LossReason.Loss.new(LossReason.Kind.BONUS, &""))
	tally.add(LossReason.Loss.new(LossReason.Kind.BONUS, &""))
	_assert.call(LossText.advice(tally, store, m.db) == "次は棚のボーナスを組もう", "bonus line")
	_assert.call(LossText.short_label(tally) == "ボーナス", "short label of the top reason")
