extends SceneTree
## 轻击第一段帧表规格测试（V8 定稿）。
## 运行：godot --headless --path . -s res://tests/test_attack_spec.gd
## 失败退出码非零，可直接做 CI 门禁。

const AS := preload("res://scripts/combat/attack_spec.gd")

var failures := 0
var total := 0


func _init() -> void:
	# --- 帧号映射：第 N 帧 = [(N-1)/60, N/60) ---
	_check(AS.frame_of(0.0) == 1, "0.0000s 是第 1 帧")
	_check(AS.frame_of(0.0167) == 2, "0.0167s 是第 2 帧")
	_check(AS.frame_of(0.0499) == 3, "0.0499s 是第 3 帧")
	_check(AS.frame_of(0.0500) == 4, "0.0500s 是第 4 帧（判定帧）")
	_check(AS.frame_of(0.0600) == 4, "0.060s 判定仍在第 4 帧")
	_check(AS.frame_of(0.0999) == 6, "0.0999s 是第 6 帧")
	_check(AS.frame_of(0.2000) == 13, "0.200s 是第 13 帧（收招结束）")

	# --- 跳取消窗：命中后 5-8f ---
	_check(not AS.jump_cancel_window(0.0599), "4f 不可跳取消")
	_check(AS.jump_cancel_window(0.0667), "5f 起点可跳取消")
	_check(AS.jump_cancel_window(0.1167), "8f 内可跳取消")
	_check(not AS.jump_cancel_window(0.1334), "9f 起点不可跳取消")
	_check(not AS.jump_cancel_window(0.2000), "收招末不可跳取消")

	# --- 连段输入窗：命中后 9f 起 ---
	_check(not AS.combo_input_allowed(0.1332), "8f 末不可连段")
	_check(AS.combo_input_allowed(0.1334), "9f 起点可连段")
	_check(AS.combo_input_allowed(0.2000), "收招末仍可连段排队")

	# --- 数据源：数值必须来自 data/combat/light_frames.tres，而不是内置兜底 ---
	_check(AS.data_source == "resource", "帧表来自 light_frames.tres 数据文件")

	# --- 帧表数值与设计定稿对齐 ---
	_check(AS.LIGHT1.freeze_ms == 75, "hit-stop 75ms")
	_check(AS.LIGHT1.jump_cancel_start_frame == 5, "跳取消起 5f")
	_check(AS.LIGHT1.jump_cancel_end_frame == 8, "跳取消止 8f")
	_check(AS.LIGHT1.combo_input_start_frame == 9, "连段起 9f")
	_check(AS.LIGHT1.hitbox_forward == 84.0, "判定水平 84px")
	_check(AS.LIGHT1.hitbox_vertical == 62.0, "判定垂直 62px")
	_check(AS.LIGHT1.needle_reach == 79.0, "针尖 79px")

	# --- 时间账：4f 真实 50-141.7ms、时长 91.7ms ---
	_check(absf(AS.freeze_end_time() - 0.141667) < 0.0001, "4f 结束真实时刻 0.1417s")
	_check(absf(AS.freeze_end_time() - AS.elapsed_of_frame(4) - 0.091667) < 0.0001, "4f 真实时长 91.7ms")

	# --- 数据文件完整性 ---
	# ResourceSaver 会省略“等于脚本默认值”的字段，直接存会得到一张空表。
	# 所以 .tres 必须由 tools/gen_data.gd 按 FIELD_NAMES 全字段落盘；
	# 这里守住这条线：少一个字段，策划就会在编辑器里看到一个“不存在的默认值”。
	var FRAMES := preload("res://scripts/combat/attack_frames.gd")
	var frames_text := FileAccess.get_file_as_string(AS.FRAMES_PATH)
	var missing := PackedStringArray()
	for field_name in FRAMES.FIELD_NAMES:
		if frames_text.count("\n%s = " % field_name) != 3:
			missing.append(field_name)
	_check(missing.is_empty(), "light_frames.tres 三段 × %d 字段齐全%s" % [
		FRAMES.FIELD_NAMES.size(),
		"" if missing.is_empty() else "（缺 %s）" % ", ".join(missing)])

	var set_res: Variant = load(AS.FRAMES_PATH)
	var invalid := PackedStringArray()
	if set_res != null:
		for i in 3:
			var problems: Array = set_res.frames_of(i).validate()
			if not problems.is_empty():
				invalid.append("第%d段: %s" % [i + 1, ", ".join(problems)])
	_check(invalid.is_empty(), "三段帧表自检全部通过%s" % (
		"" if invalid.is_empty() else "（%s）" % "；".join(invalid)))

	if failures == 0:
		print("TEST_ATTACK_SPEC: PASS (%d assertions)" % total)
	else:
		print("TEST_ATTACK_SPEC: FAIL (%d failures)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	total += 1
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
