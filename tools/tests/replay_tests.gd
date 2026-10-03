extends RefCounted
## コマンドの記録・再生・スナップショットと「CPUならどうしたか」(GameDesign.md 9.4節・10章、Architecture.md 3.5節)。

const T = preload("res://tools/tests/test_util.gd")
const STEP := 1.0 / 60.0
const SEED := 11
const SKILL_AT := 150.0
const AUTO_ORDER_AT := 30.0


## 乱数を使わずにプレイヤーの代わりをするCPU(乱数を使うと、記録したコマンドだけの再生と乱数がずれるため)
class ScriptedPlayer:
	extends CpuPlayer

	func _init(match_state: MatchState, store_index: int, profile: CpuProfile) -> void:
		super(match_state, store_index, profile)
		use_skill = false

	func update(delta: float) -> void:
		super(delta)
		if _match.elapsed >= SKILL_AT:
			_match.use_active(_index)
		var store := _match.stores[_index]
		if _match.elapsed >= AUTO_ORDER_AT and store.auto_orders.is_empty():
			_match.set_auto_order(_index, store.shelf_product_ids()[0], true)

	func _watch_announcement() -> void:
		pass


var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	var original := _play_original()
	var replayed := _test_replay_matches(original)
	_test_snapshots_continue_the_same(original, replayed)
	_test_review_finds_bands(original)


func _play_original() -> MatchState:
	var ids: Array[StringName] = [&"veteran", &"analyst"]
	var m := MatchState.new(T.db(), ids, SEED)
	var profile := m.db.cpu_profile(&"standard")
	m.record.cpu_profile_id = profile.id
	var cpus: Array[CpuPlayer] = [ScriptedPlayer.new(m, 0, profile), CpuPlayer.new(m, 1, profile)]
	var runner := MatchRunner.new(m, cpus)
	runner.take_snapshots = true
	while not m.finished:
		runner.step(STEP)
	return m


func _test_replay_matches(original: MatchState) -> MatchState:
	var record := original.record
	var kinds := {}
	for command in record.commands:
		kinds[command.kind] = true
	var expected := [
		MatchRecord.Kind.ORDER,
		MatchRecord.Kind.ASSIGN,
		MatchRecord.Kind.ACTIVE,
		MatchRecord.Kind.AUTO_ORDER,
	]
	_assert.call(
		kinds.has_all(expected), "the player's orders, shelf, skill and auto order are recorded"
	)
	_assert.call(T.near(record.step, STEP), "the tick length is recorded")
	var m := MatchState.new(original.db, record.manager_ids, record.seed_value, record.weather_id)
	var cpus: Array[CpuPlayer] = [CpuPlayer.new(m, 1, m.db.cpu_profile(record.cpu_profile_id))]
	var runner := MatchRunner.new(m, cpus)
	runner.replay = record.commands
	runner.take_snapshots = true
	runner.run_to_end(original.record.step)
	_assert.call(_same(original, m), "replaying the commands gives the same match")
	_assert.call(
		m.record.snapshots.size() == m.db.sorted_bands().size(), "one snapshot per time band"
	)
	return m


## 再生した試合の途中のスナップショットから進めても、元の試合と同じ終わりになる
func _test_snapshots_continue_the_same(original: MatchState, replayed: MatchState) -> void:
	for snapshot in replayed.record.snapshots:
		var m := snapshot.match_state.duplicate_state()
		var cpus: Array[CpuPlayer] = []
		for cpu in snapshot.cpus:
			cpus.append(cpu.duplicate_for(m))
		var runner := MatchRunner.new(m, cpus)
		for command in original.record.commands:
			if command.tick >= snapshot.tick:
				runner.replay.append(command)
		runner.run_to_end(original.record.step)
		_assert.call(
			_same(original, m), "a snapshot of band %d continues the same" % snapshot.band_index
		)


func _test_review_finds_bands(original: MatchState) -> void:
	var review := CpuReview.new(original.result, original.db, 0)
	while not review.process(1000000):
		pass
	_assert.call(
		review.findings.size() == original.db.sorted_bands().size(), "every band is recomputed"
	)
	var bands := {}
	for finding in review.findings:
		bands[finding.band] = true
		_assert.call(finding.product_ids.size() <= CpuReview.PRODUCT_NAMES, "at most two names")
	_assert.call(bands.size() == review.findings.size(), "each finding is a different band")
	_assert.call(review.shown().size() <= CpuReview.MAX_SHOWN, "at most two bands are shown")


func _same(a: MatchState, b: MatchState) -> bool:
	for i in MatchState.STORE_COUNT:
		var x := a.stores[i]
		var y := b.stores[i]
		if x.sales != y.sales or x.spent != y.spent or x.funds != y.funds:
			return false
		if x.visitor_total != y.visitor_total or x.lost_total != y.lost_total:
			return false
		if x.wasted_count != y.wasted_count or x.shelf != y.shelf:
			return false
	return a.rng.state == b.rng.state
