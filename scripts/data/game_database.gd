class_name GameDatabase
extends RefCounted
## `data/` の `.tres` をすべて読み、id → Resource の辞書を持つ(Architecture.md 2.1節)。
## 画面・テスト・シミュレーションのどこからでも `GameDatabase.get_default()` で同じものを使う。

const DATA_ROOT := "res://data/"
const BALANCE_PATH := "res://data/balance.tres"

static var _default: GameDatabase

var balance: BalanceConfig
var categories: Dictionary = {}
var products: Dictionary = {}
var customer_types: Dictionary = {}
var bands: Dictionary = {}
var combos: Dictionary = {}
var events: Dictionary = {}
var managers: Dictionary = {}
var cpu_profiles: Dictionary = {}

var _sorted_products: Array[ProductData] = []
var _sorted_bands: Array[TimeBandData] = []
var _sorted_managers: Array[ManagerData] = []
var _sorted_customer_types: Array[CustomerTypeData] = []
var _sorted_categories: Array[CategoryData] = []
var _sorted_events: Array[EventData] = []
var _sorted_cpu_profiles: Array[CpuProfile] = []


static func get_default() -> GameDatabase:
	if _default == null:
		_default = GameDatabase.new()
		_default.load_all()
	return _default


func load_all() -> void:
	balance = load(BALANCE_PATH) as BalanceConfig
	categories = _load_folder("categories")
	products = _load_folder("products")
	customer_types = _load_folder("customers")
	bands = _load_folder("bands")
	combos = _load_folder("combos")
	events = _load_folder("events")
	managers = _load_folder("managers")
	cpu_profiles = _load_folder("cpu")
	_sort_all()


func category(id: StringName) -> CategoryData:
	return categories.get(id) as CategoryData


func product(id: StringName) -> ProductData:
	return products.get(id) as ProductData


func customer_type(id: StringName) -> CustomerTypeData:
	return customer_types.get(id) as CustomerTypeData


func band(id: StringName) -> TimeBandData:
	return bands.get(id) as TimeBandData


func event(id: StringName) -> EventData:
	return events.get(id) as EventData


func manager(id: StringName) -> ManagerData:
	return managers.get(id) as ManagerData


func cpu_profile(id: StringName) -> CpuProfile:
	return cpu_profiles.get(id) as CpuProfile


func product_category(product_id: StringName) -> CategoryData:
	var data := product(product_id)
	return null if data == null else category(data.category_id)


## カテゴリの順 → 定価の安い順
func sorted_products() -> Array[ProductData]:
	return _sorted_products


func sorted_bands() -> Array[TimeBandData]:
	return _sorted_bands


func sorted_managers() -> Array[ManagerData]:
	return _sorted_managers


func sorted_customer_types() -> Array[CustomerTypeData]:
	return _sorted_customer_types


func sorted_categories() -> Array[CategoryData]:
	return _sorted_categories


func sorted_events() -> Array[EventData]:
	return _sorted_events


## CPUの強さ(弱い順。GameDesign.md 8.3節)
func sorted_cpu_profiles() -> Array[CpuProfile]:
	return _sorted_cpu_profiles


func products_in_category(category_id: StringName) -> Array[ProductData]:
	var result: Array[ProductData] = []
	for data in _sorted_products:
		if data.category_id == category_id:
			result.append(data)
	return result


## 試合時間は時間帯の長さの合計(二重に持たない)
func match_duration() -> float:
	var total := 0.0
	for data in _sorted_bands:
		total += data.duration
	return total


## 開店からの経過秒 time のときの時間帯の番号(試合終了後は最後の時間帯)
func band_index_at(time: float) -> int:
	var end := 0.0
	for i in _sorted_bands.size():
		end += _sorted_bands[i].duration
		if time < end:
			return i
	return _sorted_bands.size() - 1


func band_at(time: float) -> TimeBandData:
	return _sorted_bands[band_index_at(time)]


## 時間帯が始まる、開店からの経過秒
func band_start_time(band_index: int) -> float:
	var start := 0.0
	for i in band_index:
		start += _sorted_bands[i].duration
	return start


func total_customer_count() -> int:
	var total := 0
	for data in _sorted_bands:
		total += data.customer_count
	return total


func _load_folder(folder: String) -> Dictionary:
	var result := {}
	var path := DATA_ROOT + folder + "/"
	# 書き出した版では .tres が .remap になり DirAccess では拾えないため、ResourceLoader で列挙する
	for file_name in ResourceLoader.list_directory(path):
		if file_name.ends_with("/"):
			continue
		var res: Resource = load(path + file_name)
		if res != null and "id" in res:
			result[res.get("id")] = res
	return result


func _sort_all() -> void:
	_sorted_categories.assign(categories.values())
	_sorted_categories.sort_custom(
		func(a: CategoryData, b: CategoryData) -> bool: return a.order < b.order
	)
	_sorted_products.assign(products.values())
	_sorted_products.sort_custom(_product_before)
	_sorted_bands.assign(bands.values())
	_sorted_bands.sort_custom(
		func(a: TimeBandData, b: TimeBandData) -> bool: return a.order < b.order
	)
	_sorted_managers.assign(managers.values())
	_sorted_managers.sort_custom(
		func(a: ManagerData, b: ManagerData) -> bool: return a.order < b.order
	)
	_sorted_events.assign(events.values())
	_sorted_events.sort_custom(
		func(a: EventData, b: EventData) -> bool: return String(a.id) < String(b.id)
	)
	_sorted_cpu_profiles.assign(cpu_profiles.values())
	_sorted_cpu_profiles.sort_custom(
		func(a: CpuProfile, b: CpuProfile) -> bool: return a.order < b.order
	)
	_sorted_customer_types.assign(customer_types.values())
	_sorted_customer_types.sort_custom(
		func(a: CustomerTypeData, b: CustomerTypeData) -> bool: return a.order < b.order
	)


func _product_before(a: ProductData, b: ProductData) -> bool:
	var order_a := category(a.category_id).order
	var order_b := category(b.category_id).order
	if order_a != order_b:
		return order_a < order_b
	if a.list_price != b.list_price:
		return a.list_price < b.list_price
	return String(a.id) < String(b.id)
