class_name PriceMenu
extends MatchPart
## マスをタップすると出る値段の3段階のボタンと、棚から外すボタン(GameDesign.md 5.1節・6.3節・9.2節)。
## 画面全体を覆い、メニューの外をタップすると閉じる。

signal closed

const BUTTON_SIZE := Vector2(92, 52)
const REMOVE_HEIGHT := 34.0
const PAD := 10.0
const HEADER_HEIGHT := 30.0
const STATUS_HEIGHT := 20.0
const OFFSET := 8.0
const SELECTED_EDGE := 3
const SELECTED_LIGHTEN := 0.5
const TEXT_BASELINE := 0.75

var _slot := -1
var _product_id: StringName = &""
var _box := Rect2()
var _buttons: Array[Button] = []
var _remove: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	for step in state.balance.price_step_count():
		var button := UiDraw.make_button("", UiPalette.PRICE_COLORS[step], UiPalette.FONT_BODY)
		button.size = BUTTON_SIZE
		button.pressed.connect(_on_step_pressed.bind(step))
		add_child(button)
		_buttons.append(button)
	_remove = UiDraw.make_button("棚から外す", UiPalette.INK_SOFT, UiPalette.FONT_BODY)
	_remove.pressed.connect(_on_remove_pressed)
	add_child(_remove)


func open_for(slot: int, anchor: Rect2) -> void:
	_slot = slot
	_product_id = store().shelf[slot]
	var count := _buttons.size()
	var width := BUTTON_SIZE.x * count + PAD * (count + 1)
	var height := HEADER_HEIGHT + STATUS_HEIGHT + BUTTON_SIZE.y + REMOVE_HEIGHT + PAD * 3.0
	var pos := Vector2(anchor.get_center().x - width / 2.0, anchor.end.y + OFFSET)
	if pos.y + height > size.y:
		pos.y = anchor.position.y - OFFSET - height
	pos.x = clampf(pos.x, 0.0, size.x - width)
	_box = Rect2(pos, Vector2(width, height))
	var y := pos.y + HEADER_HEIGHT + STATUS_HEIGHT
	for i in count:
		_buttons[i].position = Vector2(pos.x + PAD + i * (BUTTON_SIZE.x + PAD), y)
	_remove.position = Vector2(pos.x + PAD, y + BUTTON_SIZE.y + PAD)
	_remove.size = Vector2(width - PAD * 2.0, REMOVE_HEIGHT)
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
		var name := match_state.balance.price_step_names[step]
		button.text = "%s\n%s" % [name, UiDraw.yen(store().price_for_step(_product_id, step))]
		button.disabled = not can_change or step == current
		var edge := UiPalette.INK if step == current else Color.TRANSPARENT
		var fill := UiPalette.PRICE_COLORS[step]
		button.add_theme_stylebox_override(
			"disabled", UiDraw.box(fill.lightened(SELECTED_LIGHTEN), edge, SELECTED_EDGE)
		)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and not _box.has_point(press.position):
		close()
		accept_event()


func _draw() -> void:
	if not visible or match_state == null or _slot < 0:
		return
	UiDraw.shadowed_panel(self, _box, UiPalette.PANEL)
	var product := db().product(_product_id)
	var header := Vector2(_box.position.x + PAD, _box.position.y + HEADER_HEIGHT * TEXT_BASELINE)
	UiDraw.text(self, header, product.display_name, UiPalette.FONT_LARGE, UiPalette.INK)
	var status := _status_text()
	var status_pos := header + Vector2(0, STATUS_HEIGHT)
	UiDraw.text(self, status_pos, status, UiPalette.FONT_SMALL, UiPalette.INK_SOFT)


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
	match_state.set_price_step(store_index, _product_id, step)
	close()


func _on_remove_pressed() -> void:
	match_state.unassign(store_index, _slot)
	close()
