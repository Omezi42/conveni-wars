class_name MatchController
extends Control
## 試合画面(Architecture.md 4章)。MatchState と CPU を持って進め、部品へ渡し、シグナルを演出へつなぐ。

const PLAYER := 0
const CPU := 1
const RESULT_SCENE := "res://scenes/result.tscn"

const SCREEN_SIZE := Vector2(1280, 720)
const HUD_RECT := Rect2(0, 0, 1280, 80)
const OWN_FRAME_RECT := Rect2(12, 86, 628, 514)
const OWN_SHELF_POS := Vector2(30, 68)
const OWN_CELL := Vector2(176, 136)
const OWN_GAP := Vector2(16, 12)
## 自店の看板の「?」(店の中の座標)と、押すと出るボーナスの見方(店の中の座標)
const HELP_RECT := Rect2(583, 8, 30, 30)
const HELP_LEGEND_RECT := Rect2(150, 72, 420, 200)
const STREET_RECT := Rect2(640, 86, 120, 514)
const RIVAL_FRAME_RECT := Rect2(760, 86, 508, 226)
const RIVAL_SHELF_POS := Vector2(100, 46)
const RIVAL_CELL := Vector2(96, 52)
const RIVAL_GAP := Vector2(10, 6)
const FORECAST_RECT := Rect2(760, 322, 508, 278)
const CATALOG_RECT := Rect2(12, 608, 988, 104)
const SKILL_RECT := Rect2(1010, 608, 258, 104)

## 「+¥」をまとめて出す間隔(1秒に十数個売れるため、商品ごとに束ねる)
const SALE_POP_INTERVAL := 0.25
const POP_SIZE := UiPalette.FONT_HEAD
## 開店直後は客数の差が小さく入れ替わりやすいため、逆転の表示を出さない秒数
const REVERSAL_GRACE := 15.0
const REVERSAL_COOLDOWN := 12.0
const RESULT_DELAY := 2.5
## 時間帯のカットインの地は空の色を暗くして白い文字を読めるようにする
const BAND_CUTIN_DARKEN := 0.25
## 初回ガイドの説明の札の位置(GameDesign.md 9.7節)
const GUIDE_CARD_LEFT := Vector2(200, 200)
const GUIDE_CARD_UPPER := Vector2(430, 330)
const GUIDE_CARD_RIGHT := Vector2(820, 380)
const GUIDE_TEXTS: Array[String] = [
	"右下は次の時間帯の予報。次に来る客が欲しがる商品が、多い順に並ぶ。先回りして仕入れよう。",
	"下の品ぞろえの札の発注ボタンで仕入れる。代金を先に払い、5秒で届く。売れ残りも仕入れ代は戻らない。",
	"札を棚のマスへドラッグ(またはタップしてからマスをタップ)して並べる。並べた商品だけが売れる。",
]

var match_state: MatchState

var _cpu: CpuPlayer
var _sky: SkyBackdrop
var _selection := UiSelection.new()
var _own_shelf: ShelfView
var _rival_shelf: ShelfView
var _own_frame: StoreFrame
var _rival_frame: StoreFrame
var _price_menu: PriceMenu
var _catalog: CatalogView
var _flow: CustomerFlow
var _fx: FxLayer
## "店番号:商品id" → [店番号, 商品id, 金額]
var _pending_pops: Dictionary = {}
var _pop_timer := 0.0
var _player_leading := false
var _reversal_cooldown := 0.0
## 初回ガイドが出ている間は開店準備の時計を止める
var _guide: GuideOverlay
var _end_timer := -1.0
var _leaving := false


func _ready() -> void:
	var db := GameDatabase.get_default()
	match_state = MatchState.new(db, GameSession.manager_ids(), GameSession.match_seed)
	_cpu = CpuPlayer.new(match_state, CPU, db.cpu_profile(GameSession.cpu_profile_id()))
	_build()
	_connect_signals()
	if GameSession.wants_guide():
		_open_guide()


func _physics_process(delta: float) -> void:
	if match_state.finished:
		_end_timer -= delta
		if _end_timer <= 0.0 and not _leaving:
			_leaving = true
			GameSession.finish_match(match_state.result)
			get_tree().change_scene_to_file(RESULT_SCENE)
		return
	if _guide != null and match_state.is_preparing():
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
	_sky = SkyBackdrop.new()
	_place(_sky, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_sky.set_band(match_state.current_band(), true)

	_place(_part(HudBar.new(), PLAYER), HUD_RECT)

	_own_frame = _part(StoreFrame.new(), PLAYER)
	_own_frame.door_on_right = true
	_own_frame.door_y = OWN_SHELF_POS.y + OWN_CELL.y * 1.5 + OWN_GAP.y
	_place(_own_frame, OWN_FRAME_RECT)
	_own_shelf = _part(ShelfView.new(), PLAYER)
	_own_shelf.configure(OWN_CELL, OWN_GAP, true)
	_own_shelf.selection = _selection
	_own_frame.add_child(_own_shelf)
	_own_shelf.position = OWN_SHELF_POS
	_own_shelf.size = _own_shelf.grid_size()
	var help: BonusHelp = _part(BonusHelp.new(), PLAYER)
	_own_frame.add_child(help)
	help.position = HELP_RECT.position
	help.size = HELP_RECT.size
	help.legend_rect = Rect2(HELP_LEGEND_RECT.position - HELP_RECT.position, HELP_LEGEND_RECT.size)
	_own_frame.sign_reserved = OWN_FRAME_RECT.size.x - HELP_RECT.position.x - StoreFrame.PAD

	_rival_frame = _part(StoreFrame.new(), CPU)
	_rival_frame.door_on_right = false
	_rival_frame.compact = true
	_rival_frame.door_y = RIVAL_SHELF_POS.y + RIVAL_CELL.y * 1.5 + RIVAL_GAP.y
	_place(_rival_frame, RIVAL_FRAME_RECT)
	_rival_shelf = _part(ShelfView.new(), CPU)
	_rival_shelf.configure(RIVAL_CELL, RIVAL_GAP, false)
	_rival_frame.add_child(_rival_shelf)
	_rival_shelf.position = RIVAL_SHELF_POS
	_rival_shelf.size = _rival_shelf.grid_size()

	_flow = _part(CustomerFlow.new(), PLAYER)
	_place(_flow, STREET_RECT)
	var street_top := STREET_RECT.position.y
	var own_door := OWN_FRAME_RECT.position.y + _own_frame.door_y - street_top
	var rival_door := RIVAL_FRAME_RECT.position.y + _rival_frame.door_y - street_top
	_flow.door_points[PLAYER] = Vector2(0.0, own_door)
	_flow.door_points[CPU] = Vector2(STREET_RECT.size.x, rival_door)

	_place(_part(ForecastPanel.new(), PLAYER), FORECAST_RECT)
	_catalog = _part(CatalogView.new(), PLAYER)
	_catalog.selection = _selection
	_place(_catalog, CATALOG_RECT)
	_place(_part(SkillButton.new(), PLAYER), SKILL_RECT)

	_price_menu = PriceMenu.new()
	_place(_price_menu, Rect2(Vector2.ZERO, SCREEN_SIZE))
	_price_menu.setup(match_state, PLAYER)
	_price_menu.closed.connect(func() -> void: _own_shelf.open_slot = -1)

	_fx = FxLayer.new()
	_place(_fx, Rect2(Vector2.ZERO, SCREEN_SIZE))

	var sounds := MatchSounds.new()
	add_child(sounds)
	sounds.setup(match_state)


func _open_guide() -> void:
	_guide = GuideOverlay.new()
	var own_shelf := Rect2(OWN_FRAME_RECT.position + OWN_SHELF_POS, _own_shelf.size)
	var forecast: Array[Rect2] = [FORECAST_RECT]
	var catalog: Array[Rect2] = [CATALOG_RECT]
	var drag: Array[Rect2] = [CATALOG_RECT, own_shelf]
	_guide.add_step(GUIDE_TEXTS[0], forecast, GUIDE_CARD_LEFT)
	_guide.add_step(GUIDE_TEXTS[1], catalog, GUIDE_CARD_UPPER)
	_guide.add_step(GUIDE_TEXTS[2], drag, GUIDE_CARD_RIGHT)
	_guide.finished.connect(func() -> void: _guide = null)
	_place(_guide, Rect2(Vector2.ZERO, SCREEN_SIZE))


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
		match_state.assign(PLAYER, _selection.product_id, slot)
		_selection.clear()
		return
	if match_state.stores[PLAYER].shelf[slot] == StoreState.EMPTY:
		return
	var rect := _own_shelf.slot_rect(slot)
	_price_menu.open_for(slot, Rect2(_own_shelf.global_position + rect.position, rect.size))
	_own_shelf.open_slot = slot


func _on_product_dropped(product_id: StringName, slot: int) -> void:
	match_state.assign(PLAYER, product_id, slot)
	_selection.clear()


func _on_band_changed(band_id: StringName) -> void:
	var band := match_state.db.band(band_id)
	_sky.set_band(band)
	_fx.cutin(band.cutin_text, band.sky_top.darkened(BAND_CUTIN_DARKEN))


## 「+¥」は自店の棚からだけ出す(相手の売上は上端のバーで分かる。9.2節)
func _on_purchased(store_index: int, product_id: StringName, _count: int, amount: int) -> void:
	if store_index != PLAYER:
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
	if store_counts[PLAYER] >= ceili(balance.event_customer_count * balance.big_catch_ratio):
		_fx.big("大口獲得!", UiPalette.MONEY, true)
		AudioDirector.play_se(&"big_catch")


func _on_skill_used(store_index: int) -> void:
	var manager := match_state.stores[store_index].manager
	var label := "%s:%s!" % [UiPalette.STORE_NAMES[store_index], manager.active_name]
	_fx.cutin(label, manager.color)


func _on_match_ended(_result: MatchResult) -> void:
	_fx.big("閉店!", UiPalette.INK_ON_DARK)
	_end_timer = RESULT_DELAY


func _check_reversal(delta: float) -> void:
	_reversal_cooldown = maxf(_reversal_cooldown - delta, 0.0)
	var own := match_state.stores[PLAYER].visitor_total
	var rival := match_state.stores[CPU].visitor_total
	var leading := own > rival
	if leading and not _player_leading and match_state.elapsed > REVERSAL_GRACE:
		if _reversal_cooldown <= 0.0:
			_fx.big("客数で逆転!", UiPalette.STORE_COLORS[PLAYER], true)
			AudioDirector.play_se(&"reversal")
			_reversal_cooldown = REVERSAL_COOLDOWN
	_player_leading = leading
