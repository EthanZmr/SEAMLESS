extends Node
## A5/A6 回归：设置持久化 + 按键重绑。
##
## 运行：godot --headless --path . res://tests/test_settings.tscn
## （用场景而不是 -s：Settings/InputRebind/HitStop 都是 autoload，脚本模式不加载。）
##
## 这个测试会改真实 InputMap 与音频总线，结束时必须复原 —— 否则后续套件会
## 拿到被污染的全局状态（踩过的坑：全局状态测试没复原，别人跑就莫名红）。

const TEST_CFG := "user://settings_test.cfg"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_SETTINGS: start")

	_test_defaults()
	_test_audio_applied()
	_test_persisted_and_reloaded()
	_test_gameplay_toggle()
	_test_rebind_defaults()
	_test_rebind_single()
	_test_rebind_conflict()
	_test_rebind_rejects()
	_test_rebind_persisted()
	_test_cleanup()

	print("TEST_SETTINGS: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _test_defaults() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	Settings.config_path = TEST_CFG
	Settings.load_settings()

	_check(Settings.get_value("audio", "music_db") == -6.0, "首次运行取默认值 music_db=-6")
	_check(Settings.get_value("video", "vsync") == true, "默认开启 vsync")
	_check(Settings.get_value("gameplay", "hitstop") == true, "默认开启 hitstop")
	_check(Settings.DEFAULTS.has("audio"), "默认值表含 audio 段")


func _test_audio_applied() -> void:
	Settings.set_value("audio", "music_db", -20.0)
	var idx := AudioServer.get_bus_index("Music")
	_check(idx >= 0, "default_bus_layout.tres 里有 Music 总线")
	_check(absf(AudioServer.get_bus_volume_db(idx) + 20.0) < 0.01, "Music 音量被写成 -20dB")

	Settings.set_value("audio", "music_db", -40.0)
	_check(AudioServer.is_bus_mute(idx), "-40dB 视为静音并 mute")


func _test_persisted_and_reloaded() -> void:
	Settings.set_value("audio", "music_db", -20.0)
	_check(FileAccess.file_exists(TEST_CFG), "设置文件已落盘")

	# 模拟重启：清空内存后重新读盘，值必须还在。
	Settings.load_settings()
	_check(Settings.get_value("audio", "music_db") == -20.0, "重新加载后仍是 -20")

	Settings.reset_section("audio")
	_check(Settings.get_value("audio", "music_db") == -6.0, "reset_section 回默认 -6")


func _test_gameplay_toggle() -> void:
	Settings.set_value("gameplay", "hitstop", false)
	_check(HitStop.enabled == false, "关掉 hitstop 后 HitStop.enabled 同步为 false")
	Settings.set_value("gameplay", "hitstop", true)
	_check(HitStop.enabled == true, "开回来同步为 true")


func _test_rebind_defaults() -> void:
	InputRebind.reset_all()
	_check(InputRebind.ACTIONS.size() == 16, "16 个可重绑动作")
	var unbound: Array[String] = []
	for action in InputRebind.ACTIONS:
		if InputRebind.primary_key(action) == KEY_NONE:
			unbound.append(String(action))
	_check(unbound.is_empty(), "所有动作都有键盘绑定%s" % (
		"" if unbound.is_empty() else "（未绑定：%s）" % ", ".join(unbound)))
	_check(InputRebind.primary_key(&"jump") == KEY_SPACE, "跳跃默认 Space")
	_check(InputRebind.describe(&"jump") == "Space", "describe(jump) 返回 Space")
	_check(InputRebind.is_default(&"attack"), "attack 与默认表一致")


func _test_rebind_single() -> void:
	var ok := InputRebind.bind(&"jump", KEY_F)
	_check(ok, "bind 成功返回 true")
	_check(_keys_are(&"jump", [KEY_F]), "跳跃只剩 F")
	_check(InputRebind.describe(&"jump") == "F", "describe 跟着变成 F")
	_check(not InputRebind.is_default(&"jump"), "改过之后 is_default 为 false")


func _test_rebind_conflict() -> void:
	# 把跳跃绑到攻击的键 J：攻击必须失去 J，而不是两个动作一起响。
	InputRebind.bind(&"jump", KEY_J)
	_check(not InputRebind.keys_of(&"attack").has(KEY_J), "冲突时原动作失去该键")
	_check(_keys_are(&"jump", [KEY_J]), "新动作拿到该键")
	_check(InputRebind.primary_key(&"attack") == KEY_NONE, "攻击变成未绑定（J 已被抢走）")


func _test_rebind_rejects() -> void:
	_check(InputRebind.bind(&"no_such_action", KEY_P) == false, "未知动作被拒绝")
	_check(InputRebind.bind(&"jump", KEY_NONE) == false, "KEY_NONE 被拒绝")


func _test_rebind_persisted() -> void:
	InputRebind.reset_all()
	InputRebind.bind(&"hook", KEY_Q)
	# Settings 里应有记录，且重新 apply_all 后依然生效。
	_check(Settings.get_value("input", "hook", null) != null, "重绑写进了设置文件")
	InputRebind.apply_all()
	_check(InputRebind.primary_key(&"hook") == KEY_Q, "apply_all 后仍是 Q")


func _test_cleanup() -> void:
	# 复原全局状态：默认绑定 + 默认设置 + 删掉测试用的配置文件。
	InputRebind.reset_all()
	Settings.reset_all()
	Settings.config_path = Settings.DEFAULT_PATH
	Settings.load_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	_check(InputRebind.primary_key(&"hook") == KEY_H, "收尾后钩索回默认 H")
	_check(Settings.get_value("audio", "music_db") == -6.0, "收尾后音量回默认")


## 键列表比对。不能写 `keys == [KEY_F] as Array[int]`：`as` 的优先级低于 `==`，
## 会被解析成 `(keys == [KEY_F]) as Array[int]`，直接解析错误。
func _keys_are(action: StringName, expect: Array) -> bool:
	var got := InputRebind.keys_of(action)
	if got.size() != expect.size():
		return false
	for i in expect.size():
		if got[i] != int(expect[i]):
			return false
	return true


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
