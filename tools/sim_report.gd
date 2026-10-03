extends RefCounted
## simulate.gd の試合の記録を集計し、GameDesign.md 1.5節の調整の目標を OK / NG で出す。
## 勝率には95%信頼区間(Wilson)を添え、区間が目標をまたぐときは印を「~」にする(判定は点推定で行う)。

const Strategies := preload("res://tools/sim_strategies.gd")

const MANAGER_JOB := -1
## 1.5節の目標
const MANAGER_WIN_MIN := 0.4
const MANAGER_WIN_MAX := 0.6
const FIXED_SHELF_WIN_MAX := 0.4
const BIASED_WIN_MAX := 0.5
## 11.1節の目標
const EVENT_SHARE_MIN := 0.2
const EVENT_SHARE_MAX := 0.3
## 95%信頼区間の z 値
const Z := 1.96
const TOTAL_KEYS: Array[String] = ["sales", "wasted", "lost", "visitors", "orders", "funds"]

var _managers: Array[ManagerData]
var _profile_id: StringName


func _init(managers: Array[ManagerData], profile_id: StringName) -> void:
	_managers = managers
	_profile_id = profile_id


func print_all(records: Array, baseline: Array) -> bool:
	var manager_records := _of_kind(records, MANAGER_JOB)
	var ok := _print_totals(manager_records)
	ok = _print_managers(manager_records, _of_kind(baseline, MANAGER_JOB)) and ok
	_print_matchups(manager_records)
	for kind in Strategies.NAMES.size():
		var rows := _of_kind(records, kind)
		if not rows.is_empty():
			ok = _print_strategy(kind, rows) and ok
	return ok


## 95%信頼区間 [下限, 上限]
static func wilson(wins: int, games: int) -> Vector2:
	if games == 0:
		return Vector2(0.0, 1.0)
	var n := float(games)
	var p := wins / n
	var z2 := Z * Z
	var center := (p + z2 / (2.0 * n)) / (1.0 + z2 / n)
	var half := Z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / (1.0 + z2 / n)
	return Vector2(center - half, center + half)


func _of_kind(records: Array, kind: int) -> Array:
	return records.filter(func(r: Dictionary) -> bool: return int(r["kind"]) == kind)


func _print_totals(records: Array) -> bool:
	if records.is_empty():
		return true
	var profits: Array[int] = []
	var totals := {}
	for key in TOTAL_KEYS:
		totals[key] = 0.0
	var share := 0.0
	for record: Dictionary in records:
		for store: Dictionary in record["stores"]:
			profits.append(int(store["profit"]))
			for key in TOTAL_KEYS:
				totals[key] += float(store[key])
			share += float(store["event_sales"]) / maxf(float(store["sales"]), 1.0)
	var stores := float(profits.size())
	profits.sort()
	var mean := 0.0
	for value in profits:
		mean += value
	mean /= stores
	print(
		(
			"== %d manager matches (CPU '%s' vs itself, mirror matches excluded)"
			% [records.size(), _profile_id]
		)
	)
	print(
		(
			"profit per store: mean %d / min %d / median %d / max %d"
			% [mean, profits[0], profits[profits.size() / 2], profits[-1]]
		)
	)
	print("sales per store: mean %.0f" % (totals["sales"] / stores))
	share /= stores
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


## 店長ごとの {games, wins, draws, profit}
func _tally(records: Array) -> Dictionary:
	var rows := {}
	for manager in _managers:
		rows[String(manager.id)] = {"games": 0, "wins": 0, "draws": 0, "profit": 0}
	for record: Dictionary in records:
		var winner := int(record["winner"])
		for seat in record["ids"].size():
			var row: Dictionary = rows[String(record["ids"][seat])]
			row["games"] += 1
			row["profit"] += int(record["stores"][seat]["profit"])
			if winner == seat:
				row["wins"] += 1
			elif winner == MatchResult.DRAW:
				row["draws"] += 1
	return rows


func _print_managers(records: Array, baseline: Array) -> bool:
	if records.is_empty():
		return true
	var rows := _tally(records)
	var before := _tally(baseline)
	var ok := true
	print(
		(
			"-- managers: win rate [95%% CI] target %.0f-%.0f%%"
			% [MANAGER_WIN_MIN * 100.0, MANAGER_WIN_MAX * 100.0]
		)
	)
	for manager in _managers:
		var row: Dictionary = rows[String(manager.id)]
		var games := maxi(row["games"], 1)
		var rate := float(row["wins"]) / games
		var ci := wilson(row["wins"], row["games"])
		var good := rate >= MANAGER_WIN_MIN and rate <= MANAGER_WIN_MAX
		var sure := ci.x >= MANAGER_WIN_MIN and ci.y <= MANAGER_WIN_MAX
		ok = ok and good
		var line := (
			"%s %s: win %.1f%% [%.1f-%.1f] (draw %d) of %d, mean profit %d"
			% [
				_mark(good, sure),
				manager.display_name,
				rate * 100.0,
				ci.x * 100.0,
				ci.y * 100.0,
				row["draws"],
				row["games"],
				row["profit"] / games
			]
		)
		var old: Dictionary = before[String(manager.id)]
		if old["games"] > 0:
			line += " | before %.1f%% of %d" % [100.0 * old["wins"] / old["games"], old["games"]]
		print(line)
	return ok


## 行の店長が列の店長に勝った割合
func _print_matchups(records: Array) -> void:
	if records.is_empty():
		return
	var wins := {}
	var games := {}
	for record: Dictionary in records:
		for seat in 2:
			var key := "%s>%s" % [record["ids"][seat], record["ids"][1 - seat]]
			games[key] = int(games.get(key, 0)) + 1
			if int(record["winner"]) == seat:
				wins[key] = int(wins.get(key, 0)) + 1
	print("-- matchups: row's win rate against column")
	var header := "          "
	for manager in _managers:
		header += "%10s" % manager.id
	print(header)
	for a in _managers:
		var line := "%-10s" % a.id
		for b in _managers:
			var key := "%s>%s" % [a.id, b.id]
			if games.has(key):
				line += "%9.0f%%" % (100.0 * int(wins.get(key, 0)) / int(games[key]))
			else:
				line += "%10s" % "-"
		print(line)


## 偏った戦い方のCPUは店番0、ふつうのCPUは店番1
func _print_strategy(kind: int, records: Array) -> bool:
	var wins := 0
	var profit := 0
	var rival_profit := 0
	for record: Dictionary in records:
		if int(record["winner"]) == 0:
			wins += 1
		profit += int(record["stores"][0]["profit"])
		rival_profit += int(record["stores"][1]["profit"])
	var count := records.size()
	var max_rate := FIXED_SHELF_WIN_MAX if kind == 0 else BIASED_WIN_MAX
	var rate := float(wins) / count
	var ci := wilson(wins, count)
	var good := rate < max_rate if kind == 0 else rate <= max_rate
	print(
		(
			"%s strategy '%s': win %.1f%% [%.1f-%.1f] of %d (target <%s%.0f%%), profit %d vs %d"
			% [
				_mark(good, ci.y <= max_rate),
				Strategies.NAMES[kind],
				rate * 100.0,
				ci.x * 100.0,
				ci.y * 100.0,
				count,
				"" if kind == 0 else "=",
				max_rate * 100.0,
				profit / count,
				rival_profit / count
			]
		)
	)
	return good


## 点推定で合否を出し、合格でも信頼区間が目標をまたげば「~」
func _mark(good: bool, sure: bool = true) -> String:
	if not good:
		return "NG"
	return "OK" if sure else "~ "
