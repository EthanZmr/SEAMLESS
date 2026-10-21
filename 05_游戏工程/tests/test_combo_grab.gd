extends Node
## 二段「拽」行为测试（D1 = A）：
##   1) 二段命中把敌人拉向玩家 14.2px（160px/s，摩擦 900）
##   2) 贴身命中只拉到 28px（玩家半宽 14 + 敌人半宽 14）
##   3) 一段对照：仍然把敌人推开 8px（120px/s）
## 运行：godot --headless --path . res://tests/test_combo_grab.tscn
## 失败退出码非零，可直接做 CI 门禁。

const PLAYER := preload("res://scenes/player/player.tscn")
const SWEEPER := preload("res://scenes/enemies/sweeper.tscn")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_pull_from_range_edge()
	await _test_pull_stops_at_min_gap()
	await _test_first_hit_still_pushes()

	if failures == 0:
		print("TEST_COMBO_GRAB: PASS (3 cases)")
	else:
		print("TEST_COMBO_GRAB: FAIL (%d failures)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _make_world(dummy_x: float) -> Dictionary:
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

	var dummy: Node2D = SWEEPER.instantiate()
	dummy.position = Vector2(dummy_x, -1.0)
	dummy.passive = true
	add_child(dummy)

	for _i in 6:
		await get_tree().physics_frame
	InputBuffer.clear()
	return {"player": player, "dummy": dummy}


func _run_attack(player: CharacterBody2D, step: int) -> void:
	## 直接进指定段，绕过连段输入，测的是判定与击退本身。
	player._start_ground_attack(step)
	# 判定 0.060/0.070s，击退在摩擦 900 下 0.178s 内停下；等 0.30s 留余量。
	for _i in 18:
		await get_tree().physics_frame


func _test_pull_from_range_edge() -> void:
	var w := await _make_world(88.0)
	var player: CharacterBody2D = w.player
	var dummy: Node2D = w.dummy
	await _run_attack(player, 1)

	var dist: float = absf(dummy.position.x - player.position.x)
	# 88 - 160^2/(2*900) = 73.8，容差 2px
	_assert_near("二段拽：88px → 73.8px", dist, 73.8, 2.0)


func _test_pull_stops_at_min_gap() -> void:
	var w := await _make_world(40.0)
	var player: CharacterBody2D = w.player
	var dummy: Node2D = w.dummy
	await _run_attack(player, 1)

	var dist: float = absf(dummy.position.x - player.position.x)
	# room = 40-28 = 12 → v = sqrt(1800*12) = 147 → 位移 12px → 28px
	_assert_between("二段拽：40px 不得拉进 28px 内", dist, 27.0, 30.0)


func _test_first_hit_still_pushes() -> void:
	# 一段范围 84，放在 80 保证命中；80 + 8 = 88
	var w := await _make_world(80.0)
	var player: CharacterBody2D = w.player
	var dummy: Node2D = w.dummy
	await _run_attack(player, 0)

	var dist: float = absf(dummy.position.x - player.position.x)
	# 一段 120px/s：80 + 8 = 88
	_assert_near("一段对照：80px → 88px", dist, 88.0, 2.0)


func _assert_near(label: String, got: float, want: float, tol: float) -> void:
	if absf(got - want) <= tol:
		print("  PASS  %s  (got %.2f)" % [label, got])
	else:
		failures += 1
		print("  FAIL  %s  want %.2f±%.2f, got %.2f" % [label, want, tol, got])


func _assert_between(label: String, got: float, lo: float, hi: float) -> void:
	if got >= lo and got <= hi:
		print("  PASS  %s  (got %.2f)" % [label, got])
	else:
		failures += 1
		print("  FAIL  %s  want %.2f..%.2f, got %.2f" % [label, lo, hi, got])
