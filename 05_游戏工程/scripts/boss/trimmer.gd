class_name Trimmer
extends CharacterBody2D
## Boss: The Trimmer. Three phases, parryable seams, unparryable red attacks.
## Whitebox: all attacks are direct calls on the player, no projectile scenes.

## Boss 状态。字符串状态换 enum：写错立即编译失败，不再静默走 default。
enum State { IDLE, WINDUP, RECOVER, STAGGER, TRANSITION, DEAD }
## 五个技能。pending_attack 也用 enum，_execute_attack 的 match 才有穷尽性。
enum Attack { COMBO, OVERHEAD, LASER, GRID, SPIN }

const GRAVITY := 1400.0
const SPEED := 90.0
## 血量调参：可用场景覆盖或未来的 BossStats 资源写入。
@export var MAX_HP := 300.0
@export var PHASE_2_HP := 200.0
@export var PHASE_3_HP := 100.0

var hp := MAX_HP
var phase := 1
var state: State = State.IDLE
var timer := 0.0
var player: Node2D
var facing := -1
var attack_cd := 0.0
var combo_index := 0
var combo_parried := 0
var stagger_timer := 0.0
var invuln := 0.0
var seam_timer := 0.0
var hit_flash := 0.0
var phase_announced := false
var pending_attack: Attack = Attack.COMBO

@onready var body: Polygon2D = $Body
@onready var telegraph: Polygon2D = $Telegraph
@onready var tag: Label = $Tag

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")
	GameEvents.message.emit("裁断者：雨市。尺寸不合。准予裁断。")
	_update_visuals()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 820.0)
	attack_cd = maxf(0.0, attack_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	seam_timer = maxf(0.0, seam_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

	if state == State.TRANSITION:
		timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		if timer <= 0.0:
			_set_state(State.IDLE)
			invuln = 0.0
		move_and_slide()
		_update_visuals()
		return

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		_update_visuals()
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if player:
		var dx: float = player.global_position.x - global_position.x
		facing = 1 if dx >= 0.0 else -1

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if attack_cd <= 0.0 and player:
				_choose_attack()
		State.WINDUP:
			timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if timer <= 0.0:
				_execute_attack()
		State.RECOVER:
			timer -= delta
			if timer <= 0.0:
				_set_state(State.IDLE)
				attack_cd = 0.25 if phase == 3 else 0.55
		State.STAGGER:
			pass

	move_and_slide()
	_update_visuals()

func _choose_attack() -> void:
	if phase == 1:
		if combo_index > 0:
			_start_windup(0.24, Attack.COMBO)
		elif randf() < 0.28:
			combo_index = 0
			_start_windup(0.65, Attack.OVERHEAD)
		else:
			combo_index = 0
			_start_windup(0.42, Attack.COMBO)
	elif phase == 2:
		if randf() < 0.5:
			_start_windup(0.70, Attack.LASER)
		else:
			_start_windup(0.60, Attack.GRID)
	else:
		if randf() < 0.35:
			_start_windup(0.52, Attack.SPIN)
		elif randf() < 0.5:
			_start_windup(0.32, Attack.COMBO)
		else:
			_start_windup(0.58, Attack.LASER)

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next


func _start_windup(duration: float, kind: Attack) -> void:
	_set_state(State.WINDUP)
	timer = duration
	pending_attack = kind
	velocity.x = 0.0

func _execute_attack() -> void:
	_set_state(State.RECOVER)
	timer = 0.55 if phase < 3 else 0.35
	match pending_attack:
		Attack.COMBO:
			_attack_combo()
		Attack.OVERHEAD:
			_attack_overhead()
		Attack.LASER:
			_attack_laser()
		Attack.GRID:
			_attack_grid()
		Attack.SPIN:
			_attack_spin()

func _attack_combo() -> void:
	combo_index += 1
	if player and _player_in_range(150.0, 90.0):
		player.receive_attack({"damage": 12.0 if phase < 3 else 15.0, "source": self, "parryable": true})
	if combo_index < 3:
		_start_windup(0.24 if phase < 3 else 0.18, Attack.COMBO)
	else:
		combo_index = 0

func _attack_overhead() -> void:
	if player and _player_in_range(170.0, 110.0):
		player.receive_attack({"damage": 20.0, "source": self, "parryable": false})

func _attack_laser() -> void:
	# Long horizontal beam: must be parried or avoided by jumping/dashing.
	if player and absf(player.global_position.x - global_position.x) < 560.0 and absf(player.global_position.y - global_position.y) < 80.0:
		var negated: bool = player.receive_attack({"damage": 15.0, "source": self, "parryable": true})
		if negated:
			stagger(1.0)
			combo_parried += 1

func _attack_grid() -> void:
	if player and _player_in_range(230.0, 130.0):
		var negated: bool = player.receive_attack({"damage": 12.0, "source": self, "parryable": true})
		if negated:
			stagger(2.0)
			seam_timer = 2.0
			GameEvents.message.emit("网格短路。接缝全开。")

func _attack_spin() -> void:
	if player and _player_in_range(220.0, 140.0):
		player.receive_attack({"damage": 25.0, "source": self, "parryable": false})
	_shake(8.0)

func _player_in_range(range_x: float, range_y: float) -> bool:
	if player == null:
		return false
	var dx: float = player.global_position.x - global_position.x
	var dy: float = absf(player.global_position.y - global_position.y)
	if absf(dx) > range_x or dy > range_y:
		return false
	return signf(dx) == signf(float(facing)) or absf(dx) < 40.0

func take_hit(damage: float, _from: Vector2, _parryable: bool = false, _launch_force: float = 0.0) -> void:
	if state == State.DEAD or state == State.TRANSITION or invuln > 0.0:
		return
	var mult := 1.5 if seam_timer > 0.0 else 1.0
	hp -= damage * mult
	hit_flash = 0.12
	if hp <= 0.0:
		die()
		return
	_check_phase()

func _check_phase() -> void:
	if phase == 1 and hp <= PHASE_2_HP:
		_enter_phase(2)
	elif phase == 2 and hp <= PHASE_3_HP:
		_enter_phase(3)

func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	_set_state(State.TRANSITION)
	timer = 1.5
	invuln = 1.5
	combo_index = 0
	combo_parried = 0
	GameEvents.boss_phase_changed.emit(phase)
	if phase == 2:
		GameEvents.message.emit("裁断者：你的缝，很旧。")
	else:
		GameEvents.message.emit("裁断者：为什么……不拆？")

func on_parried(perfect: bool) -> void:
	combo_parried += 1
	stagger(0.5)
	if perfect:
		seam_timer = maxf(seam_timer, 1.5)
	if combo_parried >= 3:
		combo_parried = 0
		stagger(1.5)
		seam_timer = 2.0
		GameEvents.message.emit("三连全弹。她跪了。")

func stagger(duration: float) -> void:
	stagger_timer = maxf(stagger_timer, duration)
	_set_state(State.STAGGER)
	velocity.x = 0.0

func die() -> void:
	_set_state(State.DEAD)
	invuln = 999.0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	GameEvents.boss_defeated.emit()
	GameEvents.message.emit("裁断者：为什么……不拆？")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.2)
	tween.tween_callback(queue_free)

func _update_visuals() -> void:
	if body == null:
		return
	if hit_flash > 0.0:
		body.color = Color.WHITE
	elif state == State.TRANSITION or invuln > 0.0:
		body.color = Color("#7FE7FF")
	elif seam_timer > 0.0:
		body.color = Color("#FFB13B")
	else:
		body.color = Color("#F2EFE6")
	if telegraph:
		telegraph.visible = state == State.WINDUP
	if tag:
		tag.text = "裁断者  P%d" % phase
		tag.modulate = Color("#F2EFE6")

# --- 标签层接口（与 EnemyBase 同一套约定） ------------------------------------

func label_text() -> String:
	if state == State.DEAD:
		return ""
	return "裁断者  P%d  %d/%d" % [phase, int(hp), int(MAX_HP)]


func label_anchor() -> Vector2:
	return global_position + Vector2(0, -118.0)


func label_alpha() -> float:
	return 1.0 if state == State.WINDUP else 0.85


func label_tint() -> Color:
	return Color("#FF6B6B") if state == State.WINDUP else Color("#F2EFE6")


func is_dead() -> bool:
	return state == State.DEAD


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(amount)
