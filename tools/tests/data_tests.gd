extends RefCounted
## 初期データが仕様(GameDesign.md 1〜3章・7章・11章)の数と合っているか、参照が切れていないか。

const T = preload("res://tools/tests/test_util.gd")

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_counts()
	_test_references_resolve()
	_test_match_totals()
	_test_event_customers_are_not_in_any_band()


func _test_counts() -> void:
	var db := T.db()
	_assert.call(db.balance != null, "balance.tres should load")
	_assert.call(db.categories.size() == 12, "12 categories")
	_assert.call(db.products.size() == 16, "16 products")
	_assert.call(db.customer_types.size() == 10, "10 customer types")
	_assert.call(db.bands.size() == 4, "4 time bands")
	_assert.call(db.combos.size() == 5, "5 combos")
	_assert.call(db.events.size() == 4, "4 events")
	_assert.call(db.managers.size() == 4, "4 managers")
	_assert.call(db.cpu_profile(&"standard") != null, "standard cpu profile")


func _test_references_resolve() -> void:
	var db := T.db()
	for product: ProductData in db.products.values():
		_assert.call(db.category(product.category_id) != null, "%s category" % product.id)
	for customer: CustomerTypeData in db.customer_types.values():
		for category_id: StringName in customer.wants:
			_assert.call(
				db.category(category_id) != null, "%s wants %s" % [customer.id, category_id]
			)
	for band: TimeBandData in db.bands.values():
		for type_id: StringName in band.mix:
			_assert.call(db.customer_type(type_id) != null, "%s mix %s" % [band.id, type_id])
	for combo: ComboData in db.combos.values():
		_assert.call(db.category(combo.category_a) != null, "%s category_a" % combo.id)
		_assert.call(db.category(combo.category_b) != null, "%s category_b" % combo.id)
	for event: EventData in db.events.values():
		_assert.call(db.customer_type(event.customer_type_id) != null, "%s customer" % event.id)
		for band_id in event.band_ids:
			_assert.call(db.band(band_id) != null, "%s band %s" % [event.id, band_id])


func _test_match_totals() -> void:
	var db := T.db()
	_assert.call(is_equal_approx(db.match_duration(), 300.0), "match is 300 seconds")
	_assert.call(db.total_customer_count() == 2000, "2,000 customers a day")
	var bands := db.sorted_bands()
	_assert.call(bands[0].id == &"morning" and bands[3].id == &"night", "bands sorted by order")
	_assert.call(db.band_index_at(0.0) == 0, "time 0 is morning")
	_assert.call(db.band_index_at(75.0) == 1, "time 75 is noon")
	_assert.call(db.band_index_at(300.0) == 3, "the end belongs to the last band")


func _test_event_customers_are_not_in_any_band() -> void:
	var db := T.db()
	for event: EventData in db.events.values():
		for band: TimeBandData in db.bands.values():
			_assert.call(
				not band.mix.has(event.customer_type_id),
				"%s's customers should come only with the event" % event.id
			)
