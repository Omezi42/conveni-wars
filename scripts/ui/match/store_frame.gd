class_name StoreFrame
extends MatchPart
## 棚の枠(店の色の見出しと店長の名前)。棚はこの上に重ねる。

const HEADER_HEIGHT := 28.0
const PAD := 10.0
const HEADER_DARKEN := 0.1
const TEXT_BASELINE := 0.72
const SHELF_TITLES: Array[String] = ["わたしの棚", "相手の棚"]


func _draw() -> void:
	if match_state == null:
		return
	var color := UiPalette.STORE_COLORS[store_index]
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size), color.lightened(0.2))
	var header := Rect2(Vector2(2, 2), Vector2(size.x - 4.0, HEADER_HEIGHT))
	UiDraw.panel(
		self,
		header,
		color.darkened(HEADER_DARKEN),
		Color.TRANSPARENT,
		0,
		UiPalette.PANEL_RADIUS - 2
	)
	var name := "%s 店長:%s" % [SHELF_TITLES[store_index], store().manager.display_name]
	var baseline := 2.0 + HEADER_HEIGHT * TEXT_BASELINE
	UiDraw.text(self, Vector2(PAD, baseline), name, UiPalette.FONT_BODY, UiPalette.INK_ON_DARK)
