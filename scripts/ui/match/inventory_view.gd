class_name InventoryView
extends MatchPart
## 在庫一覧(GameDesign.md 6.2節〜6.4節・9.2節)。商品ごとの在庫数・廃棄までの残り秒数と個数・発注中。
## カードをタップで選ぶかドラッグして、棚のマスへ置く。

const CARD_WIDTH := 72.0
const CARD_GAP := 4.0
const PAD := 4.0
const ICON_Y := 22.0
const ICON_RADIUS := 15.0
const NAME_Y := 52.0
const STOCK_Y := 80.0
const WASTE_BAR_Y := 92.0
const WASTE_BAR_HEIGHT := 16.0
const PENDING_Y := 128.0
const SHELF_MARK_HEIGHT := 4.0
## 廃棄が近いとみなす残り秒数
const WASTE_WARN_SECONDS := 15.0
const WASTE_DANGER_SECONDS := 5.0
const BLINK_MIN_ALPHA := 0.3
const SELECTED_EDGE := 3.0
const STORAGE_ALPHA := 0.55
const PENDING_COLOR := Color("#2f7de1")
const BAR_TRACK := Color("#e4e8ec")
const DRAG_PREVIEW_PAD := 8

var selection: UiSelection


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func card_rect(index: int) -> Rect2:
	return Rect2(index * (CARD_WIDTH + CARD_GAP), 0.0, CARD_WIDTH, size.y)


func _card_at(pos: Vector2) -> int:
	for i in db().sorted_products().size():
		if card_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _card_at(press.position)
	if index >= 0 and selection != null:
		selection.toggle(db().sorted_products()[index].id)
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := _card_at(at_position)
	if index < 0:
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
	var products := db().sorted_products()
	for i in products.size():
		_draw_card(card_rect(i), products[i])


func _draw_card(rect: Rect2, product: ProductData) -> void:
	var id := product.id
	var stock := store().stock(id)
	var on_shelf := store().is_on_shelf(id)
	UiDraw.shadowed_panel(self, rect, UiPalette.PANEL)
	if on_shelf:
		var mark := Rect2(rect.position, Vector2(rect.size.x, SHELF_MARK_HEIGHT))
		UiDraw.panel(self, mark, UiPalette.STORE_COLORS[store_index], Color.TRANSPARENT, 0, 2)
	if selection != null and selection.product_id == id:
		draw_rect(rect.grow(-1.0), UiPalette.STORE_COLORS[store_index], false, SELECTED_EDGE)
	var center_x := rect.position.x + rect.size.x / 2.0
	UiDraw.product_icon(self, Vector2(center_x, rect.position.y + ICON_Y), ICON_RADIUS, product)
	var name_color := UiPalette.INK if on_shelf or stock == 0 else UiPalette.INK_SOFT
	_center_text(rect, NAME_Y, product.short_name, UiPalette.FONT_SMALL, name_color)
	_center_text(rect, STOCK_Y, str(stock), UiPalette.FONT_HEAD, _stock_color(stock, on_shelf))
	if stock > 0 and not on_shelf:
		_center_text(
			rect,
			WASTE_BAR_Y + WASTE_BAR_HEIGHT * 0.8,
			"倉庫",
			UiPalette.FONT_SMALL,
			UiPalette.INK_SOFT
		)
	else:
		_draw_waste(rect, id)
	var arriving := store().next_delivery_seconds(id)
	if arriving >= 0.0:
		var pending := "入荷%d秒" % int(ceil(arriving))
		_center_text(rect, PENDING_Y, pending, UiPalette.FONT_SMALL, PENDING_COLOR)
		var count := "+%d" % store().pending_count(id)
		_center_text(
			rect, PENDING_Y + UiPalette.FONT_SMALL + 2.0, count, UiPalette.FONT_SMALL, PENDING_COLOR
		)


func _stock_color(stock: int, on_shelf: bool) -> Color:
	if stock <= 0:
		return UiPalette.INK_SOFT
	if not on_shelf:
		var faded := UiPalette.INK
		faded.a = STORAGE_ALPHA
		return faded
	if stock <= match_state.balance.low_stock_threshold:
		var color := UiPalette.BAD
		color.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink())
		return color
	return UiPalette.INK


## いちばん古いロットが廃棄されるまでの残りを、減っていくバーと「秒・個数」で出す
func _draw_waste(rect: Rect2, product_id: StringName) -> void:
	var lot := store().oldest_lot(product_id)
	if lot == null or lot.expires_at == INF:
		return
	var left := maxf(lot.expires_at - match_state.elapsed, 0.0)
	var bar := Rect2(
		rect.position.x + PAD,
		rect.position.y + WASTE_BAR_Y,
		rect.size.x - PAD * 2.0,
		WASTE_BAR_HEIGHT
	)
	UiDraw.panel(self, bar, BAR_TRACK, Color.TRANSPARENT, 0, 3)
	var ratio := left / match_state.balance.waste_seconds
	var color := UiPalette.GOOD
	if left <= WASTE_DANGER_SECONDS:
		color = UiPalette.BAD
	elif left <= WASTE_WARN_SECONDS:
		color = UiPalette.WARN
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	UiDraw.panel(self, filled, color, Color.TRANSPARENT, 0, 3)
	var label := "%d秒×%d" % [int(ceil(left)), lot.count]
	UiDraw.text_centered(self, bar, label, UiPalette.FONT_SMALL, UiPalette.INK)


func _center_text(
	rect: Rect2, baseline: float, value: String, font_size: int, color: Color
) -> void:
	var pos := Vector2(rect.position.x, rect.position.y + baseline)
	UiDraw.text(self, pos, value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
