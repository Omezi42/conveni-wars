extends SceneTree
## 画面の通し(Architecture.md 6章)。タイトル → 店長選択 → 試合 → 結果 を実際のシーンで起こし、
## 試合は自店もCPUに操作させて最後まで早回しする。画面のスクリプト(scripts/ui/)は run_tests.gd が
## 読まないため、ここで描画と操作の経路の実行時エラーを拾う。`tools/check.sh` から起動する。
## 画面のクラスは GameSession(autoload)を参照しており、--script の本体のコンパイル時にはまだ
## autoload が無いため、ここでは画面のクラスを名前で参照せず、実行時に引く(Pitfalls.md)。

const PLAYER := 0
const STEP := 1.0 / 30.0
const CPU_PROFILE_ID := &"standard"
## 本物の戦績を書き換えないよう、テストの間はこのファイルへ保存する
const TEST_SAVE_PATH := "user://test_save.cfg"
const STEPS_PER_FRAME := 200
const MAX_FRAMES := 400

var _failures: Array[String] = []
## autoload は --script の本体より後に登録されるため、名前ではなく実行時に引く
var _session: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("GameSession")
	_session.save = _test_save()
	var title: Control = await _show("res://scenes/title.tscn")
	_check(_class_of(title) == &"TitleScreen", "title scene")
	await _check_first_start(title)
	title.queue_free()

	var select: Control = await _show("res://scenes/manager_select.tscn")
	_check(_class_of(select) == &"ManagerSelectScreen", "manager select scene")
	select.queue_free()

	await _check_guide()

	_session.prepare_match(&"idol")
	_check(_session.cpu_manager_id != &"idol", "cpu picks a manager the player did not")
	var controller: Control = await _show("res://scenes/match.tscn")
	_check(_class_of(controller) == &"MatchController", "match scene")
	_exercise_player_moves(controller)
	await _play_to_the_end(controller)
	_check(_session.last_result != null, "the match hands its result to the session")
	_check(_session.save.games_played() == 2, "the result is added to the record")
	var result_screen := _find_result()
	_check(result_screen != null, "the result scene opens after the match")

	if _failures.is_empty():
		print("screen flow passed")
	else:
		for failure in _failures:
			printerr("screen flow FAILED: ", failure)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	quit(0 if _failures.is_empty() else 1)


## 戦績が無いときの「はじめる」は店長選択を飛ばし、既定の店長で試合を始める(GameDesign.md 9.1節)
func _check_first_start(title: Control) -> void:
	var wins: int = _session.save.wins
	_session.save.wins = 0
	title._on_start()
	await process_frame
	await process_frame
	_check(
		_session.player_manager_id == _session.FIRST_MANAGER_ID,
		"first start uses the default manager"
	)
	var opened := false
	for child in root.get_children():
		if _class_of(child) == &"MatchController":
			opened = true
			child.queue_free()
	_check(opened, "first start skips the manager select")
	_session.save.wins = wins
	await process_frame


## 初回ガイドの間は開店準備の時計が止まり、とばすと動き出す(GameDesign.md 9.7節)
func _check_guide() -> void:
	_session.guide_requested = true
	_session.prepare_match(&"veteran")
	var controller: Control = await _show("res://scenes/match.tscn")
	var state: MatchState = controller.match_state
	var before := state.elapsed
	controller._physics_process(1.0)
	_check(is_equal_approx(state.elapsed, before), "the guide stops the prep clock")
	controller._guide._advance()
	controller._guide._advance()
	controller._guide._advance()
	controller._physics_process(1.0)
	_check(state.elapsed > before, "the clock runs after the guide")
	_session.guide_requested = false
	controller.queue_free()
	await process_frame


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
	_exercise_catalog(controller, state)
	_exercise_shelf_order(controller, state)


## 棚に出ていない商品は品ぞろえの札の発注ボタンで発注でき、札のほかの所を押すと選べる。
## 棚に出ている商品の札には発注ボタンが無い
func _exercise_catalog(controller: Control, state: MatchState) -> void:
	var catalog = controller._catalog
	var product := state.db.product(&"melon_pan")
	var index := state.db.sorted_products().find(product)
	_check(not state.stores[PLAYER].is_on_shelf(product.id), "melon pan starts off the shelf")
	var before := state.stores[PLAYER].pending_count(product.id)
	catalog._gui_input(_left_press(catalog.order_rect(index).get_center()))
	var after := state.stores[PLAYER].pending_count(product.id)
	_check(after == before + state.balance.lot_size, "the order button on a tile orders a lot")
	catalog._gui_input(_left_press(catalog.tile_rect(index).get_center()))
	_check(controller._selection.product_id == product.id, "tapping a tile selects it")
	controller._selection.clear()
	var shelved: StringName = state.stores[PLAYER].shelf[4]
	var shelved_index := state.db.sorted_products().find(state.db.product(shelved))
	var pending := state.stores[PLAYER].pending_count(shelved)
	catalog._gui_input(_left_press(catalog.order_rect(shelved_index).get_center()))
	_check(
		state.stores[PLAYER].pending_count(shelved) == pending,
		"a tile on the shelf has no order button"
	)
	controller._selection.clear()


## 棚のマスの発注ボタンはその商品を発注し、値段のメニューは開かない
func _exercise_shelf_order(controller: Control, state: MatchState) -> void:
	var shelf = controller._own_shelf
	var product_id: StringName = state.stores[PLAYER].shelf[4]
	var before := state.stores[PLAYER].pending_count(product_id)
	shelf._gui_input(_left_press(shelf.order_rect(4).get_center()))
	var after := state.stores[PLAYER].pending_count(product_id)
	_check(after == before + state.balance.lot_size, "the order button on a slot orders a lot")
	_check(not controller._price_menu.visible, "ordering from a slot does not open the price menu")


func _left_press(pos: Vector2) -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	return press


func _play_to_the_end(controller: Control) -> void:
	var state: MatchState = controller.match_state
	var profile := state.db.cpu_profile(CPU_PROFILE_ID)
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


## 1試合遊んだことのある戦績(初回ガイドを出さない)
func _test_save() -> SaveData:
	var save := SaveData.new(TEST_SAVE_PATH)
	save.wins = 1
	return save
