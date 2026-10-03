class_name StockGauge
extends RefCounted
## 在庫の見え方と発注ボタン(GameDesign.md 6.1節・6.4節・9.2節)。棚のマス(ShelfView)と品ぞろえの札(CatalogView)で共有する。
## 廃棄までの残りのバー・入荷待ちの札・発注ボタンを描き、発注ボタンの乗せた・押した・成否の光りの状態を持つ
## (描く部品ごとに1つ持つ)。発注ボタンは押すと沈み、成否の色が一瞬光る。資金が足りないと灰色。
## 自動発注がオンの商品は「発注」を「自動」に変え、枠を緑にする(6.5節)。

const ORDER_DROP := 2.0
## この高さ以上の発注ボタンは「発注」と代金を2行に分ける
const TWO_LINE_HEIGHT := 40.0
const TEXT_PAD := 4.0
## 入荷待ちの札の、まだ届くまでの残りぶんの地の色
const DELIVERY_TRACK := Color("#a9c6f5")
## 廃棄が近いとみなす残り秒数
const WASTE_WARN_SECONDS := 15.0
const WASTE_DANGER_SECONDS := 5.0
const BAR_TRACK := Color("#e4ded0")
const FLASH_SECONDS := 0.35
const OK_FLASH := Color(0.12, 0.64, 0.36, 0.55)
const FAIL_FLASH := Color(0.9, 0.22, 0.23, 0.55)
const FADED := Color("#d9d4c8")
const FADED_INK := Color(0.36, 0.4, 0.51, 0.6)
const HOVER_LIGHTEN := 0.25

var match_state: MatchState
var store_index := 0
var hover_id: StringName = &""

var _pressed_id: StringName = &""
## 商品id → [残り秒, 成功したか]
var _flashes: Dictionary = {}


func _init(state: MatchState, index: int) -> void:
	match_state = state
	store_index = index


func store() -> StoreState:
	return match_state.stores[store_index]


func tick(delta: float) -> void:
	for id: StringName in _flashes.keys():
		_flashes[id][0] -= delta
		if _flashes[id][0] <= 0.0:
			_flashes.erase(id)


## 発注ボタンの当たり判定(押して沈んだぶんも含める)
static func hit_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(0, 0, 0, ORDER_DROP)


func press(product_id: StringName) -> bool:
	_pressed_id = product_id
	var ok := match_state.order(store_index, product_id)
	_flashes[product_id] = [FLASH_SECONDS, ok]
	return ok


func release() -> void:
	_pressed_id = &""
	hover_id = &""


## with_caption なら「発注」と1ロットの代金(ボタンが高ければ2行)。そうでなければ代金だけ
func draw_order_button(
	item: CanvasItem, rect: Rect2, product_id: StringName, with_caption: bool
) -> void:
	var cost := match_state.lot_cost(store_index, product_id)
	var affordable := store().funds >= cost
	var fill := UiPalette.MONEY if affordable else FADED
	if affordable and product_id == hover_id:
		fill = fill.lightened(HOVER_LIGHTEN)
	var radius := UiPalette.RADIUS_SMALL
	if product_id == _pressed_id:
		rect.position.y += ORDER_DROP
	else:
		var shadow := Rect2(rect.position + Vector2(0, ORDER_DROP), rect.size)
		UiDraw.panel(item, shadow, UiPalette.SHADOW, Color.TRANSPARENT, 0, radius)
	var auto := store().auto_orders.has(product_id)
	if auto:
		UiDraw.panel(item, rect, fill, UiPalette.GOOD, UiPalette.OUTLINE, radius)
	else:
		UiDraw.panel(item, rect, fill, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	if _flashes.has(product_id):
		var flash: Array = _flashes[product_id]
		var color := OK_FLASH if flash[1] else FAIL_FLASH
		color.a *= flash[0] / FLASH_SECONDS
		UiDraw.panel(item, rect, color, Color.TRANSPARENT, 0, radius)
	var ink := UiPalette.INK if affordable else FADED_INK
	var price := UiDraw.yen(cost)
	var inner := rect.grow(-TEXT_PAD)
	if not with_caption:
		UiDraw.text_centered(item, inner, price, UiPalette.FONT_BODY, ink)
		return
	var caption := "自動" if auto else "発注"
	if rect.size.y < TWO_LINE_HEIGHT:
		UiDraw.text_centered(item, inner, caption + " " + price, UiPalette.FONT_BODY, ink)
		return
	var halves := [
		Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)),
		Rect2(inner.get_center() - Vector2(inner.size.x * 0.5, 0), inner.size * Vector2(1, 0.5)),
	]
	var caption_ink := UiPalette.GOOD if auto and affordable else ink
	UiDraw.text_centered(item, halves[0], caption, UiPalette.FONT_SMALL, caption_ink)
	UiDraw.text_centered(item, halves[1], price, UiPalette.FONT_BODY, ink)


## いちばん古いロットが廃棄されるまでの残りを、減っていくバーで出す(残りが少ないと赤く点滅する)。
## 日持ちする商品と在庫の無い商品は描かない
func draw_waste_bar(item: CanvasItem, bar: Rect2, product_id: StringName, blink: float) -> void:
	var lot := store().oldest_lot(product_id)
	if lot == null or lot.expires_at == INF:
		return
	var left := maxf(lot.expires_at - match_state.elapsed, 0.0)
	var radius := int(bar.size.y * 0.5)
	UiDraw.panel(item, bar, BAR_TRACK, Color.TRANSPARENT, 0, radius)
	var ratio := clampf(left / match_state.balance.waste_seconds, 0.0, 1.0)
	var color := UiPalette.GOOD
	if left <= WASTE_DANGER_SECONDS:
		color = UiPalette.BAD.lerp(BAR_TRACK, blink)
	elif left <= WASTE_WARN_SECONDS:
		color = UiPalette.BAD
	var filled := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	UiDraw.panel(item, filled, color, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(item, bar, Color.TRANSPARENT, UiPalette.INK, 1, radius)


## 入荷待ち:届く個数の札。届くまでの残りは、左から満ちていく塗りで見せる。
## 入荷待ちが無ければ描かずに false を返す
func draw_delivery(
	item: CanvasItem, center: Vector2, product_id: StringName, height: float
) -> bool:
	var arriving := store().next_delivery_seconds(product_id)
	if arriving < 0.0:
		return false
	var label := "+%d" % store().pending_count(product_id)
	var rect := UiDraw.pill(
		item, center, label, UiPalette.FONT_SMALL, DELIVERY_TRACK, UiPalette.INK, height
	)
	var ratio := clampf(1.0 - arriving / match_state.balance.delivery_seconds, 0.0, 1.0)
	var radius := int(height * 0.5)
	var filled := Rect2(rect.position, Vector2(maxf(rect.size.x * ratio, height), rect.size.y))
	UiDraw.panel(item, filled, UiPalette.DELIVERY, Color.TRANSPARENT, 0, radius)
	UiDraw.panel(item, rect, Color.TRANSPARENT, UiPalette.INK, UiPalette.OUTLINE_THIN, radius)
	UiDraw.text_centered(
		item, rect, label, UiPalette.FONT_SMALL, UiPalette.INK_ON_DARK, UiPalette.INK
	)
	return true


## 在庫数の文字の色(切れた・棚に無い=薄い、残り少ない=赤く点滅)
func stock_color(stock: int, on_shelf: bool, blink: float) -> Color:
	if stock <= 0 or not on_shelf:
		return UiPalette.INK_SOFT
	if stock <= match_state.balance.low_stock_threshold:
		return UiPalette.BAD.lerp(UiPalette.INK, 1.0 - blink)
	return UiPalette.INK
