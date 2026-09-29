class_name BonusBoard
extends MatchPart
## 自店の棚の横の、成立しているボーナスの一覧と、ボーナスの見方(GameDesign.md 4.2節・9.2節)。
## 一覧の札と見方の色は、棚のマスの枠の色と同じにする。

const TAB_POS := Vector2.ZERO
const LIST_TOP := 36.0
const CHIP_HEIGHT := 26.0
const CHIP_GAP := 6.0
const LEGEND_ROW := 40.0
const LEGEND_SWATCH := 16.0
const LEGEND_TEXT_X := 22.0
const LEGEND_TITLE_Y := 13.0
const LEGEND_NOTE_Y := 30.0
const LEGEND_RULE_GAP := 8.0
const EMPTY_INK := Color(0.36, 0.4, 0.51, 0.7)
## 見方の2行目(ShelfBonus.Kind の順)
const KIND_NOTES: Array[String] = ["中央のマス", "縦1列が同じ種類", "隣り合う組み合わせ"]


func _draw() -> void:
	if match_state == null:
		return
	UiDraw.tab(self, TAB_POS, "ボーナス")
	var legend_top := size.y - LEGEND_ROW * KIND_NOTES.size()
	_draw_list(legend_top - LEGEND_RULE_GAP)
	_draw_legend(legend_top)


## 成立しているボーナスを上から札で並べる。入りきらないぶんは出さない
func _draw_list(bottom: float) -> void:
	var bonuses := store().shelf_bonus().bonuses
	var y := LIST_TOP
	if bonuses.is_empty():
		var rect := Rect2(0, y, size.x, CHIP_HEIGHT)
		UiDraw.text_centered(self, rect, "なし", UiPalette.FONT_SMALL, EMPTY_INK)
		return
	var radius := int(CHIP_HEIGHT * 0.5)
	for bonus in bonuses:
		if y + CHIP_HEIGHT > bottom:
			return
		var chip := Rect2(0, y, size.x, CHIP_HEIGHT)
		var fill := UiPalette.BONUS_COLORS[bonus.kind]
		UiDraw.panel(self, chip, fill, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
		var label_rect := chip.grow_individual(-radius * 0.5, 0, -radius * 0.5, 0)
		var white := UiPalette.INK_ON_DARK
		UiDraw.text_centered(
			self, label_rect, bonus.display_name, UiPalette.FONT_SMALL, white, UiPalette.INK
		)
		y += CHIP_HEIGHT + CHIP_GAP


## 種類ごとの色・名前・倍率・条件
func _draw_legend(top: float) -> void:
	var balance := match_state.balance
	var multipliers := [
		balance.center_multiplier, balance.corner_multiplier, balance.combo_multiplier
	]
	draw_line(
		Vector2(0, top - LEGEND_RULE_GAP * 0.5),
		Vector2(size.x, top - LEGEND_RULE_GAP * 0.5),
		UiPalette.PAPER_DIM,
		UiPalette.OUTLINE_THIN
	)
	for kind in KIND_NOTES.size():
		var y := top + LEGEND_ROW * kind
		var swatch := Rect2(0, y, LEGEND_SWATCH, LEGEND_SWATCH)
		UiDraw.panel(
			self,
			swatch,
			UiPalette.SLOT,
			UiPalette.BONUS_COLORS[kind],
			UiPalette.OUTLINE,
			UiPalette.RADIUS_SMALL - 3
		)
		var title := "%s ×%.1f" % [ShelfBonus.KIND_LABELS[kind], multipliers[kind]]
		UiDraw.text(
			self,
			Vector2(LEGEND_TEXT_X, y + LEGEND_TITLE_Y),
			title,
			UiPalette.FONT_SMALL,
			UiPalette.INK
		)
		var note := KIND_NOTES[kind]
		var note_size := UiDraw.fit_size(note, UiPalette.FONT_TINY, size.x)
		UiDraw.text(self, Vector2(0, y + LEGEND_NOTE_Y), note, note_size, UiPalette.INK_SOFT)
