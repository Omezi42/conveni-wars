class_name PopButton
extends BaseButton
## 輪郭線とずらした影を持つボタン(GameDesign.md 9.5節)。押している間は影の位置まで沈む。
## caption を入れると本文の上に小さな1行を添える。

const HOVER_LIGHTEN := 0.12
const DISABLED_FADE := 0.55
const DISABLED_GRAY := Color("#b7b4ad")
const CAPTION_GAP := 2.0
## 選ばれている印(右上の丸い札の中のチェック。フォントに ✓ が無いため線で描く)
const CHECK_RADIUS := 10.0
const CHECK_INSET := 4.0
## チェックの折れ線(半径に対する割合)
const CHECK_POINTS: Array[Vector2] = [Vector2(-0.5, 0.0), Vector2(-0.12, 0.38), Vector2(0.5, -0.35)]
const CHECK_WIDTH := 2.5

var text := "":
	set(value):
		text = value
		queue_redraw()
var caption := "":
	set(value):
		caption = value
		queue_redraw()
var fill := UiPalette.PAPER:
	set(value):
		fill = value
		queue_redraw()
var ink := UiPalette.INK
var font_size := UiPalette.FONT_LARGE
var caption_size := UiPalette.FONT_SMALL
var radius := UiPalette.RADIUS
## 選ばれている(押せないが沈んで、印を付けて見せる)
var chosen := false:
	set(value):
		chosen = value
		queue_redraw()


static func create(
	label: String, face: Color, label_ink := UiPalette.INK, size := UiPalette.FONT_LARGE
) -> PopButton:
	var button := PopButton.new()
	button.text = label
	button.fill = face
	button.ink = label_ink
	button.font_size = size
	return button


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(func() -> void: AudioDirector.play_se(&"click"))


func _draw() -> void:
	var drop := UiPalette.SHADOW_DROP
	var face := Rect2(Vector2.ZERO, Vector2(size.x, size.y - drop))
	var mode := get_draw_mode()
	var sunk := chosen or mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var color := fill
	var label_ink := ink
	if mode == DRAW_HOVER and not disabled:
		color = color.lightened(HOVER_LIGHTEN)
	if disabled and not chosen:
		color = color.lerp(DISABLED_GRAY, DISABLED_FADE)
		label_ink.a = DISABLED_FADE
	if sunk:
		face.position.y += drop
	else:
		var shadow := Rect2(Vector2(0, drop), face.size)
		UiDraw.panel(self, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(self, face, color, UiPalette.INK, UiPalette.OUTLINE, radius)
	_draw_label(face, label_ink)
	if chosen:
		_draw_check(face)


func _draw_label(face: Rect2, label_ink: Color) -> void:
	if caption.is_empty():
		UiDraw.text_centered(self, face, text, font_size, label_ink)
		return
	var f := UiDraw.font()
	var caption_height := f.get_height(caption_size)
	var body_height := f.get_height(font_size)
	var top := face.position.y + (face.size.y - caption_height - body_height - CAPTION_GAP) / 2.0
	var caption_rect := Rect2(face.position.x, top, face.size.x, caption_height)
	UiDraw.text_centered(self, caption_rect, caption, caption_size, label_ink)
	var body_top := top + caption_height + CAPTION_GAP
	var body_rect := Rect2(face.position.x, body_top, face.size.x, body_height)
	UiDraw.text_centered(self, body_rect, text, font_size, label_ink)


func _draw_check(face: Rect2) -> void:
	var center := Vector2(face.end.x - CHECK_INSET, face.position.y + CHECK_INSET)
	draw_circle(center, CHECK_RADIUS + UiPalette.OUTLINE_THIN, UiPalette.INK)
	draw_circle(center, CHECK_RADIUS, UiPalette.GOOD)
	var points := PackedVector2Array()
	for point in CHECK_POINTS:
		points.append(center + point * CHECK_RADIUS)
	draw_polyline(points, UiPalette.INK_ON_DARK, CHECK_WIDTH, true)
