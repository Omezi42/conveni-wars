class_name StoreFrame
extends MatchPart
## 店の建物(GameDesign.md 9.5節)。店の色の看板と帯・明るい店内の床・通りに面したガラスの入口。
## 棚はこの上に重ねる。compact は相手の店(小さく描く)。

const SIGN_HEIGHT := 40.0
const COMPACT_SIGN_HEIGHT := 28.0
const STRIPE_ACCENT := 6.0
const STRIPE_WHITE := 3.0
const COMPACT_STRIPE_ACCENT := 4.0
const COMPACT_STRIPE_WHITE := 2.0
const PAD := 12.0
const NAME_GAP := 10.0
const DOOR_SIZE := Vector2(10, 70)
const COMPACT_DOOR_SIZE := Vector2(8, 52)
const DOOR_RADIUS := 3
const DOOR_FRAME_GAP := 3.0

## 入口の縦の位置(この部品の中の座標)
var door_y := 0.0
## 入口が右側にあるか(自店は右、相手は左)
var door_on_right := true
## 相手の店として小さく描くか
var compact := false

## 看板の地(上の角だけ丸い)
var _sign_box: StyleBoxFlat


func _draw() -> void:
	if match_state == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	UiDraw.card(self, rect, UiPalette.FLOOR)
	var color := UiPalette.STORE_COLORS[store_index]
	var sign_height := COMPACT_SIGN_HEIGHT if compact else SIGN_HEIGHT
	var accent := COMPACT_STRIPE_ACCENT if compact else STRIPE_ACCENT
	var white := COMPACT_STRIPE_WHITE if compact else STRIPE_WHITE
	var border := float(UiPalette.OUTLINE)
	var inner := size.x - border * 2.0
	var sign_rect := Rect2(border, border, inner, sign_height)
	_sign_style(color).draw(get_canvas_item(), sign_rect)
	var y := sign_rect.end.y
	draw_rect(Rect2(border, y, inner, white), UiPalette.INK_ON_DARK)
	draw_rect(Rect2(border, y + white, inner, accent), UiPalette.STORE_ACCENTS[store_index])
	draw_rect(Rect2(border, y + white + accent, inner, white), UiPalette.INK_ON_DARK)
	draw_line(
		Vector2(border, y + white * 2.0 + accent),
		Vector2(size.x - border, y + white * 2.0 + accent),
		UiPalette.INK,
		UiPalette.OUTLINE_THIN
	)
	UiDraw.panel(self, rect, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE)
	_draw_sign_text(sign_rect)
	_draw_door()


func _sign_style(color: Color) -> StyleBoxFlat:
	if _sign_box == null:
		_sign_box = StyleBoxFlat.new()
		_sign_box.bg_color = color
		_sign_box.anti_aliasing = true
		var corner := UiPalette.RADIUS - UiPalette.OUTLINE
		_sign_box.corner_radius_top_left = corner
		_sign_box.corner_radius_top_right = corner
	return _sign_box


func _draw_sign_text(sign_rect: Rect2) -> void:
	var name := UiPalette.STORE_NAMES[store_index]
	var name_size := UiPalette.FONT_LARGE if compact else UiPalette.FONT_HEAD
	var baseline := UiDraw.baseline_in(sign_rect, name_size)
	var white := UiPalette.INK_ON_DARK
	var x := sign_rect.position.x + PAD
	UiDraw.text_outlined(self, Vector2(x, baseline), name, name_size, white)
	var manager := store().manager.display_name
	var label := manager if compact else "店長 " + manager
	var label_x := x + UiDraw.text_width(name, name_size) + NAME_GAP
	var width := sign_rect.end.x - PAD - label_x
	var label_size := UiDraw.fit_size(label, UiPalette.FONT_BODY, width)
	var label_base := UiDraw.baseline_in(sign_rect, label_size)
	UiDraw.text_outlined(self, Vector2(label_x, label_base), label, label_size, white)


## 通りに面したガラスの入口。夜は明かりがこぼれる(CustomerFlow が通り側を描く)
func _draw_door() -> void:
	var door_size := COMPACT_DOOR_SIZE if compact else DOOR_SIZE
	var x := size.x - door_size.x if door_on_right else 0.0
	var door := Rect2(Vector2(x, door_y - door_size.y / 2.0), door_size)
	UiDraw.panel(
		self, door, UiPalette.DOOR_GLASS, UiPalette.INK, UiPalette.OUTLINE_THIN, DOOR_RADIUS
	)
	var middle := door.get_center().y
	draw_line(
		Vector2(door.position.x + DOOR_FRAME_GAP, middle),
		Vector2(door.end.x - DOOR_FRAME_GAP, middle),
		UiPalette.INK,
		1.0
	)


func door_global() -> Vector2:
	var x := size.x if door_on_right else 0.0
	return global_position + Vector2(x, door_y)
