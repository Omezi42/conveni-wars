class_name InventoryView
extends MatchPart
## 在庫一覧(GameDesign.md 6.2節〜6.4節・9.2節・9.5節)。商品ごとのカードに在庫数・廃棄までの残りと個数・入荷待ちを出す。
## 棚に出ている商品は上端の札を店の色にする。カードをタップで選ぶ(浮き上がる)かドラッグして、棚のマスへ置く。

const CARD_WIDTH := 72.0
const CARD_GAP := 4.0
const CARD_HEIGHT := 134.0
const PAD := 5.0
const FLAG_HEIGHT := 18.0
const ICON_Y := 43.0
const ICON_SIDE := 36.0
const NAME_Y := 76.0
const STOCK_Y := 100.0
const STOCK_FONT := 24
const BAR_Y := 104.0
const BAR_HEIGHT := 12.0
const DELIVERY_Y := 117.0
const DELIVERY_HEIGHT := 12.0
## 廃棄が近いとみなす残り秒数
const WASTE_WARN_SECONDS := 15.0
const WASTE_DANGER_SECONDS := 5.0
const LIFT := 6.0
const SELECTED_GLOW := 3.0
const EMPTY_ALPHA := 0.45
const BAR_TRACK := Color("#e4ded0")
const DRAG_TOKEN_SIDE := 56.0

var selection: UiSelection


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func card_rect(index: int) -> Rect2:
	return Rect2(
		index * (CARD_WIDTH + CARD_GAP),
		size.y - CARD_HEIGHT - UiPalette.SHADOW_DROP,
		CARD_WIDTH,
		CARD_HEIGHT
	)


func _card_at(pos: Vector2) -> int:
	for i in db().sorted_products().size():
		if card_rect(i).grow_individual(0, LIFT, 0, 0).has_point(pos):
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
		var rect := card_rect(i)
		if selection != null and selection.product_id == products[i].id:
			rect.position.y -= LIFT
		_draw_card(rect, products[i])


func _draw_card(rect: Rect2, product: ProductData) -> void:
	var id := product.id
	var stock := store().stock(id)
	var on_shelf := store().is_on_shelf(id)
	var selected := selection != null and selection.product_id == id
	var team := UiPalette.STORE_COLORS[store_index]
	if selected:
		var glow := team
		glow.a = blink()
		UiDraw.panel(
			self,
			rect.grow(SELECTED_GLOW),
			glow,
			Color.TRANSPARENT,
			0,
			UiPalette.RADIUS + int(SELECTED_GLOW)
		)
	UiDraw.card(
		self,
		rect,
		UiPalette.PAPER,
		UiPalette.RADIUS_SMALL + 2,
		UiPalette.OUTLINE if selected else UiPalette.OUTLINE_THIN
	)
	_draw_flag(rect, on_shelf, stock)
	var center_x := rect.get_center().x
	var alpha := 1.0 if stock > 0 or on_shelf else EMPTY_ALPHA
	UiDraw.product_icon(
		self, Vector2(center_x, rect.position.y + ICON_Y), ICON_SIDE, product, alpha
	)
	var name_size := UiDraw.fit_size(
		product.short_name, UiPalette.FONT_TINY, rect.size.x - PAD * 2.0
	)
	_center_text(rect, NAME_Y, product.short_name, name_size, UiPalette.INK_SOFT)
	_center_text(rect, STOCK_Y, str(stock), STOCK_FONT, _stock_color(stock, on_shelf))
	_draw_waste(rect, id)
	_draw_delivery(rect, id)


## 上端の札:棚に出ている=店の色の「棚」/在庫はあるが倉庫にある=「倉庫」
func _draw_flag(rect: Rect2, on_shelf: bool, stock: int) -> void:
	if not on_shelf and stock <= 0:
		return
	var flag := Rect2(
		rect.position + Vector2(PAD, PAD), Vector2(rect.size.x - PAD * 2.0, FLAG_HEIGHT)
	)
	var fill := UiPalette.STORE_COLORS[store_index] if on_shelf else UiPalette.PAPER_DIM
	var ink := UiPalette.INK_ON_DARK if on_shelf else UiPalette.INK_SOFT
	UiDraw.panel(self, flag, fill, Color.TRANSPARENT, 0, UiPalette.RADIUS_SMALL - 2)
	UiDraw.text_centered(self, flag, "棚" if on_shelf else "倉庫", UiPalette.FONT_TINY, ink)


func _stock_color(stock: int, on_shelf: bool) -> Color:
	if stock <= 0:
		return UiPalette.INK_SOFT
	if not on_shelf:
		return UiPalette.INK_SOFT
	if stock <= match_state.balance.low_stock_threshold:
		return UiPalette.BAD.lerp(UiPalette.INK, 1.0 - blink())
	return UiPalette.INK


## いちばん古いロットが廃棄されるまでの残りを、減っていくバーと「秒×個数」で出す
func _draw_waste(rect: Rect2, product_id: StringName) -> void:
	var lot := store().oldest_lot(product_id)
	if lot == null or lot.expires_at == INF:
		return
	var left := maxf(lot.expires_at - match_state.elapsed, 0.0)
	var bar := Rect2(
		rect.position.x + PAD, rect.position.y + BAR_Y, rect.size.x - PAD * 2.0, BAR_HEIGHT
	)
	var radius := int(BAR_HEIGHT * 0.5)
	UiDraw.panel(self, bar, BAR_TRACK, Color.TRANSPARENT, 0, radius)
	var ratio := clampf(left / match_state.balance.waste_seconds, 0.0, 1.0)
	var color := UiPalette.GOOD
	if left <= WASTE_DANGER_SECONDS:
		color = UiPalette.BAD
	elif left <= WASTE_WARN_SECONDS:
		color = UiPalette.WARN
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	UiDraw.panel(self, filled, color, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, bar, Color.TRANSPARENT, UiPalette.INK, 1, radius)
	var label := "%d秒×%d" % [int(ceil(left)), lot.count]
	UiDraw.text_centered(self, bar, label, UiPalette.FONT_TINY, UiPalette.INK)


## 入荷待ち:届くまでの秒数と個数
func _draw_delivery(rect: Rect2, product_id: StringName) -> void:
	var arriving := store().next_delivery_seconds(product_id)
	if arriving < 0.0:
		return
	var label := "+%d %d秒" % [store().pending_count(product_id), int(ceil(arriving))]
	var center := Vector2(rect.get_center().x, rect.position.y + DELIVERY_Y + DELIVERY_HEIGHT * 0.5)
	UiDraw.pill(
		self,
		center,
		label,
		UiPalette.FONT_TINY,
		UiPalette.DELIVERY,
		UiPalette.INK_ON_DARK,
		DELIVERY_HEIGHT + 2.0
	)


func _center_text(
	rect: Rect2, baseline: float, value: String, font_size: int, color: Color
) -> void:
	var pos := Vector2(rect.position.x, rect.position.y + baseline)
	UiDraw.text(self, pos, value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
