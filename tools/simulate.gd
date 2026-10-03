extends SceneTree
## CPU対CPUを多数回まわし、店長ごとの勝率・利益の分布・突発イベントが売上に占める割合と、
## 偏った戦い方(固定の棚・値段の固定・買い溜め)のCPUの勝率を出して GameDesign.md 1.5節の調整の目標を判定する(Architecture.md 6章)。
## 目標は天気(GameDesign.md 12章)ごとに判定する。
## godot --headless --path . --script res://tools/simulate.gd -- [試合数] [managers|all] [天気id]
## managers を付けると、店長の勝率だけを出す(偏った戦い方のCPUを回さない)。天気idを付けると、その天気だけを回す

const Strategies := preload("res://tools/sim_strategies.gd")

const DEFAULT_MATCHES := 64
const STEP := 1.0 / 30.0
const PROFILE_ID := &"standard"
## 1.5節の目標
const MANAGER_WIN_MIN := 0.4
const MANAGER_WIN_MAX := 0.6
const FIXED_SHELF_WIN_MAX := 0.4
const BIASED_WIN_MAX := 0.5
## 11.1節の目標
const EVENT_SHARE_MIN := 0.2
const EVENT_SHARE_MAX := 0.3

var _db: GameDatabase
var _profile: CpuProfile
var _managers: Array[ManagerData]
var _weather_id: StringName


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else DEFAULT_MATCHES
	_db = GameDatabase.get_default()
	_profile = _db.cpu_profile(PROFILE_ID)
	_managers = _db.sorted_managers()
	var started := Time.get_ticks_msec()
	var managers_only := args.size() > 1 and args[1] == "managers"
	var weather_ids: Array[StringName] = []
	if args.size() > 2:
		weather_ids.append(StringName(args[2]))
	else:
		for weather in _db.sorted_weathers():
			weather_ids.append(weather.id)
	var ok := true
	for weather_id in weather_ids:
		_weather_id = weather_id
		print("######## weather: %s" % _db.weather(weather_id).display_name)
		ok = _run_managers(count) and ok
		for kind in 0 if managers_only else Strategies.NAMES.size():
			var limit := FIXED_SHELF_WIN_MAX if kind == 0 else BIASED_WIN_MAX
			ok = _run_strategy(kind, count, limit) and ok
	print("== %s" % ("ALL TARGETS OK" if ok else "SOME TARGETS NG"))
	print("elapsed %.1fs" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _pair(i: int) -> Array[StringName]:
	var a := _managers[i % _managers.size()]
	var b := _managers[(i / _managers.size()) % _managers.size()]
	return [a.id, b.id]


func _play(m: MatchState, cpus: Array[CpuPlayer]) -> void:
	while not m.finished:
		m.advance(STEP)
		for cpu in cpus:
			cpu.update(STEP)


func _run_managers(count: int) -> bool:
	var per_manager := {}
	for manager in _managers:
		per_manager[manager.id] = {"games": 0, "wins": 0, "draws": 0, "profit": 0}
	var profits: Array[int] = []
	var totals := {
		"sales": 0, "event": 0.0, "wasted": 0, "lost": 0, "visitors": 0, "orders": 0, "funds": 0
	}
	for i in count:
		var ids := _pair(i)
		var m := MatchState.new(_db, ids, i + 1, _weather_id)
		_play(m, [CpuPlayer.new(m, 0, _profile), CpuPlayer.new(m, 1, _profile)])
		for store in m.stores:
			profits.append(store.profit())
			totals["sales"] += store.sales
			totals["event"] += float(store.event_sales) / maxf(store.sales, 1.0)
			totals["wasted"] += store.wasted_count
			totals["lost"] += store.lost_total
			totals["visitors"] += store.visitor_total
			totals["orders"] += store.order_count
			totals["funds"] += store.funds
			if ids[0] == ids[1]:
				continue
			var row: Dictionary = per_manager[store.manager.id]
			row["games"] += 1
			row["profit"] += store.profit()
			if m.result.winner == store.index:
				row["wins"] += 1
			elif m.result.winner == MatchResult.DRAW:
				row["draws"] += 1
	var ok := _report_totals(count, profits, totals)
	print("-- managers (mirror matches excluded) target %d-%d%%" % _percent_range())
	for manager in _managers:
		var row: Dictionary = per_manager[manager.id]
		var games := maxi(row["games"], 1)
		var rate := float(row["wins"]) / games
		var good := rate >= MANAGER_WIN_MIN and rate <= MANAGER_WIN_MAX
		ok = ok and good
		print(
			(
				"%s %s: win %.0f%% (draw %d) of %d, mean profit %d"
				% [
					_mark(good),
					manager.display_name,
					rate * 100.0,
					row["draws"],
					row["games"],
					row["profit"] / games
				]
			)
		)
	return ok


## 偏った戦い方のCPU(店番0)とふつうのCPU(店番1)を、店長を入れ替えながら戦わせる
func _run_strategy(kind: int, count: int, max_rate: float) -> bool:
	var wins := 0
	var profit := 0
	var rival_profit := 0
	for i in count:
		var m := MatchState.new(_db, _pair(i), i + 1, _weather_id)
		var cpus: Array[CpuPlayer] = [
			Strategies.create(kind, m, 0, _profile), CpuPlayer.new(m, 1, _profile)
		]
		_play(m, cpus)
		if m.result.winner == 0:
			wins += 1
		profit += m.stores[0].profit()
		rival_profit += m.stores[1].profit()
	var rate := float(wins) / count
	var good := rate < max_rate if kind == 0 else rate <= max_rate
	print(
		(
			"%s strategy '%s': win %.0f%% (target <%s%.0f%%), profit %d vs %d"
			% [
				_mark(good),
				Strategies.NAMES[kind],
				rate * 100.0,
				"" if kind == 0 else "=",
				max_rate * 100.0,
				profit / count,
				rival_profit / count
			]
		)
	)
	return good


func _report_totals(count: int, profits: Array[int], totals: Dictionary) -> bool:
	var stores := float(profits.size())
	profits.sort()
	var mean := 0.0
	for value in profits:
		mean += value
	mean /= stores
	print("== %d matches (CPU '%s' vs itself)" % [count, PROFILE_ID])
	print(
		(
			"profit per store: mean %d / min %d / median %d / max %d"
			% [mean, profits[0], profits[profits.size() / 2], profits[-1]]
		)
	)
	print("sales per store: mean %.0f" % (totals["sales"] / stores))
	var share: float = totals["event"] / stores
	var share_ok := share >= EVENT_SHARE_MIN and share <= EVENT_SHARE_MAX
	print(
		(
			"%s event share of sales: %.1f%% (target %.0f-%.0f%%)"
			% [_mark(share_ok), share * 100.0, EVENT_SHARE_MIN * 100.0, EVENT_SHARE_MAX * 100.0]
		)
	)
	print("visitors per store: %.0f" % (totals["visitors"] / stores))
	print("lost customers per store: %.0f" % (totals["lost"] / stores))
	print("wasted units per store: %.0f" % (totals["wasted"] / stores))
	print("orders per store: %.1f" % (totals["orders"] / stores))
	print("funds left per store: %.0f" % (totals["funds"] / stores))
	return share_ok


func _percent_range() -> Array:
	return [MANAGER_WIN_MIN * 100.0, MANAGER_WIN_MAX * 100.0]


func _mark(good: bool) -> String:
	return "OK" if good else "NG"
