class_name MatchController
extends Control
## 試合画面(Architecture.md 4章)。MatchState と CPU を持って進め、部品へ渡し、シグナルを演出へつなぐ。
## オンライン対戦(GameDesign.md 13章)では CPU の代わりに OnlineMatchLink が相手の操作を流す。

const RESULT_SCENE := "res://scenes/result.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

const SCREEN_SIZE := Vector2(1280, 720)
const HUD_RECT := Rect2(0, 0, 1280, 80)
## 上端の右端の一時停止のボタン(GameDesign.md 9.9節)
const PAUSE_BUTTON_RECT := Rect2(1220, 8, 48, 50)
const OWN_FRAME_RECT := Rect2(12, 86, 628, 506)
const OWN_SHELF_POS := Vector2(30, 68)
const OWN_CELL := Vector2(176, 134)
const OWN_GAP := Vector2(16, 12)
## 自店の看板の「?」(店の中の座標)と、押すと出るボーナスの見方(店の中の座標)
const HELP_RECT := Rect2(583, 8, 30, 30)
const HELP_LEGEND_RECT := Rect2(150, 72, 420, 200)
const STREET_RECT := Rect2(640, 86, 120, 506)
const RIVAL_FRAME_RECT := Rect2(760, 86, 508, 226)
const RIVAL_SHELF_POS := Vector2(100, 46)
const RIVAL_CELL := Vector2(96, 52)
const RIVAL_GAP := Vector2(10, 6)
const FORECAST_RECT := Rect2(760, 322, 508, 270)
const CATALOG_RECT := Rect2(12, 600, 988, 112)
const SKILL_RECT := Rect2(1010, 600, 258, 112)

## 「+¥」をまとめて出す間隔(1秒に十数個売れるため、商品ごとに束ねる)
const SALE_POP_INTERVAL := 0.25
const POP_SIZE := UiPalette.FONT_HEAD
## 開店直後は利益の差が小さく入れ替わりやすいため、逆転の表示を出さない秒数
const REVERSAL_GRACE := 15.0
const REVERSAL_COOLDOWN := 12.0
const RESULT_DELAY := 2.5
## 時間帯のカットインの地は空の色を暗くして白い文字を読めるようにする
const BAND_CUTIN_DARKEN := 0.25

var match_state: MatchState

var _own := 0
var _rival := 1
var _runner: MatchRunner
var _commands: PlayerCommands
## オンライン対戦のときだけ
var _link: OnlineMatchLink
var _sky: SkyBackdrop
var _selection := UiSelection.new()
var _own_shelf: ShelfView
var _rival_shelf: ShelfView
var _own_frame: StoreFrame
var _rival_frame: StoreFrame
var _price_menu: PriceMenu
var _catalog: CatalogView
var _skill: SkillButton
var _flow: CustomerFlow
var _fx: FxLayer
var _pause: PauseMenu
## "店番号:商品id" → [店番号, 商品id, 金額]
var _pending_pops: Dictionary = {}
var _pop_timer := 0.0
var _player_leading := false
var _reversal_cooldown := 0.0
var _hints: HintLayer
var _end_timer := -1.0
var _leaving := false


func _ready() -> void:
	var db := GameDatabase.get_default()
	var ids := GameSession.manager_ids()
	_own = GameSession.own_store()
	_rival = 1 - _own
	ViewSide.own = _own
	match_state = MatchState.new(db, ids, GameSession.match_seed, GameSession.weather_id)
	match_state.record.store_index = _own
	if GameSession.online:
		var no_cpus: Array[CpuPlayer] = []
		_runner = MatchRunner.new(match_state, no_cpus)
		_link = OnlineMatchLink.new()
		_link.setup(_runner, _own)
		_commands = PlayerCommands.new(match_state, _link.lockstep)
	else:
		var cpu := CpuPlayer.new(match_state, _rival, db.cpu_profile(GameSession.cpu_profile_id()))
		match_state.record.cpu_profile_id = GameSession.cpu_profile_id()
		var cpus: Array[CpuPlayer] = [cpu]
		_runner = MatchRunner.new(match_state, cpus)
		_runner.take_snapshots = true
		_commands = PlayerCommands.new(match_state)
	_build()
	_connect_signals()
	if _link == null:
		_build_hints()
	_build_pause()
	var weather := match_state.weather
	var opening := "開店! 今日は%s" % weather.display_name
	_fx.cutin(opening, ViewSide.color(_own), false, weather.cutin_text)


func _physics_process(delta: float) -> void:
	if _pause.visible:
		return
	if match_state.finished:
		_end_timer -= delta
		if _end_timer <= 0.0 and not _leaving:
			_leaving = true
			if _link != null:
				GameSession.finish_online_match(match_state.result, _link.peer_left())
			else:
				GameSession.finish_match(match_state.result)
			get_tree().change_scene_to_file(RESULT_SCENE)
		return
	if _link != null:
		_link.step(delta)
	else:
		_runner.step(delta)


func _process(delta: float) -> void:
	_pop_timer -= delta
	if _pop_timer <= 0.0:
		_pop_timer = SALE_POP_INTERVAL
		_flush_sale_pops()
	_check_reversal(delta)


func _unhandled_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_RIGHT:
		_selection.clear()
	if event.is_action_pressed("ui_cancel"):
		if _pause.visible:
			_pause.close()
		elif _selection.has_selection():
			_selection.clear()
		elif _link != null:
			_link.open_menu()
		else:
			_open_pause()


## ブラウザのタブや窓から離れたら一時停止する(GameDesign.md 9.9節)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _pause != null and _link == null:
		_open_pause()


func _build() -> void:
	_sky = SkyBackdrop.new()
	_place(_sky, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_sky.set_band(match_state.current_band(), true, match_state.weather)

	_place(_part(HudBar.new(), _own), HUD_RECT)

	_own_frame = _part(StoreFrame.new(), _own)
	_own_frame.door_on_right = true
	_own_frame.door_y = OWN_SHELF_POS.y + OWN_CELL.y * 1.5 + OWN_GAP.y
	_place(_own_frame, OWN_FRAME_RECT)
	_own_shelf = _part(ShelfView.new(), _own)
	_own_shelf.configure(OWN_CELL, OWN_GAP, true)
	_own_shelf.selection = _selection
	_own_frame.add_child(_own_shelf)
	_own_shelf.position = OWN_SHELF_POS
	_own_shelf.size = _own_shelf.grid_size()
	var help: BonusHelp = _part(BonusHelp.new(), _own)
	_own_frame.add_child(help)
	help.position = HELP_RECT.position
	help.size = HELP_RECT.size
	help.legend_rect = Rect2(HELP_LEGEND_RECT.position - HELP_RECT.position, HELP_LEGEND_RECT.size)
	_own_frame.sign_reserved = OWN_FRAME_RECT.size.x - HELP_RECT.position.x - StoreFrame.PAD

	_rival_frame = _part(StoreFrame.new(), _rival)
	_rival_frame.door_on_right = false
	_rival_frame.compact = true
	_rival_frame.door_y = RIVAL_SHELF_POS.y + RIVAL_CELL.y * 1.5 + RIVAL_GAP.y
	_place(_rival_frame, RIVAL_FRAME_RECT)
	_rival_shelf = _part(ShelfView.new(), _rival)
	_rival_shelf.configure(RIVAL_CELL, RIVAL_GAP, false)
	_rival_frame.add_child(_rival_shelf)
	_rival_shelf.position = RIVAL_SHELF_POS
	_rival_shelf.size = _rival_shelf.grid_size()

	_flow = _part(CustomerFlow.new(), _own)
	_place(_flow, STREET_RECT)
	var street_top := STREET_RECT.position.y
	var own_door := OWN_FRAME_RECT.position.y + _own_frame.door_y - street_top
	var rival_door := RIVAL_FRAME_RECT.position.y + _rival_frame.door_y - street_top
	_flow.door_points[_own] = Vector2(0.0, own_door)
	_flow.door_points[_rival] = Vector2(STREET_RECT.size.x, rival_door)

	_place(_part(ForecastPanel.new(), _own), FORECAST_RECT)
	_catalog = _part(CatalogView.new(), _own)
	_catalog.selection = _selection
	_place(_catalog, CATALOG_RECT)
	_skill = _part(SkillButton.new(), _own)
	_place(_skill, SKILL_RECT)

	_price_menu = PriceMenu.new()
	_place(_price_menu, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_price_menu.setup(match_state, _own)
	_price_menu.commands = _commands
	_price_menu.closed.connect(func() -> void: _own_shelf.open_slot = -1)

	_fx = FxLayer.new()
	_place(_fx, Rect2(Vector2.ZERO, SCREEN_SIZE))

	var sounds := MatchSounds.new()
	add_child(sounds)
	sounds.setup(match_state)


func _build_hints() -> void:
	_hints = HintLayer.new()
	_hints.own_shelf = _own_shelf
	_hints.catalog = _catalog
	_hints.forecast_rect = FORECAST_RECT
	var skill := _skill.button_rect()
	_hints.skill_rect = Rect2(SKILL_RECT.position + skill.position, skill.size)
	_place(_hints, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_hints.setup(match_state, GameSession.save)


## 幕はヒントより上に重ねるため、最後に置く。オンライン対戦では同じボタンで降参のメニューを開く(GameDesign.md 9.9節)
func _build_pause() -> void:
	var button := PauseMenu.create_button()
	_place(button, PAUSE_BUTTON_RECT)
	if _link != null:
		_place(_link, Rect2(Vector2.ZERO, SCREEN_SIZE))
		button.pressed.connect(_link.open_menu)
	else:
		button.pressed.connect(_open_pause)
	_pause = PauseMenu.new()
	_place(_pause, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_pause.restart_requested.connect(_on_restart)
	_pause.quit_requested.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _open_pause() -> void:
	if match_state.finished or _leaving:
		return
	_selection.clear()
	_price_menu.close()
	_pause.open()


## やめた試合は戦績に数えない(GameDesign.md 9.9節)
func _on_restart() -> void:
	GameSession.prepare_match(GameSession.player_manager_id)
	get_tree().change_scene_to_file(MATCH_SCENE)


func _part(part: MatchPart, index: int) -> MatchPart:
	part.setup(match_state, index)
	part.commands = _commands
	return part


func _place(control: Control, rect: Rect2) -> void:
	add_child(control)
	control.position = rect.position
	control.size = rect.size


func _connect_signals() -> void:
	_own_shelf.slot_pressed.connect(_on_own_slot_pressed)
	_own_shelf.product_dropped.connect(_on_product_dropped)
	match_state.band_changed.connect(_on_band_changed)
	match_state.purchased.connect(_on_purchased)
	match_state.customer_arrived.connect(_flow.push_arrival)
	match_state.customer_lost.connect(_flow.push_lost)
	_flow.visible_entered.connect(_own_shelf.flash)
	match_state.event_started.connect(_on_event_started)
	match_state.event_ended.connect(_on_event_ended)
	match_state.skill_used.connect(_on_skill_used)
	match_state.match_ended.connect(_on_match_ended)


func _on_own_slot_pressed(slot: int) -> void:
	if _selection.has_selection():
		_commands.assign(_own, _selection.product_id, slot)
		_selection.clear()
		return
	if match_state.stores[_own].shelf[slot] == StoreState.EMPTY:
		return
	var rect := _own_shelf.slot_rect(slot)
	_price_menu.open_for(slot, Rect2(_own_shelf.global_position + rect.position, rect.size))
	_own_shelf.open_slot = slot


func _on_product_dropped(product_id: StringName, slot: int) -> void:
	_commands.assign(_own, product_id, slot)
	_selection.clear()


func _on_band_changed(band_id: StringName) -> void:
	var band := match_state.db.band(band_id)
	_sky.set_band(band, false, match_state.weather)
	var bands := match_state.db.sorted_bands()
	var index := bands.find(band)
	var report := "" if index <= 0 else _band_report(bands[index - 1].id)
	_fx.cutin(band.cutin_text, band.sky_top.darkened(BAND_CUTIN_DARKEN), false, report)


## 終わった時間帯の成績の1行(GameDesign.md 9.3節)。読みが当たれば、カットインのあとに「読み的中!」を出す
func _band_report(band_id: StringName) -> String:
	var store := match_state.stores[_own]
	var share := store.band_share(band_id)
	if share < 0.0:
		return ""
	var report := "%sの客 %d%%" % [match_state.db.band(band_id).display_name, roundi(share * 100.0)]
	var grade := match_state.balance.share_grade(share)
	if grade > 0:
		_fx.big("読み的中!", UiPalette.GOOD, true, FxLayer.CUTIN_SECONDS)
	elif grade < 0:
		var advice := LossText.advice(store.losses_in_band(band_id), store, match_state.db)
		if advice != "":
			report += "  " + advice
	return report


## 「+¥」は自店の棚からだけ出す(相手の売上は上端のバーで分かる。9.2節)
func _on_purchased(store_index: int, product_id: StringName, _count: int, amount: int) -> void:
	if store_index != _own:
		return
	var key := "%d:%s" % [store_index, product_id]
	if not _pending_pops.has(key):
		_pending_pops[key] = [store_index, product_id, 0]
	_pending_pops[key][2] += amount


func _flush_sale_pops() -> void:
	for entry: Array in _pending_pops.values():
		_fx.pop(
			_own_shelf.sale_origin(entry[1]), "+" + UiDraw.yen(entry[2]), UiPalette.MONEY, POP_SIZE
		)
	_pending_pops.clear()


func _on_event_started(event_id: StringName) -> void:
	_fx.cutin("%s!" % match_state.db.event(event_id).display_name, UiPalette.WARN, true)


func _on_event_ended(_event_id: StringName, store_counts: Array[int]) -> void:
	var balance := match_state.balance
	if store_counts[_own] >= ceili(balance.event_customer_count * balance.big_catch_ratio):
		_fx.big("大口獲得!", UiPalette.MONEY, true)
		AudioDirector.play_se(&"big_catch")


func _on_skill_used(store_index: int) -> void:
	var manager := match_state.stores[store_index].manager
	var label := "%s:%s!" % [ViewSide.name(store_index), manager.active_name]
	_fx.cutin(label, manager.color)


func _on_match_ended(_result: MatchResult) -> void:
	_fx.big("閉店!", UiPalette.INK_ON_DARK)
	_end_timer = RESULT_DELAY


func _check_reversal(delta: float) -> void:
	_reversal_cooldown = maxf(_reversal_cooldown - delta, 0.0)
	var own := match_state.stores[_own].profit()
	var rival := match_state.stores[_rival].profit()
	var leading := own > rival
	if leading and not _player_leading and match_state.elapsed > REVERSAL_GRACE:
		if _reversal_cooldown <= 0.0:
			_fx.big("利益で逆転!", ViewSide.color(_own), true)
			AudioDirector.play_se(&"reversal")
			_reversal_cooldown = REVERSAL_COOLDOWN
	_player_leading = leading
