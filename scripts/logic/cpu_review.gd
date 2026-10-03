class_name CpuReview
extends RefCounted
## 結果画面の「CPUならどうしたか」(GameDesign.md 9.4節、Architecture.md 3.5節)。
## 時間帯ごとに、その時間帯の始まりのスナップショットからプレイヤーの発注・棚・値段をCPUに任せて計算し直し、
## 時間帯の終わりの「自店 − 相手」の差が実際よりどれだけよくなったかを出す。


class Finding:
	extends RefCounted
	var band: TimeBandData
	## 実際より「自店 − 相手」の差がよくなった額(悪くなれば負)
	var gain: int
	## CPUのほうが長く在庫ありで並べた商品(長かった順)
	var product_ids: Array[StringName] = []
	var lost_before: int
	var lost_after: int


const MAX_SHOWN := 2
const PRODUCT_NAMES := 2
## 時間を確かめる間隔(tick)
const TICKS_PER_CHECK := 8

## 計算し終えた時間帯の結果(時間帯の順)
var findings: Array[Finding] = []
## true なら、自店の客の割合が「読み的中!」に届かなかった時間帯だけを計算し直す
var only_missed_bands := false

var _result: MatchResult
var _record: MatchRecord
var _db: GameDatabase
var _profile: CpuProfile
var _player: int
var _next_snapshot := 0
var _runner: MatchRunner
var _band: TimeBandData
## 計算し直す時間帯の終わりの tick(最後の時間帯は試合の終わりまで進めるので -1)
var _end_tick := -1


func _init(result: MatchResult, database: GameDatabase, player: int) -> void:
	_result = result
	_record = result.record
	_db = database
	_player = player
	_profile = database.cpu_profile(_record.cpu_profile_id)


func is_done() -> bool:
	return _runner == null and _next_snapshot >= _record.snapshots.size()


## budget_usec マイクロ秒ぶんだけ計算を進める。終わったら true
func process(budget_usec: int) -> bool:
	var started := Time.get_ticks_usec()
	while not is_done():
		if _runner == null:
			_start_next()
			continue
		for i in TICKS_PER_CHECK:
			_runner.step(_record.step)
			var state := _runner.match_state
			if state.finished or (_end_tick >= 0 and state.tick >= _end_tick):
				_finish_band()
				break
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return is_done()


## 出す時間帯(差が基準以上のもの。よくなった額の大きい順に最大2つ)
func shown() -> Array[Finding]:
	var picked: Array[Finding] = []
	for finding in findings:
		if finding.gain >= _db.balance.review_min_gain:
			picked.append(finding)
	picked.sort_custom(func(a: Finding, b: Finding) -> bool: return a.gain > b.gain)
	return picked.slice(0, MAX_SHOWN)


func _start_next() -> void:
	var index := _next_snapshot
	_next_snapshot += 1
	var snapshot := _record.snapshots[index]
	_band = _db.sorted_bands()[snapshot.band_index]
	var share := _result.stores[_player].band_share(_band.id)
	if only_missed_bands and share >= _db.balance.read_hit_share:
		return
	var state := snapshot.match_state.duplicate_state()
	var cpus: Array[CpuPlayer] = []
	for cpu in snapshot.cpus:
		if cpu.store_index() != _player:
			cpus.append(cpu.duplicate_for(state))
	var stand_in := CpuPlayer.new(state, _player, _profile)
	stand_in.use_skill = false
	cpus.append(stand_in)
	_runner = MatchRunner.new(state, cpus)
	_runner.replay_store = _player
	var has_next := _next_snapshot < _record.snapshots.size()
	_end_tick = _record.snapshots[_next_snapshot].tick if has_next else -1
	for command in _record.commands:
		var in_band := command.tick >= snapshot.tick and (_end_tick < 0 or command.tick < _end_tick)
		if in_band and command.kind == MatchRecord.Kind.ACTIVE:
			_runner.replay.append(command)


func _finish_band() -> void:
	var state := _runner.match_state
	_runner = null
	var actual := _result.stores
	if _next_snapshot < _record.snapshots.size():
		actual = _record.snapshots[_next_snapshot].match_state.stores
	var band := _band
	var finding := Finding.new()
	finding.band = band
	finding.gain = _gap(state.stores) - _gap(actual)
	finding.lost_before = actual[_player].lost_in_band(band.id)
	finding.lost_after = state.stores[_player].lost_in_band(band.id)
	finding.product_ids = _longer_shelved(actual[_player], state.stores[_player], band.id)
	findings.append(finding)


func _gap(stores: Array[StoreState]) -> int:
	var own := stores[_player]
	var rival := own.rival
	return own.profit() + _stock_value(own) - rival.profit() - _stock_value(rival)


## 手元の在庫と発注中の商品を仕入れ値で数えた額
func _stock_value(store: StoreState) -> int:
	var multiplier := ManagerSkills.order_cost_multiplier(store.manager)
	var total := 0.0
	for product in _db.sorted_products():
		var count := store.stock(product.id) + store.pending_count(product.id)
		total += count * product.cost * multiplier
	return roundi(total)


static func _shelf_seconds(store: StoreState, band_id: StringName, product_id: StringName) -> float:
	return float(store.shelf_seconds_by_band.get(band_id, {}).get(product_id, 0.0))


func _longer_shelved(
	actual: StoreState, stand_in: StoreState, band_id: StringName
) -> Array[StringName]:
	var ids: Array[StringName] = []
	var seconds: Dictionary = stand_in.shelf_seconds_by_band.get(band_id, {})
	for product_id: StringName in seconds:
		var longer: float = seconds[product_id] - _shelf_seconds(actual, band_id, product_id)
		if longer >= _db.balance.review_shelf_seconds:
			ids.append(product_id)
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var la := _shelf_seconds(stand_in, band_id, a) - _shelf_seconds(actual, band_id, a)
			var lb := _shelf_seconds(stand_in, band_id, b) - _shelf_seconds(actual, band_id, b)
			return la > lb
	)
	return ids.slice(0, PRODUCT_NAMES)
