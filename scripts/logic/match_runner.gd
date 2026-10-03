class_name MatchRunner
extends RefCounted
## 1tickの進め方(Architecture.md 3.5節)。試合画面・再生・計算し直しが同じ順で進むよう、ここだけで進める。
## 記録済みコマンド(再生のときだけ)→ advance → CPU(並べた順)→ 時間帯が変わったらスナップショット。

var match_state: MatchState
var cpus: Array[CpuPlayer] = []
## 流すコマンド(tick の順)と、流す先の店
var replay: Array[MatchRecord.Command] = []
var replay_store := 0
## true なら時間帯の始まりごとに match_state.record.snapshots へ撮る
var take_snapshots := false

var _cursor := 0
var _band_index := -1


func _init(state: MatchState, cpu_players: Array[CpuPlayer]) -> void:
	match_state = state
	cpus = cpu_players


func step(delta: float) -> void:
	if take_snapshots and _band_index < 0:
		_snapshot()
	while _cursor < replay.size() and replay[_cursor].tick <= match_state.tick:
		MatchRecord.apply(replay[_cursor], match_state, replay_store)
		_cursor += 1
	match_state.advance(delta)
	for cpu in cpus:
		cpu.update(delta)
	if take_snapshots and match_state.current_band_index() != _band_index:
		if not match_state.finished:
			_snapshot()


## 試合の終わりまで delta 秒ずつ進める
func run_to_end(delta: float) -> void:
	while not match_state.finished:
		step(delta)


func _snapshot() -> void:
	_band_index = match_state.current_band_index()
	match_state.record.snapshots.append(MatchRecord.Snapshot.new(match_state, cpus))
