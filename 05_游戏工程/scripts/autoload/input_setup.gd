extends Node
## 运行时输入补齐：**只负责手柄与摇杆**，键盘绑定在 InputRebind。
##
## 为什么不把键盘也留在这里：键盘要能被玩家重绑并存盘，而"默认值 + 覆盖"的
## 逻辑只能有一处。InputSetup 在本文件之后仍会补 action 存在性，但键盘事件由
## InputRebind 统一清空重写，所以这边写键盘没有意义，反而会在重绑后残留旧键。

func _enter_tree() -> void:
	# Gamepad
	_ensure_joy("move_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy("move_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy("move_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy("move_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy("jump", JOY_BUTTON_A)
	_ensure_joy("dash", JOY_BUTTON_B)
	_ensure_joy("attack", JOY_BUTTON_X)
	_ensure_joy("parry", JOY_BUTTON_Y)
	_ensure_joy("switch", JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy("stitch", JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_joy("hook", JOY_BUTTON_RIGHT_STICK)
	_ensure_joy("interact", JOY_BUTTON_X)
	_ensure_joy("pause", JOY_BUTTON_START)

	# Analog stick as movement (left stick)
	_ensure_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


func _ensure_joy(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _ensure_axis(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis:
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)
