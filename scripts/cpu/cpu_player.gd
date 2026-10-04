class_name CpuPlayer
extends RefCounted
## CPU(GameDesign.md 8.2節、Architecture.md 5章)。プレイヤーと同じコマンドと、画面に出ている情報
## (客層予報・イベントの予告・相手の棚と値段)だけを使う。乱数は MatchState のものを使う。

## false ならアクティブスキルを使わない(結果画面の計算し直しでプレイヤーの代わりに動かすとき)
var use_skill := true

var _match: MatchState
var _db: GameDatabase
var _index: int
var _profile: CpuProfile
var _think_timer := 0.0
var _skill_at := -1.0
## 見えた予告の開始時刻と、読んだ客層(読み違えを含む)
var _seen_start := -INF
var _seen_at := 0.0
var _read_type: CustomerTypeData


func _init(match_state: MatchState, store_index: int, profile: CpuProfile) -> void:
	_match = match_state
	_db = match_state.db
	_index = store_index
	_profile = profile


func store_index() -> int:
	return _index


## 内部の状態ごと写し、match_state を操作する別のCPUにする(スナップショット用)
func duplicate_for(match_state: MatchState) -> CpuPlayer:
	var copy := CpuPlayer.new(match_state, _index, _profile)
	copy.use_skill = use_skill
	copy._think_timer = _think_timer
	copy._skill_at = _skill_at
	copy._seen_start = _seen_start
	copy._seen_at = _seen_at
	copy._read_type = _read_type
	return copy


func update(delta: float) -> void:
	if _match.finished:
		return
	_watch_announcement()
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer += _profile.think_interval
	var demand := estimate_demand(_profile.stock_horizon)
	var keep_limit := estimate_demand(_match.balance.waste_seconds)
	_order(demand, keep_limit)
	_place()
	_price()
	if use_skill:
		_use_skill_when_ready()


## いまから seconds 秒のうちに自店で売れると見込むカテゴリごとの個数
func estimate_demand(seconds: float) -> Dictionary:
	var demand := {}
	var now := maxf(_match.elapsed, 0.0)
	var window_end := now + seconds
	var bands: Array[TimeBandData] = [_match.current_band()]
	bands.append_array(_match.forecast_bands(_index))
	var sorted := _db.sorted_bands()
	for band in bands:
		var start := _db.band_start_time(sorted.find(band))
		var overlap := minf(start + band.duration, window_end) - maxf(start, now)
		if overlap <= 0.0:
			continue
		var customers := overlap * band.customer_count / band.duration * _profile.assumed_share
		var mix := _match.band_mix(band)
		var total := float(MatchState.mix_total(mix))
		for type_id: StringName in mix:
			var share := int(mix[type_id]) / total
			_add_units(demand, _db.customer_type(type_id), customers * share, 1, 1)
	var event_start := _seen_start
	var reacted := _match.elapsed >= _seen_at + _profile.event_reaction_delay
	if _read_type != null and reacted and event_start < window_end:
		var balance := _match.balance
		if event_start + balance.event_arrival_seconds > now:
			var customers := balance.event_customer_count * _profile.assumed_share
			var mult := balance.event_buy_multiplier
			_add_units(demand, _read_type, customers, mult, balance.event_per_product_limit)
	return demand


func _watch_announcement() -> void:
	var announced := _match.announced_event(_index)
	if announced == null:
		return
	var start := _match.elapsed + _match.seconds_until_event()
	if is_equal_approx(start, _seen_start):
		return
	_seen_start = start
	_seen_at = _match.elapsed
	_read_type = _db.customer_type(announced.customer_type_id)
	if _match.rng.randf() < _profile.event_misread_chance:
		var others := _db.sorted_customer_types().filter(
			func(t: CustomerTypeData) -> bool: return t != _read_type
		)
		_read_type = others[_match.rng.randi_range(0, others.size() - 1)]


## 1つのカテゴリに1商品を置く前提で、客が買う個数をカテゴリへ割り振る
func _add_units(
	demand: Dictionary, customer_type: CustomerTypeData, customers: float, mult: int, per: int
) -> void:
	var categories: Array[StringName] = []
	categories.assign(customer_type.wants.keys())
	categories.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var wa := customer_type.weight_of(a)
			var wb := customer_type.weight_of(b)
			if wa != wb:
				return wa > wb
			return _db.category(a).order < _db.category(b).order
	)
	var remaining := customer_type.buy_count * mult
	for category_id in categories:
		if remaining <= 0:
			return
		var units := mini(per, remaining)
		remaining -= units
		demand[category_id] = float(demand.get(category_id, 0.0)) + customers * units


func _order(demand: Dictionary, keep_limit: Dictionary) -> void:
	var store := _match.stores[_index]
	var categories: Array = demand.keys()
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return demand[a] > demand[b])
	var lot := _match.balance.lot_size
	var ordered := true
	# 1周に1商品1ロットずつ回し、資金を上位のカテゴリだけに使い切らないようにする
	while ordered:
		ordered = false
		for category_id: StringName in categories:
			var product_id := _product_for(category_id)
			var have := store.stock(product_id) + store.pending_count(product_id)
			if have >= float(demand[category_id]):
				continue
			if _db.category(category_id).perishable:
				var limit := float(keep_limit.get(category_id, 0.0))
				if have + lot > limit and (have > 0 or limit < lot * 0.5):
					continue
			if _match.order(_index, product_id):
				ordered = true


## カテゴリの中で扱う商品(扱っている商品があればそれ、無ければ1個あたりの利益が大きいもの)
func _product_for(category_id: StringName) -> StringName:
	var store := _match.stores[_index]
	var best: ProductData
	for product in _db.products_in_category(category_id):
		var id := product.id
		if store.is_on_shelf(id) or store.stock(id) + store.pending_count(id) > 0:
			return id
		if best == null or product.list_price - product.cost > best.list_price - best.cost:
			best = product
	return best.id


func _place() -> void:
	var store := _match.stores[_index]
	for product in _db.sorted_products():
		var id := product.id
		if store.is_on_shelf(id) or store.stock(id) + store.pending_count(id) <= 0:
			continue
		var slot := _free_slot(store)
		if slot < 0:
			return
		_match.assign(_index, id, slot)


## 空のマス → 在庫が0のマス(届く予定の無いものを先)の順。無ければ -1
func _free_slot(store: StoreState) -> int:
	var empty := store.shelf.find(StoreState.EMPTY)
	if empty >= 0:
		return empty
	var waiting := -1
	for slot in StoreState.SLOT_COUNT:
		var id := store.shelf[slot]
		if store.stock(id) > 0:
			continue
		if store.pending_count(id) <= 0:
			return slot
		if waiting < 0:
			waiting = slot
	return waiting


func _price() -> void:
	var store := _match.stores[_index]
	var rival := _match.opponent(_index)
	var default_step := _match.balance.default_price_step
	var rates := _match.balance.price_step_rates
	for id in store.shelf_product_ids():
		var step := store.price_step(id)
		var rival_rate: Variant = rival.cheapest_rate_in(store.category_of(id))
		if rival_rate != null:
			if rates[step] > rival_rate:
				_match.set_price_step(_index, id, step - 1)
		elif step != default_step:
			_match.set_price_step(_index, id, default_step)


func _use_skill_when_ready() -> void:
	if not _match.can_use_active(_index):
		return
	var remaining := _match.remaining_time()
	if _skill_at < 0.0:
		if remaining > _profile.skill_after_remaining:
			return
		var window := maxf(remaining - _profile.skill_end_margin, 0.0)
		_skill_at = _match.elapsed + _match.rng.randf_range(0.0, window)
	if _match.elapsed >= _skill_at:
		_match.use_active(_index)
