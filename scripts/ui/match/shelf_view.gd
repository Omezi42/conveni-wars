class_name ShelfView
extends MatchPart
## 3×3の棚(GameDesign.md 4章・9.2節・9.5節)。自店は操作でき、相手は表示だけ(同じ部品を大きさを変えて使う)。
## 各段の手前に棚板があり、値札は棚板に掛かる。マスには商品・在庫数・売値を出し、
## 成立しているボーナスを枠の色で、名前を棚の下の札で示す。

signal slot_pressed(slot: int)
signal product_dropped(product_id: StringName, slot: int)

## 名前・倍率・ボーナスの札を出す、マスの最小の幅
const DETAIL_MIN_CELL := 90.0
## 棚板の厚さと、棚板が左右へはみ出す量
const BOARD_HEIGHT := 12.0
const COMPACT_BOARD_HEIGHT := 8.0
const BOARD_OVERHANG := 5.0
const BOARD_RADIUS := 4
## マスの中の配置(マスの幅・棚板より上の高さに対する割合)
const ICON_SIZE := 0.47
const ICON_Y := 0.4
const COMPACT_ICON_SIZE := 0.52
const COMPACT_ICON_Y := 0.44
const NAME_Y := 0.94
const BADGE_HEIGHT := 22.0
const COMPACT_BADGE_HEIGHT := 16.0
## 値札の幅(マスの幅に対する割合)と高さ
const TAG_WIDTH := 0.72
const TAG_HEIGHT := 24.0
const COMPACT_TAG_WIDTH := 0.9
const COMPACT_TAG_HEIGHT := 17.0
const FRAME_WIDTH := 3.0
const FRAME_STEP := 3.5
const MULT_POS := Vector2(6, 6)
const MULT_HEIGHT := 18.0
const SOLD_OUT_ALPHA := 0.35
## 在庫が少ない札の点滅で明るくする量
const LOW_STOCK_FLASH := 0.45
const SOLD_OUT_FILL := Color("#f8d3cf")
const EMPTY_INK := Color(0.36, 0.4, 0.51, 0.55)
const LIST_GAP := 10.0
const LIST_LINE := 26.0
const LIST_CHIP_HEIGHT := 22.0
const LIST_CHIP_PAD := 8.0
const DROP_HIGHLIGHT := Color(0.18, 0.44, 0.91, 0.25)
const SELECT_MIN_ALPHA := 0.35

var cell_size := Vector2(116, 108)
var gap := Vector2(10, 16)
var interactive := false
var selection: UiSelection
## 値段のメニューを開いているマス(強調する)
var open_slot := -1

var _drop_slot := -1


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
	return global_position + _space_rect(slot_rect(best)).get_center()


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


func _detailed() -> bool:
	return cell_size.x >= DETAIL_MIN_CELL


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
	if size.y > grid_size().y + LIST_GAP:
		_draw_bonus_list(bonus)


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
	var team := UiPalette.STORE_COLORS[store_index]
	if interactive and selection != null and selection.has_selection():
		var hint := team
		hint.a = lerpf(SELECT_MIN_ALPHA, 1.0, blink())
		UiDraw.panel(self, space, Color.TRANSPARENT, hint, UiPalette.OUTLINE, radius)
	if slot == open_slot:
		UiDraw.panel(self, space.grow(2.0), Color.TRANSPARENT, team, UiPalette.OUTLINE + 1, radius)


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
	var icon_side := space.size.x * (ICON_SIZE if detailed else COMPACT_ICON_SIZE)
	var icon_y := space.size.y * (ICON_Y if detailed else COMPACT_ICON_Y)
	var icon_center := space.position + Vector2(space.size.x * 0.5, icon_y)
	var alpha := 1.0 if stock > 0 else SOLD_OUT_ALPHA
	UiDraw.product_icon(self, icon_center, icon_side, product, alpha)
	_draw_stock_badge(icon_center, icon_side, product_id, stock)
	if detailed:
		var name_pos := Vector2(space.position.x, space.position.y + space.size.y * NAME_Y)
		var name_size := UiDraw.fit_size(product.short_name, UiPalette.FONT_SMALL, space.size.x)
		UiDraw.text(
			self,
			name_pos,
			product.short_name,
			name_size,
			UiPalette.INK_SOFT,
			HORIZONTAL_ALIGNMENT_CENTER,
			space.size.x
		)
		var multiplier := bonus.multipliers[slot]
		if multiplier > 1.0:
			_draw_multiplier(space, multiplier)


## 在庫数の札。アイコンの右上に出し、少ないと赤く点滅する。
## 切れたらアイコンの上に、入荷までの秒数か「品切れ」を出す
func _draw_stock_badge(
	icon_center: Vector2, icon_side: float, product_id: StringName, stock: int
) -> void:
	var detailed := _detailed()
	var height := BADGE_HEIGHT if detailed else COMPACT_BADGE_HEIGHT
	var font_size := UiPalette.FONT_BODY if detailed else UiPalette.FONT_TINY
	var center := icon_center + Vector2(icon_side, -icon_side) * 0.5
	var fill := UiPalette.PAPER
	var ink := UiPalette.INK
	var label := str(stock)
	if stock <= 0:
		center = icon_center
		ink = UiPalette.INK_ON_DARK
		var arriving := store().next_delivery_seconds(product_id)
		if arriving >= 0.0:
			fill = UiPalette.DELIVERY
			var seconds := int(ceil(arriving))
			label = ("入荷%d秒" if detailed else "%d秒") % seconds
		else:
			fill = UiPalette.BAD
			label = "品切れ"
	elif stock <= match_state.balance.low_stock_threshold:
		fill = UiPalette.BAD.lightened(LOW_STOCK_FLASH * blink())
		ink = UiPalette.INK_ON_DARK
	UiDraw.pill(self, center, label, font_size, fill, ink, height)


func _draw_multiplier(space: Rect2, multiplier: float) -> void:
	var label := "×%.2f" % multiplier
	var width := UiDraw.text_width(label, UiPalette.FONT_TINY) + MULT_HEIGHT * UiDraw.PILL_PAD_RATIO
	var center := space.position + MULT_POS + Vector2(width, MULT_HEIGHT) * 0.5
	UiDraw.pill(
		self, center, label, UiPalette.FONT_TINY, UiPalette.MONEY, UiPalette.INK, MULT_HEIGHT
	)


## 棚板に掛かる値札。色で値段の段階(安売り=黄色の特価札・定価=白・強気=紺)を見せる
func _draw_tag(slot: int) -> void:
	var rect := slot_rect(slot)
	var product_id := store().shelf[slot]
	var detailed := _detailed()
	var width := rect.size.x * (TAG_WIDTH if detailed else COMPACT_TAG_WIDTH)
	var height := TAG_HEIGHT if detailed else COMPACT_TAG_HEIGHT
	var board_mid := rect.end.y - _board_height() * 0.5
	var tag := Rect2(rect.get_center().x - width * 0.5, board_mid - height * 0.5, width, height)
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
	var font_size := UiPalette.FONT_BODY if detailed else UiPalette.FONT_TINY
	var price := UiDraw.yen(store().sell_price(product_id))
	UiDraw.text_centered(self, tag, price, font_size, UiPalette.PRICE_INKS[step])


func _draw_bonus_list(bonus: ShelfBonus.Result) -> void:
	var top := grid_size().y + LIST_GAP
	if bonus.bonuses.is_empty():
		var hint := "中央・縦1列・隣り合わせでボーナス"
		var hint_rect := Rect2(0, top, size.x, LIST_CHIP_HEIGHT)
		UiDraw.text_centered(self, hint_rect, hint, UiPalette.FONT_SMALL, UiPalette.INK_SOFT)
		return
	var x := 0.0
	var y := top
	for item in bonus.bonuses:
		var label := item.display_name
		var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + LIST_CHIP_PAD * 2.0
		if x + width > size.x:
			x = 0.0
			y += LIST_LINE
		var chip := Rect2(x, y, width, LIST_CHIP_HEIGHT)
		UiDraw.panel(
			self,
			chip,
			UiPalette.BONUS_COLORS[item.kind],
			UiPalette.INK,
			UiPalette.OUTLINE_THIN,
			int(LIST_CHIP_HEIGHT * 0.5)
		)
		UiDraw.text_centered(
			self, chip, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK, UiPalette.INK
		)
		x += width + LIST_CHIP_PAD * 0.5


static func _bonus_kinds(bonuses: Array[ShelfBonus.Bonus]) -> Array[int]:
	var kinds: Array[int] = []
	for item in bonuses:
		if not kinds.has(item.kind):
			kinds.append(item.kind)
	kinds.sort()
	return kinds
