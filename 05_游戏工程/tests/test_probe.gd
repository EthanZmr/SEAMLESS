extends Node2D
## MovementProbe / AttackProbe 的契约测试。
##
## 这两个类存在的意义是"空间查询能脱离 Player 单独验证"，
## 所以这里既测纯函数（collect 的去重/过滤），也测真实物理世界里的查询
## （自己造 StaticBody2D / 敌人，不依赖 main.tscn）。
##
## 运行：godot --headless --path . res://tests/test_probe.tscn

## 有 hp 字段的最小敌人。AttackProbe.nearest_alive 按鸭子类型读 hp，
## 用内部类就能在测试里造出"活/死"两种状态而不必实例化完整的 Sweeper。
class FakeEnemy extends CharacterBody2D:
	var hp := 40.0

var _fail := 0
var _total := 0

## 世界里造出来的临时节点，测完统一清掉。
var _fixtures: Array[Node] = []


func _ready() -> void:
	print("TEST_PROBE: start")

	_test_constants()
	await _test_collect_filters()
	await _test_is_solid()
	await _test_wall_dir()
	await _test_ledge()
	await _test_attack_box()
	await _test_nearest_alive()

	for node in _fixtures:
		if is_instance_valid(node):
			node.queue_free()
	_fixtures.clear()

	print("TEST_PROBE: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  " + label)
	else:
		_fail += 1
		print("  FAIL  " + label)


func _world() -> World2D:
	return get_viewport().world_2d


## 造一块实心矩形（layer 1 = world）。
func _make_block(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_fixtures.append(body)
	return body


## 造一个敌人（layer 4 = enemy，进 enemies 组）。
func _make_enemy(center: Vector2, hp_value: float = 40.0, size := Vector2(28, 56)) -> FakeEnemy:
	var body := FakeEnemy.new()
	body.position = center
	body.collision_layer = 4
	body.collision_mask = 0
	body.hp = hp_value
	body.add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_fixtures.append(body)
	return body


## 让新造的固件进入物理服务器。
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


# --- 常量语义 -----------------------------------------------------------------

func _test_constants() -> void:
	_check(MovementProbe.WORLD_MASK == 1, "WORLD_MASK 是 layer_1 的位掩码 1")
	_check(AttackProbe.ENEMY_MASK == 4, "ENEMY_MASK 是 layer_3 的位掩码 4")
	_check(AttackProbe.MIN_RADIUS >= 1.0, "半径下限不为 0（物理查询不接受零尺寸）")
	_check(AttackProbe.MIN_WIDTH >= 1.0, "攻击盒宽度下限不为 0")
	_check(MovementProbe.DEFAULT_SIDE_DIST > 0.0, "墙体探针偏移为正")
	_check(MovementProbe.DEFAULT_BELOW_OFFSET > 0.0, "墙体下方复探偏移为正")


# --- collect：纯逻辑 ----------------------------------------------------------

func _test_collect_filters() -> void:
	await _settle()

	_check(AttackProbe.collect([]).is_empty(), "空命中返回空数组")

	var good := _make_enemy(Vector2(0, 0))
	var plain := Node2D.new()
	add_child(plain)
	_fixtures.append(plain)
	await _settle()

	_check(AttackProbe.collect([{"collider": good}]).size() == 1, "单条命中保留")
	_check(AttackProbe.collect([{"collider": good}, {"collider": good}]).size() == 1,
		"同一敌人两条命中被去重")
	_check(AttackProbe.collect([{"collider": plain}]).is_empty(),
		"不在 enemies 组的节点被滤掉")
	_check(AttackProbe.collect([{"collider": 42}]).is_empty(),
		"collider 不是 Node 时被滤掉")
	_check(AttackProbe.collect([{}]).is_empty(), "缺 collider 键被滤掉")

	var second := _make_enemy(Vector2(4000, 4000))
	await _settle()
	_check(AttackProbe.collect([{"collider": good}, {"collider": second}]).size() == 2,
		"两个不同敌人都保留")


# --- is_solid_at：真实物理 ----------------------------------------------------

func _test_is_solid() -> void:
	await _settle()
	_make_block(Vector2(1000, 1000), Vector2(100, 100))
	await _settle()

	_check(MovementProbe.is_solid_at(_world(), Vector2(1000, 1000)), "方块中心判为实心")
	_check(not MovementProbe.is_solid_at(_world(), Vector2(1000, 1200)), "方块外侧判为空")
	_check(not MovementProbe.is_solid_at(null, Vector2(1000, 1000)), "world 为 null 时返回 false")


# --- wall_dir -----------------------------------------------------------------

func _test_wall_dir() -> void:
	await _settle()
	# 竖墙：x ∈ [1978, 2018]，y ∈ [-200, 400]。
	# origin (1960, 0) 的侧面探针在 ±18 → 1978 / 1942，正好右探头落在墙里。
	_make_block(Vector2(1998, 100), Vector2(40, 600))
	await _settle()

	_check(MovementProbe.wall_dir(_world(), Vector2(1960, 0), 1) == 1, "面对墙时返回 +1")
	# 背对同一面墙：先试 -1（左边无墙），再试 +1 → 仍应找到右边。
	_check(MovementProbe.wall_dir(_world(), Vector2(1960, 0), -1) == 1,
		"背对墙时仍能识别墙在右侧")
	_check(MovementProbe.wall_dir(_world(), Vector2(9000, 9000), 1) == 0, "附近没墙时返回 0")

	# 薄平台的侧面不该被当成墙：高只有 30，下方 24px 处已经出界。
	_make_block(Vector2(2600, 100), Vector2(40, 30))
	await _settle()
	_check(MovementProbe.wall_dir(_world(), Vector2(2562, 100), 1) == 0,
		"薄平台侧面不算墙（下方复探为空）")


# --- 边沿抓取 -----------------------------------------------------------------

func _test_ledge() -> void:
	await _settle()
	# 平台：x ∈ [3000, 3080]，y ∈ [0, 200]，顶面正好在 y=0。
	_make_block(Vector2(3040, 100), Vector2(80, 200))
	await _settle()

	var origin := Vector2(2980, 0)
	_check(MovementProbe.can_grab_ledge(_world(), origin, 1, 20.0, 26.0),
		"边沿：前方实心、上方空 → 可抓")

	# 头顶再高一截：前方（20, -100）落在空处。
	_check(not MovementProbe.can_grab_ledge(_world(), Vector2(2980, -100), 1, 20.0, 26.0),
		"悬空处前方无墙 → 不可抓")

	_check(not MovementProbe.can_grab_ledge(_world(), Vector2(8000, 8000), 1, 20.0, 26.0),
		"前方空旷 → 不可抓")

	# 薄台沿：厚 24，x ∈ [3500, 3580]，y ∈ [0, 24]。下方 26px 处已经出界，也要能抓。
	_make_block(Vector2(3540, 12), Vector2(80, 24))
	await _settle()
	_check(MovementProbe.can_grab_ledge(_world(), Vector2(3482, 10), 1, 20.0, 26.0),
		"薄台沿（厚 24）→ 可抓")


# --- 攻击盒 -------------------------------------------------------------------

func _test_attack_box() -> void:
	await _settle()
	# origin (0, 0)，朝向 +1，宽 84 → 盒子覆盖 x ∈ [0, 84]，y ∈ [-62, 62]。
	var near := _make_enemy(Vector2(40, 0))
	var far := _make_enemy(Vector2(400, 0))
	var behind := _make_enemy(Vector2(-40, 0))
	await _settle()

	var hits := AttackProbe.enemies_in_attack_box(_world(), Vector2.ZERO, 1, 84.0, 62.0)
	_check(hits.has(near), "身前敌人进入攻击盒")
	_check(not hits.has(far), "远处的敌人不在攻击盒内")
	_check(not hits.has(behind), "身后的敌人不在攻击盒内")

	# 朝向翻过来，behind 应该进来、near 出去。
	var flipped := AttackProbe.enemies_in_attack_box(_world(), Vector2.ZERO, -1, 84.0, 62.0)
	_check(flipped.has(behind), "翻转朝向后身后敌人进入攻击盒")
	_check(not flipped.has(near), "翻转朝向后原前方敌人离开攻击盒")

	var radius_hits := AttackProbe.enemies_in_radius(_world(), Vector2.ZERO, 60.0)
	_check(radius_hits.has(near), "半径查询能拿到近处敌人")
	_check(not radius_hits.has(far), "半径查询不含远处敌人")

	# 宽度/高度为 0 时钳到下限，不该崩。
	_check(AttackProbe.enemies_in_attack_box(_world(), Vector2.ZERO, 1, 0.0, 0.0) is Array,
		"宽度/高度为 0 时仍返回数组而不是崩")


# --- 最近活敌 -----------------------------------------------------------------

func _test_nearest_alive() -> void:
	await _settle()
	# 清掉之前造的敌人，避免互相干扰。
	for node in _fixtures:
		if is_instance_valid(node) and node.is_in_group("enemies"):
			node.remove_from_group("enemies")
	await _settle()

	var close := _make_enemy(Vector2(30, 0))
	_make_enemy(Vector2(80, 0))
	_make_enemy(Vector2(10, 0), 0.0)   # 更近但已死
	await _settle()

	var pick := AttackProbe.nearest_alive(_world(), Vector2.ZERO, 200.0)
	_check(pick == close, "最近的活敌被选中（死掉的更近也跳过）")

	close.hp = 0.0
	await _settle()
	_check(AttackProbe.nearest_alive(_world(), Vector2.ZERO, 200.0) != close,
		"hp 归零后不再被选中")

	_check(AttackProbe.nearest_alive(_world(), Vector2(9000, 9000), 50.0) == null,
		"半径内没有敌人时返回 null")
	_check(AttackProbe.nearest_alive(null, Vector2.ZERO, 50.0) == null,
		"world 为 null 时返回 null")
