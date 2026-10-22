class_name EnemyBase
extends CharacterBody2D
## 敌人骨架：血量、受击、顿帧、闪白、朝向、死亡、目标查找、状态机约定。
##
## 架构约定（P0-3）：
##   · 这里不放任何"怎么打"的逻辑，只放"怎么活/怎么死"；
##   · 状态是 enum 而不是字符串 —— typo 变成编译期错误；
##   · 状态迁移必须走 _set_state()，让子类能挂 enter/exit 钩子；
##   · 子类实现 _update_ai(delta)；不实现就站着不动。
##
## 加第 3 种敌人 = 新建一个继承本类的小脚本，不是复制 257 行。

const GRAVITY := 1400.0

## 敌人状态。加状态在这里加，_set_state 会保证 enter/exit 都被调用。
enum State { IDLE, PATROL, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

# --- 数值（场景可覆盖） -------------------------------------------------------
@export var move_speed := 72.0
@export var attack_range := 62.0
@export var detect_range := 230.0
@export var windup_time := 0.45
@export var recover_time := 0.55
@export var attack_damage := 10.0
@export var max_hp := 40.0
@export var enemy_name := "清道夫"
@export var body_tint := Color("#D9E6F2")
@export var speed_label := "快"
@export var reach_label := "短"
## 训练假人：有物理和受击反馈，但永不追击、永不出手。
@export var passive := false
## 死亡时掉落的零件 id（01_GDD/10 §4）；空 = 不掉。
@export var drops_part := ""

# --- 运行时 -------------------------------------------------------------------
var hp := 0.0
var state: State = State.PATROL
var timer := 0.0
var player: Node2D
var facing := -1
var spawn_x := 0.0
var patrol_dir := 1
var stagger_timer := 0.0
var seam_timer := 0.0
var attack_cd := 0.0
var hit_flash := 0.0

@onready var body: Polygon2D = $Body
@onready var telegraph: Polygon2D = $Telegraph
@onready var tag: Label = $Tag


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	spawn_x = global_position.x
	player = get_tree().get_first_node_in_group("player")
	_on_ready()
	_update_visuals()


## 子类钩子：_ready 之后、第一次视觉更新之前调用。
func _on_ready() -> void:
	pass


## 子类钩子：每物理帧的 AI。不实现就不动。
func _update_ai(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 820.0)
	attack_cd = maxf(0.0, attack_cd - delta)
	seam_timer = maxf(0.0, seam_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		_update_visuals()
		return
	# 硬直计时器才是权威：到点后把控制权交回追击，
	# 否则敌人会永远停在 STAGGER 里再也不动。
	if state == State.STAGGER:
		_set_state(State.CHASE)

	if passive:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		_update_visuals()
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	_update_ai(delta)
	move_and_slide()
	_update_visuals()


# --- 状态机 -------------------------------------------------------------------

## 唯一的状态迁移入口。子类用这个，不要直接写 state = X。
func _set_state(next: State) -> void:
	if state == next:
		return
	_exit_state(state)
	state = next
	_enter_state(next)


## 子类钩子：进入某状态时初始化。
func _enter_state(_next: State) -> void:
	pass


## 子类钩子：离开某状态时清理。
func _exit_state(_prev: State) -> void:
	pass


func is_dead() -> bool:
	return state == State.DEAD


func state_name() -> String:
	return State.keys()[state]


# --- 受击 / 死亡 --------------------------------------------------------------

func take_hit(damage: float, from: Vector2, _parryable: bool = false, launch_force: float = 0.0) -> void:
	if state == State.DEAD:
		return
	var mult := 1.5 if seam_timer > 0.0 else 1.0
	hp -= damage * mult
	hit_flash = 0.12 if damage < 18.0 else 0.20
	if hp <= 0.0:
		die()
		return
	stagger(0.18)
	if launch_force > 0.0:
		velocity.y = -launch_force
		velocity.x = signf(global_position.x - from.x) * 80.0
		stagger_timer = maxf(stagger_timer, 0.35)


func on_parried(perfect: bool) -> void:
	stagger(0.55)
	if perfect:
		seam_timer = 1.5
		hp = maxf(1.0, hp - 6.0)
		GameEvents.message.emit("接缝露出来了。")


func stagger(duration: float) -> void:
	stagger_timer = maxf(stagger_timer, duration)
	_set_state(State.STAGGER)
	velocity.x = 0.0


## 缝：留一口气，直接结束。
func stitch() -> void:
	die()


func die() -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	GameEvents.message.emit("缝住了。")
	_drop_part()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.3, 0.3, 0.35, 0.0), 0.35)
	tween.tween_callback(queue_free)



func _drop_part() -> void:
	if drops_part.is_empty() or get_parent() == null:
		return
	var part: Node2D = (load("res://scenes/level/part_pickup.tscn") as PackedScene).instantiate()
	part.set("part_id", drops_part)
	part.position = position
	get_parent().add_child.call_deferred(part)

# --- 供 HUD / 标签层读取（不暴露内部节点） -------------------------------------

## 一行状态摘要。EnemyLabelLayer 直接画这个，不需要认识敌人类型。
func label_text() -> String:
	return "%s · %s %.2fs · %s %dpx" % [
		enemy_name, speed_label, windup_time, reach_label, int(attack_range)]


## 标签锚点（世界坐标）。
func label_anchor() -> Vector2:
	var offset := -62.0
	if tag != null:
		offset = tag.offset_top
	return global_position + Vector2(0, offset - 30.0)


func label_alpha() -> float:
	return 0.72 if state != State.WINDUP else 1.0


func label_tint() -> Color:
	return Color(1, 0.55, 0.55) if state == State.WINDUP else Color.WHITE


# --- 视觉 ---------------------------------------------------------------------

func _draw() -> void:
	if state == State.DEAD:
		return
	var dir := float(facing)
	var reach := attack_range
	var weapon_len := 78.0 if reach > 90.0 else 24.0
	var line_color := body_tint
	# 待机剪影：长柄兵带着可见的长杆，短兵带短刃。
	draw_line(Vector2(0, -3), Vector2(dir * weapon_len, -3), line_color, 4.0)
	draw_circle(Vector2(dir * weapon_len, -3), 4.0 if reach <= 90.0 else 3.0, line_color)
	if state == State.WINDUP:
		var p: float = clampf(1.0 - timer / maxf(windup_time, 0.01), 0.0, 1.0)
		var parry_window := clampf(CombatMath.ACTIVE_WINDOW / maxf(windup_time, 0.01), 0.0, 1.0)
		var parry_now := timer <= CombatMath.ACTIVE_WINDOW
		var c := Color(0.55, 0.95, 1.0, 0.75) if parry_now else Color(1.0, 0.35, 0.42, 0.35 + 0.55 * p)
		draw_line(Vector2(dir * 8, -5), Vector2(dir * reach, -5), c, 7.0)
		# 前摇进度条让速度可读，即使没有动画帧也能判断时机。
		var bar_y := -62.0 - 48.0
		draw_rect(Rect2(-28, bar_y, 56, 7), Color(0.02, 0.03, 0.05, 0.95))
		draw_rect(Rect2(-28, bar_y, 56 * p, 7), c)
		# 前摇末尾 ACTIVE_WINDOW 就是弹反窗，画出来慢兵才不会觉得弹不了。
		var wx := -28.0 + 56.0 * (1.0 - parry_window)
		draw_rect(Rect2(wx, bar_y - 2, 56.0 * parry_window, 11),
			Color(0.55, 0.95, 1.0, 0.22 if not parry_now else 0.42))
		draw_rect(Rect2(-28, bar_y, 56, 7), Color(c.r, c.g, c.b, 0.95), false, 1.0)
	elif state == State.RECOVER:
		var a: float = clampf(timer / maxf(recover_time, 0.01), 0.0, 1.0)
		draw_line(Vector2(dir * 8, -5), Vector2(dir * reach, -5), Color(1, 0.42, 0.36, 0.35 * a), 5.0)


func _update_visuals() -> void:
	queue_redraw()
	if body == null:
		return
	if hit_flash > 0.0:
		# 身体本来就接近白色，用高亮橙 + squash 让顿帧可见。
		body.color = Color("#FF8A3D")
		body.scale = Vector2(1.14, 0.86)
	elif seam_timer > 0.0:
		body.color = Color("#FFB13B")
	else:
		body.color = body_tint if state != State.WINDUP else Color("#FF6B6B")
		body.scale = Vector2.ONE
	if telegraph:
		# 自定义距离线 + 前摇条取代旧的方框 telegraph。
		telegraph.visible = false
	if tag:
		if seam_timer > 0.0:
			tag.text = "接缝"
			tag.modulate = Color("#FFB13B")
		elif state == State.WINDUP:
			if timer <= CombatMath.ACTIVE_WINDOW:
				tag.text = "K 弹反"
				tag.modulate = Color("#8FF5E3")
			elif timer <= CombatMath.ACTIVE_WINDOW + 0.12:
				tag.text = "准备…"
				tag.modulate = Color("#FFB13B")
			else:
				tag.text = "!"
				tag.modulate = Color("#FF6B6B")
		else:
			tag.text = enemy_name
			tag.modulate = Color(1, 1, 1, 0.45)
	body.scale.x = facing
