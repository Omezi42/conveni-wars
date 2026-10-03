extends RefCounted
## 結果のふりかえりに使う試合の記録(GameDesign.md 9.4節)。

const T = preload("res://tools/tests/test_util.gd")
const STEP := 1.0 / 30.0

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_history_follows_the_whole_match()


func _test_history_follows_the_whole_match() -> void:
	var m := T.new_match(&"veteran", &"analyst", 7)
	var started_ids: Array[StringName] = []
	m.event_started.connect(func(id: StringName) -> void: started_ids.append(id))
	var cpus: Array[CpuPlayer] = []
	for i in MatchState.STORE_COUNT:
		cpus.append(CpuPlayer.new(m, i, m.db.cpu_profile(&"standard")))
	while not m.finished:
		m.advance(STEP)
		for cpu in cpus:
			cpu.update(STEP)
	var history := m.result.history
	var last := history.times.size() - 1
	_assert.call(history != null and last > 0, "the result carries the history")
	var expected := int(m.duration() / m.balance.history_interval)
	_assert.call(absi(last - expected) <= 1, "profit is recorded once per interval")
	_assert.call(
		T.near(history.times[last], m.duration()), "the last sample is the end of the match"
	)
	for i in MatchState.STORE_COUNT:
		_assert.call(
			history.profits[i][last] == m.stores[i].profit(), "the last sample is the final profit"
		)
	var started := started_ids.size()
	_assert.call(started > 0 and history.event_marks.size() == started, "every event is marked")
	var counted := 0
	for mark in history.event_marks:
		counted += mark.store_counts.size()
	_assert.call(counted == started * MatchState.STORE_COUNT, "each mark has the store counts")
	var band_visits := 0
	for store in m.stores:
		for band in m.db.sorted_bands():
			band_visits += int(store.visitors_by_band.get(band.id, 0))
	var band_total := 0
	for band in m.db.sorted_bands():
		band_total += band.customer_count
	_assert.call(
		band_visits > 0 and band_visits <= band_total, "visits by band count only band customers"
	)
