class_name StoreState
extends RefCounted
## 1店ぶんの状態(Architecture.md 3.1節)。書き換えるのは MatchState のコマンドと進行だけ。
## 在庫はマスではなく商品ごとに、届いた順のロットの列で持つ(GameDesign.md 6.2節・6.4節)。


class Lot:
	extends RefCounted
	var count: int
	## 廃棄される時刻(開店からの秒)。日持ちする商品は INF
	var expires_at: float

	func _init(amount: int, expiry: float) -> void:
		count = amount
		expires_at = expiry


class PendingOrder:
	extends RefCounted
	var product_id: StringName
	var count: int
	var remaining: float

	func _init(id: StringName, amount: int, seconds: float) -> void:
		product_id = id
		count = amount
		remaining = seconds


const SLOT_COUNT := 9
const COLUMNS := 3
const EMPTY: StringName = &""

var index: int
var manager: ManagerData
var funds: int
var sales := 0
## 仕入れに払った額(発注の代金の合計)
var spent := 0
## 突発イベントの客による売上(シミュレーションで割合を見るため)
var event_sales := 0
## 客層id → 来店数
var visitors: Dictionary = {}
var visitor_total := 0
var lost_total := 0
## 時間帯id → その時間帯の客(突発イベントの客を除く)のうち、この店に入った数
var visitors_by_band: Dictionary = {}
## 時間帯id → 取り逃した客の数
var lost_by_band: Dictionary = {}
## 負けた理由(GameDesign.md 2.7節)の試合全体の集計
var losses := LossReason.Tally.new()
## 時間帯id → LossReason.Tally
var losses_by_band: Dictionary = {}
var wasted_count := 0
var order_count := 0
## マスごとの商品id。空は EMPTY
var shelf: Array[StringName] = []
var pending: Array[PendingOrder] = []
## 自動発注がオンの商品(GameDesign.md 6.5節)
var auto_orders: Array[StringName] = []
var active_used := false
## アクティブスキルの効果の残り秒数
var active_remaining := 0.0
## 相手の店。値段補正は相手の同じカテゴリの値段と比べるため、どちらかが変われば両店の魅力度を計算し直す
var rival: StoreState

var _db: GameDatabase
var _lots: Dictionary = {}
var _price_steps: Dictionary = {}
var _price_cooldowns: Dictionary = {}
var _dirty := true
var _shelf_result: ShelfBonus.Result
var _evaluations: Dictionary = {}


func _init(database: GameDatabase, store_index: int, manager_data: ManagerData) -> void:
	_db = database
	index = store_index
	manager = manager_data
	funds = database.balance.starting_funds
	shelf.resize(SLOT_COUNT)
	shelf.fill(EMPTY)


## 利益 = 売上 − 仕入れ(GameDesign.md 1.3節)
func profit() -> int:
	return sales - spent


func stock(product_id: StringName) -> int:
	var total := 0
	for lot: Lot in _lots.get(product_id, []):
		total += lot.count
	return total


## いちばん古いロット(廃棄までの残りを出すため)。無ければ null
func oldest_lot(product_id: StringName) -> Lot:
	var lots: Array = _lots.get(product_id, [])
	return null if lots.is_empty() else lots[0]


func pending_count(product_id: StringName) -> int:
	var total := 0
	for order in pending:
		if order.product_id == product_id:
			total += order.count
	return total


## いちばん早く届く発注の残り秒数。発注中でなければ -1
func next_delivery_seconds(product_id: StringName) -> float:
	var best := -1.0
	for order in pending:
		if order.product_id == product_id and (best < 0.0 or order.remaining < best):
			best = order.remaining
	return best


func price_step(product_id: StringName) -> int:
	return int(_price_steps.get(product_id, _db.balance.default_price_step))


func price_cooldown(product_id: StringName) -> float:
	return float(_price_cooldowns.get(product_id, 0.0))


func sell_price(product_id: StringName) -> int:
	return price_for_step(product_id, ManagerSkills.sell_price_step(self, price_step(product_id)))


func price_for_step(product_id: StringName, step: int) -> int:
	var balance := _db.balance
	var raw := _db.product(product_id).list_price * (1.0 + balance.price_step_rates[step])
	var unit := balance.price_round_unit
	return int(round(raw / unit)) * unit


func is_on_shelf(product_id: StringName) -> bool:
	return shelf.has(product_id)


## 棚に置いた商品(重複なし・マスの順)
func shelf_product_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for product_id in shelf:
		if product_id != EMPTY and not result.has(product_id):
			result.append(product_id)
	return result


## 在庫があって売れる状態のマスか
func is_slot_stocked(slot: int) -> bool:
	return shelf[slot] != EMPTY and stock(shelf[slot]) > 0


## 棚に在庫ありで並んでいる商品のカテゴリか
func is_category_stocked(category_id: StringName) -> bool:
	for slot in shelf.size():
		if is_slot_stocked(slot) and category_of(shelf[slot]) == category_id:
			return true
	return false


func category_of(product_id: StringName) -> StringName:
	return _db.product(product_id).category_id


## 棚にあって在庫のある、そのカテゴリの商品のうちいちばん安い段階の率。置いていなければ null
func cheapest_rate_in(category_id: StringName) -> Variant:
	var best: Variant = null
	for slot in SLOT_COUNT:
		if not is_slot_stocked(slot):
			continue
		var product_id := shelf[slot]
		if category_of(product_id) != category_id:
			continue
		var rate := _db.balance.price_step_rates[price_step(product_id)]
		if best == null or rate < best:
			best = rate
	return best


func is_active_running(kind: SkillKinds.Active) -> bool:
	return active_remaining > 0.0 and manager.active_kind == kind


func lost_in_band(band_id: StringName) -> int:
	return int(lost_by_band.get(band_id, 0))


## その時間帯の負けた理由の集計(1件も無ければ空の集計)
func losses_in_band(band_id: StringName) -> LossReason.Tally:
	var tally: LossReason.Tally = losses_by_band.get(band_id)
	return tally if tally != null else LossReason.Tally.new()


## 時間帯の客(突発イベントの客を除く)のうち、両店に入った客に占めるこの店の割合。どちらにも入っていなければ -1
func band_share(band_id: StringName) -> float:
	var own := visitors_in_band(band_id)
	var total := own + rival.visitors_in_band(band_id)
	if total == 0:
		return -1.0
	return float(own) / total


func shelf_bonus() -> ShelfBonus.Result:
	_refresh()
	if _shelf_result == null:
		var stocked: Array[bool] = []
		for slot in SLOT_COUNT:
			stocked.append(is_slot_stocked(slot))
		_shelf_result = ShelfBonus.evaluate(shelf, stocked, _db)
	return _shelf_result


## 客層から見た魅力度と買う順番(棚・在庫の有無・値段・スキルが変わるまで使い回す)
func evaluation(customer_type: CustomerTypeData) -> Attraction.Evaluation:
	_refresh()
	var cached: Attraction.Evaluation = _evaluations.get(customer_type.id)
	if cached == null:
		cached = Attraction.evaluate(self, customer_type, _db)
		_evaluations[customer_type.id] = cached
	return cached


func mark_dirty() -> void:
	_dirty = true
	if rival != null:
		rival._dirty = true


# --- 以下は MatchState からだけ呼ぶ ---


func set_price_step_internal(product_id: StringName, step: int, cooldown: float) -> void:
	_price_steps[product_id] = step
	_price_cooldowns[product_id] = cooldown
	mark_dirty()


func tick_cooldowns(delta: float) -> void:
	for product_id: StringName in _price_cooldowns.keys():
		var left: float = _price_cooldowns[product_id] - delta
		if left <= 0.0:
			_price_cooldowns.erase(product_id)
		else:
			_price_cooldowns[product_id] = left


func add_lot(product_id: StringName, count: int, expires_at: float) -> void:
	if not _lots.has(product_id):
		_lots[product_id] = []
	var lots: Array = _lots[product_id]
	if lots.is_empty():
		mark_dirty()
	lots.append(Lot.new(count, expires_at))


## 古いロットから最大 count 個を減らし、減らせた数を返す
func take(product_id: StringName, count: int) -> int:
	var lots: Array = _lots.get(product_id, [])
	var taken := 0
	while taken < count and not lots.is_empty():
		var lot: Lot = lots[0]
		var n := mini(lot.count, count - taken)
		lot.count -= n
		taken += n
		if lot.count <= 0:
			lots.pop_front()
	if taken > 0 and lots.is_empty():
		mark_dirty()
	return taken


## 廃棄時刻を過ぎたロットを捨て、商品id → 捨てた個数 を返す
func remove_expired(now: float) -> Dictionary:
	var removed := {}
	for product_id: StringName in _lots:
		var lots: Array = _lots[product_id]
		var count := 0
		while not lots.is_empty() and (lots[0] as Lot).expires_at <= now:
			count += (lots.pop_front() as Lot).count
		if count > 0:
			removed[product_id] = count
			wasted_count += count
			if lots.is_empty():
				mark_dirty()
	return removed


## band_id は時間帯の客なら入った時間帯、突発イベントの客なら &""
func record_visit(type_id: StringName, band_id: StringName) -> void:
	visitors[type_id] = int(visitors.get(type_id, 0)) + 1
	visitor_total += 1
	if band_id != &"":
		visitors_by_band[band_id] = visitors_in_band(band_id) + 1


func visitors_in_band(band_id: StringName) -> int:
	return int(visitors_by_band.get(band_id, 0))


## 負けた理由を数える。品切れは取り逃した客(GameDesign.md 2.6節)としても数える
func record_loss(band_id: StringName, loss: LossReason.Loss) -> void:
	if loss.kind == LossReason.Kind.OUT_OF_STOCK:
		lost_by_band[band_id] = lost_in_band(band_id) + 1
		lost_total += 1
	losses.add(loss)
	var tally: LossReason.Tally = losses_by_band.get(band_id)
	if tally == null:
		tally = LossReason.Tally.new()
		losses_by_band[band_id] = tally
	tally.add(loss)


func _refresh() -> void:
	if _dirty:
		_dirty = false
		_shelf_result = null
		_evaluations.clear()
