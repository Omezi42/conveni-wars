class_name PricePanel
extends MatchPart
## 値付けパネル(GameDesign.md 5.1節・6.3節・9.2節)。棚のマスか商品タイルで選んだ商品の値段を3段階から選ぶ。
## 棚のマスから選んだときは「棚から外す」も出す。

const LOCK_ICON := preload("res://assets/icons/ui/lock.svg")
const PAD := 10.0
const TITLE_BASELINE := 20.0
const ICON_CENTER := Vector2(26, 46)
const ICON_RADIUS := 15.0
const NAME_X := 48.0
const NAME_BASELINE := 44.0
const STATUS_BASELINE := 62.0
const LOCK_RADIUS := 7.0
const BUTTON_TOP := 72.0
const BUTTON_GAP := 8.0
const REMOVE_SIZE := Vector2(92, 26)
const REMOVE_TOP := 30.0
const SELECTED_EDGE := 3
const SELECTED_LIGHTEN := 0.45

var selection: UiSelection

var _buttons: Array[Button] = []
var _remove: Button


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	for step in state.balance.price_step_count():
		var button := UiDraw.make_button("", UiPalette.PRICE_COLORS[step], UiPalette.FONT_LARGE)
		button.pressed.connect(_on_step_pressed.bind(step))
		add_child(button)
		_buttons.append(button)
	_remove = UiDraw.make_button("棚から外す", UiPalette.INK_SOFT.darkened(0.3), UiPalette.FONT_SMALL)
	_remove.pressed.connect(_on_remove_pressed)
	add_child(_remove)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _buttons.is_empty():
		_layout()


func _layout() -> void:
	var count := _buttons.size()
	var width := (size.x - PAD * 2.0 - BUTTON_GAP * (count - 1)) / count
	var height := size.y - BUTTON_TOP - PAD
	for i in count:
		_buttons[i].position = Vector2(PAD + i * (width + BUTTON_GAP), BUTTON_TOP)
		_buttons[i].size = Vector2(width, height)
	_remove.position = Vector2(size.x - PAD - REMOVE_SIZE.x, REMOVE_TOP)
	_remove.size = REMOVE_SIZE


func product_id() -> StringName:
	return &"" if selection == null else selection.focus_product


func _process(delta: float) -> void:
	super._process(delta)
	if match_state == null or selection == null:
		return
	var slot := selection.focus_slot
	if slot != UiSelection.NO_SLOT and store().shelf[slot] != selection.focus_product:
		selection.focus(selection.focus_product)
	_refresh()


func _refresh() -> void:
	var id := product_id()
	var has_product := id != &""
	_remove.visible = has_product and selection.focus_slot != UiSelection.NO_SLOT
	var can_change := has_product and match_state.can_set_price(store_index, id)
	var current := store().price_step(id) if has_product else -1
	for step in _buttons.size():
		var button := _buttons[step]
		button.visible = has_product
		if not has_product:
			continue
		var name := match_state.balance.price_step_names[step]
		button.text = "%s\n%s" % [name, UiDraw.yen(store().price_for_step(id, step))]
		button.disabled = not can_change or step == current
		var fill := UiPalette.PRICE_COLORS[step]
		var disabled_box := UiDraw.box(fill.darkened(0.2))
		if step == current:
			disabled_box = UiDraw.box(fill, UiPalette.ACCENT, SELECTED_EDGE)
		elif not can_change:
			disabled_box = UiDraw.box(fill.darkened(0.55))
		button.add_theme_stylebox_override("disabled", disabled_box)
		var ink := UiPalette.INK_ON_DARK
		if step != current and not can_change:
			ink = UiPalette.INK_SOFT
		button.add_theme_color_override("font_disabled_color", ink)


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size))
	UiDraw.panel_title(self, Vector2(PAD, TITLE_BASELINE), "値付け")
	var id := product_id()
	if id == &"":
		var hint := "棚のマスか商品をタップすると\nここで値段を変えられる"
		var rect := Rect2(Vector2(PAD, BUTTON_TOP - PAD), Vector2(size.x - PAD * 2.0, 40))
		draw_multiline_string(
			UiDraw.font(),
			Vector2(PAD, BUTTON_TOP),
			hint,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			UiPalette.FONT_BODY,
			-1,
			UiPalette.INK_SOFT
		)
		return
	var product := db().product(id)
	UiDraw.product_icon(self, ICON_CENTER, ICON_RADIUS, product)
	var name_pos := Vector2(NAME_X, NAME_BASELINE)
	UiDraw.text(self, name_pos, product.display_name, UiPalette.FONT_LARGE, UiPalette.INK)
	var locked := not match_state.can_set_price(store_index, id)
	var status_x := NAME_X
	if locked:
		var lock_center := Vector2(NAME_X + LOCK_RADIUS, STATUS_BASELINE - LOCK_RADIUS + 1.0)
		UiDraw.texture_at(self, LOCK_ICON, lock_center, LOCK_RADIUS)
		status_x += LOCK_RADIUS * 2.0 + 4.0
	var color := UiPalette.WARN if locked else UiPalette.INK_SOFT
	var status_pos := Vector2(status_x, STATUS_BASELINE)
	UiDraw.text(self, status_pos, _status_text(), UiPalette.FONT_SMALL, color)


func _status_text() -> String:
	if match_state.is_price_locked(store_index):
		var left := match_state.opponent(store_index).active_remaining
		return "値札ロック中 あと%d秒" % int(ceil(left))
	var cooldown := store().price_cooldown(product_id())
	if cooldown > 0.0:
		return "変更可能まで %d秒" % int(ceil(cooldown))
	var seconds := int(match_state.balance.price_cooldown)
	return "変えると%d秒は変えられない" % seconds


func _on_step_pressed(step: int) -> void:
	match_state.set_price_step(store_index, product_id(), step)


func _on_remove_pressed() -> void:
	match_state.unassign(store_index, selection.focus_slot)
	selection.focus(selection.focus_product)
