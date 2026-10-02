class_name HintLayer
extends Control
## ヒント(GameDesign.md 9.7節)。初めてその出来事が起きたとき、その場所を指す1行の吹き出しを出す。
## 試合も入力も止めない。出すのは1つずつで、指した操作をしたか6秒(試合の時計で)たつと消える。

const PLAYER := 0
const CPU := 1
const SHOW_SECONDS := 6.0
const OPENING_DELAY := 3.0
const SKILL_REMAINING := 150.0

const OPENING := &"forecast"
const LOST := &"lost_customer"
const LOW_STOCK := &"low_stock"
const EVENT := &"event"
const UNDERCUT := &"undercut"
const SKILL := &"skill"

const PAD := Vector2(14, 10)
const MARGIN := 8.0
## 吹き出しの尾の先と指す所の間
const POINT_GAP := 6.0
const RING := 4.0
const RING_PULSE_SPEED := 4.0
const RING_MIN_ALPHA := 0.4


## 出すヒント1つ。target は指す所(画面座標。空なら指す物が無くなったので消す)、done は指した操作をしたか
class Hint:
	extends RefCounted
	var id: StringName
	var text: String
	var target: Callable
	var done: Callable

	func _init(key: StringName, body: String, where: Callable, finished: Callable) -> void:
		id = key
		text = body
		target = where
		done = finished


var match_state: MatchState
var save: SaveData
var own_shelf: ShelfView
var catalog: CatalogView
var forecast_rect: Rect2
var skill_rect: Rect2

var _queue: Array[Hint] = []
var _current: Hint
var _shown_at := 0.0
var _start_elapsed := 0.0
## 商品id → 前の画面での在庫(少なくなった瞬間を拾う)
var _last_stock: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(state: MatchState, data: SaveData) -> void:
	match_state = state
	save = data
	_start_elapsed = state.elapsed
	state.customer_lost.connect(_on_customer_lost)
	state.event_announced.connect(_on_event_announced)
	state.price_changed.connect(_on_price_changed)


func _process(_delta: float) -> void:
	if match_state == null:
		return
	if match_state.finished:
		_current = null
		_queue.clear()
		queue_redraw()
		return
	_check_timed()
	_check_low_stock()
	_update_current()
	queue_redraw()


func _check_timed() -> void:
	if _wants(OPENING) and match_state.elapsed - _start_elapsed >= OPENING_DELAY:
		_push(
			Hint.new(
				OPENING,
				"次に来る客が欲しがる物。先に発注して並べよう",
				func() -> Rect2: return forecast_rect,
				_ordered_any.bind(store().order_count)
			)
		)
	var skill_time := match_state.remaining_time() <= SKILL_REMAINING
	if _wants(SKILL) and skill_time and not store().active_used:
		_push(
			Hint.new(
				SKILL,
				"スキルは1試合に1回。ここぞで使おう",
				func() -> Rect2: return skill_rect,
				func() -> bool: return store().active_used
			)
		)


func _check_low_stock() -> void:
	var threshold := match_state.balance.low_stock_threshold
	for product_id in store().shelf_product_ids():
		var stock := store().stock(product_id)
		var before: int = _last_stock.get(product_id, stock)
		_last_stock[product_id] = stock
		if before > threshold and stock <= threshold:
			var seconds := ManagerSkills.delivery_seconds(store().manager, match_state.balance)
			var text := "押すと%d秒で%d個届く" % [roundi(seconds), match_state.balance.lot_size]
			_push(
				Hint.new(
					LOW_STOCK, text, _order_button.bind(product_id), _has_pending.bind(product_id)
				)
			)


func _on_customer_lost(store_index: int, category_id: StringName) -> void:
	if store_index != PLAYER or catalog.first_tile_in(category_id) < 0:
		return
	var category := match_state.db.category(category_id)
	_push(
		Hint.new(
			LOST,
			"%sを探して相手の店へ! 棚へドラッグで並べよう" % category.display_name,
			_catalog_tile.bind(category_id),
			_category_on_shelf.bind(category_id)
		)
	)


func _on_event_announced(_event_id: StringName, store_index: int) -> void:
	if store_index != PLAYER:
		return
	var text := "%d人がまとめ買いに来る。先に並べよう" % match_state.balance.event_customer_count
	_push(
		Hint.new(EVENT, text, func() -> Rect2: return forecast_rect, func() -> bool: return false)
	)


## 相手が値段を変え、自店の棚の同じカテゴリの商品より安くなったら、自店のその商品の値札を指す
func _on_price_changed(store_index: int, product_id: StringName, _step: int) -> void:
	if store_index != CPU:
		return
	var rival := match_state.stores[CPU]
	var category_id := match_state.db.product(product_id).category_id
	for own_id in store().shelf_product_ids():
		if match_state.db.product(own_id).category_id != category_id:
			continue
		if rival.sell_price(product_id) < store().sell_price(own_id):
			_push(
				Hint.new(
					UNDERCUT,
					"値札をタップして値段を変えられる",
					_price_tag.bind(own_id),
					_price_moved.bind(own_id, store().price_step(own_id))
				)
			)
			return


func _wants(id: StringName) -> bool:
	if save.has_shown_hint(id) or _current != null and _current.id == id:
		return false
	return not _queue.any(func(queued: Hint) -> bool: return queued.id == id)


func _push(hint: Hint) -> void:
	if _wants(hint.id):
		_queue.append(hint)


func _update_current() -> void:
	if _current != null:
		var expired := match_state.elapsed - _shown_at >= SHOW_SECONDS
		if expired or _current.done.call() or not _target().has_area():
			_current = null
	while _current == null and not _queue.is_empty():
		var next: Hint = _queue.pop_front()
		if next.done.call() or not next.target.call().has_area():
			continue
		_current = next
		_shown_at = match_state.elapsed
		save.mark_hint(next.id)
		save.save_file()


func _target() -> Rect2:
	return _current.target.call()


func store() -> StoreState:
	return match_state.stores[PLAYER]


func _ordered_any(count_at_trigger: int) -> bool:
	return store().order_count > count_at_trigger


func _has_pending(product_id: StringName) -> bool:
	return store().pending.any(
		func(order: StoreState.PendingOrder) -> bool: return order.product_id == product_id
	)


func _category_on_shelf(category_id: StringName) -> bool:
	return store().shelf_product_ids().any(
		func(id: StringName) -> bool: return match_state.db.product(id).category_id == category_id
	)


func _price_moved(product_id: StringName, step_at_trigger: int) -> bool:
	return store().price_step(product_id) != step_at_trigger


func _first_slot(product_id: StringName) -> int:
	return store().shelf.find(product_id)


func _order_button(product_id: StringName) -> Rect2:
	var slot := _first_slot(product_id)
	if slot < 0:
		return Rect2()
	var rect := own_shelf.order_rect(slot)
	return Rect2(own_shelf.global_position + rect.position, rect.size)


func _price_tag(product_id: StringName) -> Rect2:
	var slot := _first_slot(product_id)
	if slot < 0:
		return Rect2()
	var rect := own_shelf.tag_rect(slot)
	return Rect2(own_shelf.global_position + rect.position, rect.size)


func _catalog_tile(category_id: StringName) -> Rect2:
	var index := catalog.first_tile_in(category_id)
	if index < 0:
		return Rect2()
	var rect := catalog.tile_rect(index)
	return Rect2(catalog.global_position + rect.position, rect.size)


## 吹き出しは指す所の上に置き、尾で指す。画面の端からははみ出さない
func _draw() -> void:
	if _current == null:
		return
	var target := _target()
	var ring := UiPalette.MONEY
	var wave := (sin(Time.get_ticks_msec() / 1000.0 * RING_PULSE_SPEED) + 1.0) * 0.5
	ring.a = lerpf(RING_MIN_ALPHA, 1.0, wave)
	draw_rect(target.grow(RING * 0.5), ring, false, RING)

	var font := UiDraw.font()
	var font_size := UiPalette.FONT_BODY
	var text_size := font.get_string_size(_current.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var bubble_size := text_size + PAD * 2.0
	var tail_tip := target.position.y - POINT_GAP
	var top := tail_tip - UiDraw.BUBBLE_TAIL.y - bubble_size.y
	var left := clampf(
		target.get_center().x - bubble_size.x * 0.5, MARGIN, size.x - MARGIN - bubble_size.x
	)
	var bubble := Rect2(Vector2(left, maxf(top, MARGIN)), bubble_size)
	var tail_x := clampf(
		target.get_center().x,
		bubble.position.x + UiDraw.BUBBLE_TAIL.x,
		bubble.end.x - UiDraw.BUBBLE_TAIL.x
	)
	UiDraw.bubble(self, bubble, UiPalette.PAPER, UiPalette.INK, tail_x)
	UiDraw.text_centered(self, bubble, _current.text, font_size, UiPalette.INK)
