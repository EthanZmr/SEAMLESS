class_name Player
extends CharacterBody2D
## A-Zhen / A-Ling dual-consciousness controller.
## Whitebox implementation of the slice spec: run, jump, dash, light combo,
## seam parry, form switch, stitch, takeover AI, death/respawn.

signal form_changed(form: int)
signal parried(perfect: bool)

const HitSparkScript = preload("res://scripts/effects/hit_spark.gd")
const Light1Spec = preload("res://scripts/combat/attack_spec.gd")
const StatsScript = preload("res://scripts/player/player_stats.gd")

var SPEED := 220.0
var LING_SPEED_MULT := 1.2
var ACCEL := 1800.0
var FRICTION := 2200.0
var AIR_ACCEL := 1200.0
var JUMP_VELOCITY := -600.0
var GRAVITY := 1400.0
var MAX_FALL := 820.0
var COYOTE_TIME := 0.10
var JUMP_BUFFER := 0.12
var JUMP_CUT_VELOCITY := -150.0
var DASH_SPEED := 560.0
var DASH_TIME := 0.16
var DASH_COOLDOWN := 0.35
var ATTACK_TIME := 0.22
var ATTACK_ACTIVE := 0.06
var ATTACK_COOLDOWN := 0.30
var ATTACK_RANGE := 84.0
# W4-01 ground string / launcher / air attack.
var COMBO_TIMES := [0.20, 0.22, 0.30]
var COMBO_ACTIVE := [0.06, 0.07, 0.09]
var COMBO_DAMAGE := [10.0, 12.0, 20.0]
var COMBO_RANGE := [84.0, 88.0, 100.0]
var COMBO_KNOCKBACK := [120.0, 160.0, 320.0]
var COMBO_QUEUE_WINDOW := 0.16
var COMBO_GRACE := 0.40
var LAUNCH_TIME := 0.28
var LAUNCH_ACTIVE := 0.07
var LAUNCH_DAMAGE := 7.0
var LAUNCH_RANGE := 76.0
var LAUNCH_FORCE := 520.0
var AIR_ATTACK_TIME := 0.20
var AIR_ATTACK_ACTIVE := 0.05
var AIR_ATTACK_DAMAGE := 9.0
var AIR_ATTACK_RANGE := 78.0
var AIR_ATTACK_BUFFER := 0.35
var PARRY_ACTIVE := CombatMath.ACTIVE_WINDOW
var PARRY_RECOVERY := CombatMath.RECOVERY_WINDOW
var PARRY_COOLDOWN := CombatMath.COOLDOWN
var INVULN_TIME := 0.80
var HURT_TIME := 0.28
var STITCH_RANGE := 90.0
var STITCH_COOLDOWN := 0.80

# Movement kit (range A). Values are whitebox defaults, tuned in W2-01.
var CLIMB_SPEED := 132.0
var CLIMB_SNAP_SPEED := 360.0
var CLIMB_JUMP_VERTICAL := -560.0
var CLIMB_JUMP_HORIZONTAL := 240.0
var WALL_SLIDE_SPEED := 150.0
var WALL_JUMP_HORIZONTAL := 600.0
var WALL_JUMP_VERTICAL := -560.0
var WALL_JUMP_LOCK := 0.10
var CLIMB_JUMP_LOCK := 0.22
var DOUBLE_JUMP_VERTICAL := -540.0
var LEDGE_COOLDOWN := 0.28
var LEDGE_VAULT_HORIZONTAL := 240.0
var LEDGE_VAULT_VERTICAL := -430.0
var LEDGE_PROBE_FORWARD := 20.0
var LEDGE_PROBE_ABOVE := 26.0
var LEDGE_DROP_SPEED := 140.0

# W2-02 seam hook: pull toward an anchor, no full rope swing.
var HOOK_RANGE := 320.0
var HOOK_SPEED := 680.0
var HOOK_ARRIVE := 30.0
var HOOK_JUMP_LOCK := 0.08
var HOOK_FREE_JUMP_TIME := 0.45
var HOOK_JUMP_VERTICAL := -520.0
var HOOK_JUMP_X_KEEP := 0.25
var HOOK_DETACH_KEEP := 0.35

## "builtin" = 使用脚本内建默认值；"resource" = 已从 data/player/player_stats.tres 覆盖。
var stats_source := "builtin"

enum State { IDLE, RUN, JUMP, FALL, DASH, ATTACK, PARRY, HURT, DEAD, CLIMB, WALL_SLIDE, LEDGE, HOOK }
enum AttackKind { GROUND, LAUNCHER, AIR }


func _state_name() -> String:
	match state:
		State.IDLE: return "IDLE"
		State.RUN: return "RUN"
		State.JUMP: return "JUMP"
		State.FALL: return "FALL"
		State.DASH: return "DASH"
		State.ATTACK: return "ATTACK"
		State.PARRY: return "PARRY"
		State.HURT: return "HURT"
		State.DEAD: return "DEAD"
		State.CLIMB: return "CLIMB"
		State.WALL_SLIDE: return "WALL_SLIDE"
		State.LEDGE: return "LEDGE"
		State.HOOK: return "HOOK"
	return "?"


func _dbg(event_name: String, extra: Dictionary = {}) -> void:
	if not DebugLog.enabled:
		return
	var data := {
		"state": _state_name(),
		"pos": [snappedf(global_position.x, 0.1), snappedf(global_position.y, 0.1)],
		"vel": [snappedf(velocity.x, 0.1), snappedf(velocity.y, 0.1)],
		"double": double_jump_available,
		"lock": snappedf(hook_jump_lock, 0.001),
		"charge": hook_air_charge,
		"buf_jump": InputBuffer.peek_stamp("jump"),
		"buf_hook": InputBuffer.peek_stamp("hook"),
	}
	for key in extra:
		data[key] = extra[key]
	DebugLog.log_event(event_name, data)


var state: State = State.IDLE
var form: int = 0
var facing: int = 1
var coyote := 0.0
var dash_timer := 0.0
var dash_cd := 0.0
var attack_timer := 0.0
var attack_cd := 0.0
var attack_hit_done := false
## 本次挥击是否真的打到了敌人（whiff 判定用）。attack_hit_done 只表示
## "判定帧已经执行过"，不代表命中；取消窗必须看这个。
var attack_hit_landed := false
var attack_kind: AttackKind = AttackKind.GROUND
var attack_time := ATTACK_TIME
var attack_active := ATTACK_ACTIVE
var attack_damage := 12.0
var attack_range := ATTACK_RANGE
var combo_index := 0
var combo_queued := false
var combo_grace := 0.0
var combo_next := 0
var air_attack_used := false
var parry_elapsed := 0.0
var parry_cd := 0.0
var invuln := 0.0
var hurt_timer := 0.0
var stitch_cd := 0.0
var switch_cd := 0.0
var perfect_switch_timer := 0.0
var perfect_buff := 0.0
var respawn_timer := 0.0
var last_attacker: Node = null
var takeovers_used := 0
var parry_count := 0
var perfect_parry_count := 0
var climb_zones: Array[Area2D] = []
var ledge_cd := 0.0
var ledge_dir := 1
var wall_dir := 0
var wall_jump_lock := 0.0
var climb_jump_lock := 0.0
var hook_jump_lock := 0.0
var climb_regrab_requires_release := false
var double_jump_available := true
var hook_target: Node2D = null
var hook_air_jump_armed := false
var hook_air_jump_needs_release := false
var hook_air_jump_arm_frame := -1
var hook_air_jump_preserve_double := false
var hook_arrival_grace := 0.0
var hook_release_pending := false
var hook_release_grace := 0.0
var hook_free_jump_timer := 0.0
var hook_free_jump_used := false
var hook_air_charge := 0
var hook_jump_was_held := false

@onready var body: Polygon2D = $Body
## 锁定形象 v4 的占位贴图（世界高 64，scale 0.125；脚底对齐碰撞底）。动画接入前只翻转、变色。
@onready var sprite: Sprite2D = $Sprite
@onready var overlay: Polygon2D = $Overlay
@onready var tag: Label = $Tag

## 从 data/player/player_stats.tres 覆盖调参数值；文件缺失时静默沿用内建默认值。
func _apply_stats() -> void:
	var res: Resource = StatsScript.load_from(StatsScript.PATH)
	if res == null:
		return
	var applied: int = res.apply_to(self)
	if applied <= 0:
		return
	# 这几个运行态字段在成员初始化时复制过常量，需要重新同步。
	attack_time = ATTACK_TIME
	attack_active = ATTACK_ACTIVE
	attack_range = ATTACK_RANGE
	stats_source = "resource"
	var missing: Array = res.missing_fields(self)
	if not missing.is_empty():
		push_warning("Player 缺少 PlayerStats 字段：%s" % str(missing))


func _ready() -> void:
	_apply_stats()
	add_to_group("player")
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.form_changed.connect(_on_form_changed)
	var sensor := get_node_or_null("ClimbSensor") as Area2D
	if sensor:
		sensor.area_entered.connect(_on_climb_area_entered)
		sensor.area_exited.connect(_on_climb_area_exited)
	GameState.checkpoint = global_position
	form = GameState.form
	_update_visuals()

func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if state == State.DEAD:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	if state == State.HOOK:
		_hook_update(delta)
		if state == State.HOOK:
			move_and_slide()
			if get_slide_collision_count() > 0:
				# The pull hit a platform/wall before the anchor. Do not stay
				# magnetised under it; drop and let the player re-aim.
				_dbg("HOOK_COLLISION", {"count": get_slide_collision_count()})
				_end_hook(false)
				velocity = Vector2.ZERO
				GameEvents.message.emit("钩索断了。")
		_update_visuals()
		return

	if GameState.is_takeover:
		_takeover_ai(delta)
		_apply_gravity(delta)
		move_and_slide()
		_update_visuals()
		return

	if state == State.CLIMB:
		_climb_update(delta)
		move_and_slide()
		_update_visuals()
		return

	if state == State.LEDGE:
		_ledge_update(delta)
		move_and_slide()
		_update_visuals()
		return

	if perfect_switch_timer > 0.0:
		perfect_switch_timer -= delta
		if perfect_switch_timer <= 0.0 and not GameState.is_takeover:
			GameState.set_form(0)

	_handle_input()
	_update_action_timers(delta)
	_apply_gravity(delta)
	_apply_horizontal(delta)
	_update_state()
	move_and_slide()
	if state in [State.JUMP, State.FALL, State.WALL_SLIDE] and velocity.y >= 0.0:
		_check_ledge_grab()
	_update_visuals()

## 调试快照节流：HUD 只需要看得清，不需要每帧 60 次。
var _debug_accum := 0.0


func _process(delta: float) -> void:
	# 只在开了 DebugLog 时发。关掉后 HUD 那块面板自然消失，没有额外开销。
	if not DebugLog.enabled:
		return
	_debug_accum += delta
	if _debug_accum < 0.08:
		return
	_debug_accum = 0.0
	_emit_debug_snapshot()


## 把 HUD 需要的内部读数打包成标量发出去。
## HUD 因此不需要 get_first_node_in_group("player") as Player —— 也就不会
## 因为玩家改了某个字段名而编译失败。
func _emit_debug_snapshot() -> void:
	var hook_dist := 0.0
	if is_instance_valid(hook_target):
		hook_dist = global_position.distance_to(hook_target.global_position)
	GameEvents.debug_snapshot.emit({
		"state": _state_name(),
		"vel_x": velocity.x,
		"vel_y": velocity.y,
		"double_jump": double_jump_available,
		"hook_lock": hook_jump_lock,
		"hook_charge": hook_air_charge,
		"hooked": state == State.HOOK,
		"hook_dist": hook_dist,
		"buf_jump": int(InputBuffer.peek_stamp("jump")),
		"buf_hook": int(InputBuffer.peek_stamp("hook")),
	})


func _tick_timers(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	combo_grace = maxf(0.0, combo_grace - delta)
	if combo_grace <= 0.0:
		combo_next = 0
	parry_cd = maxf(0.0, parry_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	stitch_cd = maxf(0.0, stitch_cd - delta)
	switch_cd = maxf(0.0, switch_cd - delta)
	ledge_cd = maxf(0.0, ledge_cd - delta)
	wall_jump_lock = maxf(0.0, wall_jump_lock - delta)
	climb_jump_lock = maxf(0.0, climb_jump_lock - delta)
	hook_jump_lock = maxf(0.0, hook_jump_lock - delta)
	hook_free_jump_timer = maxf(0.0, hook_free_jump_timer - delta)
	if hook_free_jump_timer <= 0.0:
		hook_free_jump_used = false
	hook_arrival_grace = maxf(0.0, hook_arrival_grace - delta)
	if state == State.HOOK and hook_release_pending:
		hook_release_grace = maxf(0.0, hook_release_grace - delta)
		if hook_release_grace <= 0.0:
			_end_hook(false)
	perfect_buff = maxf(0.0, perfect_buff - delta)
	if is_on_floor():
		coyote = COYOTE_TIME
		double_jump_available = true
		air_attack_used = false
		if velocity.y >= 0.0:
			hook_air_charge = 0
		if velocity.y >= 0.0 and hook_arrival_grace <= 0.0:
			hook_air_jump_armed = false
	else:
		coyote = maxf(0.0, coyote - delta)

func _handle_input() -> void:
	if state in [State.DASH, State.PARRY, State.HURT, State.DEAD, State.CLIMB, State.LEDGE, State.HOOK]:
		return

	if state == State.ATTACK:
		# D2 拍板：三段统一规则——命中才开窗、空挥全禁；窗口按段取（AttackSpec）。
		# 一段 5-8f 跳 / 9f 连段；二段 6-9f 跳 / 10f 连段；三段是终结技，不可取消。
		var jump_ok := false
		var combo_ok := false
		if attack_kind == AttackKind.GROUND:
			var elapsed := attack_time - attack_timer
			jump_ok = is_on_floor() and attack_hit_landed and Light1Spec.jump_cancel_window_at(combo_index, elapsed)
			combo_ok = attack_hit_landed and attack_timer > 0.0 and combo_index < 2 and Light1Spec.combo_input_allowed_at(combo_index, elapsed)
			# 取消窗之外按下的键要吞掉：否则会漏到收招结束，变成"延迟跳/延迟连段"，
			# 把空挥惩罚抹平。
			if not jump_ok and InputBuffer.peek_stamp("jump") > 0:
				InputBuffer.clear_action("jump")
			if not combo_ok and InputBuffer.peek_stamp("attack") > 0:
				InputBuffer.clear_action("attack")
			if jump_ok and InputBuffer.consume("jump", JUMP_BUFFER):
				_cancel_attack_into_jump()
				return
			if combo_ok and InputBuffer.consume("attack", COMBO_QUEUE_WINDOW):
				combo_queued = true
		# 空中/挑空攻击保持旧行为：不吞键、不取消，跳跃缓冲留到落地后生效。
		return

	if GameState.has_ability("parry") and InputBuffer.consume("parry", 0.12) and parry_cd <= 0.0:
		_start_parry()
		return

	# Air attack has its own "once per airtime" gate. Do not let the ground
	# recovery cooldown (especially after S+J launcher) eat a jump-cancel J.
	if InputBuffer.peek("attack", AIR_ATTACK_BUFFER):
		if not is_on_floor() and not air_attack_used:
			InputBuffer.consume("attack", AIR_ATTACK_BUFFER)
			_start_air_attack()
			return
		if is_on_floor() and attack_cd <= 0.0:
			InputBuffer.consume("attack", AIR_ATTACK_BUFFER)
			if Input.is_action_pressed("move_down"):
				_start_launcher()
			elif combo_grace > 0.0 and combo_next > 0:
				_start_ground_attack(combo_next)
			else:
				_start_ground_attack(0)
			return

	if GameState.has_ability("dash") and InputBuffer.consume("dash", 0.12) and dash_cd <= 0.0 and state != State.ATTACK:
		_start_dash()
		return

	# H: pull toward a seam anchor. Release H to detach.
	if InputBuffer.consume("hook", 0.12) and _try_start_hook():
		return

	# W/S on a climbable surface takes priority over jumping.
	if hook_jump_lock <= 0.0 and _try_enter_climb():
		return

	# Wall jump: away from the wall, before the normal coyote jump.
	wall_dir = _wall_dir()
	if state == State.WALL_SLIDE and (wall_dir == 0 or is_on_floor()):
		state = State.IDLE if is_on_floor() else State.FALL

	# While a hook air jump is armed, only the dedicated branch above may
	# consume Space. Buffered duplicates of the launch press must not trigger
	# a normal double jump and steal the air jump.
	var jump_pressed := InputBuffer.peek("jump", JUMP_BUFFER) or Input.is_action_just_pressed("jump")
	var wants_jump := false
	if hook_jump_lock <= 0.0:
		wants_jump = jump_pressed
	# Detaching/arriving from the hook gives one free jump. It must fire even
	# during the short post-hook lock, otherwise the first Space is eaten and
	# the player only gets one jump when they hook while overlapping an anchor.
	if jump_pressed and hook_free_jump_timer > 0.0 and not hook_free_jump_used:
		_consume_jump()
		_dbg("FREE_JUMP", {"reason": "hook_end"})
		hook_free_jump_used = true
		hook_free_jump_timer = 0.0
		hook_air_charge = 0
		double_jump_available = true
		velocity.y = JUMP_VELOCITY
		coyote = 0.0
		state = State.JUMP
		return
	# A fresh second press during the short post-hook lock is a double jump,
	# not a duplicate of the launch press. Do not rely on the buffer surviving
	# the lock; fire it on the edge.
	var can_double := GameState.has_ability("double_jump")
	if can_double and hook_jump_lock > 0.0 and Input.is_action_just_pressed("jump") and double_jump_available and state != State.ATTACK:
		_consume_jump()
		_dbg("DOUBLE_JUMP", {"source": "post_hook_lock"})
		hook_air_charge = 0
		velocity.y = DOUBLE_JUMP_VERTICAL
		double_jump_available = false
		coyote = 0.0
		state = State.JUMP
		_shake(1.2)
		return
	if GameState.has_ability("wall_jump") and hook_jump_lock <= 0.0 and wall_dir != 0 and not is_on_floor() and wants_jump:
		_consume_jump()
		_wall_jump(wall_dir)
		return

	if wants_jump and coyote > 0.0 and state != State.ATTACK:
		_consume_jump()
		velocity.y = JUMP_VELOCITY
		coyote = 0.0
		double_jump_available = true
		state = State.JUMP
		return

	if can_double and wants_jump and not double_jump_available and hook_air_charge > 0 and state != State.ATTACK:
		_consume_jump()
		hook_air_charge = 0
		velocity.y = DOUBLE_JUMP_VERTICAL
		coyote = 0.0
		state = State.JUMP
		_shake(1.2)
		return
	if can_double and wants_jump and double_jump_available and state != State.ATTACK:
		_consume_jump()
		_dbg("DOUBLE_JUMP", {"source": "normal"})
		hook_air_charge = 0
		velocity.y = DOUBLE_JUMP_VERTICAL
		double_jump_available = false
		coyote = 0.0
		state = State.JUMP
		_shake(1.2)
		return

	if GameState.has_ability("switch") and InputBuffer.consume("switch", 0.12) and switch_cd <= 0.0:
		_switch_form()

	if InputBuffer.consume("stitch", 0.12) and stitch_cd <= 0.0:
		_stitch()

	if hook_jump_lock <= 0.0 and Input.is_action_just_released("jump") and velocity.y < JUMP_CUT_VELOCITY:
		velocity.y = JUMP_CUT_VELOCITY

func _consume_jump() -> void:
	InputBuffer.consume("jump", JUMP_BUFFER)


func _cancel_attack_into_jump() -> void:
	# 三段是终结技：取消买到的是机动（跳起追/躲），不是跳过冷却。
	# 所以三段取消仍要吃 attack_cd；一段/二段本来就没有冷却，清零即可。
	var was_finisher := attack_kind == AttackKind.GROUND and combo_index == 2
	state = State.JUMP
	combo_queued = false
	combo_grace = 0.0
	combo_next = 0
	combo_index = 0
	attack_cd = ATTACK_COOLDOWN if was_finisher else 0.0
	attack_timer = 0.0
	attack_hit_done = false
	attack_hit_landed = false
	velocity.y = JUMP_VELOCITY
	coyote = 0.0
	double_jump_available = true


func _apply_horizontal(delta: float) -> void:
	if wall_jump_lock > 0.0:
		return
	if state in [State.ATTACK, State.PARRY, State.HURT]:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	if state == State.DASH:
		velocity.x = facing * DASH_SPEED
		return

	var x := Input.get_axis("move_left", "move_right")
	if absf(x) > 0.12:
		facing = 1 if x > 0.0 else -1
		var speed := SPEED * (LING_SPEED_MULT if form == 1 else 1.0)
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, x * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if velocity.y > 0.0 and wall_dir != 0 and GameState.has_ability("wall_jump"):
			var x := Input.get_axis("move_left", "move_right")
			if absf(x) > 0.2 and signf(x) == float(wall_dir):
				state = State.WALL_SLIDE
				velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)

func _update_state() -> void:
	if state in [State.DASH, State.ATTACK, State.PARRY, State.HURT, State.DEAD, State.CLIMB, State.LEDGE, State.WALL_SLIDE, State.HOOK]:
		return
	if is_on_floor():
		state = State.RUN if absf(velocity.x) > 10.0 else State.IDLE
	else:
		state = State.JUMP if velocity.y < 0.0 else State.FALL

func _update_action_timers(delta: float) -> void:
	match state:
		State.ATTACK:
			attack_timer -= delta
			if not attack_hit_done and attack_timer <= attack_time - attack_active:
				attack_hit_done = true
				_do_attack_hit()
			if attack_timer <= 0.0:
				if attack_kind == AttackKind.GROUND and combo_queued and combo_index < 2:
					_start_ground_attack(combo_index + 1)
				else:
					state = State.IDLE
					combo_queued = false
					if attack_kind == AttackKind.GROUND and combo_index < 2:
						combo_grace = COMBO_GRACE
						combo_next = combo_index + 1
						attack_cd = 0.0
					else:
						combo_grace = 0.0
						combo_next = 0
						attack_cd = ATTACK_COOLDOWN
		State.PARRY:
			parry_elapsed += delta
			if parry_elapsed >= PARRY_ACTIVE + PARRY_RECOVERY:
				state = State.IDLE
		State.DASH:
			dash_timer -= delta
			if dash_timer <= 0.0:
				state = State.IDLE
		State.HURT:
			hurt_timer -= delta
			if hurt_timer <= 0.0:
				state = State.IDLE

func _start_attack() -> void:
	_start_ground_attack(0)

func _start_ground_attack(step: int) -> void:
	state = State.ATTACK
	attack_kind = AttackKind.GROUND
	combo_grace = 0.0
	combo_next = 0
	combo_index = clampi(step, 0, 2)
	combo_queued = false
	attack_time = float(COMBO_TIMES[combo_index])
	attack_active = float(COMBO_ACTIVE[combo_index])
	attack_damage = float(COMBO_DAMAGE[combo_index])
	attack_range = float(COMBO_RANGE[combo_index])
	attack_timer = attack_time
	attack_cd = 0.0
	attack_hit_done = false
	attack_hit_landed = false
	velocity.x = facing * (35.0 + 15.0 * combo_index)
	if combo_index == 2:
		velocity.x = facing * 90.0

func _start_launcher() -> void:
	if not is_on_floor():
		return
	state = State.ATTACK
	attack_kind = AttackKind.LAUNCHER
	combo_index = 0
	combo_queued = false
	attack_time = LAUNCH_TIME
	attack_active = LAUNCH_ACTIVE
	attack_damage = LAUNCH_DAMAGE
	attack_range = LAUNCH_RANGE
	attack_timer = attack_time
	attack_cd = 0.0
	attack_hit_done = false
	attack_hit_landed = false
	velocity.x = facing * 45.0

func _start_air_attack() -> void:
	if air_attack_used:
		return
	air_attack_used = true
	state = State.ATTACK
	attack_kind = AttackKind.AIR
	combo_index = 0
	combo_queued = false
	attack_time = AIR_ATTACK_TIME
	attack_active = AIR_ATTACK_ACTIVE
	attack_damage = AIR_ATTACK_DAMAGE
	attack_range = AIR_ATTACK_RANGE
	attack_timer = attack_time
	attack_cd = 0.0
	attack_hit_done = false
	attack_hit_landed = false
	velocity.y = minf(velocity.y, -40.0)
	velocity.x = facing * 70.0

## 身前的敌人。查询本体在 AttackProbe（无状态、可单测），这里只负责把
## 玩家当前的位置、朝向、攻击距离喂给探测层。
func _enemies_in_attack_box(half_height: float) -> Array[Node]:
	if not is_inside_tree():
		return []
	return AttackProbe.enemies_in_attack_box(
		get_world_2d(), global_position, facing, attack_range, half_height
	)


## 半径内的敌人。震退、最近的敌人等"不按攻击盒算"的场景用这个。
func _enemies_in_radius(radius: float) -> Array[Node]:
	if not is_inside_tree():
		return []
	return AttackProbe.enemies_in_radius(get_world_2d(), global_position, radius)


func _do_attack_hit() -> void:
	var hit_any := false
	var hit_count := 0
	var spark_color := Color("#FFE6A8")
	if attack_kind == AttackKind.LAUNCHER:
		spark_color = Color("#8FF5E3")
	elif attack_kind == AttackKind.AIR:
		spark_color = Color("#FF7AA8")
	for enemy in _enemies_in_attack_box(62.0):
		if not is_instance_valid(enemy) or enemy.get("hp") == null:
			continue
		if enemy.get("hp") <= 0:
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.x == 0.0 or signf(offset.x) == signf(float(facing)):
			if absf(offset.x) <= attack_range and absf(offset.y) <= 62.0:
				if enemy.has_method("take_hit"):
					var launch := LAUNCH_FORCE if attack_kind == AttackKind.LAUNCHER else 0.0
					var knockback := 0.0
					if attack_kind == AttackKind.GROUND:
						var kb := float(COMBO_KNOCKBACK[combo_index])
						if combo_index == 1:
							# 二段「拽」：拉向玩家。敌人与玩家不在彼此的碰撞掩码里
							# （enemy layer 4 / player layer 2，双方 mask 只有 1），
							# 所以按剩余间距反解速度，拉到 28px 停，避免穿过身体。
							kb = AttackSpec.pull_speed(offset.x)
						enemy.take_hit(attack_damage, global_position, false)
						var ev: Variant = enemy.get("velocity")
						if ev is Vector2:
							enemy.set("velocity", Vector2(signf(offset.x) * kb, ev.y))
					elif attack_kind == AttackKind.AIR:
						enemy.take_hit(attack_damage, global_position, false)
						var ev2: Variant = enemy.get("velocity")
						if ev2 is Vector2:
							enemy.set("velocity", Vector2(signf(offset.x) * 90.0, minf(ev2.y, -120.0)))
					else:
						enemy.take_hit(attack_damage, global_position, false, launch)
					hit_any = true
					hit_count += 1
					var spark_size := 30.0 + 12.0 * float(combo_index)
					if attack_kind == AttackKind.LAUNCHER:
						spark_size = 48.0
					elif attack_kind == AttackKind.AIR:
						spark_size = 34.0
					_spawn_hit_spark(Vector2(enemy.global_position.x, enemy.global_position.y - 26.0), spark_color, spark_size)
	if hit_any:
		attack_hit_landed = true
		if form == 0:
			GameState.add_sync(-2.0)
		else:
			GameState.add_sync(4.0)
		var weight := 1.0 + float(combo_index) * 0.8
		var stop_time := 0.075
		if attack_kind == AttackKind.GROUND:
			stop_time = float(Light1Spec.spec_of(combo_index).freeze_ms) / 1000.0
		elif attack_kind == AttackKind.LAUNCHER:
			weight = 1.5
			stop_time = 0.110
		elif attack_kind == AttackKind.AIR:
			weight = 1.2
			stop_time = 0.070
		# One freeze per swing, even when the arc clips two enemies.
		HitStop.stop(stop_time, 0.06)
		_shake(5.0 + weight * 3.0 + 0.8 * float(maxi(0, hit_count - 1)))
		if attack_kind == AttackKind.LAUNCHER:
			_punch_camera(0.040)
		elif attack_kind == AttackKind.GROUND and combo_index == 2:
			_punch_camera(float(Light1Spec.LIGHT3.punch))

func _start_dash() -> void:
	state = State.DASH
	dash_timer = DASH_TIME
	dash_cd = DASH_COOLDOWN
	velocity.y = 0.0
	invuln = maxf(invuln, DASH_TIME)
	_shake(1.5)

func _start_parry() -> void:
	state = State.PARRY
	parry_elapsed = 0.0
	parry_cd = PARRY_COOLDOWN
	velocity.x *= 0.2

func receive_attack(attack: Dictionary) -> bool:
	## Returns true when the attack was negated (parry, perfect parry, or i-frame).
	if state == State.DEAD:
		return true
	if invuln > 0.0:
		return true

	var source: Variant = attack.get("source", null)
	if source is Node:
		last_attacker = source

	if not bool(attack.get("parryable", true)):
		_take_damage(float(attack.get("damage", 10)), source)
		return false

	var was_parrying := state == State.PARRY
	if was_parrying and CombatMath.is_active(parry_elapsed):
		var result := CombatMath.classify_parry(parry_elapsed)
		if result == "perfect":
			_on_perfect_parry()
			return true
		if result == "normal":
			_on_normal_parry()
			return true

	_take_damage(float(attack.get("damage", 10)), attack.get("source", null))
	# A failed parry is still information: the seam was there, you were late.
	if was_parrying:
		GameState.add_sync(CombatMath.FAIL_SYNC, true)
	return false

func _on_normal_parry() -> void:
	parry_count += 1
	GameState.add_sync(CombatMath.SUCCESS_SYNC, true)
	GameEvents.parry_result.emit("normal", false)
	parried.emit(false)
	parry_cd = CombatMath.COOLDOWN
	_shake(4.0)
	var source = _current_attack_source()
	if source and source.has_method("on_parried"):
		source.on_parried(false)

func _on_perfect_parry() -> void:
	parry_count += 1
	perfect_parry_count += 1
	GameState.add_sync(CombatMath.PERFECT_SYNC, true)
	GameState.freeze_sync(CombatMath.PERFECT_SYNC_FREEZE)
	perfect_buff = CombatMath.PERFECT_SEAM_TIME
	GameEvents.parry_result.emit("perfect", true)
	parried.emit(true)
	parry_cd = 0.0
	_shake(8.0)

	# Perfect parry is the shortest path to A-Ling: a short automatic switch.
	# 换人解锁前（01_GDD/10 §4）：完美弹反照常判定，但不换人。
	if not GameState.is_takeover and GameState.has_ability("switch"):
		GameState.set_form(1)
		perfect_switch_timer = CombatMath.PERFECT_SWITCH_TIME

	var source = _current_attack_source()
	if source and source.has_method("on_parried"):
		source.on_parried(true)

func _current_attack_source() -> Node:
	if last_attacker != null and is_instance_valid(last_attacker):
		return last_attacker
	# Fallback: nearest enemy, so a parry still staggers someone in a crowd.
	var best: Node = null
	var best_dist := 1e20
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best

func _switch_form() -> void:
	if GameState.is_takeover:
		return
	switch_cd = 0.6
	form = 1 - form
	GameState.set_form(form)
	GameState.add_sync(5.0 if form == 1 else -5.0, true)
	GameEvents.message.emit("换人。" if form == 1 else "回来。")
	_shake(3.0)
	for enemy in _enemies_in_radius(110.0):
		if enemy.has_method("stagger"):
			enemy.stagger(0.35)

func _stitch() -> void:
	stitch_cd = STITCH_COOLDOWN
	var seam := _nearest_in_group("seams", STITCH_RANGE)
	if seam and seam.has_method("activate"):
		seam.activate()
		GameState.add_sync(-6.0, true)
		GameEvents.message.emit("缝住接缝。")
		return
	var enemy := _nearest_enemy(70.0)
	if enemy and enemy.get("hp") != null and enemy.get("hp") <= 25.0 and enemy.has_method("stitch"):
		enemy.stitch()
		GameState.add_sync(-6.0, true)
		GameEvents.message.emit("缝住他。留一口气。")
		return
	GameState.heal(12.0)
	GameState.add_sync(-6.0, true)
	GameEvents.message.emit("缝自己。疼，但还能动。")

func _nearest_in_group(group: String, max_dist: float) -> Node:
	var best: Node = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best

## 最近的可及敌人。用物理半径查询，不会把墙那边的敌人算进来。
## 选取口径（活着的、距离最近的）在 AttackProbe 里，这里只给世界与原点。
func _nearest_enemy(max_dist: float) -> Node:
	if not is_inside_tree():
		return null
	return AttackProbe.nearest_alive(get_world_2d(), global_position, max_dist)

func _take_damage(amount: float, source: Variant) -> void:
	if invuln > 0.0 or state == State.DEAD:
		return
	GameState.damage(amount)
	invuln = INVULN_TIME
	state = State.HURT
	hurt_timer = HURT_TIME
	if state == State.HOOK:
		_end_hook(false)
	if source is Node2D:
		var dir := signf(global_position.x - (source as Node2D).global_position.x)
		if dir == 0.0:
			dir = -facing
		velocity = Vector2(dir * 260.0, -180.0)
	else:
		velocity = Vector2(-facing * 220.0, -160.0)
	_shake(6.0)
	modulate = Color(1.0, 0.4, 0.4, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_player_died() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	hook_target = null
	queue_redraw()
	respawn_timer = 1.2
	velocity = Vector2.ZERO
	GameEvents.message.emit("断线。")
	_shake(12.0)

func _respawn() -> void:
	GameState.reset()
	global_position = GameState.checkpoint
	velocity = Vector2.ZERO
	state = State.IDLE
	double_jump_available = true
	wall_jump_lock = 0.0
	climb_jump_lock = 0.0
	hook_jump_lock = 0.0
	climb_regrab_requires_release = false
	hook_target = null
	hook_air_jump_armed = false
	hook_air_jump_needs_release = false
	hook_free_jump_timer = 0.0
	hook_free_jump_used = false
	hook_air_charge = 0
	queue_redraw()
	invuln = 1.0
	GameEvents.message.emit("针眼。再来。")

func _takeover_ai(delta: float) -> void:
	## A-Ling's 8 seconds: she moves and hits for you, badly, beautifully.
	var enemy := _nearest_enemy(420.0)
	if enemy == null:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		return
	var dx: float = enemy.global_position.x - global_position.x
	facing = 1 if dx >= 0.0 else -1
	if absf(dx) > 60.0:
		velocity.x = move_toward(velocity.x, facing * 300.0, 1800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
		if attack_cd <= 0.0:
			attack_cd = 0.22
			_do_attack_hit()
	if is_on_floor() and randf() < 0.02:
		velocity.y = -380.0


# --- W2-02 seam hook -----------------------------------------------------------

func _try_start_hook() -> bool:
	if not GameState.has_ability("hook"):
		return false
	if state in [State.DASH, State.ATTACK, State.PARRY, State.HURT, State.DEAD, State.CLIMB, State.LEDGE, State.HOOK]:
		return false
	var target := _nearest_in_group("hook_anchors", HOOK_RANGE)
	if not target is Node2D:
		return false
	hook_target = target as Node2D
	state = State.HOOK
	velocity = Vector2.ZERO
	facing = 1 if hook_target.global_position.x >= global_position.x else -1
	queue_redraw()
	_shake(1.0)
	hook_jump_was_held = Input.is_action_pressed("jump")
	GameEvents.message.emit("钩住了。")
	return true


func _hook_update(_delta: float) -> void:
	if not is_instance_valid(hook_target):
		_end_hook(false)
		return
	var to := hook_target.global_position - global_position
	_dbg("HOOK_TICK", {"dist": snappedf(to.length(), 0.1), "jump_held": Input.is_action_pressed("jump"), "hook_held": Input.is_action_pressed("hook")})
	# Jump is checked before both arrival and H release. Players naturally
	# release H as they press Space; that must still count as a hook jump.
	var jump_stamp_before := InputBuffer.peek_stamp("jump")
	var hook_jump_pressed := InputBuffer.consume("jump", JUMP_BUFFER)
	var jump_source := "buffer" if hook_jump_pressed else ""
	if not hook_jump_pressed and Input.is_action_just_pressed("jump"):
		hook_jump_pressed = true
		jump_source = "just_pressed"
	# Hardware/edge fallback: if the press event arrived between physics
	# frames, just_pressed and the buffer can both miss it. A held-edge is
	# unambiguous while already in HOOK.
	var jump_held := Input.is_action_pressed("jump")
	if not hook_jump_pressed and jump_held and not hook_jump_was_held:
		hook_jump_pressed = true
		jump_source = "held_edge"
	hook_jump_was_held = jump_held
	if hook_jump_pressed:
		_dbg("HOOK_JUMP", {"source": jump_source, "stamp_before": jump_stamp_before, "stamp_after": InputBuffer.peek_stamp("jump")})
		hook_target = null
		state = State.JUMP
		velocity = Vector2(velocity.x * HOOK_JUMP_X_KEEP, HOOK_JUMP_VERTICAL)
		double_jump_available = true
		hook_air_charge = 1
		hook_air_jump_armed = false
		hook_air_jump_needs_release = false
		hook_air_jump_preserve_double = false
		hook_release_pending = false
		hook_release_grace = 0.0
		hook_jump_lock = HOOK_JUMP_LOCK
		hook_free_jump_timer = 0.0
		hook_free_jump_used = false
		hook_jump_was_held = true
		# Clear only the launch press if it is still the newest buffered press.
		# If the player already pressed Space again, that newer press must
		# survive as the air jump.
		var kept_newer := InputBuffer.peek_stamp("jump") > jump_stamp_before
		if not kept_newer:
			InputBuffer.clear_action("jump")
		_dbg("HOOK_CLEAR", {"kept_newer": kept_newer, "stamp_after": InputBuffer.peek_stamp("jump")})
		queue_redraw()
		return
	if not Input.is_action_pressed("hook"):
		# Give a short grace so "release H, then press Space" still reads as
		# a hook jump instead of detaching and burning the air jump.
		if not hook_release_pending:
			hook_release_pending = true
			hook_release_grace = 0.25
			_dbg("HOOK_RELEASE")
		velocity = Vector2.ZERO
		return
	hook_release_pending = false
	hook_release_grace = 0.0
	if to.length() <= HOOK_ARRIVE:
		_end_hook(true)
		return
	velocity = to.normalized() * HOOK_SPEED
	facing = 1 if velocity.x >= 0.0 else -1
	queue_redraw()


func _end_hook(arrived: bool) -> void:
	if state != State.HOOK:
		return
	_dbg("HOOK_END", {"arrived": arrived})
	hook_target = null
	state = State.FALL
	hook_release_pending = false
	hook_release_grace = 0.0
	velocity = Vector2.ZERO if arrived else velocity * HOOK_DETACH_KEEP
	# A hook arrival/detach always leaves one free jump. The window must be
	# long enough for a normal human reaction (the old 0.15s expired before
	# a Space pressed ~0.18s after arrival, which silently burned the air jump).
	hook_free_jump_timer = HOOK_FREE_JUMP_TIME
	hook_free_jump_used = false
	hook_air_charge = 1
	# Arrival and release both restore the air jump; the free jump is extra.
	double_jump_available = true
	if arrived:
		hook_air_jump_armed = false
		hook_air_jump_needs_release = false
		hook_air_jump_preserve_double = false
		hook_jump_lock = HOOK_JUMP_LOCK
	queue_redraw()


func _draw() -> void:
	if state == State.HOOK and is_instance_valid(hook_target):
		var tip := to_local(hook_target.global_position)
		draw_line(Vector2.ZERO, tip, Color("#BFF7F0"), 2.0)
		draw_circle(tip, 5.0, Color("#FF3E8A"))


# --- Movement kit: climb, wall jump, ledge grab --------------------------------

func _on_climb_area_entered(area: Area2D) -> void:
	if area == null or not area.is_in_group("climbable"):
		return
	if not climb_zones.has(area):
		climb_zones.append(area)


func _on_climb_area_exited(area: Area2D) -> void:
	climb_zones.erase(area)


func _has_climb_zone() -> bool:
	for i in range(climb_zones.size() - 1, -1, -1):
		if not is_instance_valid(climb_zones[i]):
			climb_zones.remove_at(i)
	return not climb_zones.is_empty()


func _try_enter_climb() -> bool:
	if not GameState.has_ability("climb"):
		return false
	if climb_jump_lock > 0.0 or not _has_climb_zone():
		return false
	if climb_regrab_requires_release:
		if Input.is_action_pressed("move_up"):
			return false
		climb_regrab_requires_release = false
	var y_axis := Input.get_axis("move_up", "move_down")
	if y_axis > -0.25 and (y_axis < 0.25 or is_on_floor()):
		return false
	state = State.CLIMB
	velocity = Vector2.ZERO
	var zone := climb_zones[0]
	var dx := zone.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = 1 if dx > 0.0 else -1
	ledge_dir = facing
	return true


func _climb_update(delta: float) -> void:
	# While a hook air jump is armed, only the dedicated branch above may
	# consume Space. Buffered duplicates of the launch press must not trigger
	# a normal double jump and steal the air jump.
	var wants_jump := false
	if hook_jump_lock <= 0.0:
		wants_jump = InputBuffer.peek("jump", JUMP_BUFFER) or Input.is_action_just_pressed("jump")
	if wants_jump:
		_consume_jump()
		var x_axis := Input.get_axis("move_left", "move_right")
		velocity = Vector2(x_axis * CLIMB_JUMP_HORIZONTAL, CLIMB_JUMP_VERTICAL)
		state = State.JUMP
		double_jump_available = true
		climb_jump_lock = CLIMB_JUMP_LOCK
		climb_regrab_requires_release = true
		InputBuffer.clear_action("jump")
		coyote = 0.0
		return
	if not _has_climb_zone():
		state = State.FALL
		return
	var y_axis := Input.get_axis("move_up", "move_down")
	# 抓住后横向吸附到梯缝中线（手测 2026-10-23：原先左/中/右都能爬）。
	# 走 velocity + move_and_slide：贴墙的梯缝会停在墙边，不会穿墙。
	var snap_dx := climb_zones[0].global_position.x - global_position.x
	var snap_vx := clampf(snap_dx / delta, -CLIMB_SNAP_SPEED, CLIMB_SNAP_SPEED)
	velocity = Vector2(snap_vx, y_axis * CLIMB_SPEED)
	if GameState.has_ability("dash") and InputBuffer.consume("dash", 0.12):
		_start_dash()
		return
	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		state = State.IDLE
		velocity = Vector2.ZERO


func _ledge_update(_delta: float) -> void:
	velocity = Vector2.ZERO
	if InputBuffer.consume("jump", JUMP_BUFFER):
		velocity = Vector2(ledge_dir * LEDGE_VAULT_HORIZONTAL, LEDGE_VAULT_VERTICAL)
		state = State.JUMP
		ledge_cd = LEDGE_COOLDOWN
		return
	if Input.is_action_just_pressed("move_down"):
		velocity = Vector2(0.0, LEDGE_DROP_SPEED)
		state = State.FALL
		ledge_cd = LEDGE_COOLDOWN


func _check_ledge_grab() -> void:
	if not GameState.has_ability("climb"):
		return
	if ledge_cd > 0.0 or is_on_floor() or velocity.y < 0.0:
		return
	if _try_grab_ledge():
		state = State.LEDGE
		velocity = Vector2.ZERO
		ledge_dir = facing
		ledge_cd = LEDGE_COOLDOWN


func _try_grab_ledge() -> bool:
	return MovementProbe.can_grab_ledge(
		get_world_2d(),
		global_position,
		facing,
		LEDGE_PROBE_FORWARD,
		LEDGE_PROBE_ABOVE
	)


func _wall_dir() -> int:
	return MovementProbe.wall_dir(get_world_2d(), global_position, facing)


func _wall_jump(dir: int) -> void:
	facing = -dir
	velocity = Vector2(-dir * WALL_JUMP_HORIZONTAL, WALL_JUMP_VERTICAL)
	state = State.JUMP
	coyote = 0.0
	double_jump_available = true
	wall_jump_lock = WALL_JUMP_LOCK
	InputBuffer.clear_action("jump")
	_shake(1.5)


func _update_visuals() -> void:
	if body == null or overlay == null:
		return
	body.color = Color("#3FE0D0") if form == 0 else Color("#FF3E8A")
	overlay.visible = false
	body.scale.x = facing
	overlay.scale.x = facing
	if sprite:
		sprite.scale.x = absf(sprite.scale.y) * float(facing)
		if form == 0:
			sprite.modulate = Color.WHITE
		else:
			sprite.modulate = Color(1.0, 0.62, 0.78) if not GameState.is_takeover else Color(1.0, 0.45, 0.95)
	if tag:
		tag.text = "阿针" if form == 0 else "阿绫"
		tag.modulate = Color("#BFF7F0") if form == 0 else Color("#FF8FB0")

func _on_form_changed(new_form: int) -> void:
	form = new_form
	_update_visuals()

func _spawn_hit_spark(at: Vector2, color: Color, size: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var spark: Node2D = HitSparkScript.new()
	parent.add_child(spark)
	spark.setup(at, color, size)
	spark.z_index = 20


func _punch_camera(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("punch"):
		cam.punch(amount)


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(amount)
