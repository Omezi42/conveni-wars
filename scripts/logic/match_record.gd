class_name MatchRecord
extends RefCounted
## 試合の再生に要るもの(GameDesign.md 10章、Architecture.md 3.5節)。種・店長・CPUの強さ・1tickの秒数・
## 1店ぶんのコマンドの列と、時間帯の始まりごとのスナップショットを持つ。

enum Kind { ORDER, ASSIGN, UNASSIGN, PRICE, ACTIVE, AUTO_ORDER }

const NOT_RECORDING := -1


class Command:
	extends RefCounted
	## この tick の advance の前に流す
	var tick: int
	var kind: Kind
	var product_id: StringName
	## マスの番号・値段段階・自動発注のオン(1)オフ(0)。使わないコマンドは0
	var value: int

	func _init(at: int, command_kind: Kind, id: StringName, number: int) -> void:
		tick = at
		kind = command_kind
		product_id = id
		value = number


class Snapshot:
	extends RefCounted
	var tick: int
	var band_index: int
	var match_state: MatchState
	var cpus: Array[CpuPlayer] = []

	func _init(state: MatchState, cpu_players: Array[CpuPlayer]) -> void:
		match_state = state.duplicate_state()
		tick = state.tick
		band_index = state.current_band_index()
		for cpu in cpu_players:
			cpus.append(cpu.duplicate_for(match_state))


var seed_value: int
var manager_ids: Array[StringName] = []
var cpu_profile_id: StringName = &""
## 1回の advance の秒数(最初の advance で決まる)
var step := 0.0
## コマンドを記録する店。記録しなければ NOT_RECORDING
var store_index := 0
var commands: Array[Command] = []
var snapshots: Array[Snapshot] = []


func _init(seed_number: int, ids: Array[StringName]) -> void:
	seed_value = seed_number
	manager_ids = ids.duplicate()


func add(tick: int, store: int, kind: Kind, product_id: StringName, value: int) -> void:
	if store == store_index:
		commands.append(Command.new(tick, kind, product_id, value))


## コマンドを match_state へ流す(プレイヤーの操作と同じく成否は問わない)
static func apply(command: Command, match_state: MatchState, store: int) -> void:
	match command.kind:
		Kind.ORDER:
			match_state.order(store, command.product_id)
		Kind.ASSIGN:
			match_state.assign(store, command.product_id, command.value)
		Kind.UNASSIGN:
			match_state.unassign(store, command.value)
		Kind.PRICE:
			match_state.set_price_step(store, command.product_id, command.value)
		Kind.ACTIVE:
			match_state.use_active(store)
		Kind.AUTO_ORDER:
			match_state.set_auto_order(store, command.product_id, command.value != 0)
