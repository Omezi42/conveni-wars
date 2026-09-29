class_name TitleScreen
extends Control
## タイトル(GameDesign.md 9.1節)。

const NEXT_SCENE := "res://scenes/manager_select.tscn"
const TITLE_Y := 200.0
const SUBTITLE_Y := 270.0
const RULES_Y := 340.0
const RULE_LINE := 30.0
const BUTTON_SIZE := Vector2(280, 72)
const BUTTON_Y := 540.0
const RULES: Array[String] = [
	"向かい合った2軒のコンビニで、同じ客を取り合う。1試合5分。",
	"次に来る客層を読んで先に発注し、棚に並べ、値段で出し抜く。",
	"売上の多いほうが勝ち。",
]


func _ready() -> void:
	var start := UiDraw.make_button("はじめる", UiPalette.STORE_COLORS[0], UiPalette.FONT_HEAD)
	add_child(start)
	start.size = BUTTON_SIZE
	start.position = Vector2((size.x - BUTTON_SIZE.x) / 2.0, BUTTON_Y)
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.BACKGROUND)
	var width := size.x
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var title_pos := Vector2(0, TITLE_Y)
	UiDraw.text(self, title_pos, "コンビニウォーズ", UiPalette.FONT_TITLE, UiPalette.INK, center, width)
	var subtitle := "CPUの店長と、1日の売上で勝負!"
	var subtitle_pos := Vector2(0, SUBTITLE_Y)
	UiDraw.text(
		self, subtitle_pos, subtitle, UiPalette.FONT_HEAD, UiPalette.INK_SOFT, center, width
	)
	for i in RULES.size():
		var pos := Vector2(0, RULES_Y + RULE_LINE * i)
		UiDraw.text(self, pos, RULES[i], UiPalette.FONT_LARGE, UiPalette.INK, center, width)
