class_name UiPalette
extends RefCounted
## 画面の色と文字の大きさ(UIクロームはコードで描く。CLAUDE.md「アセット」)。

const BACKGROUND := Color("#e9edf1")
const PANEL := Color("#ffffff")
const PANEL_EDGE := Color("#c9d2dc")
const INK := Color("#26303b")
const INK_SOFT := Color("#6b7785")
const INK_ON_DARK := Color("#ffffff")
const BAR := Color("#26303b")
const STREET := Color("#c7ccd3")
const STREET_LINE := Color("#f4f6f8")

## 店の色(自店・相手)
const STORE_COLORS: Array[Color] = [Color("#2f7de1"), Color("#e0484f")]
const STORE_NAMES: Array[String] = ["自店", "相手"]

const GOOD := Color("#2e9e5b")
const WARN := Color("#e8a23a")
const BAD := Color("#d64545")
const EMPTY_SLOT := Color("#dfe4ea")
const SOLD_OUT := Color("#f6d4d4")

## 値段の段階の色(安売り・定価・強気)
const PRICE_COLORS: Array[Color] = [Color("#2e9e5b"), Color("#26303b"), Color("#d9822b")]

## 棚のボーナスの枠の色(ShelfBonus.Kind の順)
const BONUS_COLORS: Array[Color] = [Color("#f0b400"), Color("#1fa2a8"), Color("#e2559b")]

const FONT_SMALL := 12
const FONT_BODY := 14
const FONT_LARGE := 18
const FONT_HEAD := 24
const FONT_HUGE := 40
const FONT_TITLE := 72

const RADIUS := 8
