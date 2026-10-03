class_name WeatherData
extends Resource
## 天気(GameDesign.md 12章)。試合ごとに1つ引き、時間帯の客層の割合とイベントの起きやすさを変える。

@export var id: StringName
@export var display_name: String
@export var order: int
## 出やすさ(ほかの天気との比で引く)
@export var chance: int = 1
## 客層id → 全時間帯の割合へ足す重み
@export var mix_bonus: Dictionary
## イベントid → 選ぶときの重み(無ければ1)
@export var event_weights: Dictionary
## 時間帯の空の色へ混ぜる色。α が混ぜる量
@export var sky_tint: Color = Color(1, 1, 1, 0)
## 開始のカットインの下に添える1行
@export var cutin_text: String
@export var icon: Texture2D


func event_weight(event_id: StringName) -> int:
	return int(event_weights.get(event_id, 1))


func tinted(color: Color) -> Color:
	return color.lerp(Color(sky_tint, 1.0), sky_tint.a)
