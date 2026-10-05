class_name ViewSide
extends RefCounted
## 画面の上の自店と相手(GameDesign.md 13.2節)。オンライン対戦で部屋に入った側は試合の店1になるが、
## どちらの画面でも自店を左・自店の色・「自店」の呼び名で出す。色と呼び名は店の番号ではなくこの側で引く。

const OWN_SIDE := 0
const RIVAL_SIDE := 1

## 自店の番号(CPU戦と部屋を作った側は0)
static var own := 0


static func rival() -> int:
	return 1 - own


## 店の番号 → 画面の側(0=自店 1=相手)
static func side(store_index: int) -> int:
	return OWN_SIDE if store_index == own else RIVAL_SIDE


static func color(store_index: int) -> Color:
	return UiPalette.STORE_COLORS[side(store_index)]


static func accent(store_index: int) -> Color:
	return UiPalette.STORE_ACCENTS[side(store_index)]


static func name(store_index: int) -> String:
	return UiPalette.STORE_NAMES[side(store_index)]
