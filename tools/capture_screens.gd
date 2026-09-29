extends SceneTree
## 各画面と試合の数場面のスクリーンショットを撮る(見た目の確認は人が行う。CLAUDE.md「検証」)。
## ウィンドウを開いて描くため --headless では撮れない(Pitfalls.md)。
## godot --path . --script res://tools/capture_screens.gd -- <出力フォルダの絶対パス>
## 画面のクラスは autoload を参照するため名前で参照しない(screen_flow_smoke.gd と同じ理由)。

const PLAYER := 0
const STEP := 1.0 / 30.0
const SETTLE_FRAMES := 6
## 試合のどの時刻(開店からの秒)で撮るか
const MATCH_SHOTS: Array[float] = [-5.0, 12.0, 70.0, 160.0, 245.0]
const SEED := 20260929

var _out_dir := ""
var _session: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://logs/shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_session = root.get_node("GameSession")

	var title := await _show("res://scenes/title.tscn")
	await _shot("01_title")
	title.queue_free()

	var select := await _show("res://scenes/manager_select.tscn")
	select._selected = 1
	select._start.disabled = false
	select.queue_redraw()
	await _shot("02_manager_select")
	select.queue_free()

	_session.prepare_match(&"idol")
	_session.match_seed = SEED
	var controller := await _show("res://scenes/match.tscn")
	await _capture_match(controller)
	controller.queue_free()
	await process_frame
	var result := _find(&"ResultScreen")
	if result == null:
		result = await _show("res://scenes/result.tscn")
	await _shot("99_result")
	print("captured to ", _out_dir)
	quit()


func _capture_match(controller: Control) -> void:
	var state: MatchState = controller.match_state
	var profile := state.db.cpu_profile(_session.CPU_PROFILE_ID)
	var player_cpu := CpuPlayer.new(state, PLAYER, profile)
	var index := 3
	for at in MATCH_SHOTS:
		while state.elapsed < at:
			_step(controller, player_cpu)
		await _shot("%02d_match_%ds" % [index, int(at)])
		index += 1
	var slot := state.stores[PLAYER].shelf.find(state.stores[PLAYER].shelf_product_ids()[0])
	controller._on_own_slot_pressed(slot)
	await _shot("%02d_match_price_menu" % index)
	controller._price_menu.close()
	index += 1
	controller._selection.toggle(state.db.sorted_products()[0].id)
	await _shot("%02d_match_selecting" % index)
	controller._selection.clear()
	index += 1
	while not state.finished:
		controller._physics_process(STEP)
		player_cpu.update(STEP)
	await _shot("%02d_match_closed" % index)
	while _find(&"ResultScreen") == null:
		controller._physics_process(STEP)
		await process_frame


## 試合を1コマ進める。演出と人の流れも同じ時間だけ進め、早送りのあいだに溜まらないようにする
func _step(controller: Control, player_cpu: CpuPlayer) -> void:
	controller._physics_process(STEP)
	controller._process(STEP)
	controller._fx._process(STEP)
	controller._flow._process(STEP)
	player_cpu.update(STEP)


func _show(path: String) -> Control:
	var scene: Control = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	for i in SETTLE_FRAMES:
		await process_frame
	return scene


func _shot(name: String) -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(_out_dir.path_join(name + ".png"))


func _find(class_id: StringName) -> Node:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script != null and script.get_global_name() == class_id:
			return child
	return null
