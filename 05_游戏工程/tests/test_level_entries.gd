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
	await _test_arena_closes_and_opens()
	await _test_arena_empty_never_closes()
	await _test_arena_opens_on_death()
	_test_split_log()
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


# --- 战斗锁门 ---------------------------------------------------------------

func _make_arena(id: String) -> Node2D:
	var script := load("res://scripts/level/arena_gate.gd") as GDScript
	if script == null:
		return null
	var arena: Node2D = script.new()
	arena.name = "Arena_" + id
	arena.set("arena_id", id)
	arena.set("rect", Rect2(0, 0, 600, 300))
	add_child(arena)
	return arena


func _make_sweeper(at: Vector2) -> Node:
	var e := (load("res://scenes/enemies/sweeper.tscn") as PackedScene).instantiate()
	e.position = at
	add_child(e)
	e.set_physics_process(false)
	return e


func _closed(arena: Node2D) -> bool:
	var l := arena.get_node_or_null("DoorL/Collision") as CollisionShape2D
	var r := arena.get_node_or_null("DoorR/Collision") as CollisionShape2D
	return l != null and r != null and not l.disabled and not r.disabled


func _test_arena_closes_and_opens() -> void:
	GameState.begin_new_game()
	var arena := _make_arena("a1")
	_check(arena != null, "arena_gate.gd 存在")
	if arena == null:
		return
	var enemy := _make_sweeper(Vector2(450, 250))
	await _frames(2)
	_check(not _closed(arena), "玩家进来之前门是开的")
	var body := _make_player(Vector2(300, 150))
	await _frames(4)
	_check(_closed(arena), "玩家进入且有活敌人：关门")
	enemy.die()
	await _frames(4)
	_check(not _closed(arena), "敌人全灭：开门")
	_check(GameState.has_flag("arena:a1"), "清场后记下 arena:a1")
	arena.queue_free()
	body.queue_free()
	await get_tree().process_frame


func _test_arena_empty_never_closes() -> void:
	GameState.begin_new_game()
	var arena := _make_arena("a2")
	if arena == null:
		return
	var body := _make_player(Vector2(300, 150))
	await _frames(4)
	_check(not _closed(arena), "锁门里没有敌人：不关门")
	arena.queue_free()
	body.queue_free()
	await get_tree().process_frame


func _test_arena_opens_on_death() -> void:
	GameState.begin_new_game()
	var arena := _make_arena("a3")
	if arena == null:
		return
	var enemy := _make_sweeper(Vector2(450, 250))
	var body := _make_player(Vector2(300, 150))
	await _frames(4)
	_check(_closed(arena), "（前提）关门")
	body.queue_free()
	GameEvents.player_died.emit()
	await _frames(2)
	_check(not _closed(arena), "玩家断线：开门，复活后可重来")
	arena.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


# --- 分段计时 ---------------------------------------------------------------

func _test_split_log() -> void:
	var script := load("res://scripts/rules/split_log.gd") as GDScript
	_check(script != null, "split_log.gd 存在")
	if script == null:
		return
	var old_dir := DebugLog.log_dir
	DebugLog.log_dir = "user://test_split_logs"
	DebugLog.open_session()
	var split: Node = script.new()
	split.name = "SplitLog"
	add_child(split)
	GameEvents.ability_unlocked.emit("climb")
	var text := FileAccess.get_file_as_string(DebugLog.session_path)
	_check(text.contains("SPLIT") and text.contains("ability_unlocked") and text.contains("climb"),
		"会话日志记下 SPLIT ability_unlocked climb")
	split.queue_free()
	DebugLog.close_session()
	DebugLog.log_dir = old_dir
