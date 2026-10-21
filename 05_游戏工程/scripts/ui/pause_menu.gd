extends Control
## 暂停菜单。**纯代码构建 UI**：项目里没有 Theme/字体资源，手搭控件比维护 .tscn
## 更容易保证和 HUD 的配色一致（同一个 ACCENT 常量），也省掉场景文件里几十行
## 属性覆盖。
##
## 关键点：整个菜单必须 PROCESS_MODE_ALWAYS。暂停用的是 get_tree().paused，
## 默认模式下 Control 收不到 gui_input，按钮会变成"看得见点不动"。
##
## 分工：ESC 的**开关**在 GameLoop（它只负责 set_paused），本文件只负责显示与
## 操作，免得两处都去改 paused 打出"按一次开两次关"。

const ACCENT := Color("#3FE0D0")
const DIM := Color(0.04, 0.05, 0.07, 0.86)
const IDLE := Color("#D9E6F2")

var _root: VBoxContainer
var _title: Label
var _buttons: Array[Button] = []
const SaveSlotsPanelScript := preload("res://scripts/ui/save_slots_panel.gd")
const SettingsPanelScript := preload("res://scripts/ui/settings_panel.gd")

var _settings: Control
var _slots: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	GameEvents.pause_changed.connect(_on_pause_changed)
	var loop := _game_loop()
	if loop != null and bool(loop.paused):
		_show()


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = DIM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_root = VBoxContainer.new()
	_root.name = "Menu"
	_root.add_theme_constant_override("separation", 10)
	_root.custom_minimum_size = Vector2(320, 0)
	center.add_child(_root)

	_title = Label.new()
	_title.text = Loc.t("UI_PAUSED")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", ACCENT)
	_root.add_child(_title)

	_add_button(Loc.t("UI_RESUME"), _on_resume)
	_add_button(Loc.t("UI_SETTINGS"), _on_settings)
	_add_button(Loc.t("UI_SAVE"), _on_save)
	_add_button(Loc.t("UI_LOAD"), _on_load)
	_add_button(Loc.t("UI_RESTART"), _on_restart)

	_settings = SettingsPanelScript.new()
	_settings.name = "SettingsPanel"
	_settings.visible = false
	_settings.closed.connect(_on_sub_closed)
	add_child(_settings)

	_slots = SaveSlotsPanelScript.new()
	_slots.name = "SlotsPanel"
	_slots.visible = false
	_slots.closed.connect(_on_sub_closed)
	add_child(_slots)


func _add_button(label: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(320, 42)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(handler)
	_root.add_child(b)
	_buttons.append(b)


func _on_pause_changed(paused: bool) -> void:
	if paused:
		_show()
	else:
		_hide()


func _show() -> void:
	visible = true
	_close_sub()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _hide() -> void:
	visible = false
	_settings.visible = false
	_slots.visible = false


func _close_sub() -> void:
	_settings.visible = false
	_slots.visible = false
	_root.visible = true


func _on_sub_closed() -> void:
	_close_sub()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


## GameLoop 不是 autoload，它是 main.tscn 里的子节点 —— 只能从当前场景取。
## 直接写 `GameLoop.set_paused()` 会在编译期通过、运行期报 Nonexistent。
##
## 两级查找：先按名字在 current_scene 下找（正常游戏路径），再退化成从自己往上
## 找兄弟节点。后者覆盖"Main 被作为子场景挂进别的根"的情况（测试就是这么干的），
## 否则菜单在测试里点"继续"会静默失效。
func _game_loop() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var direct := scene.get_node_or_null("GameLoop")
		if direct != null:
			return direct
	var cursor := get_parent()
	while cursor != null:
		var found := cursor.get_node_or_null("GameLoop")
		if found != null:
			return found
		cursor = cursor.get_parent()
	return null


func _on_resume() -> void:
	var loop := _game_loop()
	if loop != null:
		loop.set_paused(false)


func _on_settings() -> void:
	_root.visible = false
	_settings.visible = true


func _on_save() -> void:
	_root.visible = false
	_slots.open(SaveSlotsPanelScript.Mode.SAVE)


func _on_load() -> void:
	_root.visible = false
	_slots.open(SaveSlotsPanelScript.Mode.LOAD)


func _on_restart() -> void:
	var loop := _game_loop()
	if loop != null:
		loop.set_paused(false)
	LevelManager.restart_level()
