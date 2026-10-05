extends SceneTree
## オンライン対戦の通し(Architecture.md 6章・7章)。中継サーバーを通して2つの Godot で1試合を最後まで回し、
## 終わりの状態のハッシュを出す。tools/online_e2e.sh が host と guest を同時に起こして比べる。
## 引数: -- host|guest <合言葉 または random>(サーバーは環境変数 CONVENI_SERVER)

const STEP := 1.0 / 60.0
const STEPS_PER_FRAME := 8
const ACT_EVERY := 30
const TIMEOUT_MSEC := 240000
const MANAGERS: Array[StringName] = [&"veteran", &"analyst"]
const SEED := 77
const RANDOM := "random"

var _net: Node
var _host := false
var _lockstep: Lockstep
var _commands: PlayerCommands
var _rng := RandomNumberGenerator.new()
var _started_at := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_host = args[0] == "host"
	_rng.seed = 1 if _host else 2
	_started_at = Time.get_ticks_msec()
	_run.call_deferred(args[1])


func _run(code: String) -> void:
	_net = root.get_node("NetSession")
	if not _host:
		await create_timer(1.0).timeout
	if code == RANDOM:
		_net.open_random()
	else:
		_net.open_room(code, _host)
	while true:
		await process_frame
		if Time.get_ticks_msec() - _started_at > TIMEOUT_MSEC:
			_finish("E2E timeout")
			return
		while true:
			var message: Dictionary = _net.next_message()
			if message.is_empty():
				break
			_handle(message)
		if _lockstep == null:
			continue
		for i in STEPS_PER_FRAME:
			var tick := _lockstep.match_state().tick
			if tick % ACT_EVERY == 0:
				_act()
			if not _lockstep.step(STEP):
				break
		var state := _lockstep.match_state()
		if state.finished:
			await create_timer(1.0).timeout
			_finish("E2E checksum %d winner %d" % [state.checksum(), state.result.winner])
			return


func _handle(message: Dictionary) -> void:
	match message.get(NetProtocol.KIND, ""):
		NetProtocol.PAIRED:
			if _net.is_host():
				_net.send({NetProtocol.KIND: NetProtocol.START, NetProtocol.SEED: SEED})
				_begin()
		NetProtocol.START:
			_begin()
		NetProtocol.ERROR:
			_finish("E2E refused %s" % message.get(NetProtocol.REASON, ""))
		NetProtocol.INPUT, NetProtocol.HASH, NetProtocol.END:
			_lockstep.receive(message)
		NetProtocol.PEER_LEFT:
			pass


func _begin() -> void:
	var state := MatchState.new(GameDatabase.get_default(), MANAGERS, SEED)
	var no_cpus: Array[CpuPlayer] = []
	_lockstep = Lockstep.new(
		MatchRunner.new(state, no_cpus), _net.own_store(), _net.config, _net.send
	)
	_lockstep.desynced.connect(func() -> void: print("E2E desync"))
	_commands = PlayerCommands.new(state, _lockstep)


func _act() -> void:
	var state := _lockstep.match_state()
	var own := _lockstep.own
	var products := state.db.sorted_products()
	var product := products[_rng.randi_range(0, products.size() - 1)].id
	if _rng.randf() < 0.5:
		_commands.order(own, product)
	else:
		_commands.assign(own, product, _rng.randi_range(0, StoreState.SLOT_COUNT - 1))


func _finish(line: String) -> void:
	print(line)
	_net.close()
	quit()
