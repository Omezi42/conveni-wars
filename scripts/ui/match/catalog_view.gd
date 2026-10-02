class_name CatalogView
extends MatchPart
## 品ぞろえの帯(GameDesign.md 6章・9.2節)。棚に出ていない商品の札だけをカテゴリ順に並べ、カテゴリの境目を少し空ける
## (棚に出ている商品の発注は棚のマスで行う)。札には在庫数・廃棄までの残りのバー・入荷待ち・発注ボタンを出す。
## 札の発注ボタン以外をタップで選ぶ(浮き上がる)かドラッグして、棚のマスへ置く。
## 棚が変わると並ぶ札も変わるため、札の位置は毎フレーム並べ直す。
## 1段に収まらないほど多いとき(棚に空きが多いとき)は2段にし、札を絵・在庫・代金だけの小さな形にする。

const TILE_GAP := 6.0
const CATEGORY_GAP := 14.0
## 札が少ないときに横へ伸びすぎないようにする上限と、1段に並べる数の上限
const MAX_TILE_WIDTH := 150.0
const MAX_COLUMNS := 8
const ROW_GAP := 6.0
const PAD := 5.0
const ICON_SIDE := 40.0
## 絵の右の列:在庫数のベースラインと入荷待ちの札(札の中の座標)
const STOCK_Y := 24.0
const STOCK_FONT := UiPalette.FONT_LARGE
const DELIVERY_Y := 36.0
const DELIVERY_HEIGHT := 20.0
const WASTE_BAR_Y := 47.0
const WASTE_BAR_HEIGHT := 5.0
const NAME_Y := 70.0
const ORDER_HEIGHT := 26.0
## 2段のときの小さな札:絵の辺・在庫数の札・入荷待ちの札・廃棄バー・発注ボタン
const COMPACT_ICON_SIDE := 34.0
const COMPACT_BADGE_HEIGHT := 20.0
const COMPACT_DELIVERY_HEIGHT := 18.0
const COMPACT_ORDER_HEIGHT := 28.0
const LIFT := 6.0
const SELECTED_GLOW := 3.0
const DRAG_TOKEN_SIDE := 56.0

var selection: UiSelection

var _gauge: StockGauge
var _shown: Array[ProductData] = []
var _tiles: Array[Rect2] = []
var _compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	_gauge = StockGauge.new(state, index)
	_layout()


func tile_rect(index: int) -> Rect2:
	return _tiles[index]


## その商品の札の番号。棚に出ていて品ぞろえに無ければ -1
func tile_index(product_id: StringName) -> int:
	for i in _shown.size():
		if _shown[i].id == product_id:
			return i
	return -1


func order_rect(index: int) -> Rect2:
	var tile := _tiles[index]
	var bottom := tile.end.y - PAD - StockGauge.ORDER_DROP
	if _compact:
		var left := tile.position.x + PAD * 2.0 + COMPACT_ICON_SIDE
		return Rect2(
			left, bottom - COMPACT_ORDER_HEIGHT, tile.end.x - PAD - left, COMPACT_ORDER_HEIGHT
		)
	return Rect2(
		tile.position.x + PAD, bottom - ORDER_HEIGHT, tile.size.x - PAD * 2.0, ORDER_HEIGHT
	)


## 札の幅は段の幅から隙間を引いて等分し、上限で抑える(商品を足してもコードを変えずに並ぶ)
func _layout() -> void:
	_shown.clear()
	for product in db().sorted_products():
		if not store().is_on_shelf(product.id):
			_shown.append(product)
	_tiles.clear()
	if _shown.is_empty():
		return
	var rows := ceili(float(_shown.size()) / MAX_COLUMNS)
	var columns := ceili(float(_shown.size()) / rows)
	_compact = rows > 1
	var height := (size.y - UiPalette.SHADOW_DROP * rows - ROW_GAP * (rows - 1)) / rows
	for row in rows:
		var first := row * columns
		var last := mini(first + columns, _shown.size())
		var width := _tile_width(first, last)
		var y := (height + UiPalette.SHADOW_DROP + ROW_GAP) * row
		var x := 0.0
		for i in range(first, last):
			if i > first:
				x += _gap_before(i)
			_tiles.append(Rect2(x, y, width, height))
			x += width


func _tile_width(first: int, last: int) -> float:
	var gaps := 0.0
	for i in range(first + 1, last):
		gaps += _gap_before(i)
	return minf((size.x - gaps) / (last - first), MAX_TILE_WIDTH)


## カテゴリの境目は少し広く空ける(2段のときは札の幅を優先して空けない)
func _gap_before(index: int) -> float:
	if _compact:
		return TILE_GAP
	var same := _shown[index].category_id == _shown[index - 1].category_id
	return TILE_GAP if same else CATEGORY_GAP


func _tile_at(pos: Vector2) -> int:
	for i in _tiles.size():
		if _tiles[i].grow_individual(0, LIFT, 0, 0).has_point(pos):
			return i
	return -1


func _order_at(pos: Vector2) -> int:
	for i in _tiles.size():
		if StockGauge.hit_rect(order_rect(i)).has_point(pos):
			return i
	return -1


func _process(delta: float) -> void:
	if match_state == null:
		return
	_gauge.tick(delta)
	_layout()
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var products := _shown
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
	var product := _shown[index]
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
	for i in _tiles.size():
		var selected := selection != null and selection.product_id == _shown[i].id
		var lift := Vector2(0, -LIFT) if selected else Vector2.ZERO
		_draw_tile(i, _shown[i], selected, lift)


## 左上に絵、その右に在庫数と入荷待ち。下へ廃棄バー・名前・発注ボタン
func _draw_tile(index: int, product: ProductData, selected: bool, lift: Vector2) -> void:
	var rect := _tiles[index]
	rect.position += lift
	var team := UiPalette.STORE_COLORS[store_index]
	var radius := UiPalette.RADIUS_SMALL
	if selected:
		var glow := team
		glow.a = blink()
		UiDraw.panel(self, rect.grow(SELECTED_GLOW), glow, Color.TRANSPARENT, 0, radius + 3)
	UiDraw.card(self, rect, UiPalette.PAPER, radius)
	if selected:
		UiDraw.panel(self, rect, Color.TRANSPARENT, team, UiPalette.OUTLINE, radius)
	if _compact:
		_draw_compact_tile(index, rect, product, lift)
		return
	var icon_center := rect.position + Vector2(PAD + ICON_SIDE * 0.5, PAD + ICON_SIDE * 0.5)
	UiDraw.product_icon(self, icon_center, ICON_SIDE, product)
	var column_left := rect.position.x + PAD * 2.0 + ICON_SIDE
	var column_width := rect.end.x - PAD - column_left
	var stock := store().stock(product.id)
	UiDraw.text(
		self,
		Vector2(column_left, rect.position.y + STOCK_Y),
		str(stock),
		STOCK_FONT,
		_gauge.stock_color(stock, true, blink()),
		HORIZONTAL_ALIGNMENT_CENTER,
		column_width
	)
	var delivery := Vector2(column_left + column_width * 0.5, rect.position.y + DELIVERY_Y)
	_gauge.draw_delivery(self, delivery, product.id, DELIVERY_HEIGHT)
	var bar := Rect2(
		rect.position.x + PAD * 2.0,
		rect.position.y + WASTE_BAR_Y,
		rect.size.x - PAD * 4.0,
		WASTE_BAR_HEIGHT
	)
	_gauge.draw_waste_bar(self, bar, product.id, blink())
	var name_width := rect.size.x - PAD * 2.0
	var name_size := UiDraw.fit_size(product.short_name, UiPalette.FONT_BODY, name_width)
	UiDraw.text(
		self,
		Vector2(rect.position.x, rect.position.y + NAME_Y),
		product.short_name,
		name_size,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x
	)
	var order := order_rect(index)
	order.position += lift
	_gauge.draw_order_button(self, order, product.id, true)


## 2段のときの小さな札:左に絵(右上に在庫数、下に入荷待ち)、右に廃棄バーと代金だけの発注ボタン
func _draw_compact_tile(index: int, rect: Rect2, product: ProductData, lift: Vector2) -> void:
	var side := COMPACT_ICON_SIDE
	var icon_center := Vector2(rect.position.x + PAD + side * 0.5, rect.get_center().y)
	UiDraw.product_icon(self, icon_center, side, product)
	var stock := store().stock(product.id)
	if stock > 0:
		var badge := icon_center + Vector2(side, -side) * 0.5
		UiDraw.pill(
			self,
			badge,
			str(stock),
			UiPalette.FONT_SMALL,
			UiPalette.PAPER,
			UiPalette.INK,
			COMPACT_BADGE_HEIGHT
		)
	var delivery := icon_center + Vector2(0, side * 0.5)
	_gauge.draw_delivery(self, delivery, product.id, COMPACT_DELIVERY_HEIGHT)
	var order := order_rect(index)
	order.position += lift
	var bar := Rect2(order.position.x, rect.position.y + PAD, order.size.x, WASTE_BAR_HEIGHT)
	_gauge.draw_waste_bar(self, bar, product.id, blink())
	_gauge.draw_order_button(self, order, product.id, false)
