extends Control
## 设置面板：音频 / 画面 / 手感 / 按键。
##
## 所有控件**直接读写 Settings**，不维护副本 —— 单一真相。如果这里再存一份，
## 就会出现"面板显示 80%、实际播放 40%"这类双真相 bug。
##
## 按键重绑用最省事的做法：点动作 → 进入捕获态 → 下一次物理按键即绑定。
## 不弹对话框，因为对话框要处理焦点恢复与 ESC 冲突，收益不值。

signal closed

const ACCENT := Color("#3FE0D0")
const MUTED := Color("#7F93A6")
const WIDTH := 560.0

var _list: VBoxContainer
var _capturing: StringName = &""
var _capture_button: Button


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

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_header(Loc.t("UI_SETTINGS"))

	_section(Loc.t("UI_SECTION_AUDIO"))
	_slider(Loc.t("UI_VOLUME_MASTER"), "audio", "master_db")
	_slider(Loc.t("UI_VOLUME_MUSIC"), "audio", "music_db")
	_slider(Loc.t("UI_VOLUME_SFX"), "audio", "sfx_db")
	_slider(Loc.t("UI_VOLUME_UI"), "audio", "ui_db")
	_slider(Loc.t("UI_VOLUME_AMBIENCE"), "audio", "ambience_db")

	_section(Loc.t("UI_SECTION_VIDEO"))
	_toggle(Loc.t("UI_FULLSCREEN"), "video", "fullscreen")
	_toggle(Loc.t("UI_VSYNC"), "video", "vsync")
	_options(Loc.t("UI_MAX_FPS"), "video", "max_fps", [0, 30, 60, 120, 144],
		["不限", "30", "60", "120", "144"])

	_section(Loc.t("UI_SECTION_GAMEPLAY"))
	_toggle(Loc.t("UI_HITSTOP"), "gameplay", "hitstop")

	_section(Loc.t("UI_SECTION_INPUT"))
	for action in InputRebind.ACTIONS:
		_bind_row(action)

	_section("")
	_action_button(Loc.t("UI_RESET_DEFAULTS"), _on_reset)
	_action_button(Loc.t("UI_BACK"), func() -> void: closed.emit())


# --- 构建小件 --------------------------------------------------------------

func _header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(l)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", MUTED)
	if text.is_empty():
		l.custom_minimum_size = Vector2(0, 8)
	_list.add_child(l)


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(180, 0)
	l.add_theme_font_size_override("font_size", 16)
	row.add_child(l)
	_list.add_child(row)
	return row


func _slider(label: String, section: String, key: String) -> void:
	var row := _row(label)
	var slider := HSlider.new()
	slider.min_value = Settings.MUTE_DB
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = float(Settings.get_value(section, key))
	slider.custom_minimum_size = Vector2(300, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d dB" % int(slider.value)
	value_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d dB" % int(v)
		Settings.set_value(section, key, v))


func _toggle(label: String, section: String, key: String) -> void:
	var row := _row(label)
	var check := CheckButton.new()
	check.button_pressed = bool(Settings.get_value(section, key))
	check.toggled.connect(func(on: bool) -> void: Settings.set_value(section, key, on))
	row.add_child(check)


func _options(label: String, section: String, key: String,
		values: Array, labels: Array) -> void:
	var row := _row(label)
	var opt := OptionButton.new()
	for i in values.size():
		opt.add_item(str(labels[i]), int(values[i]))
	var current := int(Settings.get_value(section, key))
	for i in values.size():
		if int(values[i]) == current:
			opt.select(i)
	opt.item_selected.connect(func(idx: int) -> void:
		Settings.set_value(section, key, int(values[idx])))
	row.add_child(opt)


func _bind_row(action: StringName) -> void:
	var row := _row(str(InputRebind.LABELS.get(action, String(action))))
	var b := Button.new()
	b.text = InputRebind.describe(action)
	b.custom_minimum_size = Vector2(180, 32)
	b.pressed.connect(func() -> void: _begin_capture(action, b))
	row.add_child(b)


func _action_button(label: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(WIDTH - 20, 40)
	b.pressed.connect(handler)
	_list.add_child(b)


# --- 交互 ------------------------------------------------------------------

func _begin_capture(action: StringName, button: Button) -> void:
	_capturing = action
	_capture_button = button
	button.text = Loc.t("UI_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# ESC 取消捕获，不绑到任何动作上。
	if key.physical_keycode == KEY_ESCAPE:
		_end_capture()
		get_viewport().set_input_as_handled()
		return
	if InputRebind.bind(_capturing, key.physical_keycode):
		_end_capture()
	get_viewport().set_input_as_handled()


func _end_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = InputRebind.describe(_capturing)
	_capturing = &""
	_capture_button = null


func _on_reset() -> void:
	Settings.reset_all()
	InputRebind.reset_all()
	# 重建整个面板：滑块/开关/OptionButton 的值都要回默认，逐个同步比重建啰嗦
	# 且容易漏（漏一个就是"界面上还是旧值"）。必须先 remove_child 再 _build()，
	# 否则 queue_free 是延迟的，新一层 UI 会和旧的重叠。
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
