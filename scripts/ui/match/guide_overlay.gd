class_name GuideOverlay
extends Control
## 初回ガイド(GameDesign.md 9.7節)。暗幕に、指す部品の穴を開けて明るく残し、説明の札と「次へ」「とばす」を出す。
## 暗幕は操作を止めない(マウスを下へ通す)。出ている間は MatchController が開店準備の時計を止める。

signal finished


## 手順ごとの説明・指す部品の矩形(画面座標)・札の位置
class Step:
	extends RefCounted
	var text: String
	var holes: Array[Rect2]
	var card_position: Vector2

	func _init(body: String, rects: Array[Rect2], at: Vector2) -> void:
		text = body
		holes = rects
		card_position = at


const DIM := Color(0, 0, 0, 0.55)
const CARD_SIZE := Vector2(420, 190)
const PAD := 20.0
const HEADER_Y := 34.0
const BODY_Y := 50.0
const BODY_LINES := 4
const BUTTON_SIZE := Vector2(140, 48)
const RING := 4.0
const RING_PULSE_SPEED := 4.0
const RING_MIN_ALPHA := 0.4

var _steps: Array[Step] = []
var _index := 0
var _next: PopButton
var _skip: PopButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip = PopButton.create("とばす", UiPalette.PAPER, UiPalette.INK, UiPalette.FONT_BODY)
	_next = PopButton.create("次へ", UiPalette.MONEY, UiPalette.INK, UiPalette.FONT_LARGE)
	for button in [_skip, _next]:
		add_child(button)
		button.size = BUTTON_SIZE
	_skip.pressed.connect(_finish)
	_next.pressed.connect(_advance)
	_show_step()


func add_step(text: String, holes: Array[Rect2], card_position: Vector2) -> void:
	_steps.append(Step.new(text, holes, card_position))


func _card_rect() -> Rect2:
	return Rect2(_steps[_index].card_position, CARD_SIZE)


func _show_step() -> void:
	if _steps.is_empty():
		return
	var card := _card_rect()
	var bottom := card.end.y - PAD - BUTTON_SIZE.y
	_skip.position = Vector2(card.position.x + PAD, bottom)
	_next.position = Vector2(card.end.x - PAD - BUTTON_SIZE.x, bottom)
	_next.text = "開店!" if _index == _steps.size() - 1 else "次へ"
	queue_redraw()


func _advance() -> void:
	if _index >= _steps.size() - 1:
		_finish()
		return
	_index += 1
	_show_step()


func _finish() -> void:
	finished.emit()
	queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _steps.is_empty():
		return
	var step := _steps[_index]
	_draw_dim(step.holes)
	var ring := UiPalette.MONEY
	var wave := (sin(Time.get_ticks_msec() / 1000.0 * RING_PULSE_SPEED) + 1.0) * 0.5
	ring.a = lerpf(RING_MIN_ALPHA, 1.0, wave)
	for hole in step.holes:
		draw_rect(hole.grow(RING * 0.5), ring, false, RING)
	var card := _card_rect()
	UiDraw.card(self, card, UiPalette.PAPER)
	var header := "遊び方 %d/%d" % [_index + 1, _steps.size()]
	UiDraw.text(
		self,
		card.position + Vector2(PAD, HEADER_Y),
		header,
		UiPalette.FONT_SMALL,
		UiPalette.INK_SOFT
	)
	var font := UiDraw.font()
	var font_size := UiPalette.FONT_BODY
	var top := card.position + Vector2(PAD, BODY_Y + font.get_ascent(font_size))
	draw_multiline_string(
		font,
		top,
		step.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		card.size.x - PAD * 2.0,
		font_size,
		BODY_LINES,
		UiPalette.INK
	)


## 穴を除いた部分を暗くする。穴の辺で画面を格子に切り、穴に入らない升だけを塗る
func _draw_dim(holes: Array[Rect2]) -> void:
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for hole in holes:
		xs.append_array([hole.position.x, hole.end.x])
		ys.append_array([hole.position.y, hole.end.y])
	xs.sort()
	ys.sort()
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var cell := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var center := cell.get_center()
			if holes.any(func(hole: Rect2) -> bool: return hole.has_point(center)):
				continue
			draw_rect(cell, DIM)
