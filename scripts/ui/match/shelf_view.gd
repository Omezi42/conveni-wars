class_name ShelfView
extends MatchPart
## 3×3の棚(GameDesign.md 4章・9.2節)。自店は操作でき、相手は表示だけ(同じ部品を大きさを変えて使う)。
## マスには商品・在庫数・売値を出し、成立しているボーナスを枠の色と名前で示す。

signal slot_pressed(slot: int)
signal product_dropped(product_id: StringName, slot: int)

## 名前やボーナスの札を出す、マスの最小の大きさ
const DETAIL_MIN_CELL := 90.0
const ICON_Y := 0.28
const ICON_RADIUS := 0.17
const NAME_Y := 0.56
const STOCK_Y := 0.75
const PRICE_Y := 0.93
const SMALL_STOCK_Y := 0.66
const SMALL_PRICE_Y := 0.92
const FRAME_WIDTH := 3.0
const TAG_HEIGHT := 16.0
const TAG_PAD := 4.0
const TAG_RADIUS := 4
const TAG_SPACING := 2.0
const MULT_WIDTH := 60.0
const BLINK_MIN_ALPHA := 0.3
const DROP_HIGHLIGHT := Color(0.18, 0.49, 0.88, 0.25)
const SELECT_HINT := Color(0.18, 0.49, 0.88, 0.6)

var cell_size := 116.0
var gap := 6.0
var interactive := false
## 自店の棚だけが持つ(置く商品の選択と、値付けパネルに出しているマス)
var selection: UiSelection

var _drop_slot := -1


func configure(cell: float, spacing: float, is_interactive: bool) -> void:
	cell_size = cell
	gap = spacing
	interactive = is_interactive
	mouse_filter = Control.MOUSE_FILTER_STOP if is_interactive else Control.MOUSE_FILTER_IGNORE


func grid_size() -> Vector2:
	var side := cell_size * StoreState.COLUMNS + gap * (StoreState.COLUMNS - 1)
	return Vector2(side, side)


func slot_rect(slot: int) -> Rect2:
	var column := slot % StoreState.COLUMNS
	@warning_ignore("integer_division")
	var row := slot / StoreState.COLUMNS
	var pos := Vector2(column, row) * (cell_size + gap)
	return Rect2(pos, Vector2(cell_size, cell_size))


func slot_at(pos: Vector2) -> int:
	for slot in StoreState.SLOT_COUNT:
		if slot_rect(slot).has_point(pos):
			return slot
	return -1


## 売れた商品の「+¥」を出す位置。同じ商品が複数のマスにあれば倍率の高いマス
func sale_origin(product_id: StringName) -> Vector2:
	var best := -1
	var multipliers := store().shelf_bonus().multipliers
	for slot in StoreState.SLOT_COUNT:
		if (
			store().shelf[slot] == product_id
			and (best < 0 or multipliers[slot] > multipliers[best])
		):
			best = slot
	if best < 0:
		return global_position + grid_size() / 2.0
	return global_position + slot_rect(best).get_center()


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot := slot_at(press.position)
	if slot >= 0:
		slot_pressed.emit(slot)
		accept_event()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not interactive or not (data is Dictionary and (data as Dictionary).has("product_id")):
		return false
	_drop_slot = slot_at(at_position)
	return _drop_slot >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drop_slot = -1
	var slot := slot_at(at_position)
	if slot >= 0:
		product_dropped.emit(StringName((data as Dictionary)["product_id"]), slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drop_slot = -1


func _draw() -> void:
	if match_state == null:
		return
	var bonus := store().shelf_bonus()
	for slot in StoreState.SLOT_COUNT:
		_draw_cell(slot, bonus)


func _draw_cell(slot: int, bonus: ShelfBonus.Result) -> void:
	var rect := slot_rect(slot)
	var product_id := store().shelf[slot]
	var detailed := cell_size >= DETAIL_MIN_CELL
	if product_id == StoreState.EMPTY:
		UiDraw.panel(self, rect, UiPalette.EMPTY_SLOT)
		if detailed:
			UiDraw.text_centered(self, rect, "空き", UiPalette.FONT_BODY, UiPalette.INK_SOFT)
		else:
			UiDraw.text_centered(self, rect, "空", UiPalette.FONT_SMALL, UiPalette.INK_SOFT)
	else:
		_draw_product_cell(rect, slot, product_id, bonus, detailed)
	if slot == _drop_slot:
		UiDraw.panel(self, rect, DROP_HIGHLIGHT)
	if interactive and selection != null and selection.has_selection():
		draw_rect(rect.grow(-1.0), SELECT_HINT, false, 2.0)
	if selection != null and slot == selection.focus_slot:
		draw_rect(rect.grow(2.0), UiPalette.ACCENT, false, FRAME_WIDTH)


func _draw_product_cell(
	rect: Rect2, slot: int, product_id: StringName, bonus: ShelfBonus.Result, detailed: bool
) -> void:
	var product := db().product(product_id)
	var stock := store().stock(product_id)
	UiDraw.panel(self, rect, UiPalette.CARD if stock > 0 else UiPalette.SOLD_OUT)
	var kinds := _bonus_kinds(bonus.bonuses_at(slot))
	for i in kinds.size():
		var inset := FRAME_WIDTH * (i + 0.5)
		var color := UiPalette.BONUS_COLORS[kinds[i]]
		draw_rect(rect.grow(-inset), color, false, FRAME_WIDTH)
	var w := rect.size.x
	var icon_center := rect.position + Vector2(w / 2.0, w * ICON_Y)
	UiDraw.product_icon(self, icon_center, w * ICON_RADIUS, product)
	var stock_y := STOCK_Y if detailed else SMALL_STOCK_Y
	var price_y := PRICE_Y if detailed else SMALL_PRICE_Y
	var font := UiPalette.FONT_BODY if detailed else UiPalette.FONT_SMALL
	if detailed:
		_line(rect, NAME_Y, product.short_name, UiPalette.FONT_SMALL, UiPalette.CARD_INK_SOFT)
	_line(rect, stock_y, _stock_label(product_id, stock), font, _stock_color(stock))
	var step := store().price_step(product_id)
	var price := UiDraw.yen(store().sell_price(product_id))
	_line(rect, price_y, price, font, UiPalette.PRICE_COLORS[step])
	if detailed:
		_draw_tags(rect, kinds, bonus.multipliers[slot])


func _stock_label(product_id: StringName, stock: int) -> String:
	if stock > 0:
		return "%d個" % stock
	var arriving := store().next_delivery_seconds(product_id)
	if arriving >= 0.0:
		return "入荷%d秒" % int(ceil(arriving))
	return "品切れ"


func _stock_color(stock: int) -> Color:
	if stock <= 0:
		return UiPalette.BAD
	if stock <= match_state.balance.low_stock_threshold:
		var color := UiPalette.BAD
		color.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink())
		return color
	return UiPalette.CARD_INK


func _line(rect: Rect2, ratio: float, value: String, font_size: int, color: Color) -> void:
	var baseline := rect.position.y + rect.size.y * ratio
	UiDraw.text(
		self,
		Vector2(rect.position.x, baseline),
		value,
		font_size,
		color,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x
	)


func _draw_tags(rect: Rect2, kinds: Array[int], multiplier: float) -> void:
	var x := rect.position.x + TAG_PAD
	var y := rect.position.y + TAG_PAD
	for kind in kinds:
		var label := ShelfBonus.KIND_LABELS[kind]
		var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + TAG_PAD * 2.0
		var tag := Rect2(x, y, width, TAG_HEIGHT)
		UiDraw.panel(self, tag, UiPalette.BONUS_COLORS[kind], Color.TRANSPARENT, 0, TAG_RADIUS)
		UiDraw.text_centered(self, tag, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK)
		y += TAG_HEIGHT + TAG_SPACING
	if multiplier > 1.0:
		var label := "×%.2f" % multiplier
		var pos := Vector2(rect.end.x - TAG_PAD - MULT_WIDTH, rect.position.y + TAG_HEIGHT)
		var align := HORIZONTAL_ALIGNMENT_RIGHT
		UiDraw.text(self, pos, label, UiPalette.FONT_SMALL, UiPalette.GOOD, align, MULT_WIDTH)


static func _bonus_kinds(bonuses: Array[ShelfBonus.Bonus]) -> Array[int]:
	var kinds: Array[int] = []
	for item in bonuses:
		if not kinds.has(item.kind):
			kinds.append(item.kind)
	kinds.sort()
	return kinds
