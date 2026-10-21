extends Control
## 存档面板：3 个手工档位（自动存档以后另开一份，别混在这里 —— 自动档要按
## 章节滚动、要能被覆盖，和"我按了保存"是两件事）。
##
## 数据全部来自 SaveManager.slot_info()，面板自己不碰 GameState：
## 列存档不该有副作用（早期版本里"预览"和"读取"共用一条路径，结果一开面板
## 就把当前进度覆盖了）。

signal closed

enum Mode { SAVE, LOAD }

const ACCENT := Color("#3FE0D0")
const MUTED := Color("#7F93A6")
const SLOTS := 3

var mode: Mode = Mode.SAVE

var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_list = VBoxContainer.new()
	_list.name = "Slots"
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)

	var back := Button.new()
	back.text = Loc.t("UI_BACK")
	back.custom_minimum_size = Vector2(560, 40)
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)


func open(next_mode: Mode) -> void:
	mode = next_mode
	_title.text = Loc.t("UI_SAVE") if mode == Mode.SAVE else Loc.t("UI_LOAD")
	_refresh()
	visible = true


func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for slot in range(1, SLOTS + 1):
		_list.add_child(_slot_row(slot))


func _slot_row(slot: int) -> Control:
	var info := SaveManager.slot_info(slot)
	var exists := not info.is_empty()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.custom_minimum_size = Vector2(400, 0)
	label.add_theme_font_size_override("font_size", 16)
	if exists:
		var stamp := int(info.get("saved_at", 0))
		var when := Time.get_datetime_string_from_unix_time(stamp, true) if stamp > 0 else ""
		var level: String = str(info.get("level_name", ""))
		label.text = "%s · %s · %s" % [Loc.t("UI_SLOT", [slot]), level, when]
	else:
		label.text = "%s · %s" % [Loc.t("UI_SLOT", [slot]), Loc.t("UI_EMPTY_SLOT")]
		label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)

	if mode == Mode.SAVE:
		var save_btn := Button.new()
		save_btn.text = Loc.t("UI_SAVE")
		save_btn.custom_minimum_size = Vector2(120, 34)
		save_btn.pressed.connect(func() -> void:
			if SaveManager.save_slot(slot):
				GameEvents.message.emit(Loc.t("UI_SAVED"))
				_refresh()
			else:
				GameEvents.message.emit(Loc.t("UI_SAVE_FAILED")))
		row.add_child(save_btn)
	else:
		var load_btn := Button.new()
		load_btn.text = Loc.t("UI_LOAD")
		load_btn.custom_minimum_size = Vector2(120, 34)
		load_btn.disabled = not exists
		load_btn.pressed.connect(func() -> void:
			var loop := get_tree().current_scene.get_node_or_null("GameLoop")
			if loop != null:
				loop.set_paused(false)
			if not SaveManager.load_slot_and_enter(slot):
				GameEvents.message.emit(Loc.t("UI_LOAD_FAILED")))
		row.add_child(load_btn)

	var del := Button.new()
	del.text = Loc.t("UI_DELETE")
	del.custom_minimum_size = Vector2(90, 34)
	del.disabled = not exists
	del.pressed.connect(func() -> void:
		SaveManager.delete_slot(slot)
		_refresh())
	row.add_child(del)

	return row
