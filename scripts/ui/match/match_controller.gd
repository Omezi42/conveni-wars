class_name MatchController
extends Control
## 試合画面(Architecture.md 4章)。MatchState と CPU を持って進め、部品へ渡し、シグナルを演出へつなぐ。

const PLAYER := 0
const CPU := 1
const RESULT_SCENE := "res://scenes/result.tscn"

const SCREEN_SIZE := Vector2(1280, 720)
const HUD_RECT := Rect2(0, 0, 1280, 56)
const GRID_RECT := Rect2(8, 64, 300, 496)
const SKILL_RECT := Rect2(8, 568, 300, 144)
const FORECAST_RECT := Rect2(316, 64, 648, 96)
const STREET_RECT := Rect2(316, 160, 648, 220)
const EVENT_RECT := Rect2(430, 168, 420, 66)
## 背景の絵(assets/backgrounds/street.svg)の両店の扉の足もと(自店・相手の順)
const DOORS: Array[Vector2] = [Vector2(565, 338), Vector2(715, 338)]
const OWN_FRAME_RECT := Rect2(316, 384, 320, 328)
const OWN_SHELF_POS := Vector2(17, 36)
const OWN_CELL := 92.0
const OWN_GAP := 5.0
const PRICE_RECT := Rect2(644, 384, 320, 164)
const BONUS_RECT := Rect2(644, 556, 320, 156)
const RIVAL_FRAME_RECT := Rect2(972, 64, 300, 266)
const RIVAL_SHELF_POS := Vector2(38, 36)
const RIVAL_CELL := 72.0
const RIVAL_GAP := 4.0
const VISIT_RECT := Rect2(972, 338, 300, 374)

## 「+¥」をまとめて出す間隔(1秒に十数個売れるため、商品ごとに束ねる)
const SALE_POP_INTERVAL := 0.25
const OWN_POP_SIZE := UiPalette.FONT_LARGE
const RIVAL_POP_SIZE := UiPalette.FONT_SMALL
## 開店直後は客数の差が小さく入れ替わりやすいため、逆転の表示を出さない秒数
const REVERSAL_GRACE := 15.0
const REVERSAL_COOLDOWN := 12.0
const RESULT_DELAY := 2.5

var match_state: MatchState

var _cpu: CpuPlayer
var _selection := UiSelection.new()
var _own_shelf: ShelfView
var _rival_shelf: ShelfView
var _price_panel: PricePanel
var _flow: CustomerFlow
var _fx: FxLayer
## "店番号:商品id" → [店番号, 商品id, 金額]
var _pending_pops: Dictionary = {}
var _pop_timer := 0.0
var _player_leading := false
var _reversal_cooldown := 0.0
var _end_timer := -1.0
var _leaving := false


func _ready() -> void:
	var db := GameDatabase.get_default()
	match_state = MatchState.new(db, GameSession.manager_ids(), GameSession.match_seed)
	_cpu = CpuPlayer.new(match_state, CPU, db.cpu_profile(GameSession.CPU_PROFILE_ID))
	_build()
	_connect_signals()


func _physics_process(delta: float) -> void:
	if match_state.finished:
		_end_timer -= delta
		if _end_timer <= 0.0 and not _leaving:
			_leaving = true
			GameSession.last_result = match_state.result
			get_tree().change_scene_to_file(RESULT_SCENE)
		return
	match_state.advance(delta)
	_cpu.update(delta)


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
		_selection.clear()


func _build() -> void:
	var background := TextureRect.new()
	background.texture = UiDraw.background()
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(background, Rect2(Vector2.ZERO, SCREEN_SIZE))

	_flow = _part(CustomerFlow.new(), PLAYER)
	_place(_flow, STREET_RECT)
	for i in DOORS.size():
		_flow.door_points[i] = DOORS[i] - STREET_RECT.position
	_place(_part(EventBanner.new(), PLAYER), EVENT_RECT)

	_place(_part(HudBar.new(), PLAYER), HUD_RECT)
	var grid: ProductGrid = _part(ProductGrid.new(), PLAYER)
	grid.selection = _selection
	_place(grid, GRID_RECT)
	_place(_part(SkillButton.new(), PLAYER), SKILL_RECT)
	_place(_part(ForecastPanel.new(), PLAYER), FORECAST_RECT)

	_own_shelf = _add_shelf(PLAYER, OWN_FRAME_RECT, OWN_SHELF_POS, OWN_CELL, OWN_GAP)
	_own_shelf.selection = _selection
	_price_panel = _part(PricePanel.new(), PLAYER)
	_price_panel.selection = _selection
	_place(_price_panel, PRICE_RECT)
	_place(_part(BonusPanel.new(), PLAYER), BONUS_RECT)

	_rival_shelf = _add_shelf(CPU, RIVAL_FRAME_RECT, RIVAL_SHELF_POS, RIVAL_CELL, RIVAL_GAP)
	_place(_part(VisitCounter.new(), PLAYER), VISIT_RECT)

	_fx = FxLayer.new()
	_place(_fx, Rect2(Vector2.ZERO, SCREEN_SIZE))


func _add_shelf(
	index: int, frame_rect: Rect2, pos: Vector2, cell: float, spacing: float
) -> ShelfView:
	var frame: StoreFrame = _part(StoreFrame.new(), index)
	_place(frame, frame_rect)
	var shelf: ShelfView = _part(ShelfView.new(), index)
	shelf.configure(cell, spacing, index == PLAYER)
	frame.add_child(shelf)
	shelf.position = pos
	shelf.size = shelf.grid_size()
	return shelf


func _part(part: MatchPart, index: int) -> MatchPart:
	part.setup(match_state, index)
	return part


func _place(control: Control, rect: Rect2) -> void:
	add_child(control)
	control.position = rect.position
	control.size = rect.size


func _connect_signals() -> void:
	_own_shelf.slot_pressed.connect(_on_own_slot_pressed)
	_own_shelf.product_dropped.connect(_on_product_dropped)
	match_state.opened.connect(func() -> void: _fx.cutin("開店!", UiPalette.STORE_COLORS[PLAYER]))
	match_state.band_changed.connect(_on_band_changed)
	match_state.purchased.connect(_on_purchased)
	match_state.customer_arrived.connect(_flow.push_arrival)
	match_state.customer_lost.connect(_flow.push_lost)
	match_state.event_started.connect(_on_event_started)
	match_state.event_ended.connect(_on_event_ended)
	match_state.skill_used.connect(_on_skill_used)
	match_state.match_ended.connect(_on_match_ended)


func _on_own_slot_pressed(slot: int) -> void:
	if _selection.has_selection():
		var product_id := _selection.product_id
		match_state.assign(PLAYER, product_id, slot)
		_selection.clear()
		_selection.focus(product_id, slot)
		return
	var product_id := match_state.stores[PLAYER].shelf[slot]
	if product_id == StoreState.EMPTY:
		_selection.clear_focus()
		return
	_selection.focus(product_id, slot)


func _on_product_dropped(product_id: StringName, slot: int) -> void:
	match_state.assign(PLAYER, product_id, slot)
	_selection.clear()
	_selection.focus(product_id, slot)


func _on_band_changed(band_id: StringName) -> void:
	var band := match_state.db.band(band_id)
	_fx.cutin(band.cutin_text, UiPalette.BAR)


func _on_purchased(store_index: int, product_id: StringName, _count: int, amount: int) -> void:
	var key := "%d:%s" % [store_index, product_id]
	if not _pending_pops.has(key):
		_pending_pops[key] = [store_index, product_id, 0]
	_pending_pops[key][2] += amount


func _flush_sale_pops() -> void:
	for entry: Array in _pending_pops.values():
		var store_index: int = entry[0]
		var shelf := _own_shelf if store_index == PLAYER else _rival_shelf
		var font_size := OWN_POP_SIZE if store_index == PLAYER else RIVAL_POP_SIZE
		var color := UiPalette.GOOD if store_index == PLAYER else UiPalette.STORE_COLORS[CPU]
		_fx.pop(shelf.sale_origin(entry[1]), "+" + UiDraw.yen(entry[2]), color, font_size)
	_pending_pops.clear()


func _on_event_started(event_id: StringName) -> void:
	_fx.cutin("%s!" % match_state.db.event(event_id).display_name, UiPalette.WARN)


func _on_event_ended(_event_id: StringName, store_counts: Array[int]) -> void:
	var balance := match_state.balance
	if store_counts[PLAYER] >= ceili(balance.event_customer_count * balance.big_catch_ratio):
		_fx.big("大口獲得!", UiPalette.WARN)


func _on_skill_used(store_index: int) -> void:
	var manager := match_state.stores[store_index].manager
	var label := "%s:%s!" % [UiPalette.STORE_NAMES[store_index], manager.active_name]
	_fx.cutin(label, manager.color)


func _on_match_ended(_result: MatchResult) -> void:
	_fx.big("閉店!", UiPalette.INK)
	_end_timer = RESULT_DELAY


func _check_reversal(delta: float) -> void:
	_reversal_cooldown = maxf(_reversal_cooldown - delta, 0.0)
	var own := match_state.stores[PLAYER].visitor_total
	var rival := match_state.stores[CPU].visitor_total
	var leading := own > rival
	if leading and not _player_leading and match_state.elapsed > REVERSAL_GRACE:
		if _reversal_cooldown <= 0.0:
			_fx.big("客数で逆転!", UiPalette.STORE_COLORS[PLAYER])
			_reversal_cooldown = REVERSAL_COOLDOWN
	_player_leading = leading
