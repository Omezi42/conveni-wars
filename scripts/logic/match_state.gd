class_name MatchState
extends RefCounted
## 試合の唯一の状態(Architecture.md 3章)。画面とCPUはコマンドだけで操作し、シグナルで結果を受け取る。
## 時刻 elapsed は開店からの経過秒で、開店準備の間は負。乱数はこのクラスの rng だけを使う。

signal opened
signal band_changed(band_id: StringName)
signal delivery_arrived(store_index: int, product_id: StringName, count: int)
## store_index は入った店。どちらにも入らず帰った客は -1
signal customer_arrived(type_id: StringName, store_index: int, is_event: bool)
signal customer_lost(store_index: int, category_id: StringName)
signal purchased(store_index: int, product_id: StringName, count: int, amount: int)
signal wasted(store_index: int, product_id: StringName, count: int)
signal ordered(store_index: int, product_id: StringName)
signal price_changed(store_index: int, product_id: StringName, step: int)
signal event_announced(event_id: StringName, store_index: int)
signal event_started(event_id: StringName)
signal event_ended(event_id: StringName, store_counts: Array[int])
signal skill_used(store_index: int)
signal skill_ended(store_index: int)
signal match_ended(result: MatchResult)

const STORE_COUNT := 2
const MINUTES_PER_HOUR := 60

var db: GameDatabase
var balance: BalanceConfig
var rng := RandomNumberGenerator.new()
var elapsed: float
var stores: Array[StoreState] = []
var events: EventScheduler
var finished := false
var result: MatchResult

var _duration: float
var _band_index := -1
var _band_spawned := 0


func _init(database: GameDatabase, manager_ids: Array[StringName], seed_value: int) -> void:
	db = database
	balance = database.balance
	rng.seed = seed_value
	elapsed = -balance.prep_seconds
	_duration = database.match_duration()
	for i in STORE_COUNT:
		stores.append(StoreState.new(database, i, database.manager(manager_ids[i])))
	for i in STORE_COUNT:
		stores[i].rival = opponent(i)
	events = EventScheduler.new(database, rng, STORE_COUNT)


# --- 進行 ---


func advance(delta: float) -> void:
	if finished:
		return
	var was_preparing := is_preparing()
	elapsed += delta
	if was_preparing and not is_preparing():
		opened.emit()
	for store in stores:
		_update_stock(store, delta)
		_update_timers(store, delta)
	if not is_preparing():
		_update_band_customers()
		_update_events()
	if elapsed >= _duration:
		_finish()


# --- コマンド(成否を返し、失敗時は状態を変えない) ---


func order(store_index: int, product_id: StringName) -> bool:
	if not can_order(store_index, product_id):
		return false
	var store := stores[store_index]
	var cost := lot_cost(store_index, product_id)
	store.funds -= cost
	store.spent += cost
	store.order_count += 1
	store.pending.append(
		StoreState.PendingOrder.new(product_id, balance.lot_size, balance.delivery_seconds)
	)
	ordered.emit(store_index, product_id)
	return true


func assign(store_index: int, product_id: StringName, slot: int) -> bool:
	if finished or db.product(product_id) == null or not _is_slot(slot):
		return false
	var store := stores[store_index]
	if store.shelf[slot] != product_id:
		store.shelf[slot] = product_id
		store.mark_dirty()
	return true


func unassign(store_index: int, slot: int) -> bool:
	if finished or not _is_slot(slot):
		return false
	var store := stores[store_index]
	if store.shelf[slot] == StoreState.EMPTY:
		return false
	store.shelf[slot] = StoreState.EMPTY
	store.mark_dirty()
	return true


func set_price_step(store_index: int, product_id: StringName, step: int) -> bool:
	if not can_set_price(store_index, product_id):
		return false
	if step < 0 or step >= balance.price_step_count():
		return false
	var store := stores[store_index]
	if store.price_step(product_id) == step:
		return false
	store.set_price_step_internal(product_id, step, balance.price_cooldown)
	price_changed.emit(store_index, product_id, step)
	return true


func use_active(store_index: int) -> bool:
	if not can_use_active(store_index):
		return false
	stores[store_index].active_used = true
	ManagerSkills.activate(self, store_index)
	skill_used.emit(store_index)
	return true


# --- 問い合わせ ---


func is_preparing() -> bool:
	return elapsed < 0.0


func prep_remaining() -> float:
	return maxf(-elapsed, 0.0)


func duration() -> float:
	return _duration


func remaining_time() -> float:
	return clampf(_duration - elapsed, 0.0, _duration)


func current_band_index() -> int:
	return db.band_index_at(clampf(elapsed, 0.0, _duration))


func current_band() -> TimeBandData:
	return db.sorted_bands()[current_band_index()]


## いまの時間帯のうち進んだ割合(0〜1)
func band_progress() -> float:
	var index := current_band_index()
	var band := db.sorted_bands()[index]
	var into := clampf(elapsed, 0.0, _duration) - db.band_start_time(index)
	return clampf(into / band.duration, 0.0, 1.0)


## 店の時計(0:00からの分)。時間帯の中では一定の速さで進む
func clock_minutes() -> int:
	var band := current_band()
	var span := (band.clock_end - band.clock_start) * MINUTES_PER_HOUR
	return band.clock_start * MINUTES_PER_HOUR + int(span * band_progress())


func opponent(store_index: int) -> StoreState:
	return stores[(store_index + 1) % STORE_COUNT]


## 客層予報に出す時間帯(次の時間帯と、店長によってはその次)
func forecast_bands(store_index: int) -> Array[TimeBandData]:
	var result_bands: Array[TimeBandData] = []
	var count := 1 + ManagerSkills.extra_forecast_bands(stores[store_index].manager)
	var sorted := db.sorted_bands()
	var start := current_band_index() + 1 if not is_preparing() else 0
	for i in range(start, mini(start + count, sorted.size())):
		result_bands.append(sorted[i])
	return result_bands


func announce_lead(store_index: int) -> float:
	var manager := stores[store_index].manager
	return balance.event_announce_seconds + ManagerSkills.announce_lead_bonus(manager)


## その店に見えている突発イベントの予告。無ければ null
func announced_event(store_index: int) -> EventData:
	return events.announced_event(announce_lead(store_index), elapsed)


func seconds_until_event() -> float:
	return events.next_start - elapsed


func lot_cost(store_index: int, product_id: StringName) -> int:
	var manager := stores[store_index].manager
	var unit := db.product(product_id).cost * ManagerSkills.order_cost_multiplier(manager)
	return int(round(unit * balance.lot_size))


func can_order(store_index: int, product_id: StringName) -> bool:
	if finished or db.product(product_id) == null:
		return false
	return stores[store_index].funds >= lot_cost(store_index, product_id)


func can_set_price(store_index: int, product_id: StringName) -> bool:
	if finished or db.product(product_id) == null:
		return false
	return (
		stores[store_index].price_cooldown(product_id) <= 0.0 and not is_price_locked(store_index)
	)


## 相手の値札ロックで値段を変えられないか
func is_price_locked(store_index: int) -> bool:
	return opponent(store_index).is_active_running(SkillKinds.Active.PRICE_LOCK)


func can_use_active(store_index: int) -> bool:
	return not finished and not is_preparing() and not stores[store_index].active_used


## 在庫へすぐに加える(配送の到着とスキルから呼ぶ)
func deliver(store_index: int, product_id: StringName, count: int) -> void:
	_deliver_at(stores[store_index], product_id, count, elapsed)


# --- 内部 ---


func _is_slot(slot: int) -> bool:
	return slot >= 0 and slot < StoreState.SLOT_COUNT


func _deliver_at(store: StoreState, product_id: StringName, count: int, arrived_at: float) -> void:
	var expires := INF
	if db.product_category(product_id).perishable:
		expires = arrived_at + balance.waste_seconds
	store.add_lot(product_id, count, expires)
	delivery_arrived.emit(store.index, product_id, count)


func _update_stock(store: StoreState, delta: float) -> void:
	for pending_order: StoreState.PendingOrder in store.pending.duplicate():
		pending_order.remaining -= delta
		if pending_order.remaining <= 0.0:
			store.pending.erase(pending_order)
			var arrived_at := elapsed + pending_order.remaining
			_deliver_at(store, pending_order.product_id, pending_order.count, arrived_at)
	var removed := store.remove_expired(elapsed)
	for product_id: StringName in removed:
		wasted.emit(store.index, product_id, removed[product_id])


func _update_timers(store: StoreState, delta: float) -> void:
	store.tick_cooldowns(delta)
	if store.active_remaining <= 0.0:
		return
	store.active_remaining -= delta
	if store.active_remaining <= 0.0:
		store.active_remaining = 0.0
		store.mark_dirty()
		skill_ended.emit(store.index)


func _update_events() -> void:
	for store in stores:
		if events.take_announcement(store.index, announce_lead(store.index), elapsed):
			event_announced.emit(events.next_event.id, store.index)
	if events.try_start(elapsed):
		event_started.emit(events.active_event.id)
	var due := events.customers_due(elapsed)
	if due <= 0:
		return
	var customer_type := db.customer_type(events.active_event.customer_type_id)
	for i in due:
		events.record_customer(_serve_customer(customer_type, true))
	if events.is_active_done():
		var finished_event := events.active_event
		events.finish_active()
		event_ended.emit(finished_event.id, events.active_counts.duplicate())


## 時間帯の来店数を、その時間帯の長さで割った間隔で生成する(1回の advance で複数人になることがある)
func _update_band_customers() -> void:
	var now := minf(elapsed, _duration)
	var index := db.band_index_at(now)
	while _band_index < index:
		if _band_index >= 0:
			_spawn_band_customers(db.sorted_bands()[_band_index].customer_count)
		_band_index += 1
		_band_spawned = 0
		band_changed.emit(db.sorted_bands()[_band_index].id)
	var band := db.sorted_bands()[index]
	var progress := clampf((now - db.band_start_time(index)) / band.duration, 0.0, 1.0)
	_spawn_band_customers(int(floor(progress * band.customer_count)))


func _spawn_band_customers(target: int) -> void:
	var band := db.sorted_bands()[_band_index]
	while _band_spawned < target:
		_band_spawned += 1
		_serve_customer(_pick_customer_type(band), false)


func _pick_customer_type(band: TimeBandData) -> CustomerTypeData:
	var roll := rng.randi_range(1, band.mix_total())
	for type_id: StringName in band.mix:
		roll -= int(band.mix[type_id])
		if roll <= 0:
			return db.customer_type(type_id)
	return db.customer_type(band.mix.keys().back())


## 客に店を選ばせて買い物をさせ、入った店の番号を返す(帰った客は -1)
func _serve_customer(customer_type: CustomerTypeData, is_event: bool) -> int:
	var evaluations: Array[Attraction.Evaluation] = []
	var scores: Array[float] = []
	for store in stores:
		var evaluation := store.evaluation(customer_type)
		evaluations.append(evaluation)
		scores.append(evaluation.score)
	var chosen := _choose_store(scores)
	# 時間帯の境目で前の時間帯の残りを生成している間は、その時間帯の客として数える
	var band_id := db.sorted_bands()[maxi(_band_index, 0)].id
	for store in stores:
		if scores[store.index] <= 0.0 and chosen != store.index:
			store.record_lost(band_id)
			customer_lost.emit(store.index, customer_type.top_category())
	customer_arrived.emit(customer_type.id, chosen, is_event)
	if chosen >= 0:
		stores[chosen].record_visit(customer_type.id)
		_shop(stores[chosen], evaluations[chosen], customer_type, is_event)
	return chosen


func _choose_store(scores: Array[float]) -> int:
	# 握手会:魅力度が0でなければ、発動した店を選ぶ(両店が同時に発動していれば通常どおり)
	var handshake := -1
	for store in stores:
		if store.is_active_running(SkillKinds.Active.HANDSHAKE) and scores[store.index] > 0.0:
			handshake = store.index if handshake < 0 else STORE_COUNT
	if handshake >= 0 and handshake < STORE_COUNT:
		return handshake
	return Attraction.choose_store(scores, balance.choice_exponent, rng)


func _shop(
	store: StoreState,
	evaluation: Attraction.Evaluation,
	customer_type: CustomerTypeData,
	is_event: bool
) -> void:
	var remaining := customer_type.buy_count
	var per_product := 1
	if is_event:
		remaining *= balance.event_buy_multiplier
		per_product = balance.event_per_product_limit
	for pick in evaluation.picks:
		if remaining <= 0:
			return
		var count := store.take(pick.product_id, mini(per_product, remaining))
		if count <= 0:
			continue
		remaining -= count
		var amount := store.sell_price(pick.product_id) * count
		store.funds += amount
		store.sales += amount
		if is_event:
			store.event_sales += amount
		purchased.emit(store.index, pick.product_id, count, amount)


func _finish() -> void:
	finished = true
	result = MatchResult.new()
	result.stores = stores
	result.winner = _decide_winner()
	match_ended.emit(result)


## 利益 → 来店した客の数 の順に比べる(GameDesign.md 1.4節)
func _decide_winner() -> int:
	var a := stores[0]
	var b := stores[1]
	if a.profit() != b.profit():
		return 0 if a.profit() > b.profit() else 1
	if a.visitor_total != b.visitor_total:
		return 0 if a.visitor_total > b.visitor_total else 1
	return MatchResult.DRAW
