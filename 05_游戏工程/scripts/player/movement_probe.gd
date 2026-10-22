class_name MovementProbe
extends RefCounted
## 只读的空间探测：脚下有没有地、侧面有没有墙、边缘能不能抓。
##
## 全部 static，不持有节点、不写状态、不认识 Player。
## 传 World2D 而不是节点，是为了让探测逻辑能脱离 Player 单独测试，
## 也让 player.gd 不必为三行查询各留一个私有方法。
##
## 注意：这些函数只在物理帧间隔内有效（读到的是上一物理步的 Space）。
## 不要在 _ready() 里调，那时物理还没跑过第一帧。

## layer_1 = world（见 project.godot 的 [layer_names]）。
## 注意这是位掩码不是层号：layer_1 的掩码是 1，layer_3(enemy) 的掩码是 4。
const WORLD_MASK := 1

## 墙体探测的默认偏移。玩家体半宽约 14，取 18 保证探针在体外侧。
const DEFAULT_SIDE_DIST := 18.0

## 探针点下方再探 24px，用来排除"薄平台侧面"被当成墙。
const DEFAULT_BELOW_OFFSET := 24.0

## 该点是否落在实心几何里。
static func is_solid_at(world: World2D, point: Vector2, mask: int = WORLD_MASK) -> bool:
	if world == null:
		return false
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not world.direct_space_state.intersect_point(params, 1).is_empty()

## 身体侧面贴着的墙在哪一侧。返回 -1 / 1 / 0（没有墙）。
## 探测顺序 facing → -facing → 1 → -1：优先认定正在面对的方向，
## 这样贴墙时不会因为两侧都可爬而左右抖。
static func wall_dir(
	world: World2D,
	origin: Vector2,
	facing: int,
	side_dist: float = DEFAULT_SIDE_DIST,
	below_offset: float = DEFAULT_BELOW_OFFSET
) -> int:
	for dir in [facing, -facing, 1, -1]:
		var side := origin + Vector2(float(dir) * side_dist, 0.0)
		# 侧面实心 + 下方也实心，才算是"墙"而不是"薄平台的边"。
		if is_solid_at(world, side) and is_solid_at(world, side + Vector2(0.0, below_offset)):
			return int(dir)
	return 0

## 身前有没有可抓的边沿：前面实心、上方空、下方实心。
## 三个探针的口径由调用方决定（player.gd 用 LEDGE_PROBE_* 三个可调参数）。
static func can_grab_ledge(
	world: World2D,
	origin: Vector2,
	facing: int,
	forward: float,
	above: float,
	below: float
) -> bool:
	var wall_point := origin + Vector2(float(facing) * forward, 0.0)
	if not is_solid_at(world, wall_point):
		return false
	var up := wall_point + Vector2(0.0, -above)
	var down := wall_point + Vector2(0.0, below)
	return not is_solid_at(world, up) and is_solid_at(world, down)
