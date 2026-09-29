class_name ShelfBonus
extends RefCounted
## 棚の倍率(GameDesign.md 4.2節)。目玉・コーナー・セットを判定し、マスごとの倍率と成立したボーナスを返す。

enum Kind { CENTER, CORNER, COMBO }

const CENTER_NAME := "目玉"
const CORNER_SUFFIX := "コーナー"


class Bonus:
	extends RefCounted
	var kind: Kind
	var display_name: String
	var slots: Array[int] = []


class Result:
	extends RefCounted
	var multipliers: Array[float] = []
	var bonuses: Array[Bonus] = []

	## そのマスに成立しているボーナス
	func bonuses_at(slot: int) -> Array[Bonus]:
		var found: Array[Bonus] = []
		for bonus in bonuses:
			if bonus.slots.has(slot):
				found.append(bonus)
		return found


## stocked[i] はマス i に在庫のある商品が置いてあるか
static func evaluate(shelf: Array[StringName], stocked: Array[bool], db: GameDatabase) -> Result:
	var balance := db.balance
	var result := Result.new()
	result.multipliers.resize(shelf.size())
	result.multipliers.fill(1.0)

	var center := balance.center_slot
	if stocked[center]:
		result.multipliers[center] *= balance.center_multiplier
		_add(result, Kind.CENTER, CENTER_NAME, [center])

	var categories: Array[StringName] = []
	for slot in shelf.size():
		categories.append(db.product(shelf[slot]).category_id if stocked[slot] else &"")

	var columns := StoreState.COLUMNS
	@warning_ignore("integer_division")
	var rows := shelf.size() / columns
	for column in columns:
		var slots: Array[int] = []
		for row in rows:
			slots.append(row * columns + column)
		if _same_category(slots, categories):
			for slot in slots:
				result.multipliers[slot] *= balance.corner_multiplier
			var name := db.category(categories[slots[0]]).display_name + CORNER_SUFFIX
			_add(result, Kind.CORNER, name, slots)

	var in_combo: Array[bool] = []
	in_combo.resize(shelf.size())
	in_combo.fill(false)
	for slot in shelf.size():
		for neighbor in _right_and_below(slot, columns, shelf.size()):
			var combo := _combo_for(categories[slot], categories[neighbor], db)
			if combo == null:
				continue
			in_combo[slot] = true
			in_combo[neighbor] = true
			_add(result, Kind.COMBO, combo.display_name, [slot, neighbor])
	for slot in shelf.size():
		if in_combo[slot]:
			result.multipliers[slot] *= balance.combo_multiplier
	return result


static func _same_category(slots: Array[int], categories: Array[StringName]) -> bool:
	var first := categories[slots[0]]
	if first == &"":
		return false
	for slot in slots:
		if categories[slot] != first:
			return false
	return true


static func _right_and_below(slot: int, columns: int, count: int) -> Array[int]:
	var result: Array[int] = []
	if slot % columns < columns - 1:
		result.append(slot + 1)
	if slot + columns < count:
		result.append(slot + columns)
	return result


static func _combo_for(first: StringName, second: StringName, db: GameDatabase) -> ComboData:
	if first == &"" or second == &"":
		return null
	for combo: ComboData in db.combos.values():
		if combo.matches(first, second):
			return combo
	return null


static func _add(result: Result, kind: Kind, name: String, slots: Array) -> void:
	var bonus := Bonus.new()
	bonus.kind = kind
	bonus.display_name = name
	bonus.slots.assign(slots)
	result.bonuses.append(bonus)
