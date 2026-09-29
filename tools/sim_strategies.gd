extends RefCounted
## simulate.gd で「ふつうのCPU」と戦わせる、偏った戦い方のCPU(GameDesign.md 1.5節の調整の目標を確かめるため)。


## 棚を一度も変えない。1日を通して欲しがられる量が多いカテゴリから9つを選び、1品ずつ置く
class FixedShelf:
	extends CpuPlayer

	## 在庫と発注中の合計がこれを下回ったら1ロット発注する
	const REORDER_BELOW := 30

	var _fixed: Array[StringName] = []

	func _init(match_state: MatchState, store_index: int, profile: CpuProfile) -> void:
		super(match_state, store_index, profile)
		_fixed = _pick_products()

	func _order(_demand: Dictionary, _keep_limit: Dictionary) -> void:
		var store := _match.stores[_index]
		for id in _fixed:
			if store.stock(id) + store.pending_count(id) < REORDER_BELOW:
				_match.order(_index, id)

	func _place() -> void:
		for slot in _fixed.size():
			_match.assign(_index, _fixed[slot], slot)

	func _price() -> void:
		pass

	func _pick_products() -> Array[StringName]:
		var weight := {}
		for band in _db.sorted_bands():
			var total := float(band.mix_total())
			for type_id: StringName in band.mix:
				var customers := band.customer_count * int(band.mix[type_id]) / total
				var customer := _db.customer_type(type_id)
				for category_id: StringName in customer.wants:
					var add := customers * customer.weight_of(category_id)
					weight[category_id] = float(weight.get(category_id, 0.0)) + add
		var categories: Array = weight.keys()
		categories.sort_custom(func(a, b) -> bool: return weight[a] > weight[b])
		var result: Array[StringName] = []
		for category_id: StringName in categories.slice(0, StoreState.SLOT_COUNT):
			result.append(_db.products_in_category(category_id)[0].id)
		return result


## 値段をいつも同じ段階にする(ほかの判断はふつうのCPUと同じ)
class FixedPrice:
	extends CpuPlayer

	var step := 0

	func _price() -> void:
		var store := _match.stores[_index]
		for id in store.shelf_product_ids():
			if store.price_step(id) != step:
				_match.set_price_step(_index, id, step)


const NAMES: Array[String] = ["fixed shelf", "always bold", "always cheap"]


## 戦略の番号から、その戦い方のCPUを作る
static func create(
	kind: int, match_state: MatchState, index: int, profile: CpuProfile
) -> CpuPlayer:
	if kind == 0:
		return FixedShelf.new(match_state, index, profile)
	var cpu := FixedPrice.new(match_state, index, profile)
	var balance := match_state.balance
	cpu.step = balance.price_step_count() - 1 if kind == 1 else balance.sale_price_step
	return cpu
