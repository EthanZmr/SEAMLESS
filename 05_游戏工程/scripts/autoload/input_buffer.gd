extends Node
## Tiny input buffer: remember the last press of every action for a short window.
## Player consumes presses through this so jump/parry never feel dropped.

const DEFAULT_WINDOW := 0.15

var _stamps: Dictionary = {}


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action in InputMap.get_actions():
		if event.is_action(action):
			_stamps[action] = Time.get_ticks_msec()
			DebugLog.log_event("INPUT", {"action": String(action), "pressed": true})


func consume(action: StringName, window: float = DEFAULT_WINDOW) -> bool:
	if not _stamps.has(action):
		return false
	var age_ms := Time.get_ticks_msec() - int(_stamps[action])
	var ok := age_ms <= int(window * 1000.0)
	# Do not log every per-frame miss: a stale action would otherwise write
	# thousands of lines and stall the game while a debug session is open.
	if ok or age_ms <= 500:
		DebugLog.log_event("CONSUME", {"action": String(action), "age_ms": age_ms, "ok": ok})
	if ok:
		_stamps.erase(action)
		return true
	return false


func peek(action: StringName, window: float = DEFAULT_WINDOW) -> bool:
	if not _stamps.has(action):
		return false
	var age_ms := Time.get_ticks_msec() - int(_stamps[action])
	return age_ms <= int(window * 1000.0)


func peek_stamp(action: StringName) -> int:
	return int(_stamps.get(action, -999999))


func add_age_grace(ms: int) -> void:
	## Hit-stop consumes real time while gameplay is frozen. Shift stamps forward
	## so a press during the freeze is not older than the buffer window on resume.
	if ms <= 0:
		return
	for action in _stamps.keys():
		_stamps[action] = int(_stamps[action]) + ms


func clear_action(action: StringName) -> void:
	var had := _stamps.has(action)
	_stamps.erase(action)
	DebugLog.log_event("CLEAR", {"action": String(action), "had": had})


func clear() -> void:
	_stamps.clear()
