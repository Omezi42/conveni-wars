extends SceneTree
## CPU対CPUを多数回まわし、店長ごとの勝率(95%信頼区間つき)・利益の分布・突発イベントが売上に占める割合と、
## 偏った戦い方(固定の棚・値段の固定・買い溜め)のCPUの勝率を出して GameDesign.md 1.5節の調整の目標を判定する(Architecture.md 6章)。
## godot --headless --path . --script res://tools/simulate.gd --
##     [games=100] [strategy=96] [jobs=8] [managers] [save=名前] [compare=名前] [set=...]
##   games    店長の組み合わせ(異なる2人)ごとの試合数。席の入れ替えで半分ずつ、同じシードの一覧で回す
##   strategy 偏った戦い方ごとの試合数。16通りの店長の組み合わせへ均等に割り振る
##   jobs     並列に動かすGodotのプロセス数(既定はCPUのコア数)
##   managers 店長の勝率だけを出す(偏った戦い方のCPUを回さない)
##   save / compare  結果を logs/sim/<名前>.jsonl へ保存する / 保存した結果と店長の勝率を並べる
##   set      スキルや balance.tres の数値を試しに変える(.tres は書き換えない)。カンマで複数。
##            例: set=idol.active.duration=8,saver.active.duration=40,balance.choice_exponent=2.5

const Strategies := preload("res://tools/sim_strategies.gd")
const Report := preload("res://tools/sim_report.gd")

const DEFAULT_GAMES := 100
const DEFAULT_STRATEGY_GAMES := 96
## シードの一覧は SEED_BASE から連番。変えると変更前後を同じ試合群で比べられなくなる
const SEED_BASE := 1
const STEP := 1.0 / 30.0
const PROFILE_ID := &"standard"
const MANAGER_JOB := -1
const OUT_DIR := "res://logs/sim"
const POLL_MSEC := 200

var _db: GameDatabase
var _profile: CpuProfile
var _managers: Array[ManagerData]


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	_db = GameDatabase.get_default()
	_profile = _db.cpu_profile(PROFILE_ID)
	_managers = _db.sorted_managers()
	if options.has("set"):
		_override(options["set"])
	var jobs := _jobs(options)
	if options.has("worker"):
		var part: PackedStringArray = String(options["worker"]).split("/")
		_write(_run(jobs, int(part[0]), int(part[1])), options["out"])
		quit()
		return
	var started := Time.get_ticks_msec()
	var processes := int(options.get("jobs", OS.get_processor_count()))
	var records := _run(jobs, 0, 1) if processes <= 1 else _run_parallel(jobs.size(), processes)
	if records.size() != jobs.size():
		print("== NG: %d of %d matches finished" % [records.size(), jobs.size()])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if options.has("save"):
		_write(records, _record_path(options["save"]))
	var baseline: Array = []
	if options.has("compare"):
		baseline = _read(_record_path(options["compare"]))
	var report := Report.new(_managers, PROFILE_ID)
	var ok := report.print_all(records, baseline)
	print("== %s" % ("ALL TARGETS OK" if ok else "SOME TARGETS NG"))
	print("elapsed %.1fs (%d processes)" % [(Time.get_ticks_msec() - started) / 1000.0, processes])
	quit()


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg in args:
		var pair := arg.split("=", true, 1)
		options[pair[0]] = pair[1] if pair.size() > 1 else true
	return options


func _override(spec: String) -> void:
	for item in spec.split(","):
		var pair := item.split("=", true, 1)
		var path := pair[0].split(".")
		print("set %s = %s" % [pair[0], pair[1]])
		if path[0] == "balance":
			_db.balance.set(path[1], str_to_var(pair[1]))
			continue
		var params := (
			_db.manager(StringName(path[0])).active_params
			if path[1] == "active"
			else _db.manager(StringName(path[0])).passive_params
		)
		params[path[2]] = str_to_var(pair[1])


## 回す試合の一覧。順番もシードも引数だけで決まるので、どのプロセスでも同じ一覧になる
func _jobs(options: Dictionary) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	var per_seat := int(options.get("games", DEFAULT_GAMES)) / 2
	for a in _managers.size():
		for b in range(a + 1, _managers.size()):
			for i in per_seat:
				jobs.append(_job(MANAGER_JOB, _managers[a].id, _managers[b].id, i))
				jobs.append(_job(MANAGER_JOB, _managers[b].id, _managers[a].id, i))
	if options.has("managers"):
		return jobs
	var combos := _managers.size() * _managers.size()
	var per_combo := ceili(float(options.get("strategy", DEFAULT_STRATEGY_GAMES)) / combos)
	for kind in Strategies.NAMES.size():
		for a in _managers:
			for b in _managers:
				for i in per_combo:
					jobs.append(_job(kind, a.id, b.id, i))
	return jobs


func _job(kind: int, a: StringName, b: StringName, seed_index: int) -> Dictionary:
	return {"kind": kind, "ids": [a, b], "seed": SEED_BASE + seed_index}


## jobs のうち、番号を part_count で割った余りが part の試合を回す
func _run(jobs: Array[Dictionary], part: int, part_count: int) -> Array:
	var records: Array = []
	for i in range(part, jobs.size(), part_count):
		records.append(_play(jobs[i]))
	return records


## 各プロセスが同じ引数から同じ試合の一覧を作り、自分の分だけ回して記録をファイルへ書く
func _run_parallel(job_count: int, processes: int) -> Array:
	var root := ProjectSettings.globalize_path("res://")
	var pids: Array[int] = []
	var paths: Array[String] = []
	var passed := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if (
			not arg.begins_with("jobs=")
			and not arg.begins_with("save=")
			and not arg.begins_with("compare=")
		):
			passed.append(arg)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for part in mini(processes, job_count):
		var path := "%s/worker_%d.jsonl" % [OUT_DIR, part]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var args := PackedStringArray(
			["--headless", "--path", root, "--script", "res://tools/simulate.gd", "--"]
		)
		args.append_array(passed)
		args.append_array(["worker=%d/%d" % [part, mini(processes, job_count)], "out=%s" % path])
		pids.append(OS.create_process(OS.get_executable_path(), args))
		paths.append(path)
	for pid in pids:
		while OS.is_process_running(pid):
			OS.delay_msec(POLL_MSEC)
	var records: Array = []
	for path in paths:
		records.append_array(_read(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return records


func _play(job: Dictionary) -> Dictionary:
	var ids: Array[StringName] = [job["ids"][0], job["ids"][1]]
	var m := MatchState.new(_db, ids, job["seed"])
	var kind: int = job["kind"]
	var first := (
		CpuPlayer.new(m, 0, _profile)
		if kind == MANAGER_JOB
		else Strategies.create(kind, m, 0, _profile)
	)
	var cpus: Array[CpuPlayer] = [first, CpuPlayer.new(m, 1, _profile)]
	while not m.finished:
		m.advance(STEP)
		for cpu in cpus:
			cpu.update(STEP)
	var stores: Array = []
	for store in m.stores:
		(
			stores
			. append(
				{
					"profit": store.profit(),
					"sales": store.sales,
					"event_sales": store.event_sales,
					"wasted": store.wasted_count,
					"lost": store.lost_total,
					"visitors": store.visitor_total,
					"orders": store.order_count,
					"funds": store.funds,
				}
			)
		)
	var record := job.duplicate()
	record["winner"] = m.result.winner
	record["stores"] = stores
	return record


func _record_path(name: String) -> String:
	return "%s/%s.jsonl" % [OUT_DIR, name]


func _write(records: Array, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	for record in records:
		file.store_line(JSON.stringify(record))


func _read(path: String) -> Array:
	var records: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("cannot read %s" % path)
		return records
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			records.append(JSON.parse_string(line))
	return records
