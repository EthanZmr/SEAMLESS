extends Node
## Runtime input setup. Keeps project.godot small and guarantees actions exist
## even if the editor's Input Map was never filled in.

func _enter_tree() -> void:
	# Keyboard
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_left", KEY_LEFT)
	_ensure_key("move_right", KEY_D)
	_ensure_key("move_right", KEY_RIGHT)
	_ensure_key("move_up", KEY_W)
	_ensure_key("move_up", KEY_UP)
	_ensure_key("move_down", KEY_S)
	_ensure_key("move_down", KEY_DOWN)
	_ensure_key("jump", KEY_SPACE)
	_ensure_key("dash", KEY_SHIFT)
	_ensure_key("attack", KEY_J)
	_ensure_key("parry", KEY_K)
	_ensure_key("switch", KEY_L)
	_ensure_key("stitch", KEY_U)
	_ensure_key("hook", KEY_H)
	_ensure_key("interact", KEY_E)
	_ensure_key("pause", KEY_ESCAPE)
	_ensure_key("choice_unpick", KEY_U)
	_ensure_key("choice_stitch", KEY_I)
	_ensure_key("restart", KEY_R)

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


func _ensure_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


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
