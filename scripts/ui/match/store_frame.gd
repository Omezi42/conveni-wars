class_name StoreFrame
extends MatchPart
## 店の建物(看板・店長の名前・通りに面した入口)。棚はこの上に重ねる。

const HEADER_HEIGHT := 32.0
const PAD := 10.0
const DOOR_SIZE := Vector2(10, 64)
const HEADER_RADIUS := 8
const DOOR_RADIUS := 2
const DOOR_LIGHTEN := 0.3
const TEXT_BASELINE := 0.7

## 入口の縦の位置(この部品の中の座標)
var door_y := 0.0
## 入口が右側にあるか(自店は右、相手は左)
var door_on_right := true


func _draw() -> void:
	if match_state == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	UiDraw.shadowed_panel(self, rect, UiPalette.PANEL)
	var color := UiPalette.STORE_COLORS[store_index]
	var header := Rect2(Vector2.ZERO, Vector2(size.x, HEADER_HEIGHT))
	UiDraw.panel(self, header, color, Color.TRANSPARENT, 0, HEADER_RADIUS)
	var name := "%s 店長:%s" % [UiPalette.STORE_NAMES[store_index], store().manager.display_name]
	var baseline := HEADER_HEIGHT * TEXT_BASELINE
	UiDraw.text(self, Vector2(PAD, baseline), name, UiPalette.FONT_BODY, UiPalette.INK_ON_DARK)
	var x := size.x - DOOR_SIZE.x if door_on_right else 0.0
	var door := Rect2(Vector2(x, door_y - DOOR_SIZE.y / 2.0), DOOR_SIZE)
	UiDraw.panel(self, door, color.lightened(DOOR_LIGHTEN), Color.TRANSPARENT, 0, DOOR_RADIUS)


func door_global() -> Vector2:
	var x := size.x if door_on_right else 0.0
	return global_position + Vector2(x, door_y)
