class_name InventoryView
extends MatchPart
## 在庫一覧(GameDesign.md 6.1節〜6.4節・9.2節・9.5節)。商品ごとのカードに絵・在庫数・廃棄までの残りのバー・
## 入荷待ちと、1ロットの代金を書いた発注ボタンを出す。棚に出ている商品は店の色の枠、出ていない商品は薄く描く。
## 発注ボタンを押すと1ロットを発注する(押すと沈み、成否の色が一瞬光る。資金が足りないと灰色)。
## カードのほかの所をタップで選ぶ(浮き上がる)かドラッグして、棚のマスへ置く。

const CARD_WIDTH := 72.0
const CARD_GAP := 4.0
const CARD_HEIGHT := 160.0
const PAD := 5.0
const ICON_Y := 34.0
const ICON_SIDE := 46.0
const NAME_Y := 72.0
const STOCK_Y := 96.0
const STOCK_FONT := 22
const BAR_Y := 101.0
const BAR_HEIGHT := 5.0
const DELIVERY_Y := 116.0
const DELIVERY_HEIGHT := 14.0
const ORDER_TOP := 124.0
const ORDER_HEIGHT := 28.0
const ORDER_DROP := 2.0
const ORDER_CAPTION_Y := 12.0
const ORDER_COST_Y := 25.0
## 廃棄が近いとみなす残り秒数
const WASTE_WARN_SECONDS := 15.0
const WASTE_DANGER_SECONDS := 5.0
const LIFT := 6.0
const SELECTED_GLOW := 3.0
const OFF_SHELF_ALPHA := 0.5
const BAR_TRACK := Color("#e4ded0")
const DRAG_TOKEN_SIDE := 56.0
const FLASH_SECONDS := 0.35
const OK_FLASH := Color(0.12, 0.64, 0.36, 0.55)
const FAIL_FLASH := Color(0.9, 0.22, 0.23, 0.55)
const FADED := Color("#d9d4c8")
const FADED_INK := Color(0.36, 0.4, 0.51, 0.6)
const HOVER_LIGHTEN := 0.25

var selection: UiSelection

var _hover_order := -1
var _pressed_order := -1
## カードの番号 → [残り秒, 成功したか]
var _flashes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func card_rect(index: int) -> Rect2:
	var top := size.y - CARD_HEIGHT - UiPalette.SHADOW_DROP
	return Rect2(index * (CARD_WIDTH + CARD_GAP), top, CARD_WIDTH, CARD_HEIGHT)


func order_rect(index: int) -> Rect2:
	var card := card_rect(index)
	var pos := card.position + Vector2(PAD, ORDER_TOP)
	return Rect2(pos, Vector2(card.size.x - PAD * 2.0, ORDER_HEIGHT))


func _card_at(pos: Vector2) -> int:
	for i in db().sorted_products().size():
		if card_rect(i).grow_individual(0, LIFT, 0, 0).has_point(pos):
			return i
	return -1


func _order_at(pos: Vector2) -> int:
	for i in db().sorted_products().size():
		if order_rect(i).grow_individual(0, 0, 0, ORDER_DROP).has_point(pos):
			return i
	return -1


func _process(delta: float) -> void:
	for index: int in _flashes.keys():
		_flashes[index][0] -= delta
		if _flashes[index][0] <= 0.0:
			_flashes.erase(index)
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover_order = _order_at(motion.position)
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not press.pressed:
		_pressed_order = -1
		return
	var order := _order_at(press.position)
	if order >= 0:
		_pressed_order = order
		var product := db().sorted_products()[order]
		_flashes[order] = [FLASH_SECONDS, match_state.order(store_index, product.id)]
		accept_event()
		return
	var index := _card_at(press.position)
	if index >= 0 and selection != null:
		selection.toggle(db().sorted_products()[index].id)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_order = -1
		_pressed_order = -1


func _get_drag_data(at_position: Vector2) -> Variant:
	if _order_at(at_position) >= 0:
		return null
	var index := _card_at(at_position)
	if index < 0:
		return null
	var product := db().sorted_products()[index]
	var token := Control.new()
	token.size = Vector2.ONE * DRAG_TOKEN_SIDE
	token.draw.connect(
		func() -> void: UiDraw.product_icon(token, Vector2.ZERO, DRAG_TOKEN_SIDE, product)
	)
	set_drag_preview(token)
	return {"product_id": product.id}


func _draw() -> void:
	if match_state == null:
		return
	var products := db().sorted_products()
	for i in products.size():
		var lift := Vector2.ZERO
		if selection != null and selection.product_id == products[i].id:
			lift.y = -LIFT
		var rect := card_rect(i)
		rect.position += lift
		_draw_card(rect, products[i])
		_draw_order_button(i, products[i], lift)


func _draw_card(rect: Rect2, product: ProductData) -> void:
	var id := product.id
	var stock := store().stock(id)
	var on_shelf := store().is_on_shelf(id)
	var selected := selection != null and selection.product_id == id
	var team := UiPalette.STORE_COLORS[store_index]
	if selected:
		var glow := team
		glow.a = blink()
		var glow_radius := UiPalette.RADIUS + int(SELECTED_GLOW)
		UiDraw.panel(self, rect.grow(SELECTED_GLOW), glow, Color.TRANSPARENT, 0, glow_radius)
	var radius := UiPalette.RADIUS_SMALL + 2
	UiDraw.card(self, rect, UiPalette.PAPER if on_shelf else UiPalette.PAPER_DIM, radius)
	if on_shelf or selected:
		UiDraw.panel(self, rect, Color.TRANSPARENT, team, UiPalette.OUTLINE, radius)
	var alpha := 1.0 if on_shelf else OFF_SHELF_ALPHA
	var icon_center := Vector2(rect.get_center().x, rect.position.y + ICON_Y)
	UiDraw.product_icon(self, icon_center, ICON_SIDE, product, alpha)
	var name_width := rect.size.x - PAD * 2.0
	var name_size := UiDraw.fit_size(product.short_name, UiPalette.FONT_TINY, name_width)
	_center_text(rect, NAME_Y, product.short_name, name_size, UiPalette.INK_SOFT)
	_center_text(rect, STOCK_Y, str(stock), STOCK_FONT, _stock_color(stock, on_shelf))
	_draw_waste(rect, id)
	_draw_delivery(rect, id)


## 発注ボタン:1行目に「発注」、2行目に1ロットの代金
func _draw_order_button(index: int, product: ProductData, lift: Vector2) -> void:
	var rect := order_rect(index)
	rect.position += lift
	var cost := match_state.lot_cost(store_index, product.id)
	var affordable := store().funds >= cost
	var fill := UiPalette.MONEY if affordable else FADED
	if affordable and index == _hover_order:
		fill = fill.lightened(HOVER_LIGHTEN)
	var radius := UiPalette.RADIUS_SMALL
	if index == _pressed_order:
		rect.position.y += ORDER_DROP
	else:
		var shadow := Rect2(rect.position + Vector2(0, ORDER_DROP), rect.size)
		UiDraw.panel(self, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, rect, fill, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	if _flashes.has(index):
		var flash: Array = _flashes[index]
		var color := OK_FLASH if flash[1] else FAIL_FLASH
		color.a *= flash[0] / FLASH_SECONDS
		UiDraw.panel(self, rect, color, Color.TRANSPARENT, 0, radius)
	var ink := UiPalette.INK if affordable else FADED_INK
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var caption_pos := Vector2(rect.position.x, rect.position.y + ORDER_CAPTION_Y)
	UiDraw.text(self, caption_pos, "発注", UiPalette.FONT_TINY, ink, center, rect.size.x)
	var price := UiDraw.yen(cost)
	var price_size := UiDraw.fit_size(price, UiPalette.FONT_SMALL, rect.size.x - PAD)
	var price_pos := Vector2(rect.position.x, rect.position.y + ORDER_COST_Y)
	UiDraw.text(self, price_pos, price, price_size, ink, center, rect.size.x)


func _stock_color(stock: int, on_shelf: bool) -> Color:
	if stock <= 0 or not on_shelf:
		return UiPalette.INK_SOFT
	if stock <= match_state.balance.low_stock_threshold:
		return UiPalette.BAD.lerp(UiPalette.INK, 1.0 - blink())
	return UiPalette.INK


## いちばん古いロットが廃棄されるまでの残りを、減っていくバーで出す(残りが少ないと赤く点滅する)
func _draw_waste(rect: Rect2, product_id: StringName) -> void:
	var lot := store().oldest_lot(product_id)
	if lot == null or lot.expires_at == INF:
		return
	var left := maxf(lot.expires_at - match_state.elapsed, 0.0)
	var bar := Rect2(
		rect.position.x + PAD * 2.0, rect.position.y + BAR_Y, rect.size.x - PAD * 4.0, BAR_HEIGHT
	)
	var radius := int(BAR_HEIGHT * 0.5)
	UiDraw.panel(self, bar, BAR_TRACK, Color.TRANSPARENT, 0, radius)
	var ratio := clampf(left / match_state.balance.waste_seconds, 0.0, 1.0)
	var color := UiPalette.GOOD
	if left <= WASTE_DANGER_SECONDS:
		color = UiPalette.BAD.lerp(BAR_TRACK, blink())
	elif left <= WASTE_WARN_SECONDS:
		color = UiPalette.BAD
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	UiDraw.panel(self, filled, color, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, bar, Color.TRANSPARENT, UiPalette.INK, 1, radius)


## 入荷待ち:届くまでの秒数と個数
func _draw_delivery(rect: Rect2, product_id: StringName) -> void:
	var arriving := store().next_delivery_seconds(product_id)
	if arriving < 0.0:
		return
	var label := "+%d %d秒" % [store().pending_count(product_id), int(ceil(arriving))]
	var center := Vector2(rect.get_center().x, rect.position.y + DELIVERY_Y)
	var white := UiPalette.INK_ON_DARK
	UiDraw.pill(
		self, center, label, UiPalette.FONT_TINY, UiPalette.DELIVERY, white, DELIVERY_HEIGHT
	)


func _center_text(
	rect: Rect2, baseline: float, value: String, font_size: int, color: Color
) -> void:
	var pos := Vector2(rect.position.x, rect.position.y + baseline)
	UiDraw.text(self, pos, value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
