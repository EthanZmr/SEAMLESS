extends SceneTree
## 关卡编辑场景 ↔ JSON 互转守门。
##
## 1) JSON → 场景 → JSON 逐字节不变（导出器不会悄悄改写数据）。
## 2) 仓库里的 level_src/<id>.tscn 导出结果与 data/levels/<id>.json 一致
##    （拦住"场景改了没导出"和"JSON 被手改、场景没同步"）。
## 3) 结构错误能被报出来，不会静默导出缺数据的关卡。
## 运行：bash tools/test_all.sh test_level_authoring

const Exporter := preload("res://scripts/level/authoring/level_exporter.gd")
const EntryScript := preload("res://scripts/level/authoring/level_entry.gd")

var failures := 0
var total := 0


func _init() -> void:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/index.json"))
	var ids: Array = []
	if index is Dictionary:
		for level in index.get("levels", []):
			ids.append(String(level.get("id", "")))
	_check(not ids.is_empty(), "关卡清单非空")

	for level_id in ids:
		var json_text := FileAccess.get_file_as_string(Exporter.data_path(level_id))
		var parsed: Variant = JSON.parse_string(json_text)
		_check(parsed is Dictionary, "%s.json 可解析" % level_id)
		if not parsed is Dictionary:
			continue

		var root := Exporter.dict_to_scene(parsed)
		var errors: Array = []
		var round_trip := Exporter.to_json_text(Exporter.scene_to_dict(root, errors))
		_check(errors.is_empty(), "%s JSON→场景 无结构错误 %s" % [level_id, errors])
		_check(round_trip == json_text, "%s JSON→场景→JSON 逐字节不变" % level_id)
		root.free()

		var scene_path := Exporter.scene_path(level_id)
		_check(ResourceLoader.exists(scene_path), "%s 有编辑场景 %s" % [level_id, scene_path])
		var packed := load(scene_path) as PackedScene
		if packed:
			var src := packed.instantiate()
			var src_errors: Array = []
			var exported := Exporter.to_json_text(Exporter.scene_to_dict(src, src_errors))
			_check(src_errors.is_empty(), "%s 编辑场景无结构错误 %s" % [level_id, src_errors])
			_check(exported == json_text,
				"%s 编辑场景与 JSON 一致（不一致就跑 tools/export_level.gd -- %s）" % [level_id, level_id])
			src.free()

	_check_shift_semantics()
	_check_structure_errors()

	if failures == 0:
		print("TEST_LEVEL_AUTHORING: PASS (%d assertions)" % total)
	else:
		print("TEST_LEVEL_AUTHORING: FAIL (%d failures)" % failures)
	quit(0 if failures == 0 else 1)


## 编辑器里看到的是世界坐标；shift_east 条目导出时减去 east_shift。
func _check_shift_semantics() -> void:
	var data := {
		"meta": {"id": "t", "display_name": "t", "east_shift": 2000.0,
			"bounds": {"left": 0.0, "right": 100.0, "top": 0.0, "bottom": 100.0}},
		"platforms": [{"rect": [10.0, 20.0, 30.0, 40.0], "color": "#1B2A3F", "shift": "east"}],
		"boss_trigger": {"pos": [100.0, 50.0], "boss_spawn": [300.0, 60.0], "shift": "east"},
	}
	var root := Exporter.dict_to_scene(data)
	var plat := root.get_node("platforms/platforms_01") as Node2D
	_check(plat.position == Vector2(2010, 20), "shift_east 平台在场景里是世界坐标 (2010, 20)")
	var boss := root.get_node("boss_trigger/boss_trigger_01")
	_check(boss.boss_spawn == Vector2(2300, 60), "Boss 刷出点同样平移")

	plat.position += Vector2(5, 0)
	var out := Exporter.scene_to_dict(root)
	_check(out["platforms"][0]["rect"] == [15.0, 20.0, 30.0, 40.0], "在编辑器里右移 5px → JSON rect.x 15")
	_check(out["boss_trigger"]["boss_spawn"] == [300.0, 60.0], "Boss 刷出点导出时减回 east_shift")
	root.free()


func _check_structure_errors() -> void:
	var root := Exporter.dict_to_scene({"meta": {"id": "t"}})
	var stray := Node2D.new()
	stray.name = "platform"  # 少了 s：分类名拼错
	root.add_child(stray)
	var not_entry := Node2D.new()
	not_entry.name = "plain"
	root.get_node("enemies").add_child(not_entry)
	root.get_node("boss_trigger").add_child(EntryScript.new())
	root.get_node("boss_trigger").add_child(EntryScript.new())
	var errors: Array = []
	Exporter.scene_to_dict(root, errors)
	var joined := " | ".join(errors)
	_check("未知分类容器 platform" in joined, "拼错的分类容器会报错")
	_check("enemies/plain 不是 LevelEntry" in joined, "混进非 LevelEntry 节点会报错")
	_check("boss_trigger 只能有 1 个条目" in joined, "多个 Boss 触发点会报错")
	root.free()


func _check(condition: bool, label: String) -> void:
	total += 1
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
