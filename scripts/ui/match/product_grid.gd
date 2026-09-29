class_name ProductGrid
extends MatchPart
## 商品タイル(GameDesign.md 6章・9.2節)。1枚に商品・在庫数・廃棄までの残り秒数・入荷までの残り秒数・発注ボタン。
## 発注ボタンを押すと1ロットを発注する。それ以外をタップすると選び(値付けパネルに出る)、次にタップした棚のマスへ置く。
## ドラッグして棚のマスへ置くこともできる。

const COLUMNS := 3
const HEADER_HEIGHT := 26.0
const PAD := 6.0
const GAP := 4.0
const ICON_RADIUS := 15.0
const ICON_OFFSET := Vector2(20, 21)
const STOCK_BASELINE := 31.0
const NAME_BASELINE := 45.0
const STATUS_TOP := 48.0
const STATUS_HEIGHT := 13.0
const ORDER_HEIGHT := 24.0
const SHELF_MARK_HEIGHT := 4.0
## 廃棄が近いとみなす残り秒数。これより近ければ入荷の表示より廃棄を先に出す
const WASTE_WARN_SECONDS := 15.0
const WASTE_DANGER_SECONDS := 5.0
const BLINK_MIN_ALPHA := 0.3
const SELECTED_EDGE := 3.0
const STORAGE_ALPHA := 0.55
const FLASH_SECONDS := 0.35
const PENDING_COLOR := Color("#2f7de1")
const BAR_TRACK := Color("#e1e7ef")
const ORDER_DISABLED := Color("#c9d1dc")
const OK_FLASH := Color(0.39, 0.85, 0.56, 0.6)
const FAIL_FLASH := Color(0.88, 0.29, 0.29, 0.6)
const DRAG_PREVIEW_PAD := 8

var selection: UiSelection

## 商品の番号 → [残り秒, 成功したか]
var _flashes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func tile_rect(index: int) -> Rect2:
	var rows := ceili(float(db().sorted_products().size()) / COLUMNS)
	var width := (size.x - PAD * 2.0 - GAP * (COLUMNS - 1)) / COLUMNS
	var height := (size.y - HEADER_HEIGHT - PAD - GAP * (rows - 1)) / rows
	@warning_ignore("integer_division")
	var row := index / COLUMNS
	var column := index % COLUMNS
	var pos := Vector2(PAD + column * (width + GAP), HEADER_HEIGHT + row * (height + GAP))
	return Rect2(pos, Vector2(width, height))


func order_rect(index: int) -> Rect2:
	var rect := tile_rect(index)
	return Rect2(
		rect.position.x + 3.0, rect.end.y - ORDER_HEIGHT - 3.0, rect.size.x - 6.0, ORDER_HEIGHT
	)


func _tile_at(pos: Vector2) -> int:
	for i in db().sorted_products().size():
		if tile_rect(i).has_point(pos):
			return i
	return -1


func _process(delta: float) -> void:
	for index: int in _flashes.keys():
		_flashes[index][0] -= delta
		if _flashes[index][0] <= 0.0:
			_flashes.erase(index)
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _tile_at(press.position)
	if index < 0:
		return
	var product := db().sorted_products()[index]
	if order_rect(index).has_point(press.position):
		_flashes[index] = [FLASH_SECONDS, match_state.order(store_index, product.id)]
	elif selection != null:
		selection.toggle(product.id)
	accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := _tile_at(at_position)
	if index < 0 or order_rect(index).has_point(at_position):
		return null
	var product := db().sorted_products()[index]
	var preview := Label.new()
	preview.text = product.short_name
	preview.add_theme_font_override("font", UiDraw.font())
	preview.add_theme_font_size_override("font_size", UiPalette.FONT_LARGE)
	var box := UiDraw.box(db().category(product.category_id).color).duplicate() as StyleBoxFlat
	box.set_content_margin_all(DRAG_PREVIEW_PAD)
	preview.add_theme_stylebox_override("normal", box)
	preview.add_theme_color_override("font_color", UiPalette.INK_ON_DARK)
	set_drag_preview(preview)
	return {"product_id": product.id}


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size))
	var lot := match_state.balance.lot_size
	var seconds := int(match_state.balance.delivery_seconds)
	var title := "商品(発注は%d個ずつ・%d秒で届く)" % [lot, seconds]
	UiDraw.panel_title(self, Vector2(PAD + 4.0, HEADER_HEIGHT * 0.7), title)
	var products := db().sorted_products()
	for i in products.size():
		_draw_tile(i, products[i])


func _draw_tile(index: int, product: ProductData) -> void:
	var rect := tile_rect(index)
	var id := product.id
	var stock := store().stock(id)
	var on_shelf := store().is_on_shelf(id)
	UiDraw.shadowed_panel(self, rect, UiPalette.CARD)
	if on_shelf:
		var mark := Rect2(rect.position, Vector2(rect.size.x, SHELF_MARK_HEIGHT))
		UiDraw.panel(self, mark, UiPalette.STORE_COLORS[store_index], Color.TRANSPARENT, 0, 2)
	if selection != null and selection.product_id == id:
		draw_rect(rect.grow(-1.0), UiPalette.ACCENT.darkened(0.1), false, SELECTED_EDGE)
	UiDraw.product_icon(self, rect.position + ICON_OFFSET, ICON_RADIUS, product)
	var stock_pos := Vector2(rect.position.x, rect.position.y + STOCK_BASELINE)
	var stock_width := rect.size.x - PAD
	UiDraw.text(
		self,
		stock_pos,
		str(stock),
		UiPalette.FONT_HEAD,
		_stock_color(stock, on_shelf),
		HORIZONTAL_ALIGNMENT_RIGHT,
		stock_width
	)
	var name_color := UiPalette.CARD_INK if on_shelf or stock == 0 else UiPalette.CARD_INK_SOFT
	_center_text(rect, NAME_BASELINE, product.short_name, UiPalette.FONT_SMALL, name_color)
	_draw_status(rect, id, stock, on_shelf)
	_draw_order(index, id)


## 状態の行:入荷待ち・廃棄までの残り・倉庫(棚に無い)のうち、いま知るべきものを1つ出す
func _draw_status(rect: Rect2, product_id: StringName, stock: int, on_shelf: bool) -> void:
	var bar := Rect2(
		rect.position.x + 4.0, rect.position.y + STATUS_TOP, rect.size.x - 8.0, STATUS_HEIGHT
	)
	var lot := store().oldest_lot(product_id)
	var waste_left := INF
	if lot != null and lot.expires_at != INF:
		waste_left = maxf(lot.expires_at - match_state.elapsed, 0.0)
	var arriving := store().next_delivery_seconds(product_id)
	if arriving >= 0.0 and waste_left > WASTE_WARN_SECONDS:
		var label := "入荷%d秒 +%d" % [int(ceil(arriving)), store().pending_count(product_id)]
		UiDraw.text_centered(self, bar, label, UiPalette.FONT_SMALL, PENDING_COLOR)
		return
	if waste_left != INF:
		_draw_waste(bar, waste_left, lot.count)
		return
	if stock > 0 and not on_shelf:
		UiDraw.text_centered(self, bar, "倉庫", UiPalette.FONT_SMALL, UiPalette.CARD_INK_SOFT)


func _draw_waste(bar: Rect2, left: float, count: int) -> void:
	UiDraw.panel(self, bar, BAR_TRACK, Color.TRANSPARENT, 0, 3)
	var color := UiPalette.GOOD
	if left <= WASTE_DANGER_SECONDS:
		color = UiPalette.BAD
	elif left <= WASTE_WARN_SECONDS:
		color = UiPalette.WARN
	var ratio := left / match_state.balance.waste_seconds
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	UiDraw.panel(self, filled, color, Color.TRANSPARENT, 0, 3)
	var label := "廃棄%d秒×%d" % [int(ceil(left)), count]
	UiDraw.text_centered(self, bar, label, UiPalette.FONT_SMALL, UiPalette.CARD_INK)


func _draw_order(index: int, product_id: StringName) -> void:
	var rect := order_rect(index)
	var cost := match_state.lot_cost(store_index, product_id)
	var affordable := store().funds >= cost
	var fill := UiPalette.ACCENT if affordable else ORDER_DISABLED
	UiDraw.panel(self, rect, fill, fill.darkened(0.2), 1, UiPalette.RADIUS)
	if _flashes.has(index):
		var flash: Array = _flashes[index]
		var color := OK_FLASH if flash[1] else FAIL_FLASH
		color.a *= flash[0] / FLASH_SECONDS
		UiDraw.panel(self, rect, color, Color.TRANSPARENT, 0, UiPalette.RADIUS)
	var ink := UiPalette.ACCENT_INK if affordable else UiPalette.CARD_INK_SOFT
	var label := "+%d %s" % [match_state.balance.lot_size, UiDraw.yen(cost)]
	UiDraw.text_centered(self, rect, label, UiPalette.FONT_SMALL, ink)


func _stock_color(stock: int, on_shelf: bool) -> Color:
	if stock <= 0:
		return UiPalette.CARD_INK_SOFT
	if not on_shelf:
		var faded := UiPalette.CARD_INK
		faded.a = STORAGE_ALPHA
		return faded
	if stock <= match_state.balance.low_stock_threshold:
		var color := UiPalette.BAD
		color.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink())
		return color
	return UiPalette.CARD_INK


func _center_text(
	rect: Rect2, baseline: float, value: String, font_size: int, color: Color
) -> void:
	var pos := Vector2(rect.position.x, rect.position.y + baseline)
	UiDraw.text(self, pos, value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
