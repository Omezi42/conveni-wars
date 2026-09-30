class_name SettingsPanel
extends Control
## タイトルに重ねる設定の札(GameDesign.md 9.7節)。BGMと効果音の音量(10%きざみ)と全画面の切り替え。
## 変えたらすぐに保存して音量へ反映する。

const CARD_SIZE := Vector2(460, 330)
const PAD := 28.0
const TITLE_Y := 50.0
const ROW_Y := 96.0
const ROW_GAP := 74.0
const STEP_BUTTON := Vector2(56, 52)
const VALUE_WIDTH := 110.0
const WIDE_BUTTON := Vector2(190, 56)
const VOLUME_STEP := 0.1
const DIM := Color(0, 0, 0, 0.45)
const ROWS: Array[String] = ["BGM", "効果音"]

var _values: Array[float] = [0.0, 0.0]
var _fullscreen: PopButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var save: SaveData = GameSession.save
	_values = [save.bgm_volume, save.se_volume]
	var card := _card_rect()
	for i in ROWS.size():
		var y := card.position.y + ROW_Y + ROW_GAP * i
		var right := card.end.x - PAD
		var plus_x := right - STEP_BUTTON.x
		var minus_x := plus_x - VALUE_WIDTH - STEP_BUTTON.x
		_add_button("−", Rect2(minus_x, y, STEP_BUTTON.x, STEP_BUTTON.y), _change.bind(i, -1))
		_add_button("+", Rect2(plus_x, y, STEP_BUTTON.x, STEP_BUTTON.y), _change.bind(i, 1))
	var bottom := card.end.y - PAD - WIDE_BUTTON.y
	_fullscreen = _add_button(
		"全画面", Rect2(Vector2(card.position.x + PAD, bottom), WIDE_BUTTON), _toggle_fullscreen
	)
	_fullscreen.chosen = _is_fullscreen()
	var close := _add_button(
		"とじる", Rect2(Vector2(card.end.x - PAD - WIDE_BUTTON.x, bottom), WIDE_BUTTON), queue_free
	)
	close.fill = UiPalette.MONEY


func _card_rect() -> Rect2:
	return Rect2((size - CARD_SIZE) / 2.0, CARD_SIZE)


func _add_button(label: String, rect: Rect2, action: Callable) -> PopButton:
	var button := PopButton.create(label, UiPalette.PAPER)
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(action)
	return button


func _change(index: int, direction: int) -> void:
	_values[index] = clampf(snappedf(_values[index] + VOLUME_STEP * direction, VOLUME_STEP), 0, 1)
	var save: SaveData = GameSession.save
	save.bgm_volume = _values[0]
	save.se_volume = _values[1]
	save.save_file()
	AudioDirector.apply_volumes(save.bgm_volume, save.se_volume)
	queue_redraw()


func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN
	if _is_fullscreen():
		mode = DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	_fullscreen.chosen = _is_fullscreen()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var card := _card_rect()
	UiDraw.card(self, card, UiPalette.PAPER)
	var title := Vector2(card.position.x, card.position.y + TITLE_Y)
	UiDraw.text(
		self,
		title,
		"設定",
		UiPalette.FONT_HEAD,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		card.size.x
	)
	for i in ROWS.size():
		var row := Rect2(
			card.position.x + PAD,
			card.position.y + ROW_Y + ROW_GAP * i,
			card.size.x - PAD * 2.0,
			STEP_BUTTON.y
		)
		var base := UiDraw.baseline_in(row, UiPalette.FONT_LARGE)
		UiDraw.text(
			self, Vector2(row.position.x, base), ROWS[i], UiPalette.FONT_LARGE, UiPalette.INK
		)
		var value_x := row.end.x - STEP_BUTTON.x - VALUE_WIDTH
		UiDraw.text(
			self,
			Vector2(value_x, base),
			"%d%%" % roundi(_values[i] * 100.0),
			UiPalette.FONT_LARGE,
			UiPalette.INK,
			HORIZONTAL_ALIGNMENT_CENTER,
			VALUE_WIDTH
		)
