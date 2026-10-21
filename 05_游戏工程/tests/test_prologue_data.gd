extends Node
## 第四刀回归：序章对白必须来自 data/dialogue/prologue_01.json。
##
## 运行：godot --headless --path . res://tests/test_prologue_data.tscn

const PROLOGUE_SCENE := "res://scenes/prologue.tscn"
const DIALOGUE_PATH := "res://data/dialogue/prologue_01.json"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_PROLOGUE_DATA: start")

	_check(FileAccess.file_exists(DIALOGUE_PATH), "prologue_01.json 已落到 data/dialogue/")

	var scene := load(PROLOGUE_SCENE) as PackedScene
	_check(scene != null, "序章场景可加载")
	if scene:
		var prologue := scene.instantiate()
		add_child(prologue)
		await get_tree().process_frame
		_check(prologue.lines_source == "json", "对白来源标记为 json")
		_check(prologue.LINES.size() == 34, "读到 34 行对白（got %d）" % prologue.LINES.size())
		if prologue.LINES.size() > 0:
			var first: Dictionary = prologue.LINES[0]
			_check(first.get("who") == "旁白", "首行说话人是旁白")
			_check(String(first.get("text", "")).begins_with("地下诊所"), "首行正文来自 JSON")
			_check(prologue.speaker.text == first.get("who"), "UI 首行说话人已同步")
			_check(prologue.progress.text == "01 / 34", "进度条显示 01 / 34（got %s）" % prologue.progress.text)
		prologue.queue_free()
		await get_tree().process_frame

	print("TEST_PROLOGUE_DATA: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
