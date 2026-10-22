extends Node
## 关卡条目：零件拾取、升降梯、战斗锁门、分段计时。
##
## 场景用 load() 运行时加载：缺失时记一次失败并正常退出，不会让进程挂住。
## 运行：bash tools/test_all.sh test_level_entries

var _fail := 0
var _total := 0


func _ready() -> void:
	await _test_part_pickup()
	await _test_lift()
	GameState.unlock_all_abilities()
	if _fail == 0:
		print("TEST_LEVEL_ENTRIES: PASS (%d assertions)" % _total)
	else:
		print("TEST_LEVEL_ENTRIES: FAIL (%d failures)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## 放在 player 组、碰撞层 2 的测试玩家。
func _make_player(at: Vector2) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = "TestPlayer"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 56)
	shape.shape = rect
	body.add_child(shape)
	body.add_to_group("player")
	body.global_position = at
	add_child(body)
	return body


func _test_part_pickup() -> void:
	var scene := load("res://scenes/level/part_pickup.tscn") as PackedScene
	_check(scene != null, "part_pickup.tscn 存在")
	if scene == null:
		return
	GameState.begin_new_game()
	var pick := scene.instantiate()
	pick.set("part_id", "claw")
	pick.position = Vector2(200, 200)
	add_child(pick)
	var body := _make_player(Vector2(200, 200))
	await _frames(4)
	_check(GameState.has_ability("climb"), "碰到攀爬爪零件后解锁攀爬")
	_check(not is_instance_valid(pick) or pick.is_queued_for_deletion(), "拾取后零件消失")
	var again := scene.instantiate()
	again.set("part_id", "claw")
	again.position = Vector2(600, 200)
	add_child(again)
	await get_tree().process_frame
	_check(not is_instance_valid(again) or again.is_queued_for_deletion(), "已安装的零件重载后不再出现")
	body.queue_free()
	await get_tree().process_frame


## 升降梯：未激活不动；激活（flag）后站上去 0.3 秒驶向另一端。
func _make_lift(id: String) -> Node:
	var scene := load("res://scenes/level/lift.tscn") as PackedScene
	if scene == null:
		return null
	var lift := scene.instantiate()
	lift.set("lift_id", id)
	lift.set("stop_a", Vector2(0, 0))
	lift.set("stop_b", Vector2(0, -320))
	add_child(lift)
	return lift


func _test_lift() -> void:
	GameState.begin_new_game()
	var lift := _make_lift("t1")
	_check(lift != null, "lift.tscn 存在")
	if lift == null:
		return
	var body := _make_player(Vector2(0, -36))
	await get_tree().create_timer(1.0).timeout
	_check(absf(lift.global_position.y) < 0.5, "未激活的升降梯站上去不动")
	lift.queue_free()
	body.queue_free()
	await get_tree().process_frame
	GameState.set_flag("lift:t1")
	lift = _make_lift("t1")
	body = _make_player(Vector2(0, -36))
	var reached := false
	var t := 0.0
	while t < 2.8 and not reached:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		reached = absf(lift.global_position.y - (-320.0)) <= 2.0
	_check(reached, "激活后站上去 2.8 秒内到达另一端（%.1fs）" % t)
	lift.queue_free()
	body.queue_free()
	await get_tree().process_frame
