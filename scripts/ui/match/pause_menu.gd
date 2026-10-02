class_name PauseMenu
extends Control
## 一時停止(GameDesign.md 9.9節)。画面全体を暗い幕で覆って棚や予報を隠し、「続ける」「やり直す」「タイトルへ」を出す。
## 開いている間は MatchController が試合とCPUを進めない。

signal resumed
signal restart_requested
signal quit_requested

const CURTAIN := Color(0.07, 0.08, 0.2, 0.92)
const HEADER_Y := 230.0
const BUTTON_SIZE := Vector2(300, 66)
const BUTTON_TOP := 290.0
const BUTTON_GAP := 20.0
## ボタンの2本線の幅と高さ・あいだ・角の丸み(ボタンの面の高さに対する割合)
const BAR_SIZE := Vector2(0.14, 0.44)
const BAR_GAP := 0.11
const BAR_RADIUS := 0.04

var _buttons: Array[PopButton] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var resume := PopButton.create("続ける", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_HEAD)
	var restart := PopButton.create("やり直す", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD)
	var quit := PopButton.create("タイトルへ", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_HEAD)
	_buttons = [resume, restart, quit]
	for button in _buttons:
		add_child(button)
		button.size = BUTTON_SIZE
	resized.connect(_layout)
	_layout()
	resume.pressed.connect(close)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	quit.pressed.connect(func() -> void: quit_requested.emit())
	hide()


func _layout() -> void:
	for i in _buttons.size():
		_buttons[i].position = Vector2(
			(size.x - BUTTON_SIZE.x) / 2.0, BUTTON_TOP + i * (BUTTON_SIZE.y + BUTTON_GAP)
		)


func open() -> void:
	show()


func close() -> void:
	if not visible:
		return
	hide()
	resumed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CURTAIN)
	UiDraw.text_outlined(
		self,
		Vector2(0, HEADER_Y),
		"一時停止中",
		UiPalette.FONT_TITLE,
		UiPalette.INK_ON_DARK,
		UiPalette.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x
	)


## 上端の右端に置く一時停止のボタン(縦の2本線。フォントに無い記号は形で描く)
static func create_button() -> PopButton:
	var button := PopButton.create("", UiPalette.PAPER)
	button.draw.connect(_draw_bars.bind(button))
	return button


static func _draw_bars(button: PopButton) -> void:
	var face_height := button.size.y - UiPalette.SHADOW_DROP
	var mode := button.get_draw_mode()
	var sunk := mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var center := Vector2(button.size.x / 2.0, face_height / 2.0)
	if sunk:
		center.y += UiPalette.SHADOW_DROP
	var bar := BAR_SIZE * face_height
	var offset := (BAR_GAP * face_height + bar.x) / 2.0
	for side: float in [-1.0, 1.0]:
		var rect := Rect2(center + Vector2(side * offset, 0.0) - bar / 2.0, bar)
		var corner := int(BAR_RADIUS * face_height)
		UiDraw.panel(button, rect, UiPalette.INK, Color.TRANSPARENT, 0, corner)
