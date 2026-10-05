extends RefCounted
## オンライン対戦の進め方(GameDesign.md 13.1節、Architecture.md 7.2節)。2つの端末を、遅れて届く通信でつないで回し、
## 両方の試合が最後まで同じになるか・相手が止まったらCPUに任せて進むか・食い違いを見つけるかを確かめる。

const STEP := 1.0 / 60.0
const SEED := 23
const MANAGERS: Array[StringName] = [&"veteran", &"analyst"]
## 通信の遅れ(フレーム)の幅と、端末が1フレーム止まる確率
const MAX_LATENCY_FRAMES := 8
const STALL_CHANCE := 0.05
## 操作する間隔(フレーム)
const ACT_EVERY := 20
const FRAME_LIMIT := 60 * 60 * 10


## 遅れて届く一方向の通信(順番は入れ替わらない。WebSocket と同じ)
class Wire:
	extends RefCounted
	var queue: Array = []
	var last_due := 0
	var rng: RandomNumberGenerator
	var frame := 0

	func _init(random: RandomNumberGenerator) -> void:
		rng = random

	func push(message: Dictionary) -> void:
		var copy: Variant = JSON.parse_string(JSON.stringify(message))
		last_due = maxi(last_due, frame + rng.randi_range(0, MAX_LATENCY_FRAMES))
		queue.append([last_due, copy])

	func deliver(to: Lockstep) -> void:
		while not queue.is_empty() and queue[0][0] <= frame:
			to.receive(queue.pop_front()[1])


## 1つの端末:自分の試合と、乱数で操作するプレイヤー
class Device:
	extends RefCounted
	var state: MatchState
	var lockstep: Lockstep
	var commands: PlayerCommands
	var rng := RandomNumberGenerator.new()

	func _init(own: int, outgoing: Wire, seed_value: int) -> void:
		state = MatchState.new(GameDatabase.get_default(), MANAGERS, SEED)
		var no_cpus: Array[CpuPlayer] = []
		var config := NetConfig.load_default()
		lockstep = Lockstep.new(MatchRunner.new(state, no_cpus), own, config, outgoing.push)
		commands = PlayerCommands.new(state, lockstep)
		rng.seed = seed_value

	func act(frame: int) -> void:
		if frame % ACT_EVERY != 0:
			return
		var own := lockstep.own
		var products := state.db.sorted_products()
		var product := products[rng.randi_range(0, products.size() - 1)].id
		match rng.randi_range(0, 4):
			0, 1:
				commands.order(own, product)
			2:
				commands.assign(own, product, rng.randi_range(0, StoreState.SLOT_COUNT - 1))
			3:
				var shelf := state.stores[own].shelf_product_ids()
				if not shelf.is_empty():
					var step_count := state.balance.price_step_count()
					commands.set_price_step(own, shelf[0], rng.randi_range(0, step_count - 1))
			4:
				commands.use_active(own)


var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_two_sides_stay_identical()
	_test_take_over_when_peer_stops()
	_test_detects_desync()


func _pair() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var a_to_b := Wire.new(rng)
	var b_to_a := Wire.new(rng)
	var a := Device.new(0, a_to_b, 1)
	var b := Device.new(1, b_to_a, 2)
	return [a, b, a_to_b, b_to_a, rng]


func _test_two_sides_stay_identical() -> void:
	var pair := _pair()
	var a: Device = pair[0]
	var b: Device = pair[1]
	var rng: RandomNumberGenerator = pair[4]
	var desyncs := [0]
	a.lockstep.desynced.connect(func() -> void: desyncs[0] += 1)
	b.lockstep.desynced.connect(func() -> void: desyncs[0] += 1)
	var frame := 0
	while not (a.state.finished and b.state.finished) and frame < FRAME_LIMIT:
		frame += 1
		for wire: Wire in [pair[2], pair[3]]:
			wire.frame = frame
		(pair[3] as Wire).deliver(a.lockstep)
		(pair[2] as Wire).deliver(b.lockstep)
		for side: Device in [a, b]:
			if rng.randf() < STALL_CHANCE:
				continue
			side.act(frame)
			side.lockstep.step(STEP)
	_assert.call(a.state.finished and b.state.finished, "both sides reach the end of the match")
	_assert.call(a.state.checksum() == b.state.checksum(), "both sides end in the same state")
	_assert.call(a.state.result.winner == b.state.result.winner, "both sides agree on the winner")
	_assert.call(
		a.state.stores[1].order_count > 0 and b.state.stores[0].order_count > 0,
		"each side runs the other side's orders"
	)
	_assert.call(desyncs[0] == 0, "no desync is reported when both stay identical")


func _test_take_over_when_peer_stops() -> void:
	var pair := _pair()
	var a: Device = pair[0]
	var config := NetConfig.load_default()
	var frames := 0
	while a.lockstep.waiting_seconds < config.drop_seconds and frames < FRAME_LIMIT:
		frames += 1
		a.lockstep.step(STEP)
	_assert.call(a.state.tick == config.input_delay_ticks, "a side waits once the peer goes silent")
	var profile := a.state.db.cpu_profile(config.takeover_profile_id)
	a.lockstep.take_over(CpuPlayer.new(a.state, a.lockstep.peer(), profile))
	while not a.state.finished and frames < FRAME_LIMIT:
		frames += 1
		a.lockstep.step(STEP)
	_assert.call(a.state.finished, "after the take over the match runs to the end")
	_assert.call(a.state.stores[1].order_count > 0, "the CPU runs the dropped store")


func _test_detects_desync() -> void:
	var pair := _pair()
	var a: Device = pair[0]
	var b: Device = pair[1]
	var desyncs := [0]
	a.lockstep.desynced.connect(func() -> void: desyncs[0] += 1)
	b.state.stores[0].funds += 1
	var frame := 0
	var first_band_end := a.state.db.sorted_bands()[0].duration + 1.0
	while a.state.elapsed < first_band_end and frame < FRAME_LIMIT:
		frame += 1
		for wire: Wire in [pair[2], pair[3]]:
			wire.frame = frame
		(pair[3] as Wire).deliver(a.lockstep)
		(pair[2] as Wire).deliver(b.lockstep)
		a.lockstep.step(STEP)
		b.lockstep.step(STEP)
	_assert.call(
		desyncs[0] > 0, "a difference between the two sides is reported at the band change"
	)
