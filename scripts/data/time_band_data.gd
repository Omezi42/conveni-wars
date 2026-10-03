class_name TimeBandData
extends Resource
## 時間帯(GameDesign.md 1.2節・2.2節)。

@export var id: StringName
@export var display_name: String
@export var order: int
## 試合の中での長さ(秒)
@export var duration: float
## 両店あわせた来店数
@export var customer_count: int
## 店の時計の時刻(時)
@export var clock_start: int
@export var clock_end: int
## 客層id → 来る割合の重み(試合では天気を足した MatchState.band_mix を使う)
@export var mix: Dictionary
## 時間帯が変わるときのカットインの文言(GameDesign.md 9.3節)
@export var cutin_text: String
## 画面の背景の空の色(上端・下端)と、夜か(月と星を出す)(GameDesign.md 9.5節)
@export var sky_top: Color
@export var sky_bottom: Color
@export var night: bool
