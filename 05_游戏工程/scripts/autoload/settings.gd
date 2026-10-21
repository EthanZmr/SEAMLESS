extends Node
## 全局设置：一份 ConfigFile 存 user://settings.cfg，改一项就落盘并广播。
##
## 为什么做成 autoload 而不是散落在各处的字段：设置必须是"单一真相"。
## 一旦音频音量既存在设置里又存在 HUD 里，就会出现"调了没反应"和
## "重启后变回去"两类 bug，而且没人能说清哪个是权威。
##
## 约定：
## - 读取一律走 get_value(section, key, 默认值)，不要直接读 _cfg，
##   否则新增字段时老存档会拿到 null。
## - 写入一律走 set_value()，它负责 落盘 + apply_section + emit changed。
## - 音频用分贝（-40 = 静音）。线性 0..1 在 UI 上好看、在混音上难算，统一在
##   UI 层转换，数据层只存 dB。

signal changed(section: String, key: String, value: Variant)

const DEFAULT_PATH := "user://settings.cfg"

const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX", "UI", "Ambience"]
const MUTE_DB := -40.0

# 默认值表。新增设置项时**先加到这里**，get_value 的兜底才有一致来源。
const DEFAULTS := {
	"audio": {
		"master_db": 0.0,
		"music_db": -6.0,
		"sfx_db": -3.0,
		"ui_db": -8.0,
		"ambience_db": -12.0,
	},
	"video": {
		"fullscreen": false,
		"vsync": true,
		"max_fps": 0,
	},
	"gameplay": {
		"screen_shake": true,
		"hitstop": true,
	},
}

## 测试用：改成 user://settings_test.cfg 之类，避免污染真实配置。
var config_path: String = DEFAULT_PATH

var _cfg := ConfigFile.new()


func _enter_tree() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var err := _cfg.load(config_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("设置文件读取失败（%s），改用默认值：%s" % [config_path, error_string(err)])
	# 文件不存在 / 损坏都不算错：全部走默认值即可。


func save_settings() -> bool:
	var err := _cfg.save(config_path)
	if err != OK:
		push_warning("设置写入失败（%s）：%s" % [config_path, error_string(err)])
		return false
	return true


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var default_value: Variant = fallback
	if fallback == null:
		var table: Dictionary = DEFAULTS.get(section, {})
		default_value = table.get(key, null)
	# 必须先 has_section_key：ConfigFile.get_value 的默认值参数不接受 null，
	# 缺键时会直接报 "no default was given" 而不是返回 null。
	if not _cfg.has_section_key(section, key):
		return default_value
	return _cfg.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant, persist := true) -> void:
	_cfg.set_value(section, key, value)
	apply_section(section)
	if persist:
		save_settings()
	changed.emit(section, key, value)


func reset_section(section: String) -> void:
	var table: Dictionary = DEFAULTS.get(section, {})
	for key in table:
		_cfg.set_value(section, key, table[key])
	apply_section(section)
	save_settings()
	changed.emit(section, "*", null)


func reset_all() -> void:
	for section in DEFAULTS:
		reset_section(section)


# --- 应用 ------------------------------------------------------------------

func apply_all() -> void:
	apply_section("audio")
	apply_section("video")
	apply_section("gameplay")


func apply_section(section: String) -> void:
	match section:
		"audio":
			_apply_audio()
		"video":
			_apply_video()
		"gameplay":
			_apply_gameplay()
		_:
			pass


func _apply_audio() -> void:
	for bus_name in AUDIO_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var db: float = float(get_value("audio", _bus_key(bus_name), 0.0))
		AudioServer.set_bus_volume_db(idx, maxf(db, MUTE_DB))
		# -40 视为静音：直接 mute，省得音频线程还在算一个听不见的混音。
		AudioServer.set_bus_mute(idx, db <= MUTE_DB)


func _apply_video() -> void:
	# headless（CI / 测试）下没有真实窗口，调用会打一堆 warning，直接跳过。
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen: bool = bool(get_value("video", "fullscreen", false))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	var vsync: bool = bool(get_value("video", "vsync", true))
	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	Engine.max_fps = int(get_value("video", "max_fps", 0))


func _apply_gameplay() -> void:
	# 用 get_node_or_null 而不是直接 `HitStop`：autoload 顺序上 Settings 在
	# HitStop 之前，_enter_tree 阶段它还不存在，直接引用会拿到未初始化的标识符。
	var hs := get_node_or_null("/root/HitStop")
	if hs != null:
		hs.enabled = bool(get_value("gameplay", "hitstop", true))


func _bus_key(bus_name: String) -> String:
	return bus_name.to_lower() + "_db"
