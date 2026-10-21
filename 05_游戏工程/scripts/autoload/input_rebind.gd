extends Node
## 键盘按键重绑。
##
## 分工（重要）：InputSetup 只管"动作存在 + 手柄/摇杆"，键盘默认值归本文件。
## 本文件在 InputSetup 之后加载，会把键盘事件清空后按"用户保存的绑定 → 默认表"
## 重新写入，所以两边不会打架。手柄暂不支持重绑（真要支持得先有手柄热插拔与
## 双人分出输入，那是另一个量级）。
##
## 冲突策略：一个物理键只能绑一个动作。绑到已被占用的键时，先从原动作摘掉，
## 再绑到新动作 —— 玩家看到的应该是"这个键改管别的了"，而不是两个动作同时触发。

signal binding_changed(action: StringName)

const SECTION := "input"

## 可重绑的动作。顺序即 UI 展示顺序。
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"dash", &"attack", &"parry", &"switch", &"stitch", &"hook",
	&"interact", &"pause", &"choice_unpick", &"choice_stitch", &"restart",
]

## 动作 → 人类可读名（UI 直接显示）。
const LABELS := {
	&"move_left": "左移",
	&"move_right": "右移",
	&"move_up": "上",
	&"move_down": "下",
	&"jump": "跳跃",
	&"dash": "冲刺",
	&"attack": "攻击",
	&"parry": "格挡",
	&"switch": "换形",
	&"stitch": "缝合",
	&"hook": "钩索",
	&"interact": "交互",
	&"pause": "暂停",
	&"choice_unpick": "拆线",
	&"choice_stitch": "缝线",
	&"restart": "重开",
}

## 默认键盘绑定。这是唯一真相 —— InputSetup 不再写键盘。
const DEFAULT_KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"jump": [KEY_SPACE],
	&"dash": [KEY_SHIFT],
	&"attack": [KEY_J],
	&"parry": [KEY_K],
	&"switch": [KEY_L],
	&"stitch": [KEY_U],
	&"hook": [KEY_H],
	&"interact": [KEY_E],
	&"pause": [KEY_ESCAPE],
	&"choice_unpick": [KEY_U],
	&"choice_stitch": [KEY_I],
	&"restart": [KEY_R],
}


func _enter_tree() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	apply_all()


## 按"已保存 → 默认表"重写全部键盘事件。
##
## 注意顺序：**先取键、再清空、最后写入**。如果先清空再读 InputMap，读到的是
## 空数组，结果所有动作都变成没绑定（踩过一次：全部 hook/jump 测试同时红）。
func apply_all() -> void:
	for action in ACTIONS:
		var keys := _saved_keys(action)
		_clear_keyboard(action)
		for keycode in keys:
			_add_key(action, keycode)


## 设置里存的键；没有记录（首次运行）时退回默认表。
func _saved_keys(action: StringName) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = Settings.get_value(SECTION, String(action), null)
	if raw is Array or raw is PackedInt32Array:
		for v in raw:
			var k := int(v)
			if k != KEY_NONE:
				out.append(k)
	if out.is_empty():
		for v in DEFAULT_KEYS.get(action, []):
			out.append(int(v))
	return out


## 当前生效的键（读 InputMap，不读设置 —— 这样外部代码改了 InputMap 也一致）。
func keys_of(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append((ev as InputEventKey).physical_keycode)
	return out


## 主键（UI 第一列显示的那个）。没有绑定时返回 KEY_NONE。
func primary_key(action: StringName) -> int:
	var keys := keys_of(action)
	return keys[0] if not keys.is_empty() else KEY_NONE


func describe(action: StringName) -> String:
	var key := primary_key(action)
	return key_name(key) if key != KEY_NONE else "未绑定"


func key_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "未绑定"
	var text := OS.get_keycode_string(keycode)
	return text if not text.is_empty() else "键%d" % keycode


## 把 action 绑到 keycode（单键替换主键，保留副键？不 —— 重绑就是这一下按的键）。
## 返回 false 表示这个键不能用（KEY_NONE 或与鼠标/系统键冲突）。
func bind(action: StringName, keycode: int) -> bool:
	if not ACTIONS.has(action):
		push_warning("bind: 未知动作 %s" % action)
		return false
	if keycode == KEY_NONE:
		return false

	# 解冲突：先从所有其他动作上摘掉这个键。
	for other in ACTIONS:
		if other == action:
			continue
		if keys_of(other).has(keycode):
			_remove_key(other, keycode)
			_persist(other)
			binding_changed.emit(other)

	# 覆盖本动作：清空后写新键（重绑的语义就是"这个动作现在只按这个键"）。
	_clear_keyboard(action)
	_add_key(action, keycode)
	_persist(action)
	binding_changed.emit(action)
	return true


func reset_action(action: StringName) -> void:
	var defaults: Array = DEFAULT_KEYS.get(action, [])
	_clear_keyboard(action)
	for keycode in defaults:
		_add_key(action, keycode)
	_persist(action)
	binding_changed.emit(action)


func reset_all() -> void:
	for action in ACTIONS:
		_clear_keyboard(action)
		var defaults: Array = DEFAULT_KEYS.get(action, [])
		for keycode in defaults:
			_add_key(action, keycode)
		_persist(action)
		binding_changed.emit(action)


## 与默认表相比是否有改动（设置界面用来显示"恢复默认"按钮）。
func is_default(action: StringName) -> bool:
	var current := keys_of(action)
	var defaults: Array = DEFAULT_KEYS.get(action, [])
	if current.size() != defaults.size():
		return false
	for i in current.size():
		if current[i] != int(defaults[i]):
			return false
	return true


# --- 内部 ------------------------------------------------------------------

func _clear_keyboard(action: StringName) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)


func _add_key(action: StringName, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)


func _remove_key(action: StringName, keycode: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			InputMap.action_erase_event(action, ev)


func _persist(action: StringName) -> void:
	var keys := keys_of(action)
	Settings.set_value(SECTION, String(action), keys)
