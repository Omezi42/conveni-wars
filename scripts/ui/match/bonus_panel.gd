class_name BonusPanel
extends MatchPart
## 棚のボーナスのパネル(GameDesign.md 4.2節・9.2節)。目玉・コーナー・セットの3種類を常に出し、
## 成立しているものを光らせて名前を出す。

const PAD := 10.0
const TITLE_BASELINE := 20.0
const ROW_TOP := 30.0
const ROW_GAP := 4.0
const CHIP_WIDTH := 64.0
const CHIP_PAD := 6.0
const TEXT_BASELINE := 0.66
const DIM_ALPHA := 0.35
const HINTS: Array[String] = ["中央のマスの商品が強くなる", "縦1列を同じカテゴリで揃える", "隣り合う2マスを決まった組み合わせに"]


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.glass_panel(self, Rect2(Vector2.ZERO, size))
	UiDraw.panel_title(self, Vector2(PAD, TITLE_BASELINE), "棚のボーナス")
	var bonus := store().shelf_bonus()
	var kinds := ShelfBonus.KIND_LABELS.size()
	var height := (size.y - ROW_TOP - PAD - ROW_GAP * (kinds - 1)) / kinds
	for kind in kinds:
		var rect := Rect2(PAD, ROW_TOP + kind * (height + ROW_GAP), size.x - PAD * 2.0, height)
		_draw_row(rect, kind, _names_of(bonus, kind))


func _draw_row(rect: Rect2, kind: int, names: Array[String]) -> void:
	var active := not names.is_empty()
	var color := UiPalette.BONUS_COLORS[kind]
	var fill := UiPalette.PANEL_INNER
	if active:
		fill = color
		fill.a = DIM_ALPHA
	UiDraw.panel(self, rect, fill, color if active else Color.TRANSPARENT, 2 if active else 0)
	var chip := Rect2(
		rect.position + Vector2(CHIP_PAD, CHIP_PAD),
		Vector2(CHIP_WIDTH, rect.size.y - CHIP_PAD * 2.0)
	)
	var chip_fill := color
	if not active:
		chip_fill.a = DIM_ALPHA
	UiDraw.panel(self, chip, chip_fill)
	UiDraw.text_centered(
		self, chip, ShelfBonus.KIND_LABELS[kind], UiPalette.FONT_BODY, UiPalette.INK_ON_DARK
	)
	var text_x := chip.end.x + CHIP_PAD * 1.5
	var baseline := rect.position.y + rect.size.y * TEXT_BASELINE
	var width := rect.end.x - text_x - CHIP_PAD
	var label := HINTS[kind]
	# 目玉は名前が種類と同じなので、成立していても説明を出す
	if active and names != [ShelfBonus.KIND_LABELS[kind]]:
		label = " / ".join(names)
	var ink := UiPalette.INK if active else UiPalette.INK_SOFT
	UiDraw.text(
		self,
		Vector2(text_x, baseline),
		label,
		UiPalette.FONT_SMALL,
		ink,
		HORIZONTAL_ALIGNMENT_LEFT,
		width
	)


## 成立している同じ種類のボーナスの名前(重複は1つに)
static func _names_of(bonus: ShelfBonus.Result, kind: int) -> Array[String]:
	var names: Array[String] = []
	for item in bonus.bonuses:
		if item.kind == kind and not names.has(item.display_name):
			names.append(item.display_name)
	return names
