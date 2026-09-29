extends SceneTree
## 画面の通し(Architecture.md 6章)。タイトル → 店長選択 → 試合 → 結果 を実際のシーンで起こし、
## 試合は自店もCPUに操作させて最後まで早回しする。画面のスクリプト(scripts/ui/)は run_tests.gd が
## 読まないため、ここで描画と操作の経路の実行時エラーを拾う。`tools/check.sh` から起動する。
## 画面のクラスは GameSession(autoload)を参照しており、--script の本体のコンパイル時にはまだ
## autoload が無いため、ここでは画面のクラスを名前で参照せず、実行時に引く(Pitfalls.md)。

const PLAYER := 0
const STEP := 1.0 / 30.0
const STEPS_PER_FRAME := 200
const MAX_FRAMES := 400

var _failures: Array[String] = []
## autoload は --script の本体より後に登録されるため、名前ではなく実行時に引く
var _session: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("GameSession")
	var title: Control = await _show("res://scenes/title.tscn")
	_check(_class_of(title) == &"TitleScreen", "title scene")
	title.queue_free()

	var select: Control = await _show("res://scenes/manager_select.tscn")
	_check(_class_of(select) == &"ManagerSelectScreen", "manager select scene")
	select.queue_free()

	_session.prepare_match(&"idol")
	_check(_session.cpu_manager_id != &"idol", "cpu picks a manager the player did not")
	var controller: Control = await _show("res://scenes/match.tscn")
	_check(_class_of(controller) == &"MatchController", "match scene")
	_exercise_player_moves(controller)
	await _play_to_the_end(controller)
	_check(_session.last_result != null, "the match hands its result to the session")
	var result_screen := _find_result()
	_check(result_screen != null, "the result scene opens after the match")

	if _failures.is_empty():
		print("screen flow passed")
	else:
		for failure in _failures:
			printerr("screen flow FAILED: ", failure)
	quit(0 if _failures.is_empty() else 1)


func _show(path: String) -> Control:
	var scene: Control = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	return scene


## 画面の操作の経路(選んでマスを押す・値段メニュー・発注)を通す
func _exercise_player_moves(controller: Control) -> void:
	var state: MatchState = controller.match_state
	_check(state.order(PLAYER, &"nori_bento"), "order from the match screen")
	controller._selection.toggle(&"nori_bento")
	controller._on_own_slot_pressed(4)
	_check(state.stores[0].shelf[4] == &"nori_bento", "tap-select then tap a slot places it")
	_check(not controller._selection.has_selection(), "placing clears the selection")
	controller._on_own_slot_pressed(4)
	_check(controller._price_menu.visible, "tapping a stocked slot opens the price menu")
	controller._price_menu._on_step_pressed(0)
	_check(state.stores[0].price_step(&"nori_bento") == 0, "the price menu changes the price")
	_check(not controller._price_menu.visible, "choosing a price closes the menu")
	controller._on_product_dropped(&"hot_coffee", 1)
	_check(state.stores[0].shelf[1] == &"hot_coffee", "dropping a card places it")


func _play_to_the_end(controller: Control) -> void:
	var state: MatchState = controller.match_state
	var profile := state.db.cpu_profile(_session.CPU_PROFILE_ID)
	var player_cpu := CpuPlayer.new(state, PLAYER, profile)
	var frames := 0
	while _find_result() == null and frames < MAX_FRAMES:
		for i in STEPS_PER_FRAME:
			if state.finished:
				break
			controller._physics_process(STEP)
			controller._process(STEP)
			player_cpu.update(STEP)
		if state.finished:
			controller._physics_process(STEP * STEPS_PER_FRAME)
		await process_frame
		frames += 1
	_check(state.finished, "the match reaches the end")
	_check(state.stores[0].sales > 0 and state.stores[1].sales > 0, "both stores sell")


func _find_result() -> Node:
	for child in root.get_children():
		if _class_of(child) == &"ResultScreen":
			return child
	return null


func _class_of(node: Node) -> StringName:
	var script := node.get_script() as Script
	return &"" if script == null else script.get_global_name()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
