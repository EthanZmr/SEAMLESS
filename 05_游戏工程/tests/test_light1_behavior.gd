extends Node
## 轻击第一段行为测试（V8 定稿）：whiff 禁止取消、命中后 5-8f 跳取消、9f 起连段。
## 运行：godot --headless --path . res://tests/test_light1_behavior.tscn
## 失败退出码非零，可直接做 CI 门禁。

const PLAYER := preload("res://scenes/player/player.tscn")
const SWEEPER := preload("res://scenes/enemies/sweeper.tscn")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_whiff_blocks_jump_cancel()
	await _test_whiff_blocks_combo()
	await _test_hit_opens_jump_cancel()
	await _test_jump_cancel_closes_after_8f()
	await _test_combo_opens_from_9f()

	if failures == 0:
		print("TEST_LIGHT1_BEHAVIOR: PASS (7 assertions)")
	else:
		print("TEST_LIGHT1_BEHAVIOR: FAIL (%d failures)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _make_world(with_dummy: bool) -> Dictionary:
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
	if with_dummy:
		dummy = SWEEPER.instantiate()
		dummy.position = Vector2(60.0, -1.0)
		dummy.passive = true
		add_child(dummy)

	# 落地 + 清掉残余输入
	for _i in 6:
		await get_tree().physics_frame
	InputBuffer.clear()
	return {"player": player, "dummy": dummy}


func _press(action: String) -> void:
	InputBuffer._stamps[action] = Time.get_ticks_msec()


func _start_attack(player: CharacterBody2D) -> bool:
	_press("attack")
	await get_tree().physics_frame
	await get_tree().physics_frame
	return player.state == Player.State.ATTACK


func _test_whiff_blocks_jump_cancel() -> void:
	var w := await _make_world(false)
	var player: CharacterBody2D = w.player
	if not await _start_attack(player):
		_fail("攻击未启动（whiff 跳取消）")
		return
	# _start_attack 返回时是第 3 帧；再等 4 帧到第 7 帧（跳取消窗内）
	for _i in 4:
		await get_tree().physics_frame
	_press("jump")
	for _i in 3:
		await get_tree().physics_frame
	_check(not player.attack_hit_landed, "空挥不应记成命中")
	_check(player.state == Player.State.ATTACK, "空挥 7f 按跳不应取消攻击")


func _test_whiff_blocks_combo() -> void:
	var w := await _make_world(false)
	var player: CharacterBody2D = w.player
	if not await _start_attack(player):
		_fail("攻击未启动（whiff 连段）")
		return
	for _i in 9:
		await get_tree().physics_frame
	_press("attack")
	await get_tree().physics_frame
	_check(not player.combo_queued, "空挥 9f 按攻击不应排队连段")


func _test_hit_opens_jump_cancel() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	if not await _start_attack(player):
		_fail("攻击未启动（命中跳取消）")
		return
	for _i in 4:
		await get_tree().physics_frame
	_check(player.attack_hit_landed, "4f 应已命中假人")
	await get_tree().physics_frame
	_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state == Player.State.JUMP, "命中后 5f 按跳应取消成跳跃")


func _test_jump_cancel_closes_after_8f() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	if not await _start_attack(player):
		_fail("攻击未启动（9f 后跳取消）")
		return
	# 第 3 帧再等 6 帧 = 第 9 帧（连段窗起点、跳取消窗已关）
	for _i in 6:
		await get_tree().physics_frame
	_press("jump")
	for _i in 2:
		await get_tree().physics_frame
	_check(player.state == Player.State.ATTACK, "命中后 9f 按跳不应取消")


func _test_combo_opens_from_9f() -> void:
	var w := await _make_world(true)
	var player: CharacterBody2D = w.player
	if not await _start_attack(player):
		_fail("攻击未启动（9f 连段）")
		return
	for _i in 6:
		await get_tree().physics_frame
	_press("attack")
	await get_tree().physics_frame
	_check(player.combo_queued, "命中后 9f 按攻击应排队连段")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL  ", label)
