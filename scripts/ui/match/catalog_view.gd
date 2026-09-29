class_name CatalogView
extends MatchPart
## 品ぞろえの帯(GameDesign.md 6章・9.2節)。全商品の小さな札をカテゴリ順に並べ、カテゴリの境目を少し空ける。
## 棚に出ていない商品の札は在庫数・廃棄までの残りのバー・入荷待ち・1ロットの代金の発注ボタンを出す。
## 棚に出ている商品は「陳列中」として薄く描き、発注ボタンを出さない(その商品の発注は棚のマスで行う)。
## 札の発注ボタン以外をタップで選ぶ(浮き上がる)かドラッグして、棚のマスへ置く。

const TILE_GAP := 3.0
const CATEGORY_GAP := 10.0
const PAD := 4.0
const ICON_Y := 24.0
const ICON_SIDE := 36.0
const BADGE_HEIGHT := 16.0
const DELIVERY_HEIGHT := 15.0
const NAME_Y := 56.0
const WASTE_BAR_Y := 61.0
const WASTE_BAR_HEIGHT := 4.0
const ORDER_HEIGHT := 24.0
const ON_SHELF_Y := 82.0
const LIFT := 6.0
const SELECTED_GLOW := 3.0
const ON_SHELF_ALPHA := 0.45
const DRAG_TOKEN_SIDE := 56.0

var selection: UiSelection

var _gauge: StockGauge
var _tiles: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_layout)


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	_gauge = StockGauge.new(state, index)
	_layout()


func tile_rect(index: int) -> Rect2:
	return _tiles[index]


func order_rect(index: int) -> Rect2:
	var tile := _tiles[index]
	var bottom := tile.end.y - PAD - StockGauge.ORDER_DROP
	return Rect2(
		tile.position.x + PAD, bottom - ORDER_HEIGHT, tile.size.x - PAD * 2.0, ORDER_HEIGHT
	)


## 札の幅は帯の幅から隙間を引いて等分する(商品を足してもコードを変えずに並ぶ)
func _layout() -> void:
	if match_state == null:
		return
	var products := db().sorted_products()
	var category_breaks := 0
	for i in range(1, products.size()):
		if products[i].category_id != products[i - 1].category_id:
			category_breaks += 1
	var gaps := (products.size() - 1 - category_breaks) * TILE_GAP + category_breaks * CATEGORY_GAP
	var width := (size.x - gaps) / products.size()
	var height := size.y - UiPalette.SHADOW_DROP
	_tiles.clear()
	var x := 0.0
	for i in products.size():
		if i > 0:
			var same := products[i].category_id == products[i - 1].category_id
			x += TILE_GAP if same else CATEGORY_GAP
		_tiles.append(Rect2(x, size.y - height - UiPalette.SHADOW_DROP, width, height))
		x += width


func _orderable(product: ProductData) -> bool:
	return not store().is_on_shelf(product.id)


func _tile_at(pos: Vector2) -> int:
	for i in _tiles.size():
		if _tiles[i].grow_individual(0, LIFT, 0, 0).has_point(pos):
			return i
	return -1


func _order_at(pos: Vector2) -> int:
	var products := db().sorted_products()
	for i in _tiles.size():
		if _orderable(products[i]) and StockGauge.hit_rect(order_rect(i)).has_point(pos):
			return i
	return -1


func _process(delta: float) -> void:
	if _gauge != null:
		_gauge.tick(delta)
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var products := db().sorted_products()
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hovered := _order_at(motion.position)
		_gauge.hover_id = products[hovered].id if hovered >= 0 else &""
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not press.pressed:
		_gauge.release()
		return
	var order := _order_at(press.position)
	if order >= 0:
		_gauge.press(products[order].id)
		accept_event()
		return
	var index := _tile_at(press.position)
	if index >= 0 and selection != null:
		selection.toggle(products[index].id)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _gauge != null:
		_gauge.release()


func _get_drag_data(at_position: Vector2) -> Variant:
	if _order_at(at_position) >= 0:
		return null
	var index := _tile_at(at_position)
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
	if match_state == null or _tiles.is_empty():
		return
	var products := db().sorted_products()
	for i in products.size():
		var selected := selection != null and selection.product_id == products[i].id
		var lift := Vector2(0, -LIFT) if selected else Vector2.ZERO
		_draw_tile(i, products[i], selected, lift)


func _draw_tile(index: int, product: ProductData, selected: bool, lift: Vector2) -> void:
	var rect := _tiles[index]
	rect.position += lift
	var team := UiPalette.STORE_COLORS[store_index]
	var radius := UiPalette.RADIUS_SMALL
	if selected:
		var glow := team
		glow.a = blink()
		UiDraw.panel(self, rect.grow(SELECTED_GLOW), glow, Color.TRANSPARENT, 0, radius + 3)
	var orderable := _orderable(product)
	UiDraw.card(self, rect, UiPalette.PAPER if orderable else UiPalette.PAPER_DIM, radius)
	if selected:
		UiDraw.panel(self, rect, Color.TRANSPARENT, team, UiPalette.OUTLINE, radius)
	var alpha := 1.0 if orderable else ON_SHELF_ALPHA
	var icon_center := Vector2(rect.get_center().x, rect.position.y + ICON_Y)
	UiDraw.product_icon(self, icon_center, ICON_SIDE, product, alpha)
	var name_width := rect.size.x - PAD * 2.0
	var name_size := UiDraw.fit_size(product.short_name, UiPalette.FONT_TINY, name_width)
	var name_pos := Vector2(rect.position.x, rect.position.y + NAME_Y)
	UiDraw.text(
		self,
		name_pos,
		product.short_name,
		name_size,
		UiPalette.INK if orderable else UiPalette.INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x
	)
	if not orderable:
		var on_shelf_pos := Vector2(rect.position.x, rect.position.y + ON_SHELF_Y)
		UiDraw.text(
			self,
			on_shelf_pos,
			"陳列中",
			UiPalette.FONT_TINY,
			UiPalette.INK_SOFT,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x
		)
		return
	_draw_stock(rect, icon_center, product.id)
	var order := order_rect(index)
	order.position += lift
	_gauge.draw_order_button(self, order, product.id, false)


## 在庫数は絵の右上の札。入荷待ちは絵の下に重ね、廃棄バーは名前の下
func _draw_stock(rect: Rect2, icon_center: Vector2, product_id: StringName) -> void:
	var stock := store().stock(product_id)
	if stock > 0:
		var badge := icon_center + Vector2(ICON_SIDE, -ICON_SIDE) * 0.5
		UiDraw.pill(
			self,
			badge,
			str(stock),
			UiPalette.FONT_TINY,
			UiPalette.PAPER,
			UiPalette.INK,
			BADGE_HEIGHT
		)
	var delivery := icon_center + Vector2(0, ICON_SIDE * 0.5)
	_gauge.draw_delivery(self, delivery, product_id, DELIVERY_HEIGHT)
	var bar := Rect2(
		rect.position.x + PAD * 2.0,
		rect.position.y + WASTE_BAR_Y,
		rect.size.x - PAD * 4.0,
		WASTE_BAR_HEIGHT
	)
	_gauge.draw_waste_bar(self, bar, product_id, blink())
