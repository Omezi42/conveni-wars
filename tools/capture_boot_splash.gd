extends SceneTree
## Webの読み込み中に出す絵(GameDesign.md 10章)を、タイトルの通りと題字から撮って assets/boot_splash.png へ書く。
## ボタンと歩く客は除く。タイトルの絵を変えたら撮り直す。
## ウィンドウを開いて描くため --headless では撮れない(capture_screens.gd と同じ)。
## godot --path . --script res://tools/capture_boot_splash.gd

const TITLE_SCENE := "res://scenes/title.tscn"
const OUT_PATH := "res://assets/boot_splash.png"
const SETTLE_FRAMES := 6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var title: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	root.add_child(title)
	for child in title.get_children():
		child.queue_free()
	for i in SETTLE_FRAMES:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("boot splash saved: ", OUT_PATH)
	title.queue_free()
	await process_frame
	quit()
