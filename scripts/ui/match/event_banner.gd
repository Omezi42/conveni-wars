class_name EventBanner
extends MatchPart
## 突発イベントの予告と発生中の帯(GameDesign.md 11章・9.2節)。予告も発生もないときは何も描かない。

const MEGAPHONE := preload("res://assets/icons/ui/megaphone.svg")
const PAD := 10.0
const ICON_RADIUS := 20.0
const TITLE_BASELINE := 26.0
const INFO_BASELINE := 52.0
const CUSTOMER_RADIUS := 10.0
const CHIP_HEIGHT := 20.0
const CHIP_PAD := 6.0
const BLINK_EDGE := 3
const BLINK_MIN_ALPHA := 0.3
const FILL := Color(0.35, 0.2, 0.02, 0.92)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if match_state == null:
		return
	var active := match_state.events.active_event
	var announced := match_state.announced_event(store_index)
	if active == null and announced == null:
		return
	var event := active if active != null else announced
	var rect := Rect2(Vector2.ZERO, size)
	var edge := UiPalette.ACCENT
	edge.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink())
	UiDraw.panel(self, rect, FILL, edge, BLINK_EDGE, UiPalette.PANEL_RADIUS)
	var icon := Vector2(PAD + ICON_RADIUS, size.y / 2.0)
	UiDraw.texture_at(self, MEGAPHONE, icon, ICON_RADIUS)
	var text_x := icon.x + ICON_RADIUS + PAD
	var title: String
	if active != null:
		var counts := match_state.events.active_counts
		title = "%s 発生中! 自店%d 相手%d" % [event.display_name, counts[0], counts[1]]
	else:
		var seconds := int(ceil(match_state.seconds_until_event()))
		title = "突発イベント %s あと%d秒" % [event.display_name, seconds]
	UiDraw.text(
		self, Vector2(text_x, TITLE_BASELINE), title, UiPalette.FONT_LARGE, UiPalette.ACCENT
	)
	var customer := db().customer_type(event.customer_type_id)
	var customer_center := Vector2(text_x + CUSTOMER_RADIUS, INFO_BASELINE - CUSTOMER_RADIUS + 3.0)
	UiDraw.customer_icon(self, customer_center, CUSTOMER_RADIUS, customer)
	var balance := match_state.balance
	var info := (
		"%s×%d 買う数%d倍"
		% [customer.display_name, balance.event_customer_count, balance.event_buy_multiplier]
	)
	var info_x := customer_center.x + CUSTOMER_RADIUS + 4.0
	UiDraw.text(self, Vector2(info_x, INFO_BASELINE), info, UiPalette.FONT_SMALL, UiPalette.INK)
	var chip_x := info_x + UiDraw.text_width(info, UiPalette.FONT_SMALL) + CHIP_PAD
	for category_id in customer.sorted_wants():
		var category := db().category(category_id)
		var label := category.display_name
		var width := UiDraw.text_width(label, UiPalette.FONT_SMALL) + CHIP_PAD * 2.0
		var chip := Rect2(chip_x, INFO_BASELINE - CHIP_HEIGHT + 5.0, width, CHIP_HEIGHT)
		UiDraw.panel(self, chip, category.color)
		UiDraw.text_centered(self, chip, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK)
		chip_x += width + CHIP_PAD
