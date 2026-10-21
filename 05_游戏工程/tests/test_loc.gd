extends Node
## A7 回归：本地化机制。
##
## 运行：godot --headless --path . res://tests/test_loc.tscn
##
## 注意：这个测试会切换全局 locale，结束时必须切回中文 —— 否则后续套件拿到的
## 界面文案会是英文（虽然断言大多不看文案，但顺序一变就难查）。

const CSV_PATH := "res://data/loc/strings.csv"
const ZH_PATH := "res://data/loc/strings.zh.translation"
const EN_PATH := "res://data/loc/strings.en.translation"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_LOC: start")

	_test_files()
	_test_project_setting()
	_test_zh_default()
	_test_switch()
	_test_placeholders()
	_test_missing_key()
	_test_cleanup()

	print("TEST_LOC: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _test_files() -> void:
	_check(FileAccess.file_exists(CSV_PATH), "strings.csv 存在")
	_check(FileAccess.file_exists(ZH_PATH), "strings.zh.translation 已生成")
	_check(FileAccess.file_exists(EN_PATH), "strings.en.translation 已生成")

	var text := FileAccess.get_file_as_string(CSV_PATH)
	_check(text.contains("UI_RESUME"), "CSV 含 UI_RESUME 键")
	_check(text.contains("Resume"), "CSV 含英文列")


func _test_project_setting() -> void:
	var cfg := ConfigFile.new()
	_check(cfg.load("res://project.godot") == OK, "project.godot 可读")
	var locales: Variant = cfg.get_value("internationalization", "locale/translations", [])
	_check(locales is PackedStringArray and (locales as PackedStringArray).size() >= 2,
		"project.godot 注册了两份翻译")
	_check(str(cfg.get_value("internationalization", "locale/fallback", "")) == "zh", "回退语言是 zh")


func _test_zh_default() -> void:
	Loc.set_locale("zh")
	_check(Loc.current_locale() == "zh", "默认语言 zh")
	_check(Loc.t("UI_RESUME") == "继续游戏", "UI_RESUME → 继续游戏（来自翻译文件）")
	_check(Loc.t("GAME_TITLE") == "无缝", "GAME_TITLE → 无缝")
	_check(Loc.has("UI_RESUME"), "has() 认得 UI_RESUME")


func _test_switch() -> void:
	Loc.set_locale("en")
	_check(Loc.t("UI_RESUME") == "Resume", "切到 en 后 UI_RESUME → Resume")
	_check(Loc.t("UI_SAVE") == "Save", "UI_SAVE → Save")

	Loc.set_locale("zh")
	_check(Loc.t("UI_SAVE") == "保存进度", "切回 zh 恢复中文")


func _test_placeholders() -> void:
	_check(Loc.t("UI_SLOT", [3]) == "档位 3", "占位符替换：档位 3")
	_check(Loc.t("UI_SLOT") == "档位 %d", "不传参数时保留占位符")


func _test_missing_key() -> void:
	_check(Loc.t("NO_SUCH_KEY_XYZ") == "NO_SUCH_KEY_XYZ", "缺键时原样返回 key")
	_check(not Loc.has("NO_SUCH_KEY_XYZ"), "has() 对缺键返回 false")


func _test_cleanup() -> void:
	Loc.set_locale("zh")
	_check(Loc.current_locale() == "zh", "收尾切回 zh")


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
