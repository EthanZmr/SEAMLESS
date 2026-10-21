extends Node
## A8/A9 回归：暂停菜单 + 存档面板。
##
## 运行：godot --headless --path . res://tests/test_menu.tscn
##
## 直接把 main.tscn 挂进测试根节点，而不是切 current_scene —— 切场景会把测试
## 自己顶掉。代价是 `get_tree().current_scene` 仍指向测试场景，所以这里刻意
## 用 `_loop()` 显式取 Main 下的 GameLoop，不依赖 current_scene。

const MAIN := "res://scenes/main.tscn"
const TEST_SLOT := 3

var _fail := 0
var _total := 0
var _main: Node
var _menu: Control
var _slots: Control
var _settings: Control


func _ready() -> void:
	print("TEST_MENU: start")
	await _spawn()

	_test_scene_wiring()
	_test_initial_hidden()
	_test_pause_shows()
	_test_buttons()
	_test_settings_panel()
	_test_save_panel()
	await _test_save_roundtrip()
	_test_cleanup()

	print("TEST_MENU: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _spawn() -> void:
	_main = load(MAIN).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var layer := _main.get_node_or_null("MenuLayer")
	if layer != null:
		_menu = layer.get_node_or_null("PauseMenu")
	if _menu != null:
		for child in _menu.get_children():
			if child.get_script() != null and String(child.get_script().resource_path).ends_with("settings_panel.gd"):
				_settings = child
			elif child.get_script() != null and String(child.get_script().resource_path).ends_with("save_slots_panel.gd"):
				_slots = child


func _loop() -> Node:
	return _main.get_node_or_null("GameLoop") if _main != null else null


func _test_scene_wiring() -> void:
	_check(_menu != null, "main.tscn 里挂了 MenuLayer/PauseMenu")
	_check(_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "菜单在暂停时仍然处理输入")


func _test_initial_hidden() -> void:
	_check(_menu.visible == false, "未暂停时菜单隐藏")
	_check(_loop() != null and _loop().paused == false, "GameLoop 初始未暂停")


func _test_pause_shows() -> void:
	_loop().set_paused(true)
	_check(_menu.visible, "暂停后菜单显示")
	_check(get_tree().paused, "整棵树被暂停")
	_loop().set_paused(false)
	_check(not _menu.visible, "继续后菜单隐藏")
	_check(not get_tree().paused, "整棵树恢复")


func _test_buttons() -> void:
	var texts: Array[String] = []
	for child in _menu.get_node("Center/Menu").get_children():
		if child is Button:
			texts.append((child as Button).text)
	_check(texts.size() == 5, "主菜单 5 个按钮（got %d）" % texts.size())
	_check(texts.has(Loc.t("UI_RESUME")), "有「继续游戏」")
	_check(texts.has(Loc.t("UI_SETTINGS")), "有「设置」")
	_check(texts.has(Loc.t("UI_SAVE")), "有「保存进度」")
	_check(texts.has(Loc.t("UI_LOAD")), "有「读取进度」")


func _test_settings_panel() -> void:
	_check(_settings != null, "设置面板已实例化")
	_check(_settings.visible == false, "设置面板初始隐藏")
	_settings.visible = true
	_check(_settings.get_child_count() > 0, "设置面板有内容")
	_settings.visible = false


func _test_save_panel() -> void:
	_check(_slots != null, "存档面板已实例化")
	_slots.open(2)  # Mode.LOAD
	_check(_slots.visible, "open() 后存档面板可见")
	var list := _slots.get_node("Center/Box/Slots")
	_check(list.get_child_count() == 3, "三个档位（got %d）" % list.get_child_count())
	_slots.visible = false


func _test_save_roundtrip() -> void:
	SaveManager.delete_slot(TEST_SLOT)
	var ok := SaveManager.save_slot(TEST_SLOT)
	_check(ok, "存档到档位 3 成功")
	_check(SaveManager.has_slot(TEST_SLOT), "档位 3 存在")
	var info := SaveManager.slot_info(TEST_SLOT)
	_check(not info.is_empty(), "slot_info 能读到")
	_check(str(info.get("level_name", "")) == "雨市", "存档记了关卡名「雨市」")

	# 面板刷新应显示 3 行且第一行是可读信息（不是"空档位"）
	_slots.open(2)
	var list := _slots.get_node("Center/Box/Slots")
	var row := list.get_child(TEST_SLOT - 1) as Control
	var label := row.get_child(0) as Label
	_check(not label.text.contains(Loc.t("UI_EMPTY_SLOT")), "档位 3 不再显示空档位")
	_check(label.text.contains("雨市"), "档位 3 显示关卡名")

	SaveManager.delete_slot(TEST_SLOT)
	_check(not SaveManager.has_slot(TEST_SLOT), "删除后档位 3 消失")
	await get_tree().process_frame


func _test_cleanup() -> void:
	SaveManager.delete_slot(TEST_SLOT)
	if _loop() != null:
		_loop().set_paused(false)
	get_tree().paused = false
	_check(not get_tree().paused, "收尾时未暂停")


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
