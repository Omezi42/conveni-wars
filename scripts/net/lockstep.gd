class_name Lockstep
extends RefCounted
## オンライン対戦の進め方(GameDesign.md 13.1節、Architecture.md 7.2節)。両方の端末で同じ試合を回し、操作だけを送り合う。
## 自分の操作は input_delay_ticks 後の tick に予約して相手へ送り、両店の操作がそろった tick だけ進める。
## 同じ tick の操作は店の番号の順・出した順に流すので、両方の端末で同じ順になる。

signal desynced

var runner: MatchRunner
var own: int
## 相手の通信が切れ、相手の店をCPUに任せた
var peer_dropped := false
## 相手の試合が終わった(相手の操作はもう来ない)
var peer_ended := false
## 相手の操作を待って進めなかった秒数(進めたら0に戻る)
var waiting_seconds := 0.0

var _config: NetConfig
var _send: Callable
## まだ tick に予約していない自分の操作 [種類, 商品id, 値]
var _pending: Array = []
## tick → [店0の操作の列, 店1の操作の列]
var _scheduled: Dictionary = {}
## 相手がこの tick までの操作を出し終えた
var _peer_upto: int
var _own_upto: int
var _sent_upto: int
var _outbox: Array = []
var _own_hashes: Dictionary = {}
var _peer_hashes: Dictionary = {}
var _band_index: int


## send は相手へ文(辞書)を送る関数
func _init(match_runner: MatchRunner, own_index: int, config: NetConfig, send: Callable) -> void:
	runner = match_runner
	own = own_index
	_config = config
	_send = send
	_peer_upto = config.input_delay_ticks - 1
	_own_upto = _peer_upto
	_sent_upto = _peer_upto
	_band_index = match_state().current_band_index()


func match_state() -> MatchState:
	return runner.match_state


func peer() -> int:
	return 1 - own


func submit(kind: MatchRecord.Kind, product_id: StringName, value: int) -> void:
	_pending.append([kind, product_id, value])


func receive(message: Dictionary) -> void:
	match message.get(NetProtocol.KIND, ""):
		NetProtocol.INPUT:
			for command: Array in message.get(NetProtocol.COMMANDS, []):
				_add(
					int(command[0]),
					peer(),
					[int(command[1]), StringName(command[2]), int(command[3])]
				)
			_peer_upto = maxi(_peer_upto, int(message.get(NetProtocol.UPTO, _peer_upto)))
		NetProtocol.END:
			peer_ended = true
		NetProtocol.HASH:
			var tick := int(message.get(NetProtocol.TICK, -1))
			_peer_hashes[tick] = int(message.get(NetProtocol.VALUE, 0))
			_compare(tick)


func can_step() -> bool:
	return peer_dropped or peer_ended or _peer_upto >= match_state().tick


## 1tick進めたら true。相手の操作が届いていなければ進めずに待つ
func step(delta: float) -> bool:
	var state := match_state()
	if state.finished:
		return false
	if not can_step():
		waiting_seconds += delta
		_flush()
		return false
	waiting_seconds = 0.0
	var target := state.tick + _config.input_delay_ticks
	for command: Array in _pending:
		_add(target, own, command)
		_outbox.append([target, command[0], String(command[1]), command[2]])
	_pending.clear()
	_own_upto = target
	if state.tick % _config.send_interval_ticks == 0:
		_flush()
	_apply(state.tick)
	runner.step(delta)
	if state.current_band_index() != _band_index or state.finished:
		_band_index = state.current_band_index()
		_record_hash()
	if state.finished:
		_flush()
		if not peer_dropped:
			_send.call({NetProtocol.KIND: NetProtocol.END})
	return true


## 相手の店をCPUに任せ、これからは相手の操作を待たない
func take_over(cpu: CpuPlayer) -> void:
	if peer_dropped:
		return
	peer_dropped = true
	waiting_seconds = 0.0
	runner.cpus.append(cpu)


func _add(tick: int, store: int, command: Array) -> void:
	if not _scheduled.has(tick):
		_scheduled[tick] = [[], []]
	_scheduled[tick][store].append(command)


func _apply(tick: int) -> void:
	if not _scheduled.has(tick):
		return
	var state := match_state()
	for store in MatchState.STORE_COUNT:
		for command: Array in _scheduled[tick][store]:
			var kind := command[0] as MatchRecord.Kind
			MatchRecord.apply(
				MatchRecord.Command.new(tick, kind, command[1], command[2]), state, store
			)
	_scheduled.erase(tick)


func _flush() -> void:
	if peer_dropped or (_own_upto <= _sent_upto and _outbox.is_empty()):
		return
	(
		_send
		. call(
			{
				NetProtocol.KIND: NetProtocol.INPUT,
				NetProtocol.UPTO: _own_upto,
				NetProtocol.COMMANDS: _outbox,
			}
		)
	)
	_outbox = []
	_sent_upto = _own_upto


func _record_hash() -> void:
	var state := match_state()
	_own_hashes[state.tick] = state.checksum()
	if not peer_dropped:
		(
			_send
			. call(
				{
					NetProtocol.KIND: NetProtocol.HASH,
					NetProtocol.TICK: state.tick,
					NetProtocol.VALUE: _own_hashes[state.tick],
				}
			)
		)
	_compare(state.tick)


func _compare(tick: int) -> void:
	if peer_dropped or not _own_hashes.has(tick) or not _peer_hashes.has(tick):
		return
	if _own_hashes[tick] != _peer_hashes[tick]:
		desynced.emit()
