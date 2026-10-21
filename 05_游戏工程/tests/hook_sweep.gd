extends Node
## Diagnostic sweep: real InputEventAction timings for hook -> jump -> double.
## Run: godot --headless --path . res://tests/hook_sweep.tscn

const PROTO := preload("res://scenes/prototype/climb_prototype.tscn")
const OUT := "user://hook_sweep.log"

var _file: FileAccess


func _ready() -> void:
	DebugLog.enabled = false
	_file = FileAccess.open(OUT, FileAccess.WRITE)
	if "--one" in OS.get_cmdline_args():
		DebugLog.enabled = true
		_line("ONE CASE hold=6 release=after gap=5")
		var r1 := await _run_case(6, "after", 5)
		_line("ONE RESULT " + JSON.stringify(r1))
		_file.close()
		get_tree().quit(0)
		return
	_line("HOOK_SWEEP start")
	var cases := 0
	var fails := 0
	for hold_frames in [0, 1, 2, 3, 4, 5, 6, 8]:
		for release_mode in ["hold", "before", "after"]:
			for gap in [0, 1, 2, 3, 4, 5, 8]:
				cases += 1
				var r := await _run_case(hold_frames, release_mode, gap)
				if not r["ok"]:
					fails += 1
					_line("FAIL hold=%d release=%s gap=%d detail=%s" % [hold_frames, release_mode, gap, JSON.stringify(r)])
				elif cases % 20 == 0:
					_line("ok %d" % cases)
	_line("HOOK_SWEEP cases=%d fails=%d" % [cases, fails])
	print("HOOK_SWEEP cases=%d fails=%d log=%s" % [cases, fails, ProjectSettings.globalize_path(OUT)])
	_file.close()
	get_tree().quit(1 if fails > 0 else 0)


func _line(text: String) -> void:
	print(text)
	if _file:
		_file.store_line(text)
		_file.flush()


func _event(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _run_case(hold_frames: int, release_mode: String, gap: int) -> Dictionary:
	var proto := PROTO.instantiate()
	add_child(proto)
	await get_tree().process_frame
	await get_tree().physics_frame
	var p: Player = proto.player
	InputBuffer.clear()
	p.global_position = Vector2(700, 560)
	p.velocity = Vector2.ZERO
	p.state = Player.State.FALL
	p.double_jump_available = true
	p.hook_jump_lock = 0.0
	p.hook_air_charge = 0
	await get_tree().physics_frame

	_event("hook", true)
	await get_tree().process_frame
	await get_tree().physics_frame
	await _frames(hold_frames)
	if release_mode == "before":
		_event("hook", false)
		await get_tree().process_frame

	_event("jump", true)
	await get_tree().process_frame
	_event("jump", false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var vy1 := p.velocity.y
	var double1 := p.double_jump_available
	var state1 := p._state_name()

	if release_mode == "after":
		_event("hook", false)
		await get_tree().process_frame
	await _frames(gap)

	_event("jump", true)
	await get_tree().process_frame
	_event("jump", false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var vy2 := p.velocity.y
	var double2 := p.double_jump_available
	var state2 := p._state_name()
	var ok := state2 == "JUMP" and not double2
	var result := {
		"ok": ok,
		"hold": hold_frames,
		"rel": release_mode,
		"gap": gap,
		"vy1": snappedf(vy1, 1.0),
		"vy2": snappedf(vy2, 1.0),
		"d1": double1,
		"d2": double2,
		"s1": state1,
		"s2": state2,
	}
	_event("hook", false)
	_event("jump", false)
	InputBuffer.clear()
	proto.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return result
