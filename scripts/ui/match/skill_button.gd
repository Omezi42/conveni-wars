class_name SkillButton
extends MatchPart
## 資金と、アクティブスキルのボタン(GameDesign.md 7章・9.2節・9.5節)。スキルは試合中に1回だけ使える。
## 使えるときは黄色く光り、発動中は残り時間のバーが減っていき、使い終わると灰色になる。
## 説明文はカーソルを乗せると出る(ボタンには名前と状態だけを大きく出す)。

const PAD := 12.0
const FUNDS_HEIGHT := 36.0
const GAP := 6.0
const COIN_RADIUS := 11.0
const FUNDS_FONT := 22
const TOKEN_RADIUS := 21.0
const TOKEN_X := 36.0
const TEXT_X := 70.0
const NAME_Y := 0.48
const STATE_Y := 0.84
const GLOW_SIZE := 5.0
const HOVER_LIGHTEN := 0.1
const USED_GRAY := Color("#a9a59c")
const RUNNING_TRACK := Color(1, 1, 1, 0.35)
const TOKEN_DARKEN := 0.25

var _hover := false
var _pressing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(state: MatchState, index: int) -> void:
	super.setup(state, index)
	tooltip_text = "%s:%s" % [store().manager.active_name, store().manager.active_description]


func button_rect() -> Rect2:
	var top := FUNDS_HEIGHT + GAP
	return Rect2(0.0, top, size.x, size.y - top - UiPalette.SHADOW_DROP)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = button_rect().has_point(motion.position)
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if _hover else Control.CURSOR_ARROW
		)
		return
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	_pressing = press.pressed and button_rect().has_point(press.position)
	if _pressing:
		match_state.use_active(store_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_pressing = false


func _draw() -> void:
	if match_state == null:
		return
	_draw_funds()
	var manager := store().manager
	var rect := button_rect()
	var usable := match_state.can_use_active(store_index)
	var running := store().active_remaining > 0.0
	var fill := manager.color
	if store().active_used and not running:
		fill = USED_GRAY
	elif _hover and usable:
		fill = fill.lightened(HOVER_LIGHTEN)
	if usable:
		var glow := UiPalette.MONEY
		glow.a = blink()
		UiDraw.panel(
			self,
			rect.grow(GLOW_SIZE),
			glow,
			Color.TRANSPARENT,
			0,
			UiPalette.RADIUS + int(GLOW_SIZE)
		)
	if _pressing and usable:
		rect.position.y += UiPalette.SHADOW_DROP
		UiDraw.panel(self, rect, fill, UiPalette.INK, UiPalette.OUTLINE)
	else:
		UiDraw.card(self, rect, fill)
	if running:
		_draw_running_bar(rect)
	_draw_token(rect, manager)
	var white := UiPalette.INK_ON_DARK
	var text_width := rect.size.x - TEXT_X - PAD
	var name_size := UiDraw.fit_size(manager.active_name, UiPalette.FONT_LARGE, text_width)
	var name_pos := Vector2(rect.position.x + TEXT_X, rect.position.y + rect.size.y * NAME_Y)
	UiDraw.text_outlined(self, name_pos, manager.active_name, name_size, white)
	var state_pos := Vector2(rect.position.x + TEXT_X, rect.position.y + rect.size.y * STATE_Y)
	UiDraw.text_outlined(self, state_pos, _state_text(), UiPalette.FONT_SMALL, white)


## 店長の顔(絵が無いうちは店長の色の丸に頭文字)
func _draw_token(rect: Rect2, manager: ManagerData) -> void:
	var center := Vector2(rect.position.x + TOKEN_X, rect.get_center().y)
	draw_circle(center, TOKEN_RADIUS + UiPalette.OUTLINE, UiPalette.INK)
	draw_circle(center, TOKEN_RADIUS, UiPalette.INK_ON_DARK)
	if manager.portrait != null:
		var side := Vector2.ONE * TOKEN_RADIUS * 2.0
		draw_texture_rect(manager.portrait, Rect2(center - side / 2.0, side), false)
		return
	draw_circle(center, TOKEN_RADIUS - UiPalette.OUTLINE, manager.color.darkened(TOKEN_DARKEN))
	var cell := Rect2(center - Vector2.ONE * TOKEN_RADIUS, Vector2.ONE * TOKEN_RADIUS * 2.0)
	UiDraw.text_centered(
		self, cell, manager.display_name.left(1), UiPalette.FONT_HEAD, UiPalette.INK_ON_DARK
	)


## 発動中は残り時間のぶんだけ明るい帯を残す
func _draw_running_bar(rect: Rect2) -> void:
	var total := ManagerSkills.active_duration(store().manager)
	if total <= 0.0:
		return
	var ratio := clampf(store().active_remaining / total, 0.0, 1.0)
	var inner := rect.grow(-UiPalette.OUTLINE)
	var bar := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
	UiDraw.panel(
		self, bar, RUNNING_TRACK, Color.TRANSPARENT, 0, UiPalette.RADIUS - UiPalette.OUTLINE
	)


func _state_text() -> String:
	if store().active_remaining > 0.0:
		return "発動中 あと%d秒" % int(ceil(store().active_remaining))
	if store().active_used:
		return "使用済み"
	return "タップで発動!"


func _draw_funds() -> void:
	var rect := Rect2(0.0, 0.0, size.x, FUNDS_HEIGHT)
	UiDraw.card(self, rect, UiPalette.PAPER)
	var coin := Vector2(PAD + COIN_RADIUS, FUNDS_HEIGHT / 2.0)
	UiDraw.coin(self, coin, COIN_RADIUS)
	var label_x := coin.x + COIN_RADIUS + PAD * 0.5
	var label_base := UiDraw.baseline_in(rect, UiPalette.FONT_BODY)
	UiDraw.text(self, Vector2(label_x, label_base), "資金", UiPalette.FONT_BODY, UiPalette.INK_SOFT)
	var cheapest := INF
	for product in db().sorted_products():
		cheapest = minf(cheapest, match_state.lot_cost(store_index, product.id))
	var color := UiPalette.BAD if store().funds < cheapest else UiPalette.INK
	var funds := UiDraw.yen(store().funds)
	var pos := Vector2(PAD, UiDraw.baseline_in(rect, FUNDS_FONT))
	UiDraw.text(
		self, pos, funds, FUNDS_FONT, color, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - PAD * 2.0
	)
