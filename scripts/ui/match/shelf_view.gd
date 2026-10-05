class_name ShelfView
extends MatchPart
## 3×3の棚(GameDesign.md 4章・6章・9.2節・9.5節)。自店は操作でき、相手は表示だけ(同じ部品を大きさを変えて使う)。
## 各段の手前に棚板があり、値札は棚板に掛かる。マスには商品の絵と売値を出し、
## 成立しているボーナスを枠の色と、マスの左上に縦に並べた名前の札で示す(自店だけ。相手は枠の色だけ)。
## 自店のマスは左に絵、右の列に在庫数・廃棄までの残りのバー・入荷待ち・発注ボタンを置く。
## 相手のマスは絵と値札だけで、在庫が切れたマスを赤くする。
## 発注ボタンを押すとその商品を発注し、ほかの所をタップすると値段のメニューを開く(slot_pressed)。
## 自店のマスを別のマスへドラッグすると、同じ商品をそのマスにも置く(product_dropped。6.3節)。

signal slot_pressed(slot: int)
signal product_dropped(product_id: StringName, slot: int)

## 棚板の厚さと、棚板が左右へはみ出す量
const BOARD_HEIGHT := 12.0
const COMPACT_BOARD_HEIGHT := 8.0
const BOARD_OVERHANG := 5.0
const BOARD_RADIUS := 4
## マスの中の配置(アイコンの辺は棚板より上の幅と高さの短いほう、縦の位置はその高さに対する割合)
const ICON_SIZE := 0.6
const COMPACT_ICON_Y := 0.44
## 自店のマス:左の絵の列の幅(マスの幅に対する割合)・絵の辺と縦の位置(割合)
const ART_WIDTH := 0.5
const ART_ICON_SIZE := 0.82
const ART_ICON_Y := 0.52
## 自店のマス:右の列の余白・在庫数のベースライン・廃棄バー・入荷待ちの札・発注ボタン(マスの中の座標)
const COLUMN_PAD := 6.0
const STOCK_BASELINE := 32.0
const STOCK_FONT := 32
const WASTE_BAR_Y := 40.0
const WASTE_BAR_HEIGHT := 7.0
const DELIVERY_Y := 62.0
const DELIVERY_HEIGHT := 22.0
const ORDER_HEIGHT := 44.0
const BADGE_HEIGHT := 26.0
## 値札の幅(マスの幅に対する割合)と高さ
const TAG_WIDTH := 0.72
const TAG_HEIGHT := 30.0
const COMPACT_TAG_WIDTH := 0.86
const COMPACT_TAG_HEIGHT := 24.0
const FRAME_WIDTH := 3.0
const FRAME_STEP := 3.5
const BONUS_TAG_POS := Vector2(6, 6)
const BONUS_TAG_HEIGHT := 22.0
const BONUS_TAG_GAP := 3.0
const SOLD_OUT_ALPHA := 0.35
const DRAG_TOKEN_SIDE := 56.0
const SOLD_OUT_FILL := Color("#f8d3cf")
const EMPTY_INK := Color(0.36, 0.4, 0.51, 0.55)
const DROP_HIGHLIGHT := Color(0.18, 0.44, 0.91, 0.25)
const SELECT_MIN_ALPHA := 0.35
## 見える客が入ったときにマスを光らせる秒数・光の濃さ・枠の広がり
const FLASH_SECONDS := 0.7
const FLASH_ALPHA := 0.55
const FLASH_GROW := 4.0

var cell_size := Vector2(116, 108)
var gap := Vector2(10, 16)
var interactive := false
var selection: UiSelection
## 値段のメニューを開いているマス(強調する)
var open_slot := -1

var _drop_slot := -1
## 押して、まだ離していないマス(離したときに値段のメニューを開く。ドラッグしたら取り消す)
var _press_slot := -1
var _gauge: StockGauge
## マスごとの光りの残り(1 → 0)
var _flash: Array[float] = []


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	_gauge = StockGauge.new(state, index)


func configure(cell: Vector2, spacing: Vector2, is_interactive: bool) -> void:
	cell_size = cell
	gap = spacing
	interactive = is_interactive
	mouse_filter = Control.MOUSE_FILTER_STOP if is_interactive else Control.MOUSE_FILTER_IGNORE


func grid_size() -> Vector2:
	var columns := StoreState.COLUMNS
	@warning_ignore("integer_division")
	var rows := StoreState.SLOT_COUNT / columns
	return cell_size * Vector2(columns, rows) + gap * Vector2(columns - 1, rows - 1)


func slot_rect(slot: int) -> Rect2:
	var column := slot % StoreState.COLUMNS
	@warning_ignore("integer_division")
	var row := slot / StoreState.COLUMNS
	var pos := Vector2(column, row) * (cell_size + gap)
	return Rect2(pos, cell_size)


## 自店のマスの発注ボタン(棚板より上の右下)
func order_rect(slot: int) -> Rect2:
	var space := _space_rect(slot_rect(slot))
	var left := space.position.x + space.size.x * ART_WIDTH
	var bottom := space.end.y - COLUMN_PAD - StockGauge.ORDER_DROP
	return Rect2(left, bottom - ORDER_HEIGHT, space.end.x - COLUMN_PAD - left, ORDER_HEIGHT)


## 商品の入っている自店のマスのうち、発注ボタンの上にある番号(無ければ -1)
func order_slot_at(pos: Vector2) -> int:
	if not interactive:
		return -1
	for slot in StoreState.SLOT_COUNT:
		if (
			store().shelf[slot] != StoreState.EMPTY
			and StockGauge.hit_rect(order_rect(slot)).has_point(pos)
		):
			return slot
	return -1


func slot_at(pos: Vector2) -> int:
	for slot in StoreState.SLOT_COUNT:
		if slot_rect(slot).has_point(pos):
			return slot
	return -1


## 売れた商品の「+¥」を出す位置。同じ商品が複数のマスにあれば倍率の高いマス
func sale_origin(product_id: StringName) -> Vector2:
	var best := _best_slot(product_id)
	if best < 0:
		return global_position + grid_size() / 2.0
	return global_position + _space_rect(slot_rect(best)).get_center()


## 見える客が買った商品のマスを光らせる(GameDesign.md 9.2節)
func flash(product_id: StringName) -> void:
	var slot := _best_slot(product_id)
	if slot < 0:
		return
	if _flash.is_empty():
		_flash.resize(StoreState.SLOT_COUNT)
		_flash.fill(0.0)
	_flash[slot] = 1.0


## その商品が並ぶマスのうち、ボーナスの倍率の高いマス(無ければ -1)
func _best_slot(product_id: StringName) -> int:
	var best := -1
	var multipliers := store().shelf_bonus().multipliers
	for slot in StoreState.SLOT_COUNT:
		if (
			store().shelf[slot] == product_id
			and (best < 0 or multipliers[slot] > multipliers[best])
		):
			best = slot
	return best


func _process(delta: float) -> void:
	if _gauge != null:
		_gauge.tick(delta)
	for slot in _flash.size():
		_flash[slot] = maxf(_flash[slot] - delta / FLASH_SECONDS, 0.0)
	super._process(delta)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hovered := order_slot_at(motion.position)
		_gauge.hover_id = store().shelf[hovered] if hovered >= 0 else &""
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if slot_at(motion.position) >= 0 else Control.CURSOR_ARROW
		)
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not press.pressed:
		_gauge.release()
		var released := slot_at(press.position)
		if released >= 0 and released == _press_slot:
			slot_pressed.emit(released)
			accept_event()
		_press_slot = -1
		return
	var order_slot := order_slot_at(press.position)
	if order_slot >= 0:
		_gauge.press(store().shelf[order_slot], commands)
		accept_event()
		return
	_press_slot = slot_at(press.position)
	if _press_slot >= 0:
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	if not interactive or order_slot_at(at_position) >= 0:
		return null
	var slot := slot_at(at_position)
	if slot < 0 or store().shelf[slot] == StoreState.EMPTY:
		return null
	_press_slot = -1
	var product := db().product(store().shelf[slot])
	var token := Control.new()
	token.size = Vector2.ONE * DRAG_TOKEN_SIDE
	token.draw.connect(
		func() -> void: UiDraw.product_icon(token, Vector2.ZERO, DRAG_TOKEN_SIDE, product)
	)
	set_drag_preview(token)
	return {"product_id": product.id, "from_slot": slot}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not interactive or not (data is Dictionary and (data as Dictionary).has("product_id")):
		return false
	_drop_slot = slot_at(at_position)
	if _drop_slot >= 0 and (data as Dictionary).get("from_slot", -1) == _drop_slot:
		_drop_slot = -1
	return _drop_slot >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drop_slot = -1
	var slot := slot_at(at_position)
	if slot >= 0 and (data as Dictionary).get("from_slot", -1) != slot:
		product_dropped.emit(StringName((data as Dictionary)["product_id"]), slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drop_slot = -1
	if what == NOTIFICATION_MOUSE_EXIT and _gauge != null:
		_gauge.release()


## ボーナスの札と右の列まで出すか(操作する自店の棚だけ)
func _detailed() -> bool:
	return interactive


func _board_height() -> float:
	return BOARD_HEIGHT if _detailed() else COMPACT_BOARD_HEIGHT


## マスのうち棚板より上(商品が立つところ)
func _space_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position, Vector2(rect.size.x, rect.size.y - _board_height()))


func _draw() -> void:
	if match_state == null:
		return
	var bonus := store().shelf_bonus()
	for slot in StoreState.SLOT_COUNT:
		_draw_space(slot, bonus)
	_draw_boards()
	for slot in StoreState.SLOT_COUNT:
		if store().shelf[slot] != StoreState.EMPTY:
			_draw_tag(slot)


func _draw_boards() -> void:
	@warning_ignore("integer_division")
	var rows := StoreState.SLOT_COUNT / StoreState.COLUMNS
	var board_height := _board_height()
	for row in rows:
		var top := row * (cell_size.y + gap.y) + cell_size.y - board_height
		var board := Rect2(-BOARD_OVERHANG, top, grid_size().x + BOARD_OVERHANG * 2.0, board_height)
		UiDraw.panel(
			self, board, UiPalette.SHELF_BOARD, UiPalette.INK, UiPalette.OUTLINE_THIN, BOARD_RADIUS
		)


func _draw_space(slot: int, bonus: ShelfBonus.Result) -> void:
	var space := _space_rect(slot_rect(slot))
	var product_id := store().shelf[slot]
	var radius := UiPalette.RADIUS_SMALL
	if product_id == StoreState.EMPTY:
		UiDraw.panel(self, space, UiPalette.SLOT, Color.TRANSPARENT, 0, radius)
		if _detailed():
			UiDraw.text_centered(self, space, "空き", UiPalette.FONT_BODY, EMPTY_INK)
	else:
		_draw_product(slot, space, product_id, bonus)
	if slot == _drop_slot:
		UiDraw.panel(self, space, DROP_HIGHLIGHT, Color.TRANSPARENT, 0, radius)
	var team := ViewSide.color(store_index)
	if interactive and selection != null and selection.has_selection():
		var hint := team
		hint.a = lerpf(SELECT_MIN_ALPHA, 1.0, blink())
		UiDraw.panel(self, space, Color.TRANSPARENT, hint, UiPalette.OUTLINE, radius)
	if slot == open_slot:
		UiDraw.panel(self, space.grow(2.0), Color.TRANSPARENT, team, UiPalette.OUTLINE + 1, radius)
	if slot < _flash.size() and _flash[slot] > 0.0:
		var glow := UiPalette.MONEY
		glow.a = FLASH_ALPHA * _flash[slot]
		var edge := UiPalette.MONEY
		edge.a = _flash[slot]
		var grow := FLASH_GROW * (1.0 - _flash[slot])
		UiDraw.panel(self, space.grow(grow), glow, edge, UiPalette.OUTLINE, radius)


func _draw_product(
	slot: int, space: Rect2, product_id: StringName, bonus: ShelfBonus.Result
) -> void:
	var product := db().product(product_id)
	var stock := store().stock(product_id)
	var detailed := _detailed()
	var radius := UiPalette.RADIUS_SMALL
	UiDraw.panel(
		self, space, UiPalette.SLOT if stock > 0 else SOLD_OUT_FILL, Color.TRANSPARENT, 0, radius
	)
	var kinds := _bonus_kinds(bonus.bonuses_at(slot))
	for i in kinds.size():
		var frame := space.grow(-(FRAME_WIDTH * 0.5 + FRAME_STEP * i))
		UiDraw.panel(
			self,
			frame,
			Color.TRANSPARENT,
			UiPalette.BONUS_COLORS[kinds[i]],
			int(FRAME_WIDTH),
			radius
		)
	if stock <= 0:
		UiDraw.panel(self, space, Color.TRANSPARENT, UiPalette.BAD, UiPalette.OUTLINE_THIN, radius)
	var alpha := 1.0 if stock > 0 else SOLD_OUT_ALPHA
	if not detailed:
		var icon_side := minf(space.size.x, space.size.y) * ICON_SIZE
		var icon_center := (
			space.position + Vector2(space.size.x * 0.5, space.size.y * COMPACT_ICON_Y)
		)
		UiDraw.product_icon(self, icon_center, icon_side, product, alpha)
		return
	var art := Rect2(space.position, Vector2(space.size.x * ART_WIDTH, space.size.y))
	var art_side := minf(art.size.x, art.size.y) * ART_ICON_SIZE
	var art_center := art.position + Vector2(art.size.x * 0.5, art.size.y * ART_ICON_Y)
	UiDraw.product_icon(self, art_center, art_side, product, alpha)
	if stock <= 0 and store().next_delivery_seconds(product_id) < 0.0:
		UiDraw.pill(
			self,
			art_center,
			"品切れ",
			UiPalette.FONT_BODY,
			UiPalette.BAD,
			UiPalette.INK_ON_DARK,
			BADGE_HEIGHT
		)
	_draw_bonus_tags(space, kinds)
	_draw_stock_column(slot, space, product_id, stock)


## 自店のマスの右の列:在庫数(残り少ないと赤く点滅、切れると赤)・廃棄バー・入荷待ち・発注ボタン
func _draw_stock_column(slot: int, space: Rect2, product_id: StringName, stock: int) -> void:
	var left := space.position.x + space.size.x * ART_WIDTH
	var width := space.end.x - COLUMN_PAD - left
	var color := _gauge.stock_color(stock, true, blink()) if stock > 0 else UiPalette.BAD
	var stock_pos := Vector2(left, space.position.y + STOCK_BASELINE)
	UiDraw.text(self, stock_pos, str(stock), STOCK_FONT, color, HORIZONTAL_ALIGNMENT_CENTER, width)
	var bar := Rect2(left, space.position.y + WASTE_BAR_Y, width, WASTE_BAR_HEIGHT)
	_gauge.draw_waste_bar(self, bar, product_id, blink())
	var delivery := Vector2(left + width * 0.5, space.position.y + DELIVERY_Y)
	_gauge.draw_delivery(self, delivery, product_id, DELIVERY_HEIGHT)
	_gauge.draw_order_button(self, order_rect(slot), product_id, true)


func _draw_bonus_tags(space: Rect2, kinds: Array[int]) -> void:
	var pos := space.position + BONUS_TAG_POS
	for kind in kinds:
		var label: String = ShelfBonus.KIND_LABELS[kind]
		var pad := BONUS_TAG_HEIGHT * UiDraw.PILL_PAD_RATIO
		var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + pad
		var center := pos + Vector2(width, BONUS_TAG_HEIGHT) * 0.5
		UiDraw.pill(
			self,
			center,
			label,
			UiPalette.FONT_SMALL,
			UiPalette.BONUS_COLORS[kind],
			UiPalette.INK,
			BONUS_TAG_HEIGHT
		)
		pos.y += BONUS_TAG_HEIGHT + BONUS_TAG_GAP


## 棚板に掛かる値札。色で値段の段階(安売り=黄色の特価札・定価=白・強気=紺)を見せる
## マスの値札(棚板の中央)
func tag_rect(slot: int) -> Rect2:
	var rect := slot_rect(slot)
	var detailed := _detailed()
	var width := rect.size.x * (TAG_WIDTH if detailed else COMPACT_TAG_WIDTH)
	var height := TAG_HEIGHT if detailed else COMPACT_TAG_HEIGHT
	var board_mid := rect.end.y - _board_height() * 0.5
	return Rect2(rect.get_center().x - width * 0.5, board_mid - height * 0.5, width, height)


func _draw_tag(slot: int) -> void:
	var product_id := store().shelf[slot]
	var detailed := _detailed()
	var tag := tag_rect(slot)
	var step := store().price_step(product_id)
	var shadow := Rect2(tag.position + Vector2(0, UiPalette.SHADOW_DROP * 0.5), tag.size)
	UiDraw.panel(self, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, UiPalette.RADIUS_SMALL)
	UiDraw.panel(
		self,
		tag,
		UiPalette.PRICE_FILLS[step],
		UiPalette.INK,
		UiPalette.OUTLINE_THIN,
		UiPalette.RADIUS_SMALL
	)
	var font_size := UiPalette.FONT_LARGE if detailed else UiPalette.FONT_BODY
	var price := UiDraw.yen(store().sell_price(product_id))
	UiDraw.text_centered(self, tag, price, font_size, UiPalette.PRICE_INKS[step])


static func _bonus_kinds(bonuses: Array[ShelfBonus.Bonus]) -> Array[int]:
	var kinds: Array[int] = []
	for item in bonuses:
		if not kinds.has(item.kind):
			kinds.append(item.kind)
	kinds.sort()
	return kinds
