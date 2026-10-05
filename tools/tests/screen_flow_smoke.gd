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

	await _check_hints()

	_session.prepare_match(&"idol")
	_check(_session.cpu_manager_id != &"idol", "cpu picks a manager the player did not")
	var controller: Control = await _show("res://scenes/match.tscn")
	_check(_class_of(controller) == &"MatchController", "match scene")
	_exercise_player_moves(controller)
	_exercise_pause(controller)
	await _play_to_the_end(controller)
	_check(_session.last_result != null, "the match hands its result to the session")
	_check(_session.save.games_played() == 2, "the result is added to the record")
	var result_screen := _find_result()
	_check(result_screen != null, "the result scene opens after the match")
	result_screen.queue_free()
	await process_frame

	await _check_online()

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


## ヒントは試合を止めずに出て、端末に1回だけ記録される(GameDesign.md 9.7節)。
## 雨の日は開店直後に客を逃し、そのヒントが先に出るため、初回の試合と同じ天気に固定する
func _check_hints() -> void:
	_session.save.clear_hints()
	_session.prepare_match(&"veteran")
	_session.weather_id = _session.FIRST_WEATHER_ID
	var controller: Control = await _show("res://scenes/match.tscn")
	var state: MatchState = controller.match_state
	var hints: HintLayer = controller._hints
	var before := state.elapsed
	controller._physics_process(HintLayer.OPENING_DELAY)
	hints._process(0.0)
	_check(state.elapsed > before, "hints do not stop the clock")
	_check(
		hints._current != null and hints._current.id == HintLayer.OPENING,
		"the forecast hint appears after a few seconds"
	)
	_check(_session.save.has_shown_hint(HintLayer.OPENING), "a shown hint is recorded")
	state.order(0, state.db.sorted_products()[0].id)
	hints._process(0.0)
	_check(hints._current == null, "the hint closes when the player orders")
	controller.queue_free()
	await process_frame


## オンライン対戦の画面(GameDesign.md 13章)。相手がつながらないまま試合を始め、待ったあと相手の店をCPUに任せて
## 最後まで進み、自分の勝ちとしてオンラインの戦績に入るまでを通す
func _check_online() -> void:
	var lobby: Control = await _show("res://scenes/online_lobby.tscn")
	_check(_class_of(lobby) == &"OnlineLobbyScreen", "online lobby scene")
	lobby._on_join_pressed()
	for i in 4:
		lobby._on_key("7")
	lobby._on_key("7")
	_check(lobby._code == "7777", "the keypad enters a four digit code")
	lobby._on_key(lobby.LABEL_DELETE)
	_check(lobby._code == "777", "the keypad deletes a digit")
	lobby.queue_free()

	_session.online = true
	_session.online_own = 1
	var select: Control = await _show("res://scenes/manager_select.tscn")
	_check(not select._levels[0].visible, "online manager select hides the cpu levels")
	select._selected = 0
	select._on_start()
	_check(select._own_pick != &"", "picking a manager waits for the other player")
	select.queue_free()

	var ids: Array[StringName] = [&"veteran", &"idol"]
	_session.prepare_online_match(5, ids)
	var controller: Control = await _show("res://scenes/match.tscn")
	var state: MatchState = controller.match_state
	_check(controller._link != null, "an online match has a link instead of a cpu")
	_check(controller._own_shelf.store_index == 1, "the guest plays store 1 on the left")
	var product := state.db.sorted_products()[0].id
	var before := state.stores[1].pending_count(product)
	controller._commands.order(1, product)
	_check(state.stores[1].pending_count(product) == before, "an online order waits for its tick")
	controller._link.open_menu()
	_check(controller._link._resign.visible, "the pause button opens the resign menu")
	controller._link.close_menu()
	var config := NetConfig.load_default()
	var waited := 0.0
	while not controller._link.peer_left() and waited < config.drop_seconds * 2.0:
		controller._physics_process(STEP)
		waited += STEP
	_check(controller._link.peer_left(), "a silent peer is handed to the cpu")
	for i in config.input_delay_ticks * 2:
		controller._physics_process(STEP)
	_check(state.stores[1].pending_count(product) > before, "the delayed order runs")
	var player_cpu := CpuPlayer.new(state, 1, state.db.cpu_profile(CPU_PROFILE_ID))
	await _run_until_result(controller, player_cpu)
	_check(_session.last_result.winner == 1, "the player wins when the peer leaves")
	_check(_session.save.online_wins == 1, "the online result goes to the online record")
	var result_screen := _find_result()
	_check(
		result_screen != null and result_screen._buttons.size() == 2,
		"online result has two buttons"
	)
	_session.online = false


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
## 棚に出ている商品は品ぞろえに出ない
func _exercise_catalog(controller: Control, state: MatchState) -> void:
	var catalog = controller._catalog
	var product := state.db.product(&"melon_pan")
	_check(not state.stores[PLAYER].is_on_shelf(product.id), "melon pan starts off the shelf")
	catalog._layout()
	var index: int = catalog.tile_index(product.id)
	_check(index >= 0, "a product off the shelf has a tile")
	var before := state.stores[PLAYER].pending_count(product.id)
	catalog._gui_input(_left_press(catalog.order_rect(index).get_center()))
	var after := state.stores[PLAYER].pending_count(product.id)
	_check(after == before + state.balance.lot_size, "the order button on a tile orders a lot")
	var icon_point: Vector2 = catalog.tile_rect(index).position + Vector2.ONE * catalog.PAD * 2.0
	catalog._gui_input(_left_press(icon_point))
	_check(controller._selection.product_id == product.id, "tapping a tile selects it")
	controller._selection.clear()
	var shelved: StringName = state.stores[PLAYER].shelf[4]
	_check(catalog.tile_index(shelved) < 0, "a product on the shelf has no tile")


## 棚のマスの発注ボタンはその商品を発注し、値段のメニューは開かない
func _exercise_shelf_order(controller: Control, state: MatchState) -> void:
	var shelf = controller._own_shelf
	var product_id: StringName = state.stores[PLAYER].shelf[4]
	var before := state.stores[PLAYER].pending_count(product_id)
	shelf._gui_input(_left_press(shelf.order_rect(4).get_center()))
	var after := state.stores[PLAYER].pending_count(product_id)
	_check(after == before + state.balance.lot_size, "the order button on a slot orders a lot")
	_check(not controller._price_menu.visible, "ordering from a slot does not open the price menu")
	var copy := {"product_id": product_id, "from_slot": 4}
	shelf._drop_data(shelf.slot_rect(0).get_center(), copy)
	_check(state.stores[PLAYER].shelf[0] == product_id, "dragging a slot copies it to another slot")
	_check(state.stores[PLAYER].shelf[4] == product_id, "the dragged slot keeps its product")


## 一時停止の間は試合が進まず、続けると動き出す(GameDesign.md 9.9節)
func _exercise_pause(controller: Control) -> void:
	var state: MatchState = controller.match_state
	controller._open_pause()
	_check(controller._pause.visible, "the pause menu opens")
	var before := state.elapsed
	controller._physics_process(1.0)
	_check(is_equal_approx(state.elapsed, before), "the pause stops the match")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	controller._unhandled_input(escape)
	_check(not controller._pause.visible, "escape closes the pause menu")
	controller._physics_process(1.0)
	_check(state.elapsed > before, "the match runs after the pause")


func _left_press(pos: Vector2) -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	return press


func _play_to_the_end(controller: Control) -> void:
	var state: MatchState = controller.match_state
	var profile := state.db.cpu_profile(CPU_PROFILE_ID)
	await _run_until_result(controller, CpuPlayer.new(state, PLAYER, profile))
	_check(state.stores[0].sales > 0 and state.stores[1].sales > 0, "both stores sell")


func _run_until_result(controller: Control, player_cpu: CpuPlayer) -> void:
	var state: MatchState = controller.match_state
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


## 1試合遊んだことのある戦績(タイトルの「はじめる」で店長選択を出す)
func _test_save() -> SaveData:
	var save := SaveData.new(TEST_SAVE_PATH)
	save.wins = 1
	return save
