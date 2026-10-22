extends SceneTree
## 从关卡 JSON 生成编辑场景 level_src/<id>.tscn（一次性迁移，或 JSON 被手改后重新同步）。
##
## 用法：
##   godot --headless --path . -s res://tools/level_json_to_scene.gd -- rain_market
##   godot --headless --path . -s res://tools/level_json_to_scene.gd -- rain_market --force   覆盖已有场景
##
## 之后在编辑器里打开 level_src/<id>.tscn 摆放，改完跑 tools/export_level.gd 写回 JSON。

const Exporter := preload("res://scripts/level/authoring/level_exporter.gd")


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var args := OS.get_cmdline_user_args()
	var ids := Array(args).filter(func(a): return not String(a).begins_with("--"))
	if ids.size() != 1:
		printerr("用法：-s res://tools/level_json_to_scene.gd -- <level_id> [--force]")
		return 2
	var level_id := String(ids[0])
	var src := Exporter.data_path(level_id)
	var dst := Exporter.scene_path(level_id)
	if not FileAccess.file_exists(src):
		printerr("找不到关卡数据 %s" % src)
		return 1
	if FileAccess.file_exists(dst) and not "--force" in args:
		printerr("%s 已存在（加 --force 覆盖；会丢掉编辑器里没导出的改动）" % dst)
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(src))
	if not parsed is Dictionary:
		printerr("%s 不是合法 JSON 对象" % src)
		return 1

	var root := Exporter.dict_to_scene(parsed)
	var errors: Array = []
	var back := Exporter.to_json_text(Exporter.scene_to_dict(root, errors))
	# 按解析后的内容比：JSON 里的整数（如 size）读回来是 float，逐字比会误报。
	if not errors.is_empty() or JSON.parse_string(back) != parsed:
		printerr("JSON → 场景 → JSON 不一致，未写入。%s" % "; ".join(errors))
		root.free()
		return 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Exporter.SRC_DIR))
	var err := ResourceSaver.save(Exporter.pack(root), dst)
	root.free()
	if err != OK:
		printerr("保存 %s 失败：%s" % [dst, error_string(err)])
		return 1
	print("OK  %s → %s" % [src, dst])
	return 0
