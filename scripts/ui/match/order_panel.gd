class_name OrderPanel
extends MatchPart
## 発注パネル(GameDesign.md 6.1節・9.2節・9.5節)。商品ごとのボタンに1ロットの代金を出し、
## タップで1ロットを発注する。押すと沈み、成否の色が一瞬光る。資金が足りない行は灰色になる。

const PAD := 8.0
const TAB_POS := Vector2(8, 8)
const INFO_Y := 50.0
const LIST_TOP := 62.0
const ROW_HEIGHT := 29.0
const ROW_GAP := 3.0
const ROW_DROP := 2.0
const ICON_SIDE := 21.0
const ICON_X := 16.0
const NAME_X := 34.0
const COST_WIDTH := 46.0
const FLASH_SECONDS := 0.35
const HOVER_LIGHTEN := 0.5
const OK_FLASH := Color(0.12, 0.64, 0.36, 0.45)
const FAIL_FLASH := Color(0.9, 0.22, 0.23, 0.45)
const FADED := Color("#d9d4c8")
const FADED_INK := Color(0.36, 0.4, 0.51, 0.6)

var _hover_row := -1
var _pressed_row := -1
## 行の番号 → [残り秒, 成功したか]
var _flashes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	for row: int in _flashes.keys():
		_flashes[row][0] -= delta
		if _flashes[row][0] <= 0.0:
			_flashes.erase(row)
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover_row = _row_at(motion.position)
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not press.pressed:
		_pressed_row = -1
		return
	var row := _row_at(press.position)
	if row < 0:
		return
	_pressed_row = row
	var product := db().sorted_products()[row]
	var ok := match_state.order(store_index, product.id)
	_flashes[row] = [FLASH_SECONDS, ok]
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_row = -1
		_pressed_row = -1


func _row_rect(row: int) -> Rect2:
	var y := LIST_TOP + row * (ROW_HEIGHT + ROW_GAP)
	return Rect2(PAD, y, size.x - PAD * 2.0, ROW_HEIGHT)


func _row_at(pos: Vector2) -> int:
	for row in db().sorted_products().size():
		if _row_rect(row).grow_individual(0, 0, 0, ROW_GAP).has_point(pos):
			return row
	return -1


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.card(self, Rect2(Vector2.ZERO, size), UiPalette.PAPER)
	UiDraw.tab(self, TAB_POS, "発注")
	var balance := match_state.balance
	var info := "%d個ずつ・%d秒で入荷" % [balance.lot_size, int(balance.delivery_seconds)]
	var info_pos := Vector2(PAD, INFO_Y)
	UiDraw.text(
		self,
		info_pos,
		info,
		UiPalette.FONT_TINY,
		UiPalette.INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - PAD * 2.0
	)
	var products := db().sorted_products()
	for row in products.size():
		_draw_row(row, products[row])


func _draw_row(row: int, product: ProductData) -> void:
	var rect := _row_rect(row)
	var cost := match_state.lot_cost(store_index, product.id)
	var affordable := store().funds >= cost
	var category := db().category(product.category_id)
	var fill := UiPalette.INK_ON_DARK
	if not affordable:
		fill = FADED
	elif row == _hover_row:
		fill = category.color.lerp(UiPalette.INK_ON_DARK, HOVER_LIGHTEN)
	var radius := UiPalette.RADIUS_SMALL
	if row == _pressed_row:
		rect.position.y += ROW_DROP
	else:
		var shadow := Rect2(rect.position + Vector2(0, ROW_DROP), rect.size)
		UiDraw.panel(self, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, rect, fill, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	if _flashes.has(row):
		var flash: Array = _flashes[row]
		var color := OK_FLASH if flash[1] else FAIL_FLASH
		color.a *= flash[0] / FLASH_SECONDS
		UiDraw.panel(self, rect, color, Color.TRANSPARENT, 0, radius)
	var alpha := 1.0 if affordable else FADED_INK.a
	var icon_center := Vector2(rect.position.x + ICON_X, rect.get_center().y)
	UiDraw.product_icon(self, icon_center, ICON_SIDE, product, alpha)
	var ink := UiPalette.INK if affordable else FADED_INK
	var name_width := rect.size.x - NAME_X - COST_WIDTH
	var name_size := UiDraw.fit_size(product.display_name, UiPalette.FONT_SMALL, name_width)
	var name_pos := Vector2(rect.position.x + NAME_X, UiDraw.baseline_in(rect, name_size))
	UiDraw.text(self, name_pos, product.display_name, name_size, ink)
	var cost_pos := Vector2(
		rect.end.x - COST_WIDTH - PAD * 0.5, UiDraw.baseline_in(rect, UiPalette.FONT_TINY)
	)
	var cost_ink := UiPalette.INK_SOFT if affordable else FADED_INK
	UiDraw.text(
		self,
		cost_pos,
		UiDraw.yen(cost),
		UiPalette.FONT_TINY,
		cost_ink,
		HORIZONTAL_ALIGNMENT_RIGHT,
		COST_WIDTH
	)
