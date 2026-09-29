class_name OrderPanel
extends MatchPart
## 発注パネル(GameDesign.md 6.1節・9.2節)。商品の一覧と1ロットの代金。タップで1ロットを発注する。

const HEADER_HEIGHT := 28.0
const ROW_HEIGHT := 36.0
const ROW_GAP := 2.0
const PAD := 8.0
const DOT_RADIUS := 6.0
const FLASH_SECONDS := 0.35
const TEXT_BASELINE := 0.65
const HOVER := Color(0.18, 0.49, 0.88, 0.08)
const OK_FLASH := Color(0.18, 0.62, 0.36, 0.35)
const FAIL_FLASH := Color(0.84, 0.27, 0.27, 0.35)
const FADED_ALPHA := 0.35

var _hover_row := -1
## 行の番号 → [残り秒, 成功したか]
var _flashes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var row := _row_at(press.position)
	if row < 0:
		return
	var product := db().sorted_products()[row]
	var ok := match_state.order(store_index, product.id)
	_flashes[row] = [FLASH_SECONDS, ok]
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_row = -1


func _row_rect(row: int) -> Rect2:
	var y := HEADER_HEIGHT + row * (ROW_HEIGHT + ROW_GAP)
	return Rect2(0.0, y, size.x, ROW_HEIGHT)


func _row_at(pos: Vector2) -> int:
	for row in db().sorted_products().size():
		if _row_rect(row).has_point(pos):
			return row
	return -1


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.shadowed_panel(self, Rect2(Vector2.ZERO, size), UiPalette.PANEL)
	var lot := match_state.balance.lot_size
	var title := "発注(%d個ずつ・%d秒で届く)" % [lot, int(match_state.balance.delivery_seconds)]
	var title_pos := Vector2(PAD, HEADER_HEIGHT * TEXT_BASELINE)
	UiDraw.text(self, title_pos, title, UiPalette.FONT_SMALL, UiPalette.INK_SOFT)
	var products := db().sorted_products()
	for row in products.size():
		_draw_row(row, products[row])


func _draw_row(row: int, product: ProductData) -> void:
	var rect := _row_rect(row).grow_individual(-PAD / 2.0, 0.0, -PAD / 2.0, 0.0)
	var cost := match_state.lot_cost(store_index, product.id)
	var affordable := store().funds >= cost
	if row == _hover_row and affordable:
		UiDraw.panel(self, rect, HOVER)
	if _flashes.has(row):
		var flash: Array = _flashes[row]
		var color := OK_FLASH if flash[1] else FAIL_FLASH
		color.a *= flash[0] / FLASH_SECONDS
		UiDraw.panel(self, rect, color)
	var ink := UiPalette.INK
	var soft := UiPalette.INK_SOFT
	if not affordable:
		ink.a = FADED_ALPHA
		soft.a = FADED_ALPHA
	var category := db().category(product.category_id)
	var mid := rect.get_center().y
	draw_circle(Vector2(rect.position.x + PAD, mid), DOT_RADIUS, category.color)
	var baseline := rect.position.y + rect.size.y * TEXT_BASELINE
	var name_x := rect.position.x + PAD * 2.0 + DOT_RADIUS
	UiDraw.text(self, Vector2(name_x, baseline), product.display_name, UiPalette.FONT_SMALL, ink)
	var cost_width := rect.end.x - name_x - PAD
	var cost_pos := Vector2(name_x, baseline)
	var align := HORIZONTAL_ALIGNMENT_RIGHT
	UiDraw.text(self, cost_pos, UiDraw.yen(cost), UiPalette.FONT_SMALL, soft, align, cost_width)
