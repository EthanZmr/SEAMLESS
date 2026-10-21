extends Node
## A10 回归：对话系统泛化（DialogueScript / DialoguePlayer / DialogueBox）。
##
## 运行：godot --headless --path . res://tests/test_dialogue.tscn
##
## 三层各测各的：数据层是纯函数（无节点），推进器是 Node（无 UI），
## 对话框是 Control（无场景依赖）。这样任何一层坏了都能立刻定位。

const PROLOGUE_PATH := "res://data/dialogue/prologue_01.json"
const MISSING_PATH := "res://data/dialogue/__nope__.json"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_DIALOGUE: start")
	_test_load_ok()
	_test_normalize()
	_test_load_missing()
	_test_validate()
	_test_player_flow()
	_test_player_stop()
	await _test_box()
	print("TEST_DIALOGUE: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _test_load_ok() -> void:
	var result := DialogueScript.load_lines(PROLOGUE_PATH)
	_check(result.source == "json", "序章 JSON 加载成功")
	_check(result.lines.size() == 34, "序章 34 行（got %d）" % result.lines.size())
	_check(result.error.is_empty(), "无错误信息")
	_check(String(result.lines[0]["who"]) == "旁白", "首行是旁白")
	var first_text := String(result.lines[0]["text"])
	_check(first_text.begins_with("地下诊所"), "首行正文以「地下诊所」开头")
	_check(result.lines[0].has("color") and not String(result.lines[0]["color"]).is_empty(),
		"每行都有颜色")


func _test_normalize() -> void:
	var bare := DialogueScript.normalize({"who": "阿针", "text": "测试"})
	_check(bare.size() == 3, "标准化后只有 3 个字段")
	_check(String(bare["color"]) == DialogueScript.DEFAULT_COLOR, "有名字的行用默认色")
	var narrator := DialogueScript.normalize({"who": "", "text": "旁白测试"})
	_check(String(narrator["color"]) == DialogueScript.NARRATOR_COLOR, "无名行用旁白色")
	_check(DialogueScript.is_narrator(narrator), "空 who 判定为旁白")
	_check(not DialogueScript.is_narrator(bare), "有名字的不是旁白")
	var extra := DialogueScript.normalize({"who": "A", "text": "B", "junk": 1})
	_check(not extra.has("junk"), "多余字段被丢弃")


func _test_load_missing() -> void:
	var result := DialogueScript.load_lines(MISSING_PATH)
	_check(result.source == "fallback", "缺文件时退化为 fallback")
	_check(result.lines.size() == 1, "退化后仍有一行可播")
	_check(not result.error.is_empty(), "记录了错误原因")
	_check(String(result.lines[0]["text"]).contains("缺失"), "提示行说明了缺失")


func _test_validate() -> void:
	var good := DialogueScript.load_lines(PROLOGUE_PATH).lines
	_check(DialogueScript.validate(good).is_empty(), "序章 34 行全部通过校验")
	var bad: Array = [
		{"who": "A", "text": ""},
		{"who": "B", "text": "正常", "color": "not-a-color"},
		{"who": "C", "text": "x".repeat(200), "color": "#FFFFFF"},
	]
	var problems := DialogueScript.validate(bad)
	# 第 1 行同时犯了两个错（空文本 + 缺颜色），所以是 4 条而不是 3 条。
	_check(problems.size() == 4, "四类问题都被报出（got %d）" % problems.size())
	_check(problems.any(func(p): return p.contains("文本为空")), "报出空文本")
	_check(problems.any(func(p): return p.contains("颜色无法解析")), "报出非法颜色")
	_check(problems.any(func(p): return p.contains("140")), "报出超长行")
	_check(DialogueScript.validate([]).size() == 1, "空数组报「没有对白行」")


func _test_player_flow() -> void:
	var player := DialoguePlayer.new()
	add_child(player)
	var seen: Array[int] = []
	var finished_count := [0]
	player.line_changed.connect(func(_line, i, _t): seen.append(i))
	player.finished.connect(func(): finished_count[0] += 1)

	var lines: Array = [
		{"who": "阿针", "text": "一"},
		{"who": "阿绫", "text": "二"},
		{"who": "骑手", "text": "三"},
	]
	player.start(lines)
	_check(player.index == 0, "start 后停在第一行")
	_check(player.total() == 3, "总行数 3")
	_check(player.position() == 1, "位置从 1 起算")
	_check(String(player.current()["text"]) == "一", "current 是第一行")
	_check(player.has_next(), "还有下一行")

	_check(player.advance(), "advance 成功")
	_check(String(player.current()["text"]) == "二", "推进到第二行")
	_check(player.advance(), "再 advance 成功")
	_check(player.position() == 3, "位置 3")

	# 最后一行再 advance：结束，返回 false，finished 只发一次
	_check(not player.advance(), "末行 advance 返回 false")
	_check(not player.is_playing(), "结束后不再播放")
	_check(finished_count[0] == 1, "finished 只发一次（got %d）" % finished_count[0])
	_check(seen == [0, 1, 2], "line_changed 依次发了 0/1/2（got %s）" % str(seen))

	# 结束后再 advance 不应重复发 finished
	_check(not player.advance(), "结束后 advance 仍返回 false")
	_check(finished_count[0] == 1, "finished 没有被重复发")
	player.queue_free()


func _test_player_stop() -> void:
	var player := DialoguePlayer.new()
	add_child(player)
	var finished_count := [0]
	player.finished.connect(func(): finished_count[0] += 1)
	player.start([{"who": "A", "text": "x"}, {"who": "B", "text": "y"}])
	player.stop()
	_check(not player.is_playing(), "stop 后停止播放")
	_check(finished_count[0] == 1, "stop 发了 finished")
	player.advance()
	_check(finished_count[0] == 1, "stop 后再 advance 不重复发")

	# 空数组：start 立即结束
	var empty := DialoguePlayer.new()
	add_child(empty)
	var empty_finished := [0]
	empty.finished.connect(func(): empty_finished[0] += 1)
	empty.start([])
	_check(empty_finished[0] == 1, "空数组 start 立即发 finished")
	_check(empty.current().is_empty(), "空数组 current 返回空字典")
	player.queue_free()
	empty.queue_free()


func _test_box() -> void:
	var box: Control = load("res://scripts/ui/dialogue_box.gd").new()
	add_child(box)
	await get_tree().process_frame
	_check(box.visible == false, "对话框初始隐藏")
	_check(box.get_node_or_null("Bg") != null, "有背景节点")
	_check(box.get_node_or_null("Speaker") != null, "有名字条")
	_check(box.get_node_or_null("Body") != null, "有正文")
	_check(box.get_node_or_null("Hint") != null, "有提示条")

	box.open_file(PROLOGUE_PATH)
	_check(box.visible, "open_file 后可见")
	_check(box.source == "json", "对话框读到 JSON")
	_check(box.player.total() == 34, "对话框载入 34 行")
	var speaker: Label = box.get_node("Speaker")
	var hint: Label = box.get_node("Hint")
	_check(hint.text == "01 / 34", "提示条显示 01 / 34（got %s）" % hint.text)
	_check(speaker.text == "", "旁白行不显示名字")

	# 第一次 advance：跳过打字机；第二次：推进到下一行
	box.advance()
	_check(box.player.index == 0, "首次 advance 只跳过打字机")
	box.advance()
	_check(box.player.index == 1, "再次 advance 才推进")
	_check(hint.text == "02 / 34", "提示条跟着走")

	box.close()
	_check(box.visible == false, "close 后隐藏")
	_check(not box.player.is_playing(), "close 同时停掉推进器")
	box.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
