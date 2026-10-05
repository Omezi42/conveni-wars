class_name ResultShare
extends RefCounted
## 結果の共有(GameDesign.md 9.4節・Architecture.md 4.4節)。結果画面を1280×720の画像にして、
## Webでは共有シートかダウンロード、デスクトップではピクチャのフォルダへ保存する。

enum Delivery { SHARED, SAVED, FAILED }

const IMAGE_SIZE := Vector2i(1280, 720)
const FILE_PREFIX := "conveni-wars_"
const FOLDER := "コンビニウォーズ"
const MIME := "image/png"
const HASHTAG := "#コンビニウォーズ"
const WIN_TEXT := "に勝ち!"
const LOSE_TEXT := "に負け…"
const DRAW_TEXT := "と引き分け"
const CAN_SHARE_JS := """
matchMedia("(pointer: coarse)").matches && !!navigator.canShare
	&& navigator.canShare({files: [new File([""], "a.png", {type: "image/png"})]})
"""
const SHARE_JS := """
(function() {
	const raw = atob(%s);
	const bytes = new Uint8Array(raw.length);
	for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
	const file = new File([bytes], %s, {type: "image/png"});
	navigator.share({files: [file], text: %s, url: location.href}).catch(function() {});
})();
"""


static func is_web() -> bool:
	return OS.has_feature("web")


static func button_label() -> String:
	return "結果を共有" if is_web() else "画像を保存"


## opponent は相手の呼び名(「CPU(つよい)」「オンライン対戦の相手」)
static func share_text(winner: int, own: int, opponent: String, profit: int) -> String:
	var verdict := DRAW_TEXT
	if winner == own:
		verdict = WIN_TEXT
	elif winner != MatchResult.DRAW:
		verdict = LOSE_TEXT
	return "コンビニウォーズで%s%s 利益 %s %s" % [opponent, verdict, UiDraw.yen(profit), HASHTAG]


static func file_name(now: Dictionary) -> String:
	return (
		"%s%04d%02d%02d_%02d%02d%02d.png"
		% [FILE_PREFIX, now.year, now.month, now.day, now.hour, now.minute, now.second]
	)


## 拡大縮小の変換から、黒帯を除いた画面の範囲(ウィンドウの画素)を出す
static func content_rect(final_transform: Transform2D, base: Vector2, window: Vector2i) -> Rect2i:
	var rect := Rect2(final_transform.origin, base * final_transform.get_scale())
	return Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, window))


static func capture(viewport: Viewport) -> Image:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var base := Vector2(IMAGE_SIZE)
	var region := content_rect(viewport.get_final_transform(), base, image.get_size())
	if region.has_area() and region.size != image.get_size():
		image = image.get_region(region)
	if image.get_size() != IMAGE_SIZE:
		image.resize(IMAGE_SIZE.x, IMAGE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return image


static func deliver(image: Image, text: String) -> Delivery:
	if image == null:
		return Delivery.FAILED
	var name := file_name(Time.get_datetime_dict_from_system())
	var png := image.save_png_to_buffer()
	if is_web():
		if JavaScriptBridge.eval(CAN_SHARE_JS, true):
			var b64 := JSON.stringify(Marshalls.raw_to_base64(png))
			JavaScriptBridge.eval(
				SHARE_JS % [b64, JSON.stringify(name), JSON.stringify(text)], true
			)
			return Delivery.SHARED
		JavaScriptBridge.download_buffer(png, name, MIME)
		return Delivery.SAVED
	var folder := save_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	if image.save_png(folder.path_join(name)) != OK:
		return Delivery.FAILED
	return Delivery.SAVED


static func save_folder() -> String:
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures == "":
		pictures = OS.get_user_data_dir()
	return pictures.path_join(FOLDER)
