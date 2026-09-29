class_name SkillButton
extends MatchPart
## 資金と、店長の顔つきのアクティブスキルのボタン(GameDesign.md 7章・9.2節)。スキルは試合中に1回だけ使える。

const PAD := 10.0
const FUNDS_HEIGHT := 40.0
const GAP := 6.0
const TEXT_BASELINE := 0.7
const DESC_LINES := 2
const PORTRAIT_RADIUS := 28.0
const BUTTON_DARKEN := 0.25
const USED_ALPHA := 0.35
const HOVER_LIGHTEN := 0.1
const GLOW_SIZE := 3.0

var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _button_rect() -> Rect2:
	return Rect2(0.0, FUNDS_HEIGHT + GAP, size.x, size.y - FUNDS_HEIGHT - GAP)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = _button_rect().has_point(motion.position)
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if _button_rect().has_point(press.position):
		match_state.use_active(store_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = false


func _draw() -> void:
	if match_state == null:
		return
	_draw_funds()
	var manager := store().manager
	var rect := _button_rect()
	var usable := match_state.can_use_active(store_index)
	var fill := manager.color
	if not usable and store().active_remaining <= 0.0:
		fill.a = USED_ALPHA
	elif _hover and usable:
		fill = fill.lightened(HOVER_LIGHTEN)
	if usable:
		var glow := UiPalette.ACCENT
		glow.a = blink()
		var radius := UiPalette.PANEL_RADIUS + int(GLOW_SIZE)
		UiDraw.panel(self, rect.grow(GLOW_SIZE), glow, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, rect, fill, fill.darkened(BUTTON_DARKEN), 2, UiPalette.PANEL_RADIUS)
	var portrait := rect.position + Vector2(PAD + PORTRAIT_RADIUS, rect.size.y / 2.0)
	UiDraw.portrait(self, portrait, PORTRAIT_RADIUS, manager)
	var ink := UiPalette.INK_ON_DARK
	var text_x := PAD * 2.0 + PORTRAIT_RADIUS * 2.0
	var text_width := rect.size.x - text_x - PAD
	var title_pos := rect.position + Vector2(text_x, UiPalette.FONT_LARGE + PAD)
	UiDraw.text(self, title_pos, manager.active_name, UiPalette.FONT_LARGE, ink)
	var state_pos := title_pos + Vector2(0, UiPalette.FONT_BODY + 4.0)
	UiDraw.text(self, state_pos, _state_text(), UiPalette.FONT_BODY, UiPalette.ACCENT)
	var desc_y := UiPalette.FONT_LARGE + UiPalette.FONT_BODY + UiPalette.FONT_SMALL + PAD * 1.5
	draw_multiline_string(
		UiDraw.font(),
		rect.position + Vector2(text_x, desc_y),
		manager.active_description,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		UiPalette.FONT_SMALL,
		DESC_LINES,
		ink
	)


func _state_text() -> String:
	if store().active_remaining > 0.0:
		return "発動中 あと%d秒" % int(ceil(store().active_remaining))
	if store().active_used:
		return "使用済み"
	if match_state.is_preparing():
		return "開店後に使える"
	return "タップで発動!"


func _draw_funds() -> void:
	var rect := Rect2(0.0, 0.0, size.x, FUNDS_HEIGHT)
	UiDraw.glass_panel(self, rect)
	var baseline := FUNDS_HEIGHT * TEXT_BASELINE
	UiDraw.text(self, Vector2(PAD, baseline), "資金", UiPalette.FONT_BODY, UiPalette.INK_SOFT)
	var cheapest := INF
	for product in db().sorted_products():
		cheapest = minf(cheapest, match_state.lot_cost(store_index, product.id))
	var color := UiPalette.BAD_BRIGHT if store().funds < cheapest else UiPalette.INK
	var funds := UiDraw.yen(store().funds)
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	var pos := Vector2(PAD, baseline)
	UiDraw.text(self, pos, funds, UiPalette.FONT_HEAD, color, align, rect.size.x - PAD * 2.0)
