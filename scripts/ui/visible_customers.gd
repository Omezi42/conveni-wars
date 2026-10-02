class_name VisibleCustomers
extends RefCounted
## 見える客(GameDesign.md 9.2節)。来店を1秒に1人ほどに間引き、客層の絵で歩かせて、頭の上の吹き出しに
## 最初に買った商品の絵を出す。取り逃した客はいちばん欲しがったカテゴリの絵に×を付け「〇〇が無い…」と出す。
## 歩く道は画面ごとに違うため、呼ぶ側が accept() で受けた客に道を付けて spawn() する。
## 試合画面(上から見た通り)とタイトル(横から見た歩道)で共有する。

## 歩き終えて店へ入った(見える客が入ったマスを光らせる合図)
signal entered(store_index: int, product_id: StringName)

const INTERVAL := 1.0
## 取り逃した客は間引きとは別に、この間隔で優先して見える客にする
const LOST_INTERVAL := 1.0
const MAX_WALKERS := 12
const ICON_RADIUS := 20.0
const EVENT_RING := 3.0
const BOB_HEIGHT := 3.0
const BOB_STEPS := 6.0
## 歩き始めと店へ入るときに薄くする割合(道のりに対する割合)
const FADE_IN := 0.08
const FADE_OUT := 0.88
## 吹き出しは店の入口の手前で消す(入口の脇の棚に重ならないように)
const BUBBLE_FADE_FROM := 0.72
const BUBBLE_FADE_TO := 0.86
const BUBBLE_GAP := 12.0
const BUBBLE_ICON := 30.0
const BUBBLE_PAD := 5.0
const BUBBLE_TEXT_GAP := 4.0
const CROSS_WIDTH := 4.0
const CROSS_INSET := 0.2
const HALF := 0.5

## 取り逃しを優先して見せる店(タイトルは -1 で優先しない)
var priority_store := -1

var _walkers: Array[Dictionary] = []
var _cooldown := 0.0
var _lost_cooldown := 0.0
## 直前の customer_lost のカテゴリ(店ごと)。MatchState は customer_lost を customer_arrived より先に出す
var _pending_lost: Array[StringName] = [&"", &""]


func note_lost(store_index: int, category_id: StringName) -> void:
	_pending_lost[store_index] = category_id


## 来店を受けて、見える客にするなら客の辞書(道は未設定)を返す。間引くなら空の辞書
func accept(
	type_id: StringName, store_index: int, is_event: bool, product_id: StringName
) -> Dictionary:
	var lost := _lost_category(store_index)
	_pending_lost = [&"", &""]
	if lost != &"" and priority_store >= 0:
		if _lost_cooldown > 0.0:
			return {}
		_lost_cooldown = LOST_INTERVAL
	else:
		if _cooldown > 0.0:
			return {}
		_cooldown = INTERVAL
	return {
		"type": type_id,
		"store": store_index,
		"event": is_event,
		"product": product_id if lost == &"" else &"",
		"lost": lost,
	}


## accept() で受けた客を、start → control → end の曲線に沿って seconds 秒で歩かせる
func spawn(
	walker: Dictionary, start: Vector2, control: Vector2, end: Vector2, seconds: float
) -> void:
	if _walkers.size() >= MAX_WALKERS:
		_walkers.pop_front()
	walker["start"] = start
	walker["control"] = control
	walker["end"] = end
	walker["seconds"] = seconds
	walker["t"] = 0.0
	_walkers.append(walker)


func update(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_lost_cooldown = maxf(_lost_cooldown - delta, 0.0)
	for walker in _walkers:
		walker["t"] += delta / float(walker["seconds"])
		if walker["t"] >= 1.0 and int(walker["store"]) >= 0 and walker["lost"] == &"":
			entered.emit(int(walker["store"]), walker["product"])
	_walkers = _walkers.filter(func(w: Dictionary) -> bool: return w["t"] < 1.0)


func draw(item: CanvasItem, db: GameDatabase) -> void:
	for walker in _walkers:
		_draw_walker(item, db, walker)


func _lost_category(store_index: int) -> StringName:
	if priority_store >= 0:
		return _pending_lost[priority_store]
	if store_index < 0:
		return _pending_lost[0] if _pending_lost[0] != &"" else _pending_lost[1]
	return &""


func _draw_walker(item: CanvasItem, db: GameDatabase, walker: Dictionary) -> void:
	var t: float = walker["t"]
	var start: Vector2 = walker["start"]
	var control: Vector2 = walker["control"]
	var end: Vector2 = walker["end"]
	var pos := start.lerp(control, t).lerp(control.lerp(end, t), t)
	pos.y -= absf(sin(t * float(walker["seconds"]) * BOB_STEPS)) * BOB_HEIGHT
	var alpha := clampf(t / FADE_IN, 0.0, 1.0) * clampf((1.0 - t) / (1.0 - FADE_OUT), 0.0, 1.0)
	UiDraw.ground_shadow(item, pos + Vector2(0, ICON_RADIUS), ICON_RADIUS * 2.0, alpha)
	if walker["event"]:
		var ring := UiPalette.MONEY
		ring.a = alpha
		item.draw_circle(pos, ICON_RADIUS + EVENT_RING * 2.0, ring)
	UiDraw.customer_icon(item, pos, ICON_RADIUS, db.customer_type(walker["type"]), alpha)
	var lost: StringName = walker["lost"]
	var bubble_alpha := alpha
	if lost == &"":
		bubble_alpha *= 1.0 - smoothstep(BUBBLE_FADE_FROM, BUBBLE_FADE_TO, t)
	if bubble_alpha <= 0.0:
		return
	var head := pos - Vector2(0, ICON_RADIUS + BUBBLE_GAP)
	if lost != &"":
		_draw_lost_bubble(item, db, head, lost, bubble_alpha)
	elif walker["product"] != &"":
		_draw_product_bubble(item, db, head, walker["product"], bubble_alpha)


func _draw_product_bubble(
	item: CanvasItem, db: GameDatabase, head: Vector2, product_id: StringName, alpha: float
) -> void:
	var side := BUBBLE_ICON + BUBBLE_PAD * 2.0
	var rect := Rect2(head.x - side * HALF, head.y - side, side, side)
	UiDraw.bubble(item, rect, _faded(UiPalette.PAPER, alpha), _faded(UiPalette.INK, alpha), head.x)
	UiDraw.product_icon(item, rect.get_center(), BUBBLE_ICON, db.product(product_id), alpha)


## いちばん欲しがったカテゴリの絵に×と「〇〇が無い…」
func _draw_lost_bubble(
	item: CanvasItem, db: GameDatabase, head: Vector2, category_id: StringName, alpha: float
) -> void:
	var label := "%sが無い…" % db.category(category_id).display_name
	var text_width := UiDraw.text_width(label, UiPalette.FONT_SMALL)
	var height := BUBBLE_ICON + BUBBLE_PAD * 2.0
	var width := BUBBLE_PAD * 2.0 + BUBBLE_ICON + BUBBLE_TEXT_GAP + text_width
	var rect := Rect2(head.x - width * HALF, head.y - height, width, height)
	var edge := _faded(UiPalette.BAD, alpha)
	UiDraw.bubble(item, rect, _faded(UiPalette.PAPER, alpha), edge, head.x)
	var icon_center := rect.position + Vector2(BUBBLE_PAD + BUBBLE_ICON * HALF, height * HALF)
	UiDraw.category_icon(item, icon_center, BUBBLE_ICON, category_id, alpha)
	var reach := BUBBLE_ICON * (HALF - CROSS_INSET)
	for sign_y: float in [-1.0, 1.0]:
		var from := icon_center + Vector2(-reach, -reach * sign_y)
		var to := icon_center + Vector2(reach, reach * sign_y)
		item.draw_line(from, to, edge, CROSS_WIDTH)
	var text_rect := Rect2(
		icon_center.x + BUBBLE_ICON * HALF + BUBBLE_TEXT_GAP, rect.position.y, text_width, height
	)
	UiDraw.text_centered(item, text_rect, label, UiPalette.FONT_SMALL, edge)


static func _faded(color: Color, alpha: float) -> Color:
	var faded := color
	faded.a *= alpha
	return faded
