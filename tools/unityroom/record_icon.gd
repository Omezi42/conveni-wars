extends SceneTree
## thumbnail_art.gd をループ1周ぶん、コマごとに PNG へ書き出す(GIFへの変換は make_thumbnails.sh)。
## 輪郭をなめらかにするため、2倍の大きさで描いて縮める。
## ウィンドウを開いて描くため --headless では撮れない:
##   godot --path . --script res://tools/unityroom/record_icon.gd -- <出力フォルダ>

const ART := preload("res://tools/unityroom/thumbnail_art.gd")
const FPS := 15
const SUPERSAMPLE := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = (
		args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://logs/icon")
	)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var art: Control = ART.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Vector2(ART.SIDE, ART.SIDE) * SUPERSAMPLE)
	viewport.size_2d_override = Vector2i(ART.SIDE, ART.SIDE)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(art)
	root.add_child(viewport)
	for frame in int(ART.LOOP * FPS):
		art.t = float(frame) / FPS
		art.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(out_dir.path_join("f%04d.png" % frame))
	print("recorded to ", out_dir)
	quit()
