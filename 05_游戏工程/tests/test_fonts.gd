extends Node
## B1 回归：字体加载器。
##
## 运行：godot --headless --path . res://tests/test_fonts.tscn
##
## 关键行为是"没有字体文件时也不能崩、不能返回 null"——白盒阶段就是这种情况，
## 所以这里刻意不断言某个具体字体名，只断言回退链生效。

const FONT_DIR := "res://assets/fonts"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_FONTS: start")
	_test_slots()
	_test_fallback()
	_test_cache()
	_test_reload()
	print("TEST_FONTS: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _test_slots() -> void:
	_check(DirAccess.dir_exists_absolute(FONT_DIR), "字体目录存在（可以是空的）")
	var names := Fonts.available()
	_check(names is Array, "available() 返回数组")
	# 当前仓库里没有字体文件；有的话这条会变红，提醒把断言改成"确实加载了文件"。
	_check(names.is_empty(), "当前没有字体文件（got %d）" % names.size())
	_check(Fonts.has(Fonts.SLOT_UI) == false, "ui 槽位走系统回退")
	_check(not Fonts.describe(Fonts.SLOT_UI).is_empty(), "describe 有内容")
	_check(Fonts.describe(Fonts.SLOT_UI).begins_with("system:"), "describe 说明是系统字体")


func _test_fallback() -> void:
	for slot in [Fonts.SLOT_UI, Fonts.SLOT_DISPLAY, Fonts.SLOT_MONO]:
		var font: Font = Fonts._font_for(slot, Fonts.SYSTEM_NAMES) \
			if slot != Fonts.SLOT_MONO else Fonts.mono()
		_check(font != null, "%s 槽位返回非 null" % slot)
	_check(Fonts.ui() is SystemFont, "ui() 回退成 SystemFont")
	_check(Fonts.display() is SystemFont, "display() 回退成 SystemFont")
	_check(Fonts.mono() is SystemFont, "mono() 回退成 SystemFont")
	var sys := Fonts.mono() as SystemFont
	_check(sys.font_names.size() > 0, "等宽回退链非空")
	_check(String(sys.font_names[0]) == "Consolas", "等宽首选 Consolas")
	var ui := Fonts.ui() as SystemFont
	_check(String(ui.font_names[0]) == "Microsoft YaHei", "UI 首选微软雅黑")
	_check(ui.allow_system_fallback, "允许系统字形回退（缺字时不留豆腐块）")


func _test_cache() -> void:
	var a := Fonts.ui()
	var b := Fonts.ui()
	_check(a == b, "同一个槽位复用同一实例")
	_check(is_same(a, b), "确实是同一对象，不是相等副本")


func _test_reload() -> void:
	Fonts.reload()
	var after := Fonts.ui()
	_check(after != null, "reload 后仍能取到字体")
	_check(after is SystemFont, "reload 后仍走回退")
	_check(Fonts.SIZE_BODY > 0 and Fonts.SIZE_HERO > Fonts.SIZE_BODY, "字号常量有序")


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
