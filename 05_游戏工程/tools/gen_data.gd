extends SceneTree
## 数据源生成器：把默认数值写成数据文件，供策划在编辑器里直接编辑。
##
## 运行：godot --headless --path . -s res://tools/gen_data.gd
##      godot --headless --path . -s res://tools/gen_data.gd -- --force   重置
##
## 只在首次建档、或需要把数据重置回代码默认值时使用。
## 日常调数值直接编辑 data/ 下的文件，不需要跑这个脚本。
## 已存在的文件不会被覆盖，除非带 --force。
##
## ## 为什么手写文本而不是 ResourceSaver
## ResourceSaver 会省略“等于脚本默认值”的字段。直接存的话，light_frames.tres 第一段
## 只剩下 3 个字段、player_stats.tres 只剩 script 一行 —— 数据文件看着是空的，
## 策划无法审阅，代码评审也看不到数值。
## 所以这里按 FIELD_NAMES 把每个字段显式落盘，写盘后立刻回读比对（round-trip），
## 任何字段值或类型漂移都以非 0 退出码报错。
## 两个 .tres 的字段清单都来自各自的 FIELD_NAMES 常量，加字段不用改本文件。

const AttackFramesScript := preload("res://scripts/combat/attack_frames.gd")
const AttackFrameSetScript := preload("res://scripts/combat/attack_frame_set.gd")
const PlayerStatsScript := preload("res://scripts/player/player_stats.gd")
const SyncRulesScript := preload("res://scripts/rules/sync_rules.gd")

const FRAMES_SCRIPT_PATH := "res://scripts/combat/attack_frames.gd"
const FRAME_SET_SCRIPT_PATH := "res://scripts/combat/attack_frame_set.gd"
const STATS_SCRIPT_PATH := "res://scripts/player/player_stats.gd"
const LIGHT_FRAMES_PATH := "res://data/combat/light_frames.tres"
const PLAYER_STATS_PATH := "res://data/player/player_stats.tres"
const SYNC_RULES_PATH := "res://data/rules/sync_rules.tres"

var _failures := 0


func _init() -> void:
	var force := "--force" in OS.get_cmdline_args() or "--force" in OS.get_cmdline_user_args()
	for dir in ["combat", "dialogue", "levels", "player", "rules"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/" + dir))

	if FileAccess.file_exists(LIGHT_FRAMES_PATH) and not force:
		print("SKIP  light_frames.tres 已存在（加 --force 覆盖）")
	else:
		var err := _save_frame_set()
		print("SAVE  light_frames.tres -> ", _err_name(err))
		if err != OK:
			_failures += 1

	if FileAccess.file_exists(PLAYER_STATS_PATH) and not force:
		print("SKIP  player_stats.tres 已存在（加 --force 覆盖）")
	else:
		var err := _save_player_stats()
		print("SAVE  player_stats.tres -> ", _err_name(err))
		if err != OK:
			_failures += 1

	if FileAccess.file_exists(SYNC_RULES_PATH) and not force:
		print("SKIP  sync_rules.tres 已存在（加 --force 覆盖）")
	else:
		var err := _save_sync_rules()
		print("SAVE  sync_rules.tres -> ", _err_name(err))
		if err != OK:
			_failures += 1

	if _failures > 0:
		print("GEN_FAILED (%d)" % _failures)
	else:
		print("GEN_OK")
	quit(1 if _failures > 0 else 0)


func _save_frame_set() -> int:
	var set_res: Resource = _build_frame_set()
	var segments: Array = [set_res.light1, set_res.light2, set_res.light3]

	var text := "[gd_resource type=\"Resource\" script_class=\"AttackFrameSet\" format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_frames\"]\n" % FRAMES_SCRIPT_PATH
	text += "[ext_resource type=\"Script\" path=\"%s\" id=\"2_set\"]\n\n" % FRAME_SET_SCRIPT_PATH

	for i in 3:
		text += "[sub_resource type=\"Resource\" id=\"Resource_light%d\"]\n" % (i + 1)
		text += "script = ExtResource(\"1_frames\")\n"
		text += _dump_fields(segments[i], AttackFramesScript.FIELD_NAMES)
		text += "\n"

	text += "[resource]\nscript = ExtResource(\"2_set\")\n"
	for i in 3:
		text += "light%d = SubResource(\"Resource_light%d\")\n" % [i + 1, i + 1]

	var err := _write_text(LIGHT_FRAMES_PATH, text)
	if err != OK:
		return err
	return _verify_frame_set()


func _save_player_stats() -> int:
	var stats: Resource = PlayerStatsScript.new()
	var text := "[gd_resource type=\"Resource\" script_class=\"PlayerStats\" format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_stats\"]\n\n" % STATS_SCRIPT_PATH
	text += "[resource]\nscript = ExtResource(\"1_stats\")\n"
	text += _dump_fields(stats, PlayerStatsScript.FIELD_NAMES)

	var err := _write_text(PLAYER_STATS_PATH, text)
	if err != OK:
		return err
	return _verify_player_stats(stats)


func _save_sync_rules() -> int:
	var rules: Resource = SyncRulesScript.new()
	var text := "[gd_resource type=\"Resource\" script_class=\"SyncRules\" format=3]

"
	text += "[ext_resource type=\"Script\" path=\"res://scripts/rules/sync_rules.gd\" id=\"1_rules\"]

"
	text += "[resource]
script = ExtResource(\"1_rules\")
"
	text += _dump_fields(rules, SyncRulesScript.FIELD_NAMES)

	var err := _write_text(SYNC_RULES_PATH, text)
	if err != OK:
		return err
	return _verify_sync_rules(rules)


## 逐字段落盘。Array[float] 必须带类型标注，否则文本 .tres 会加载成无类型 Array。
func _dump_fields(source: Resource, field_names: Array) -> String:
	var out := ""
	for field_name in field_names:
		var value: Variant = source.get(field_name)
		if value is Array:
			var parts := PackedStringArray()
			for item in value:
				parts.append(var_to_str(item))
			out += "%s = Array[float]([%s])\n" % [field_name, ", ".join(parts)]
		else:
			out += "%s = %s\n" % [field_name, var_to_str(value)]
	return out


func _write_text(path: String, text: String) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


## 回读校验：字段值/类型漂移、或帧表自检不过，都算失败。
func _verify_frame_set() -> int:
	var reloaded: Resource = ResourceLoader.load(
		LIGHT_FRAMES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded == null:
		print("  ERROR light_frames.tres 回读失败")
		return ERR_CANT_OPEN

	var expected_totals := [12, 13, 18]
	var bad := 0
	for i in 3:
		var frames: Variant = reloaded.frames_of(i)
		if frames == null:
			print("  ERROR 第 %d 段帧表为空" % (i + 1))
			bad += 1
			continue
		if frames.total_frames != expected_totals[i]:
			print("  ERROR 第 %d 段 total_frames=%d，应为 %d" % [
				i + 1, frames.total_frames, expected_totals[i]])
			bad += 1
		var problems: Array = frames.validate()
		if not problems.is_empty():
			print("  ERROR 第 %d 段自检失败：%s" % [i + 1, ", ".join(problems)])
			bad += 1
	if bad > 0:
		return ERR_INVALID_DATA
	print("  VERIFY light_frames.tres 回读一致（3 段 × %d 字段，自检通过）" % (
		AttackFramesScript.FIELD_NAMES.size()))
	return OK


func _verify_player_stats(expected: Resource) -> int:
	var reloaded: Resource = ResourceLoader.load(
		PLAYER_STATS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded == null:
		print("  ERROR player_stats.tres 回读失败")
		return ERR_CANT_OPEN

	var bad := 0
	for field_name in PlayerStatsScript.FIELD_NAMES:
		var want: Variant = expected.get(field_name)
		var got: Variant = reloaded.get(field_name)
		if typeof(want) != typeof(got) or want != got:
			print("  ERROR 字段漂移 %s：写入 %s，回读 %s" % [field_name, want, got])
			bad += 1
	if bad > 0:
		return ERR_INVALID_DATA
	print("  VERIFY player_stats.tres 回读一致（%d 字段）" % PlayerStatsScript.FIELD_NAMES.size())
	return OK


func _verify_sync_rules(expected: Resource) -> int:
	var reloaded: Resource = ResourceLoader.load(
		SYNC_RULES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded == null:
		print("  ERROR sync_rules.tres 回读失败")
		return ERR_CANT_OPEN

	var bad := 0
	for field_name in SyncRulesScript.FIELD_NAMES:
		var want: Variant = expected.get(field_name)
		var got: Variant = reloaded.get(field_name)
		if typeof(want) != typeof(got) or want != got:
			print("  ERROR 字段漂移 %s：写入 %s，回读 %s" % [field_name, want, got])
			bad += 1
	if bad > 0:
		return ERR_INVALID_DATA
	var problems: Array = reloaded.call("validate")
	if not problems.is_empty():
		print("  ERROR sync_rules 自检失败：%s" % ", ".join(problems))
		return ERR_INVALID_DATA
	print("  VERIFY sync_rules.tres 回读一致（%d 字段，自检通过）" % SyncRulesScript.FIELD_NAMES.size())
	return OK


func _build_frame_set() -> Resource:
	var set_res: Resource = AttackFrameSetScript.new()

	var l1: Resource = AttackFramesScript.new()
	l1.total_frames = 12
	l1.startup_frames = 3
	l1.hit_frame = 4
	l1.hit_time = 0.06
	l1.freeze_ms = 75
	l1.recovery_start_frame = 6
	l1.hitbox_forward = 84.0
	l1.hitbox_vertical = 62.0
	l1.jump_cancel_start_frame = 5
	l1.jump_cancel_end_frame = 8
	l1.combo_input_start_frame = 9
	l1.whiff_frames = 12
	l1.needle_reach = 79.0
	l1.needle_body = 37.0
	var lean: Array[float] = [12.0, 16.0]
	l1.body_lean = lean

	var l2: Resource = AttackFramesScript.new()
	l2.total_frames = 13
	l2.startup_frames = 4
	l2.hit_frame = 5
	l2.hit_time = 0.07
	l2.freeze_ms = 105
	l2.recovery_start_frame = 6
	l2.hitbox_forward = 88.0
	l2.hitbox_vertical = 62.0
	l2.jump_cancel_start_frame = 6
	l2.jump_cancel_end_frame = 9
	l2.combo_input_start_frame = 10
	l2.whiff_frames = 0
	l2.pull = true
	l2.pull_min_gap = 28.0
	l2.pull_speed_cap = 160.0

	var l3: Resource = AttackFramesScript.new()
	l3.total_frames = 18
	l3.startup_frames = 5
	l3.hit_frame = 6
	l3.hit_time = 0.09
	l3.freeze_ms = 160
	l3.recovery_start_frame = 7
	l3.hitbox_forward = 100.0
	l3.hitbox_vertical = 62.0
	l3.jump_cancel_start_frame = 0
	l3.jump_cancel_end_frame = 0
	l3.combo_input_start_frame = 0
	l3.whiff_frames = 0
	l3.knockback = 320.0
	l3.punch = 0.055
	l3.attack_cd_after = 0.30

	set_res.light1 = l1
	set_res.light2 = l2
	set_res.light3 = l3
	return set_res


func _err_name(err: int) -> String:
	match err:
		OK:
			return "OK"
		ERR_FILE_CANT_WRITE:
			return "ERR_FILE_CANT_WRITE"
		ERR_FILE_NO_PERMISSION:
			return "ERR_FILE_NO_PERMISSION"
		ERR_INVALID_DATA:
			return "ERR_INVALID_DATA"
		ERR_CANT_OPEN:
			return "ERR_CANT_OPEN"
		_:
			return "ERR_%d" % err
