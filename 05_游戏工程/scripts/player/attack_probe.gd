class_name AttackProbe
extends RefCounted
## 只读的敌人选取：谁在攻击范围内、谁离我最近。
##
## 全部 static，不持有节点、不写状态、不认识 Player。
## 用物理查询而不是 get_nodes_in_group("enemies")：只有真正处在可及空间的
## 敌人才会被选中，且已死、已 queue_free 的不会漏进来。
##
## 传给 player.gd 时用 AttackProbe.enemies_in_attack_box(get_world_2d(), global_position, facing, attack_range, 62.0)。

## layer_3 = enemy（见 project.godot 的 [layer_names]）。
## 位掩码 4 = 第 3 层。别把层号当掩码用：layer_3 的掩码是 4 不是 3。
const ENEMY_MASK := 4

## 半径下限。物理查询不接受 0 尺寸的形状。
const MIN_RADIUS := 1.0

## 攻击盒宽度下限。attack_range 被数据改成 0 时也不至于查询退化成一条线。
const MIN_WIDTH := 8.0

## intersect_shape 的最大命中数。32/16 是经验值：同屏敌人远少于这个数，
## 超过说明有东西在刷怪，宁可截断也不要每帧分配大数组。
const RADIUS_LIMIT := 32
const BOX_LIMIT := 16

## 以 origin 为圆心取半径内的敌人。
static func enemies_in_radius(
	world: World2D,
	origin: Vector2,
	radius: float,
	limit: int = RADIUS_LIMIT
) -> Array[Node]:
	if world == null:
		return []
	var shape := CircleShape2D.new()
	shape.radius = maxf(radius, MIN_RADIUS)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, origin)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = ENEMY_MASK
	return collect(world.direct_space_state.intersect_shape(params, limit))

## 身前矩形攻击盒：宽 width，高 2*half_height，中心在身前半臂长处。
static func enemies_in_attack_box(
	world: World2D,
	origin: Vector2,
	facing: int,
	width: float,
	half_height: float,
	limit: int = BOX_LIMIT
) -> Array[Node]:
	if world == null:
		return []
	var w := maxf(width, MIN_WIDTH)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, maxf(half_height, 1.0) * 2.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, origin + Vector2(float(facing) * w * 0.5, 0.0))
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = ENEMY_MASK
	return collect(world.direct_space_state.intersect_shape(params, limit))

## 物理查询结果去重：一个敌人可能有多个 shape，intersect_shape 会重复返回。
## 同时滤掉非 enemies 组的东西（比如敌人的血条 Area2D 若也挂了 layer 4）。
static func collect(hits: Array[Dictionary]) -> Array[Node]:
	var out: Array[Node] = []
	for hit in hits:
		var collider: Variant = hit.get("collider")
		if not (collider is Node):
			continue
		var node := collider as Node
		if not node.is_in_group("enemies"):
			continue
		if not out.has(node):
			out.append(node)
	return out

## 半径内最近的活着的敌人。没有则返回 null。
## "活着"按鸭子类型判 hp > 0 —— 敌人基类约定有这个字段，
## 这里不 import EnemyBase 是为了让探测层不依赖实体层。
static func nearest_alive(world: World2D, origin: Vector2, max_dist: float) -> Node:
	var best: Node = null
	var best_dist := max_dist
	for enemy in enemies_in_radius(world, origin, max_dist):
		var hp: Variant = enemy.get("hp")
		if hp == null or float(hp) <= 0.0:
			continue
		var d := origin.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best
