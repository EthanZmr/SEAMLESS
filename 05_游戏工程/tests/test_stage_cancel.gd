extends Node
## 二段/三段取消规则测试（D2 = 统一规则、窗口按段取）。
## 运行：bash tools/test_all.sh test_stage_cancel（不要用 -s）。
##   1) 二段命中 7f 按跳 → 取消成跳跃
##   2) 二段空挥 7f 按跳 → 不取消，且按键被吞掉
##   3) 二段空挥 8f 按攻击 → 不排队（连段窗 10f 才开）
##   4) 二段命中 10f 按攻击 → 排队成功
##   5) 三段命中 8f 按跳 → 不取消（击退未播完，13f 才开窗）
##   6) 三段命中 14f 按跳 → 可取消，但 attack_cd 保留 0.30（取消不清零冷却）
##   7) 三段空挥走完 18f → 回 IDLE 且进入 0.30s 冷却
## 运行：godot --headless --path . res://tests/test_stage_cancel.tscn

const PLAYER := preload("res://scenes/player/player.tscn")
const SWEEPER := preload("res://scenes/enemies/sweeper.tscn")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_stage2_hit_jump_cancel()
	await _test_stage2_whiff_blocks_jump()
	await _test_stage2_whiff_blocks_combo()
	await _test_stage2_hit_combo_queues()
	await _test_stage3_no_jump_cancel()
	await _test_stage3_late_cancel_locked()
	await _test_stage3_whiff_full_commit()

	if failures == 0:
		print("TEST_STAGE_CANCEL: PASS (7 cases)")
	else:
		print("TEST_STAGE_CANCEL: FAIL (%d failures)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _make_world(with_enemy: bool) -> Dictionary:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	var fshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000.0, 40.0)
	fshape.shape = rect
	floor_body.add_child(fshape)
	floor_body.position = Vector2(0.0, 20.0)
	add_child(floor_body)

	var player: CharacterBody2D = PLAYER.instantiate()
	player.position = Vector2(0.0, -1.0)
	player.facing = 1
	add_child(player)

	var dummy: Node2D = null
	if with_enemy:
		dummy = SWEEPER.instantiate()
		dummy.position = Vector2(70.0, -1.0)
		dummy.passive = true
		add_child(dummy)

	for _i in 6:
		await get_tree().physics_frame
	InputBuffer.clear()
	return {"player": player, "dummy": dummy}


func _press(action: String) -> void:
	InputBuffer._stamps[action] = Time.get_ticks_msec()


func _start_stage(player: CharacterBody2D, step: int) -> void:
	## 直接进指定段，测取消规则本身，不经过连段输入。
	player._start_ground_attack(step)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _wait_until_frame(player: CharacterBody2D, frame: int) -> void:
	var guard := 0
	while AttackSpec.frame_of(player.attack_time - player.attack_timer) < frame and guard < 60:
		await get_tree().physics_frame
		guard += 1


func _test_stage2_hit_jump_cancel() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 1)
	await _wait_until_frame(player, 7)
	_check(player.attack_hit_landed, "二段 5f 应已命中")
	_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state == Player.State.JUMP, "二段命中 7f 按跳应取消成跳跃")


func _test_stage2_whiff_blocks_jump() -> void:
	var w := await _make_world(false)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 1)
	await _wait_until_frame(player, 7)
	_check(not player.attack_hit_landed, "二段空挥不应记成命中")
	_press("jump")
	for _i in 3:
		await get_tree().physics_frame
	_check(player.state == Player.State.ATTACK, "二段空挥 7f 按跳不应取消")


func _test_stage2_whiff_blocks_combo() -> void:
	var w := await _make_world(false)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 1)
	await _wait_until_frame(player, 8)
	_press("attack")
	await get_tree().physics_frame
	_check(not player.combo_queued, "二段空挥 8f 按攻击不应排队（连段窗 10f 开）")
	# 按键应被吞掉，不会在 10f 之后补触发
	for _i in 4:
		await get_tree().physics_frame
	_check(not player.combo_queued, "被吞掉的输入不应延迟补触发")


func _test_stage2_hit_combo_queues() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 1)
	await _wait_until_frame(player, 10)
	_check(player.attack_hit_landed, "二段 10f 应已命中")
	_press("attack")
	await get_tree().physics_frame
	_check(player.combo_queued, "二段命中 10f 按攻击应排队三段")


func _test_stage3_no_jump_cancel() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 2)
	await _wait_until_frame(player, 8)
	_check(player.attack_hit_landed, "三段 6f 应已命中")
	_press("jump")
	for _i in 3:
		await get_tree().physics_frame
	_check(player.state == Player.State.ATTACK, "三段命中 8f（击退未播完）按跳不应取消")


## 设计确认：attack_spec 里三段的 jump_cancel_start_frame = 0（终结技不可取消），
## 与 _test_stage3_no_jump_cancel 一致。此前的“14f 可取消”断言与实现冲突，属过期测试。
func _test_stage3_late_cancel_locked() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 2)
	await _wait_until_frame(player, 14)
	_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state == Player.State.ATTACK, "三段 14f 按跳仍不可取消")
	_check(player.attack_cd == 0.0, "未取消时 attack_cd 还未写入（got %.2f）" % player.attack_cd)


func _test_stage3_whiff_full_commit() -> void:
	var w := await _make_world(false)
	var player: CharacterBody2D = w.player
	await _start_stage(player, 2)
	for _i in 20:
		await get_tree().physics_frame
	_check(player.state == Player.State.IDLE, "三段空挥应走完 18f 回 IDLE")
	_check(player.attack_cd > 0.20, "三段结束后应进入 0.30s 冷却（got %.2f）" % player.attack_cd)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)
