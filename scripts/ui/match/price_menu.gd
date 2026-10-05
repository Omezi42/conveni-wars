class_name PriceMenu
extends MatchPart
## マスをタップすると出る値段の3段階のボタンと、棚から外す・自動発注の切り替えのボタン(GameDesign.md 5.1節・6.3節・6.5節・9.2節・9.5節)。
## ボタンは棚の値札と同じ色(安売り=黄色の特価札・定価=白・強気=紺)で、いまの段階は沈んで印が付く。
## 画面全体を覆い、メニューの外をタップすると閉じる。

signal closed

const BUTTON_SIZE := Vector2(98, 60)
const REMOVE_HEIGHT := 36.0
const PAD := 12.0
const HEADER_HEIGHT := 30.0
const STATUS_HEIGHT := 22.0
const OFFSET := 14.0
const POINTER := Vector2(18, 10)
const PRICE_FONT := 20
const REMOVE_FILL := Color("#dcd6c8")
const AUTO_FILL := Color("#cdeed9")

var _slot := -1
var _product_id: StringName = &""
var _box := Rect2()
## 吹き出しの先(マスを指す点)
var _pointer_tip := Vector2.ZERO
var _buttons: Array[PopButton] = []
var _remove: PopButton
var _auto: PopButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	for step in state.balance.price_step_count():
		var button := PopButton.create(
			"", UiPalette.PRICE_FILLS[step], UiPalette.PRICE_INKS[step], PRICE_FONT
		)
		button.caption = state.balance.price_step_names[step]
		button.size = BUTTON_SIZE
		button.pressed.connect(_on_step_pressed.bind(step))
		add_child(button)
		_buttons.append(button)
	_remove = PopButton.create("棚から外す", REMOVE_FILL, UiPalette.INK, UiPalette.FONT_BODY)
	_remove.radius = UiPalette.RADIUS_SMALL
	_remove.pressed.connect(_on_remove_pressed)
	add_child(_remove)
	_auto = PopButton.create("自動発注", AUTO_FILL, UiPalette.INK, UiPalette.FONT_BODY)
	_auto.radius = UiPalette.RADIUS_SMALL
	_auto.pressed.connect(_on_auto_pressed)
	add_child(_auto)


func open_for(slot: int, anchor: Rect2) -> void:
	_slot = slot
	_product_id = store().shelf[slot]
	var count := _buttons.size()
	var width := BUTTON_SIZE.x * count + PAD * (count + 1)
	var height := HEADER_HEIGHT + STATUS_HEIGHT + BUTTON_SIZE.y + REMOVE_HEIGHT + PAD * 3.0
	var pos := Vector2(anchor.get_center().x - width / 2.0, anchor.end.y + OFFSET)
	var below := pos.y + height <= size.y
	if not below:
		pos.y = anchor.position.y - OFFSET - height
	pos.x = clampf(pos.x, PAD, size.x - width - PAD)
	_box = Rect2(pos, Vector2(width, height))
	var tip_y := anchor.end.y if below else anchor.position.y
	_pointer_tip = Vector2(anchor.get_center().x, tip_y)
	var y := pos.y + PAD * 0.5 + HEADER_HEIGHT + STATUS_HEIGHT
	for i in count:
		_buttons[i].position = Vector2(pos.x + PAD + i * (BUTTON_SIZE.x + PAD), y)
	var half := (width - PAD * 3.0) * 0.5
	_remove.position = Vector2(pos.x + PAD, y + BUTTON_SIZE.y + PAD)
	_remove.size = Vector2(half, REMOVE_HEIGHT)
	_auto.position = _remove.position + Vector2(half + PAD, 0)
	_auto.size = _remove.size
	visible = true
	_refresh()


func close() -> void:
	if visible:
		visible = false
		_slot = -1
		closed.emit()


func current_slot() -> int:
	return _slot


func _process(delta: float) -> void:
	super._process(delta)
	if visible:
		if store().shelf[_slot] != _product_id:
			close()
			return
		_refresh()


func _refresh() -> void:
	var can_change := match_state.can_set_price(store_index, _product_id)
	var current := store().price_step(_product_id)
	for step in _buttons.size():
		var button := _buttons[step]
		button.text = UiDraw.yen(store().price_for_step(_product_id, step))
		button.chosen = step == current
		button.disabled = not can_change or step == current
	_auto.chosen = store().auto_orders.has(_product_id)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and not _box.has_point(press.position):
		close()
		accept_event()


func _draw() -> void:
	if not visible or match_state == null or _slot < 0:
		return
	_draw_pointer()
	UiDraw.card(self, _box, UiPalette.PAPER)
	var product := db().product(_product_id)
	var inner_x := _box.position.x + PAD
	var header_base := _box.position.y + PAD * 0.5 + HEADER_HEIGHT * 0.8
	UiDraw.text(
		self,
		Vector2(inner_x, header_base),
		product.display_name,
		UiPalette.FONT_LARGE,
		UiPalette.INK
	)
	var status_pos := Vector2(inner_x, header_base + STATUS_HEIGHT)
	var status_color := (
		UiPalette.BAD
		if not match_state.can_set_price(store_index, _product_id)
		else UiPalette.INK_SOFT
	)
	UiDraw.text(self, status_pos, _status_text(), UiPalette.FONT_SMALL, status_color)


## 吹き出しのしっぽ(メニューがどのマスのものかを指す)
func _draw_pointer() -> void:
	var edge_y := _box.position.y if _pointer_tip.y < _box.position.y else _box.end.y
	var direction := signf(edge_y - _pointer_tip.y)
	var base_y := edge_y + direction * UiPalette.OUTLINE
	var tip := Vector2(_pointer_tip.x, edge_y - direction * POINTER.y)
	var points := PackedVector2Array(
		[Vector2(tip.x - POINTER.x * 0.5, base_y), Vector2(tip.x + POINTER.x * 0.5, base_y), tip]
	)
	draw_colored_polygon(points, UiPalette.INK)


func _status_text() -> String:
	if match_state.is_price_locked(store_index):
		var left := match_state.opponent(store_index).active_remaining
		return "値札ロック中 あと%d秒" % int(ceil(left))
	var cooldown := store().price_cooldown(_product_id)
	if cooldown > 0.0:
		return "あと%d秒で変えられる" % int(ceil(cooldown))
	var seconds := int(match_state.balance.price_cooldown)
	return "変えると%d秒は同じ商品の値段を変えられない" % seconds


func _on_step_pressed(step: int) -> void:
	commands.set_price_step(store_index, _product_id, step)
	close()


func _on_remove_pressed() -> void:
	commands.unassign(store_index, _slot)
	close()


func _on_auto_pressed() -> void:
	commands.set_auto_order(store_index, _product_id, not store().auto_orders.has(_product_id))
	close()
