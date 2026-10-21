extends Node
## Debug-only operation log for hook / jump input disputes.
## File: user://hook_debug.log (absolute path printed at startup).

const LOG_PATH := "user://hook_debug.log"
var enabled := false
var _file: FileAccess = null
var _lines_since_flush := 0


func _ready() -> void:
	enabled = OS.is_debug_build() and OS.get_cmdline_args().has("--hook-debug")
	if not enabled:
		return
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	log_event("SESSION", {
		"engine": Engine.get_version_info().get("string", "?"),
		"scene": str(get_tree().current_scene.name) if get_tree().current_scene else "?",
	})
	print("[DEBUGLOG] ", ProjectSettings.globalize_path(LOG_PATH))


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
		if _lines_since_flush >= 30:
			_file.flush()
			_lines_since_flush = 0


func _exit_tree() -> void:
	if _file:
		_file.flush()
		_file.close()
		_file = null
