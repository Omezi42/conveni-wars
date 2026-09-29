extends RefCounted
## 突発イベント(GameDesign.md 11章)。

const T = preload("res://tools/tests/test_util.gd")
const STEP := 1.0 / 60.0
const FRAME_TOLERANCE := 0.02

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	for seed_value in [1, 2, 3]:
		_test_schedule_and_arrivals(seed_value)
	_test_event_customer_buys_three_times_with_a_per_product_limit()


func _test_schedule_and_arrivals(seed_value: int) -> void:
	var m := T.new_match(&"veteran", &"analyst", seed_value)
	var starts: Array[float] = []
	var ids: Array[StringName] = []
	var announced := {}
	var event_customers: Array[float] = []
	var ended_counts: Array[int] = []
	m.event_started.connect(
		func(id: StringName) -> void:
			starts.append(m.elapsed)
			ids.append(id)
	)
	m.event_announced.connect(
		func(id: StringName, store_index: int) -> void:
			announced["%s:%d:%d" % [id, store_index, starts.size()]] = m.elapsed
	)
	m.customer_arrived.connect(
		func(_type: StringName, _store: int, is_event: bool) -> void:
			if is_event:
				event_customers.append(m.elapsed)
	)
	m.event_ended.connect(
		func(_id: StringName, counts: Array[int]) -> void:
			ended_counts.append(counts[0] + counts[1])
	)
	while not m.finished:
		m.advance(STEP)

	var label := "seed %d: " % seed_value
	_assert.call(starts.size() >= 10, label + "events happen every 15-25s (%d)" % starts.size())
	_assert.call(starts[0] >= 15.0 and starts[0] <= 25.0 + STEP, label + "first event 15-25s")
	for i in range(1, starts.size()):
		var gap := starts[i] - starts[i - 1]
		_assert.call(gap >= 15.0 - STEP and gap <= 25.0 + STEP, label + "gap 15-25s (%f)" % gap)
	for i in starts.size():
		var band := m.db.band_at(starts[i])
		_assert.call(
			m.db.event(ids[i]).band_ids.has(band.id), label + "%s allowed in %s" % [ids[i], band.id]
		)
	_assert.call(starts.back() + 5.0 <= 300.0, label + "last event finishes before closing")
	_assert.call(event_customers.size() == 20 * starts.size(), label + "20 customers per event")
	_assert.call(ended_counts.size() == starts.size(), label + "every event ends")

	var first_id: StringName = ids[0]
	var normal_at: float = announced.get("%s:0:0" % first_id, -1.0)
	var analyst_at: float = announced.get("%s:1:0" % first_id, -1.0)
	_assert.call(absf(normal_at - (starts[0] - 10.0)) < FRAME_TOLERANCE, label + "10s notice")
	_assert.call(absf(analyst_at - (starts[0] - 15.0)) < FRAME_TOLERANCE, label + "15s notice")
	var first_wave := event_customers.filter(
		func(t: float) -> bool: return t >= starts[0] and t <= starts[0] + 5.0 + FRAME_TOLERANCE
	)
	_assert.call(first_wave.size() == 20, label + "the 20 customers come within 5 seconds")


func _test_event_customer_buys_three_times_with_a_per_product_limit() -> void:
	var m := T.new_match()
	T.stock_slot(m, 0, &"umbrella", 0)
	T.stock_slot(m, 0, &"green_tea", 2)
	m._serve_customer(T.customer(&"rain_shelter"), true)
	var store := m.stores[0]
	_assert.call(store.stock(&"umbrella") == 27, "up to 3 of one product")
	_assert.call(store.stock(&"green_tea") == 27, "then the next product, 6 in all")
	_assert.call(store.sales == 500 * 3 + 140 * 3, "pays for all 6")
	_assert.call(store.event_sales == store.sales, "event sales are tracked separately")
