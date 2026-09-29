class_name TitleScreen
extends Control
## タイトル(GameDesign.md 9.1節)。素材の出典もここに出す(9.6節)。

const NEXT_SCENE := "res://scenes/manager_select.tscn"
const TITLE_Y := 200.0
const TITLE_OUTLINE := 14
const SUBTITLE_Y := 262.0
const RULES_RECT := Rect2(260, 300, 760, 150)
const RULES_TOP := 44.0
const RULE_LINE := 36.0
const BUTTON_SIZE := Vector2(300, 72)
const BUTTON_Y := 500.0
const CREDIT_Y := 704.0
const CREDIT := "アイコン: Twemoji (Twitter, Inc and other contributors / CC-BY 4.0)"
const RULES: Array[String] = [
	"向かい合った2軒のコンビニで、同じ客を取り合う。1試合5分。",
	"次に来る客層を読んで先に発注し、棚に並べ、値段で出し抜く。",
	"売上の多いほうが勝ち。",
]


func _ready() -> void:
	var start := UiDraw.make_button(
		"はじめる", UiPalette.ACCENT, UiPalette.FONT_HEAD, UiPalette.ACCENT_INK
	)
	add_child(start)
	start.size = BUTTON_SIZE
	start.position = Vector2((size.x - BUTTON_SIZE.x) / 2.0, BUTTON_Y)
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))


func _draw() -> void:
	UiDraw.backdrop(self, Rect2(Vector2.ZERO, size), UiPalette.SCRIM)
	var width := size.x
	var center := HORIZONTAL_ALIGNMENT_CENTER
	var title := "コンビニウォーズ"
	var title_size := UiPalette.FONT_TITLE
	var title_x := (width - UiDraw.text_width(title, title_size)) / 2.0
	UiDraw.text_outlined(
		self,
		Vector2(title_x, TITLE_Y),
		title,
		title_size,
		UiPalette.ACCENT,
		TITLE_OUTLINE,
		UiPalette.BAR
	)
	var subtitle := "CPUの店長と、1日の売上で勝負!"
	UiDraw.text(
		self, Vector2(0, SUBTITLE_Y), subtitle, UiPalette.FONT_HEAD, UiPalette.INK, center, width
	)
	UiDraw.glass_panel(self, RULES_RECT)
	for i in RULES.size():
		var pos := Vector2(RULES_RECT.position.x, RULES_RECT.position.y + RULES_TOP + RULE_LINE * i)
		UiDraw.text(
			self, pos, RULES[i], UiPalette.FONT_LARGE, UiPalette.INK, center, RULES_RECT.size.x
		)
	UiDraw.text(
		self, Vector2(0, CREDIT_Y), CREDIT, UiPalette.FONT_SMALL, UiPalette.INK_SOFT, center, width
	)
