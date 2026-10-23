extends Node
## 运行日志 + 输入调试记录。
##
## 两条通道，各管各的：
##   1. hook_debug.log —— 只在 `--hook-debug` 时开，记输入争议（掉帧、双跳、钩索断线）。
##   2. logs/session_<时间>.log —— 只在 `--log` 时开，记错误/警告/关键状态变更。
##
## 分成两条是因为它们的使用场景完全相反：前者是"我在复现一个手感问题"，
## 需要毫秒级密集记录；后者是"玩家崩了，把日志发我"，需要长期存在、能滚动清理。
## 混在一个文件里会让第二种场景被输入噪音淹掉。

const HOOK_LOG_PATH := "user://hook_debug.log"
const LOG_DIR := "user://logs"
const MAX_SESSION_LOGS := 10
const FLUSH_EVERY := 30

## 输入调试通道（--hook-debug）
var enabled := false
## 会话日志通道（--log）
var logging := false
## 会话日志文件绝对路径，方便启动时打给用户看
var session_path := ""
## 日志目录。默认 user://logs；测试可以指到临时目录，避免污染玩家真实日志。
var log_dir: String = LOG_DIR

var _file: FileAccess = null
var _session: FileAccess = null
var _lines_since_flush := 0
var _error_count := 0
var _warn_count := 0


func _ready() -> void:
	# 文档写法是 `godot --path . -- --log`：`--` 之后的参数只在 get_cmdline_user_args() 里，
	# 不在 get_cmdline_args() 里（4.7.2 实测）。两边都认，不带 `--` 的写法也照样能用。
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	enabled = OS.is_debug_build() and args.has("--hook-debug")
	logging = args.has("--log")

	if enabled:
		_file = FileAccess.open(HOOK_LOG_PATH, FileAccess.WRITE)
		log_event("SESSION", {
			"engine": Engine.get_version_info().get("string", "?"),
			"scene": _scene_name(),
		})
		print("[DEBUGLOG] ", ProjectSettings.globalize_path(HOOK_LOG_PATH))

	if logging:
		open_session()


## 打开一个会话日志文件。返回是否成功。
## 公开是因为它有两个正当调用方：--log 启动时，和测试里手动开。
func open_session() -> bool:
	DirAccess.make_dir_recursive_absolute(log_dir)
	_rotate_sessions()
	# 秒级时间戳 + 毫秒后缀：同一秒里开两次会话（测试会这么干）时，
	# 名字必须不同，否则第二次会把第一次的日志覆盖掉。
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
	var millis := Time.get_ticks_msec() % 1000
	session_path = "%s/session_%s_%03d.log" % [log_dir, stamp, millis]
	_session = FileAccess.open(session_path, FileAccess.WRITE)
	if _session == null:
		logging = false
		push_warning("DebugLog: 无法写入 %s" % session_path)
		return false
	logging = true
	info("SESSION", "start · %s · %s" % [
		_scene_name(), str(Engine.get_version_info().get("string", "?"))])
	print("[LOG] ", ProjectSettings.globalize_path(session_path))
	return true


## 关闭当前会话日志（测试收尾 / 切换日志目录时用）。
func close_session() -> void:
	if _session == null:
		return
	_session.flush()
	_session.close()
	_session = null
	logging = false


## 只保留最近 MAX_SESSION_LOGS 个会话日志。按文件名排序（带时间戳，即时间序）。
func _rotate_sessions() -> void:
	var dir := DirAccess.open(log_dir)
	if dir == null:
		return
	var names: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("session_") and f.ends_with(".log"):
			names.append(f)
	if names.size() < MAX_SESSION_LOGS:
		return
	names.sort()
	var remove_count := names.size() - MAX_SESSION_LOGS + 1
	for i in range(remove_count):
		dir.remove(names[i])


## 输入调试记录（--hook-debug）。未开时是空操作。
func log_event(tag: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var payload := data.duplicate(true)
	payload["ms"] = Time.get_ticks_msec()
	payload["pf"] = Engine.get_physics_frames()
	var line := "[%d] %-16s %s" % [payload["ms"], tag, JSON.stringify(payload)]
	if _file:
		_file.store_line(line)
		_lines_since_flush += 1
		# Flushing every line is expensive during input-heavy play. Keep the
		# record durable enough without turning debug mode into a frame hitch.
		if _lines_since_flush >= FLUSH_EVERY:
			_file.flush()
			_lines_since_flush = 0


## 会话日志：普通信息。未开 --log 时是空操作。
func info(tag: String, message: String) -> void:
	_write("INFO ", tag, message)


## 会话日志：警告。同时计数，退出时汇总。
## 计数只统计"真的写进文件"的那些 —— 没开 --log 时 stats() 应该是干净的 0。
func warn(tag: String, message: String) -> void:
	if _write("WARN ", tag, message):
		_warn_count += 1


## 会话日志：错误。调用的同时应该照常 push_error，两者互不替代 ——
## 终端输出给开发时看，文件给"玩家发来的日志"看。
func error(tag: String, message: String) -> void:
	if _write("ERROR", tag, message):
		_error_count += 1


## 一次性把当前状态写进日志头，崩了以后能看到"什么局面下崩的"。
func dump_state(tag: String, state: Dictionary) -> void:
	_write("STATE", tag, JSON.stringify(state))


func _write(level: String, tag: String, message: String) -> bool:
	if not logging or _session == null:
		return false
	_session.store_line("%s %-14s %s" % [level, tag, message])
	_session.flush()
	return true


func stats() -> Dictionary:
	return {
		"errors": _error_count,
		"warnings": _warn_count,
		"session_path": session_path,
		"logging": logging,
	}


func _scene_name() -> String:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return str(scene.name) if scene != null else "?"


func _exit_tree() -> void:
	if enabled and _file:
		_file.flush()
		_file.close()
		_file = null
	if logging and _session:
		info("SESSION", "end · errors=%d warnings=%d" % [_error_count, _warn_count])
		_session.flush()
		_session.close()
		_session = null
