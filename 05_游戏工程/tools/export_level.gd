extends SceneTree
## 把编辑场景 level_src/<id>.tscn 导出成运行时读的 data/levels/<id>.json。
##
## 用法：
##   godot --headless --path . -s res://tools/export_level.gd -- rain_market
##   godot --headless --path . -s res://tools/export_level.gd -- rain_market --check   只比对，不写（CI/自查用）
##
## 结构有问题（未知分类容器、混进非 LevelEntry 节点、多个 Boss 触发点）时不写文件，退出码 1。

const Exporter := preload("res://scripts/level/authoring/level_exporter.gd")


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var args := OS.get_cmdline_user_args()
	var ids := Array(args).filter(func(a): return not String(a).begins_with("--"))
	if ids.size() != 1:
		printerr("用法：-s res://tools/export_level.gd -- <level_id> [--check]")
		return 2
	var level_id := String(ids[0])
	var src := Exporter.scene_path(level_id)
	var dst := Exporter.data_path(level_id)
	var packed := load(src) as PackedScene
	if packed == null:
		printerr("找不到编辑场景 %s（先跑 tools/level_json_to_scene.gd）" % src)
		return 1
	var root := packed.instantiate()
	var errors: Array = []
	var data := Exporter.scene_to_dict(root, errors)
	root.free()
	if not errors.is_empty():
		for e in errors:
			printerr("  ", e)
		printerr("场景结构有问题，未导出")
		return 1
	if String(data["meta"]["id"]) != level_id:
		printerr("场景 level_id=%s 与参数 %s 不一致" % [data["meta"]["id"], level_id])
		return 1

	var text := Exporter.to_json_text(data)
	var old := FileAccess.get_file_as_string(dst) if FileAccess.file_exists(dst) else ""
	if "--check" in args:
		if text == old:
			print("OK  %s 与 %s 一致" % [src, dst])
			return 0
		printerr("%s 与 %s 不一致：场景改过但没导出，或 JSON 被手改" % [src, dst])
		return 1
	if text == old:
		print("SKIP  %s 无变化" % dst)
		return 0
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		printerr("写入 %s 失败：%s" % [dst, error_string(FileAccess.get_open_error())])
		return 1
	f.store_string(text)
	f.close()
	# 写完回读：确认落盘内容能被 level.gd 当作合法 JSON 读回。
	var reread: Variant = JSON.parse_string(FileAccess.get_file_as_string(dst))
	if not reread is Dictionary or reread != JSON.parse_string(text):
		printerr("回读校验失败：%s" % dst)
		return 1
	print("OK  %s → %s（平台 %d / 敌人 %d）" % [src, dst, data["platforms"].size(), data["enemies"].size()])
	return 0
