extends SceneTree
## CPU対CPUを多数回まわし、店長ごとの勝率・売上の分布・突発イベントが売上に占める割合を出す
## (Architecture.md 6章。バランス調整用)。
## godot --headless --path . --script res://tools/simulate.gd -- [試合数]

const DEFAULT_MATCHES := 64
const STEP := 1.0 / 30.0
const PROFILE_ID := &"standard"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else DEFAULT_MATCHES
	var db := GameDatabase.get_default()
	var managers := db.sorted_managers()
	var profile := db.cpu_profile(PROFILE_ID)
	var per_manager := {}
	for manager in managers:
		per_manager[manager.id] = {"games": 0, "wins": 0, "draws": 0, "sales": 0}
	var sales: Array[int] = []
	var totals := {"event": 0.0, "wasted": 0, "lost": 0, "visitors": 0, "orders": 0, "funds": 0}
	var started := Time.get_ticks_msec()
	for i in count:
		var a := managers[i % managers.size()]
		var b := managers[(i / managers.size()) % managers.size()]
		var ids: Array[StringName] = [a.id, b.id]
		var m := MatchState.new(db, ids, i + 1)
		var cpus: Array[CpuPlayer] = [CpuPlayer.new(m, 0, profile), CpuPlayer.new(m, 1, profile)]
		while not m.finished:
			m.advance(STEP)
			for cpu in cpus:
				cpu.update(STEP)
		for store in m.stores:
			sales.append(store.sales)
			totals["event"] += float(store.event_sales) / maxf(store.sales, 1.0)
			totals["wasted"] += store.wasted_count
			totals["lost"] += store.lost_total
			totals["visitors"] += store.visitor_total
			totals["orders"] += store.order_count
			totals["funds"] += store.funds
			if a.id == b.id:
				continue
			var row: Dictionary = per_manager[store.manager.id]
			row["games"] += 1
			row["sales"] += store.sales
			if m.result.winner == store.index:
				row["wins"] += 1
			elif m.result.winner == MatchResult.DRAW:
				row["draws"] += 1
	_report(count, sales, totals, per_manager, managers)
	print("elapsed %.1fs" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _report(
	count: int, sales: Array[int], totals: Dictionary, per_manager: Dictionary, managers: Array
) -> void:
	var stores := float(sales.size())
	sales.sort()
	var mean := 0.0
	for value in sales:
		mean += value
	mean /= stores
	print("== %d matches (CPU '%s' vs itself)" % [count, PROFILE_ID])
	print(
		(
			"sales per store: mean %d / min %d / median %d / max %d"
			% [mean, sales[0], sales[sales.size() / 2], sales[-1]]
		)
	)
	print("event share of sales: %.1f%%" % (totals["event"] / stores * 100.0))
	print("visitors per store: %.0f" % (totals["visitors"] / stores))
	print("lost customers per store: %.0f" % (totals["lost"] / stores))
	print("wasted units per store: %.0f" % (totals["wasted"] / stores))
	print("orders per store: %.1f" % (totals["orders"] / stores))
	print("funds left per store: %.0f" % (totals["funds"] / stores))
	print("-- managers (mirror matches excluded)")
	for manager: ManagerData in managers:
		var row: Dictionary = per_manager[manager.id]
		var games := maxi(row["games"], 1)
		print(
			(
				"%s: win %.0f%% (draw %d) of %d, mean sales %d"
				% [
					manager.display_name,
					100.0 * row["wins"] / games,
					row["draws"],
					row["games"],
					row["sales"] / games
				]
			)
		)
