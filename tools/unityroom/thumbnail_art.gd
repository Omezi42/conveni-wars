extends Control
## unityroom のサムネイル(正方形・ループするGIF)の1コマを描く。t(秒)を変えて描き直すと次のコマになる。
## 夕焼けの空に題字、向かい合う2軒の店と「VS」。横断歩道を渡ってきた客が、欲しい物の吹き出しを出して
## どちらかの店へ入り、店の上に売上の「+¥」が飛び出す。GIFを小さく保つため、背景は動かさない。

const SIDE := 512.0
const LOOP := 4.0
## 題字(2段)
const LOGO_HEAD := "コンビニ"
const LOGO_TAIL := "ウォーズ"
const LOGO_SIZE := 88
const LOGO_BASELINES: Array[float] = [96.0, 186.0]
const LOGO_SHADOW := Vector2(0, 6)
const LOGO_OUTLINE := 18
## 店(左が自店・右が相手。入口は通りの中央を向く)
const STORE_RECTS: Array[Rect2] = [Rect2(-24, 218, 222, 206), Rect2(314, 218, 222, 206)]
const SIGN_HEIGHT := 46.0
const SIGN_TEXT := "24H"
const SIGN_TEXT_SIZE := 32
const STRIPE := Vector2(3, 7)
const WALL := Color("#f4eee2")
const WINDOW_LIGHT := Color("#fff1c9")
const WINDOW_INSET := 14.0
const WINDOW_TOP := 70.0
const DOOR_WIDTH := 58.0
const DOOR_GAP := 10.0
const HANDLE := Vector2(4, 18)
const SHELF_ROWS := 3
const SHELF_LINE := 3.0
const ITEM_SIDE := 30.0
const ITEM_GAP := 5.0
## 両店の窓に並べる商品
const WINDOW_GOODS: Array[StringName] = [
	&"salmon_onigiri",
	&"green_tea",
	&"karaage_bento",
	&"hot_coffee",
	&"melon_pan",
	&"cola",
	&"karaage_stick",
	&"potato_chips",
	&"pudding",
	&"ice_bar",
]
## 中央の「VS」
const VS_CENTER := Vector2(256, 300)
const VS_RADIUS := 36.0
const VS_TEXT_SIZE := 34
const VS_PULSE := 0.08
## 歩道・車道・横断歩道
const SIDEWALK_Y := 424.0
const ROAD_Y := 452.0
const ROAD_DASH := Vector2(34, 6)
const ROAD_LINE_Y := 484.0
const CROSSWALK := Rect2(214, 452, 84, 60)
const CROSSWALK_STRIPE := 12.0
## 客:横断歩道を上がってきて、歩道で店の入口へ曲がる
const WALKERS := [
	{"customer": &"office", "product": &"hot_coffee", "store": 0},
	{"customer": &"student", "product": &"salmon_onigiri", "store": 1},
	{"customer": &"homemaker", "product": &"karaage_bento", "store": 0},
]
const WALKER_RADIUS := 32.0
const WALK_FROM_Y := 560.0
const WALK_Y := 398.0
## 1人の歩みのうち、横断歩道を上がる割合・入口まで歩き終える割合・入口で消える割合
const CROSS_END := 0.42
const ARRIVE := 0.82
const ENTER_END := 0.9
const BOB_HEIGHT := 4.0
const BOB_STEPS := 6.0
const BUBBLE_SIDE := 44.0
const BUBBLE_GAP := 8.0
const BUBBLE_ICON := 34.0
## 売上の飛び出し(入口の上から上がる。中央の「VS」に重ならないよう、入口の外側の端へ揃える)
const POP_SIZE := 30
const POP_RISE := 40.0
const POP_SECONDS := 1.1
const POP_GROW := 0.35
const POP_START_Y := 344.0
const COIN_RADIUS := 13.0
const COIN_GAP := 6.0

var t := 0.0


func _ready() -> void:
	size = Vector2(SIDE, SIDE)


func _draw() -> void:
	UiDraw.gradient_rect(
		self, Rect2(Vector2.ZERO, size), UiPalette.MENU_SKY_TOP, UiPalette.MENU_SKY_BOTTOM
	)
	_draw_ground()
	for i in STORE_RECTS.size():
		_draw_store(i)
	_draw_logo()
	_draw_vs()
	var walkers := WALKERS.size()
	for i in walkers:
		_draw_walker(WALKERS[i], fposmod(t / LOOP - float(i) / walkers, 1.0))
	for i in walkers:
		_draw_pop(WALKERS[i], fposmod(t / LOOP - float(i) / walkers, 1.0))


func _draw_ground() -> void:
	draw_rect(Rect2(0, SIDEWALK_Y, SIDE, ROAD_Y - SIDEWALK_Y), UiPalette.SIDEWALK)
	draw_rect(Rect2(0, ROAD_Y, SIDE, SIDE - ROAD_Y), UiPalette.STREET)
	var x := 0.0
	while x < SIDE:
		if x + ROAD_DASH.x < CROSSWALK.position.x or x > CROSSWALK.end.x:
			draw_rect(
				Rect2(x, ROAD_LINE_Y - ROAD_DASH.y * 0.5, ROAD_DASH.x, ROAD_DASH.y),
				UiPalette.STREET_LINE
			)
		x += ROAD_DASH.x * 2.0
	var stripe_x := CROSSWALK.position.x
	while stripe_x < CROSSWALK.end.x:
		draw_rect(
			Rect2(stripe_x, CROSSWALK.position.y, CROSSWALK_STRIPE, CROSSWALK.size.y),
			UiPalette.STREET_LINE
		)
		stripe_x += CROSSWALK_STRIPE * 2.0
	for y in [SIDEWALK_Y, ROAD_Y]:
		draw_line(Vector2(0, y), Vector2(SIDE, y), UiPalette.INK, UiPalette.OUTLINE)


func _draw_store(index: int) -> void:
	var rect := STORE_RECTS[index]
	UiDraw.card(self, rect, WALL)
	var border := float(UiPalette.OUTLINE)
	var sign_rect := Rect2(
		rect.position + Vector2(border, border), Vector2(rect.size.x - border * 2.0, SIGN_HEIGHT)
	)
	draw_rect(sign_rect, UiPalette.STORE_COLORS[index])
	var y := sign_rect.end.y
	draw_rect(Rect2(sign_rect.position.x, y, sign_rect.size.x, STRIPE.x), UiPalette.INK_ON_DARK)
	draw_rect(
		Rect2(sign_rect.position.x, y + STRIPE.x, sign_rect.size.x, STRIPE.y),
		UiPalette.STORE_ACCENTS[index]
	)
	draw_rect(
		Rect2(sign_rect.position.x, y + STRIPE.x + STRIPE.y, sign_rect.size.x, STRIPE.x),
		UiPalette.INK_ON_DARK
	)
	UiDraw.panel(self, rect, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE)
	UiDraw.text_centered(
		self, sign_rect, SIGN_TEXT, SIGN_TEXT_SIZE, UiPalette.INK_ON_DARK, UiPalette.INK
	)
	var door := _door_rect(index)
	var body := _body_rect(index)
	var window_x := body.position.x if index == 0 else door.end.x + DOOR_GAP
	var window := Rect2(
		window_x, body.position.y, body.size.x - DOOR_WIDTH - DOOR_GAP, body.size.y - WINDOW_INSET
	)
	UiDraw.panel(
		self, window, WINDOW_LIGHT, UiPalette.INK, UiPalette.OUTLINE, UiPalette.RADIUS_SMALL
	)
	_draw_window_goods(window, index)
	UiDraw.panel(
		self, door, UiPalette.DOOR_GLASS, UiPalette.INK, UiPalette.OUTLINE, UiPalette.RADIUS_SMALL
	)
	var handle_x := door.position.x + DOOR_GAP if index == 0 else door.end.x - DOOR_GAP - HANDLE.x
	draw_rect(
		Rect2(handle_x, door.get_center().y - HANDLE.y * 0.5, HANDLE.x, HANDLE.y), UiPalette.INK
	)


func _body_rect(index: int) -> Rect2:
	var rect := STORE_RECTS[index]
	return Rect2(
		rect.position.x + WINDOW_INSET,
		rect.position.y + WINDOW_TOP,
		rect.size.x - WINDOW_INSET * 2.0,
		rect.size.y - WINDOW_TOP
	)


func _door_rect(index: int) -> Rect2:
	var body := _body_rect(index)
	var door_x := body.end.x - DOOR_WIDTH if index == 0 else body.position.x
	return Rect2(door_x, body.position.y, DOOR_WIDTH, body.size.y)


func _draw_window_goods(window: Rect2, index: int) -> void:
	var db := GameDatabase.get_default()
	var row_height := window.size.y / SHELF_ROWS
	var count := index * SHELF_ROWS
	for row in SHELF_ROWS:
		var shelf_y := window.position.y + row_height * (row + 1) - ITEM_GAP
		var x := window.position.x + ITEM_GAP * 2.0
		while x + ITEM_SIDE < window.end.x - ITEM_GAP:
			var center := Vector2(x + ITEM_SIDE * 0.5, shelf_y - ITEM_SIDE * 0.5)
			var id: StringName = WINDOW_GOODS[count % WINDOW_GOODS.size()]
			UiDraw.product_icon(self, center, ITEM_SIDE, db.product(id))
			x += ITEM_SIDE + ITEM_GAP
			count += 1
		draw_line(
			Vector2(window.position.x + UiPalette.OUTLINE, shelf_y),
			Vector2(window.end.x - UiPalette.OUTLINE, shelf_y),
			UiPalette.INK,
			SHELF_LINE
		)


## 「コンビニ」は白、「ウォーズ」は黄色の2段。太い縁取りと下へずらした影
func _draw_logo() -> void:
	var font := UiDraw.font()
	var parts := [[LOGO_HEAD, UiPalette.INK_ON_DARK], [LOGO_TAIL, UiPalette.MONEY]]
	for i in parts.size():
		var text: String = parts[i][0]
		var pos := Vector2((SIDE - UiDraw.text_width(text, LOGO_SIZE)) * 0.5, LOGO_BASELINES[i])
		for offset in [LOGO_SHADOW, Vector2.ZERO]:
			draw_string_outline(
				font,
				pos + offset,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				LOGO_SIZE,
				LOGO_OUTLINE,
				UiPalette.INK
			)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_SIZE, parts[i][1])


## 左半分が自店の色・右半分が相手の色の丸に「VS」。ループに合わせて2回脈打つ
func _draw_vs() -> void:
	var pulse := 1.0 + VS_PULSE * maxf(0.0, sin(t / LOOP * TAU * 2.0))
	var radius := VS_RADIUS * pulse
	draw_circle(VS_CENTER + Vector2(0, UiPalette.SHADOW_DROP), radius, UiPalette.SHADOW)
	draw_circle(VS_CENTER, radius + UiPalette.OUTLINE, UiPalette.INK)
	for side in 2:
		var from := PI * 0.5 + PI * side
		draw_colored_polygon(_half_disc(radius, from), UiPalette.STORE_COLORS[side])
	var cell := Rect2(VS_CENTER - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	UiDraw.text_centered(
		self, cell, "VS", int(VS_TEXT_SIZE * pulse), UiPalette.INK_ON_DARK, UiPalette.INK
	)


func _half_disc(radius: float, from: float) -> PackedVector2Array:
	var points := PackedVector2Array([VS_CENTER])
	var steps := 24
	for i in steps + 1:
		points.append(VS_CENTER + Vector2.from_angle(from + PI * i / steps) * radius)
	return points


## phase は1人の歩みの進み(0〜1)。横断歩道を上がり、歩道で入口へ曲がって入る
func _draw_walker(walker: Dictionary, phase: float) -> void:
	if phase >= ENTER_END:
		return
	var db := GameDatabase.get_default()
	var door_x := _door_rect(walker["store"]).get_center().x
	var pos := Vector2(CROSSWALK.get_center().x, WALK_Y)
	if phase < CROSS_END:
		pos.y = lerpf(WALK_FROM_Y, WALK_Y, _ease(phase / CROSS_END))
	else:
		pos.x = lerpf(pos.x, door_x, _ease(minf(1.0, (phase - CROSS_END) / (ARRIVE - CROSS_END))))
	var walking := phase < ARRIVE
	if walking:
		pos.y -= absf(sin(phase * PI * BOB_STEPS * 2.0)) * BOB_HEIGHT
	var radius := WALKER_RADIUS
	if not walking:
		radius *= 1.0 - (phase - ARRIVE) / (ENTER_END - ARRIVE)
	UiDraw.ground_shadow(self, Vector2(pos.x, WALK_Y + radius), radius * 2.0)
	UiDraw.customer_icon(self, pos, radius, db.customer_type(walker["customer"]))
	if walking:
		var bubble := Rect2(
			pos.x - BUBBLE_SIDE * 0.5,
			pos.y - radius - BUBBLE_GAP - BUBBLE_SIDE,
			BUBBLE_SIDE,
			BUBBLE_SIDE
		)
		UiDraw.bubble(self, bubble, UiPalette.PAPER, UiPalette.INK, pos.x)
		UiDraw.product_icon(self, bubble.get_center(), BUBBLE_ICON, db.product(walker["product"]))


## 客が入った店の入口の上へ「+¥」と硬貨が飛び出して上がる。出始めは少し大きく弾む
func _draw_pop(walker: Dictionary, phase: float) -> void:
	var since := (phase - ARRIVE) * LOOP
	if since < 0.0:
		since += LOOP
	if since > POP_SECONDS:
		return
	var progress := since / POP_SECONDS
	var grow := 1.0 + POP_GROW * maxf(0.0, 1.0 - progress * 4.0)
	var font_size := int(POP_SIZE * grow)
	var price: int = GameDatabase.get_default().product(walker["product"]).list_price
	var text := "+¥%d" % price
	var door := _door_rect(walker["store"])
	var width := UiDraw.text_width(text, font_size) + COIN_RADIUS * 2.0 + COIN_GAP
	var y := POP_START_Y - POP_RISE * _ease(progress)
	var left := door.end.x - width if walker["store"] == 0 else door.position.x
	UiDraw.coin(self, Vector2(left + COIN_RADIUS, y - font_size * 0.35), COIN_RADIUS * grow)
	UiDraw.text_outlined(
		self, Vector2(left + COIN_RADIUS * 2.0 + COIN_GAP, y), text, font_size, UiPalette.MONEY
	)


func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 2.0)
