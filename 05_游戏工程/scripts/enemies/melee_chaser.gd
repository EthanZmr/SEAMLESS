class_name MeleeChaser
extends EnemyBase
## 近战追兵：巡逻 → 发现 → 追击 → 前摇 → 出手 → 恢复。
##
## 这是"清道夫 / 截线者"共用的行为。差异只有数值和一两处可覆盖点：
##   · _do_attack()      出手判定（截线者可以改成横向长扫 / 突刺）
##   · _attack_bonus()   额外攻击距离（默认 30）
##   · _patrol_half()    巡逻半径
##
## 加第 3 种近战敌人：继承本类，覆盖一个方法即可，不用碰 250 行。
## 加非近战敌人（远程/飞行/召唤）：直接继承 EnemyBase 实现 _update_ai()。

## 发现目标后，前摇开始前允许的最大垂直落差。
const VERTICAL_DETECT := 140.0
## 追击距离比发现距离多出的滞后量，避免在边界上反复横跳。
const CHASE_RELEASE_SLACK := 40.0


func _update_ai(delta: float) -> void:
	if player != null and is_instance_valid(player):
		_acquire_target(delta)

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			# 有目标就去追；没有就出门巡逻。
			if player != null:
				_set_state(State.CHASE)
			else:
				_set_state(State.PATROL)
		State.PATROL:
			var half := _patrol_half()
			if global_position.x <= spawn_x - half:
				patrol_dir = 1
			elif global_position.x >= spawn_x + half:
				patrol_dir = -1
			velocity.x = patrol_dir * move_speed * 0.55
			facing = patrol_dir
		State.CHASE:
			if player == null:
				_set_state(State.PATROL)
			else:
				var dx: float = player.global_position.x - global_position.x
				facing = 1 if dx >= 0.0 else -1
				if absf(dx) <= attack_range and attack_cd <= 0.0:
					_start_windup()
				else:
					velocity.x = move_toward(velocity.x, facing * move_speed, 900.0 * delta)
		State.WINDUP:
			timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if timer <= 0.0:
				_do_attack()
		State.RECOVER:
			timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if timer <= 0.0:
				_set_state(State.CHASE)
		_:
			pass


## 发现/丢失目标的统一判断。子类可覆盖以改变感知方式（听觉/视线）。
func _acquire_target(_delta: float) -> void:
	var dx: float = player.global_position.x - global_position.x
	var dy: float = absf(player.global_position.y - global_position.y)
	if absf(dx) < detect_range and dy < VERTICAL_DETECT:
		facing = 1 if dx >= 0.0 else -1
		if state == State.PATROL or state == State.IDLE:
			_set_state(State.CHASE)
	elif state == State.CHASE and absf(dx) > detect_range + CHASE_RELEASE_SLACK:
		_set_state(State.PATROL)


func _start_windup() -> void:
	_set_state(State.WINDUP)
	timer = windup_time
	velocity.x = 0.0


## 出手。默认：身前一条横线，命中则交给玩家的 receive_attack 处理。
func _do_attack() -> void:
	_set_state(State.RECOVER)
	timer = recover_time
	attack_cd = 1.1
	if player == null or not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	var max_reach := attack_range + _attack_bonus()
	if absf(dx) <= max_reach and absf(player.global_position.y - global_position.y) < _attack_height():
		if player.has_method("receive_attack"):
			player.receive_attack({"damage": attack_damage, "source": self, "parryable": true})


## 前摇/判定用的臂长余量。
func _attack_bonus() -> float:
	return 30.0


## 判定高度。长柄横扫可以调高，让上段也能扫到。
func _attack_height() -> float:
	return 70.0


## 巡逻半径。
func _patrol_half() -> float:
	return 90.0
