class_name BonusHelp
extends MatchPart
## 自店の看板の「?」と、ボーナスの見方(GameDesign.md 4.2節・9.2節)。
## カーソルを乗せるか押すと、棚の上に見方を重ねて出す(もう一度押すと消える)。

const MARK_FONT := 20
const LEGEND_PAD := 14.0
const ROW_HEIGHT := 46.0
const SWATCH := 26.0
const TEXT_X := 40.0
const TITLE_Y := 18.0
const NOTE_Y := 38.0
const TITLE_GAP := 34.0
## 見方の2行目(ShelfBonus.Kind の順)
const KIND_NOTES: Array[String] = ["中央のマスに置いた商品", "縦1列の3マスが同じ種類", "隣り合うマスがセットの組み合わせ"]

## 見方を出す矩形(この部品の中の座標)
var legend_rect := Rect2()

var _hover := false
var _pinned := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_pinned = not _pinned
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false


func _draw() -> void:
	if match_state == null:
		return
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - UiPalette.OUTLINE_THIN
	var open := _hover or _pinned
	draw_circle(center, radius + UiPalette.OUTLINE_THIN, UiPalette.INK)
	draw_circle(center, radius, UiPalette.MONEY if open else UiPalette.INK_ON_DARK)
	UiDraw.text_centered(self, Rect2(Vector2.ZERO, size), "?", MARK_FONT, UiPalette.INK)
	if open:
		_draw_legend()


func _draw_legend() -> void:
	UiDraw.card(self, legend_rect, UiPalette.PAPER)
	var balance := match_state.balance
	var multipliers := [
		balance.center_multiplier, balance.corner_multiplier, balance.combo_multiplier
	]
	var x := legend_rect.position.x + LEGEND_PAD
	var title_pos := Vector2(x, legend_rect.position.y + LEGEND_PAD + TITLE_Y)
	UiDraw.text(self, title_pos, "ボーナス(売れやすさが上がる)", UiPalette.FONT_LARGE, UiPalette.INK)
	var top := legend_rect.position.y + LEGEND_PAD + TITLE_GAP
	for kind in KIND_NOTES.size():
		var y := top + ROW_HEIGHT * kind
		var swatch := Rect2(x, y + (ROW_HEIGHT - SWATCH) * 0.5, SWATCH, SWATCH)
		UiDraw.panel(
			self,
			swatch,
			UiPalette.SLOT,
			UiPalette.BONUS_COLORS[kind],
			UiPalette.OUTLINE + 1,
			UiPalette.RADIUS_SMALL
		)
		var title := "%s ×%.1f" % [ShelfBonus.KIND_LABELS[kind], multipliers[kind]]
		var text_x := x + TEXT_X
		UiDraw.text(self, Vector2(text_x, y + TITLE_Y), title, UiPalette.FONT_BODY, UiPalette.INK)
		UiDraw.text(
			self,
			Vector2(text_x, y + NOTE_Y),
			KIND_NOTES[kind],
			UiPalette.FONT_SMALL,
			UiPalette.INK_SOFT
		)
