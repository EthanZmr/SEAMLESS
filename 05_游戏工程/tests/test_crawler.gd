extends Node
## 沟爬子：天花板巡逻、玩家在下方时脱落、落地接触伤害、死亡掉落零件（掉落在 EnemyBase）。
## 运行：bash tools/test_all.sh test_crawler

const PLAYER := preload("res://scenes/player/player.tscn")
const FLOOR_Y := 600.0

var _fail := 0
var _total := 0


func _ready() -> void:
	await _test_patrol()
	await _test_drop_and_contact()
	await _test_drops_part()
	GameState.unlock_all_abilities()
	GameState.reset()
	if _fail == 0:
		print("TEST_CRAWLER: PASS (%d assertions)" % _total)
	else:
		print("TEST_CRAWLER: FAIL (%d failures)" % _fail)
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


func _world() -> Node2D:
	var w := Node2D.new()
	w.name = "World"
	add_child(w)
	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(3000, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(500, FLOOR_Y + 20)
	w.add_child(floor_body)
	return w


func _crawler(w: Node2D, a: Vector2, b: Vector2) -> Node:
	var scene := load("res://scenes/enemies/crawler.tscn") as PackedScene
	if scene == null:
		return null
	var c := scene.instantiate()
	c.set("surface", "ceiling")
	c.set("point_a", a)
	c.set("point_b", b)
	c.position = a
	w.add_child(c)
	return c


func _test_patrol() -> void:
	var w := _world()
	var c := _crawler(w, Vector2(100, 400), Vector2(300, 400))
	_check(c != null, "crawler.tscn 存在")
	if c == null:
		w.queue_free()
		return
	var ok := true
	for i in range(120):
		await get_tree().physics_frame
		var p: Vector2 = c.global_position
		if p.x < 98.0 or p.x > 302.0 or absf(p.y - 400.0) > 0.5:
			ok = false
	_check(ok, "无人时在 a/b 之间往返，高度不变")
	w.queue_free()
	await get_tree().process_frame


func _test_drop_and_contact() -> void:
	GameState.reset()
	var w := _world()
	var player := PLAYER.instantiate()
	player.position = Vector2(200, FLOOR_Y - 28)
	w.add_child(player)
	var c := _crawler(w, Vector2(160, 400), Vector2(240, 400))
	if c == null:
		w.queue_free()
		return
	var y0: float = c.global_position.y
	var landed := false
	for i in range(90):
		await get_tree().physics_frame
		if c.is_on_floor():
			landed = true
			break
	_check(c.global_position.y > y0 + 50.0 and landed, "玩家在正下方：脱落并落地")
	var hp0 := GameState.integrity
	await _frames(60)
	_check(GameState.integrity <= hp0 - 8.0, "落地后接触玩家造成伤害（%.0f → %.0f）" % [hp0, GameState.integrity])
	w.queue_free()
	await get_tree().process_frame


func _part_ids(w: Node) -> Array:
	var ids := []
	for n in w.get_children():
		if n is PartPickup:
			ids.append(n.part_id)
	return ids


func _test_drops_part() -> void:
	GameState.begin_new_game()
	var w := _world()
	var c := _crawler(w, Vector2(100, 400), Vector2(300, 400))
	if c == null:
		w.queue_free()
		return
	c.set("drops_part", "claw")
	c.die()
	await _frames(2)
	_check("claw" in _part_ids(w), "沟爬子死亡掉落攀爬爪")
	var lancer := (load("res://scenes/enemies/lancer.tscn") as PackedScene).instantiate()
	lancer.position = Vector2(600, FLOOR_Y - 28)
	w.add_child(lancer)
	lancer.set("drops_part", "buffer")
	lancer.die()
	await _frames(2)
	_check("buffer" in _part_ids(w), "截线者死亡掉落缓冲片")
	w.queue_free()
	await get_tree().process_frame
