extends RefCounted
## CPU(GameDesign.md 8章)。コマンドだけで1試合を最後まで回せるか、予告に反応するか。

const T = preload("res://tools/tests/test_util.gd")
const STEP := 1.0 / 30.0

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_cpu_vs_cpu_plays_a_whole_match()
	_test_cpu_adds_announced_event_demand_after_its_reaction_delay()


func _test_cpu_vs_cpu_plays_a_whole_match() -> void:
	var m := T.new_match(&"veteran", &"idol", 5)
	var profile := T.db().cpu_profile(&"standard")
	var cpus: Array[CpuPlayer] = [CpuPlayer.new(m, 0, profile), CpuPlayer.new(m, 1, profile)]
	while not m.finished:
		m.advance(STEP)
		for cpu in cpus:
			cpu.update(STEP)
	for store in m.stores:
		var label := "cpu store %d: " % store.index
		_assert.call(store.order_count > 10, label + "orders (%d)" % store.order_count)
		_assert.call(store.sales > 100000, label + "sells (%d)" % store.sales)
		_assert.call(store.active_used, label + "uses its active skill")
		_assert.call(store.funds >= 0, label + "never goes below zero funds")
	_assert.call(m.result != null, "the match produces a result")


func _test_cpu_adds_announced_event_demand_after_its_reaction_delay() -> void:
	var m := T.new_match(&"veteran", &"veteran", 3)
	var profile := T.db().cpu_profile(&"standard")
	var cpu := CpuPlayer.new(m, 0, profile)
	while m.announced_event(0) == null:
		m.advance(STEP)
		cpu.update(STEP)
	var before := cpu.estimate_demand(profile.stock_horizon)
	for i in int(ceil(profile.event_reaction_delay / STEP)) + 1:
		m.advance(STEP)
		cpu.update(STEP)
	var after := cpu.estimate_demand(profile.stock_horizon)
	var grew := false
	for category_id: StringName in after:
		if float(after[category_id]) > float(before.get(category_id, 0.0)) + 1.0:
			grew = true
	_assert.call(grew, "demand grows once the cpu has reacted to the notice")
