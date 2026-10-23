extends Node
## 关卡度量实测（D18 角色定稿第 2 层）：用真实 player.gd + player_stats.tres，
## 在程序化场地里量跳高、缺口、台阶、墙跳井、钩点、冲刺，结果填进 01_GDD/11。
## 改 player_stats.tres 或移动代码后重跑。
## Run: godot --headless --path . --fixed-fps 60 res://tools/measure_metrics.tscn
## 必须跑 .tscn（要 autoload）；--fixed-fps 60 让每帧固定 1/60 s、不等实时。

const PLAYER := preload("res://scenes/player/player.tscn")
const HALF_H := 28.0  # 碰撞 28×56：中心 → 脚底
const HALF_W := 14.0

## 能力阶段，按 01_GDD/10 §4 的获取顺序累加。缺口测试去掉 climb，量的是纯跳。
const S0: Array = []
const S1 := ["climb"]
const S3 := ["climb", "parry", "hook"]
const S4 := ["climb", "parry", "hook", "wall_jump"]
const S5 := ["climb", "parry", "hook", "wall_jump", "double_jump", "dash"]
const S5_NO_LEDGE := ["parry", "hook", "wall_jump", "double_jump", "dash"]

var _arena: Node2D
var _flush_actions: Array[String] = []


func _ready() -> void:
	DebugLog.enabled = false
	await get_tree().process_frame

	_out("== 开局：跑、跳 ==")
	_out("单跳最高（长按，脚底上升）", await _rise(S0, [_at("jump")]))
	_out("小跳最低（点按 1 帧）", await _rise(S0, [_at("jump", {}, true)]))
	_out("单跳上台阶（贴墙起跳）", await _step_max(S0, [_at("jump")]))
	_out("单跳越缺口（助跑，离地即跳）", await _gap_max(S0, [_at("jump", {"air": true})]))

	_out("== ① 攀爬爪：+攀爬、抓边 ==")
	var vault := _at("jump", {"state": Player.State.LEDGE})
	_out("单跳+抓边上台阶", await _step_max(S1, [_at("jump"), vault]))
	_out("单跳+抓边上薄台沿（厚 16 / 24）", "%.1f / %.1f" % [
		await _step_max(S1, [_at("jump"), vault], 16.0),
		await _step_max(S1, [_at("jump"), vault], 24.0)])
	_out("单跳上薄台沿（厚 24，不抓边）", await _step_max(S0, [_at("jump")], 24.0))
	_out("单跳+抓边越缺口", await _gap_max(S1, [_at("jump", {"air": true}), vault]))

	_out("== ③ 纤维发射器：+钩索 ==")
	_out("钩到点后再跳，脚底高出钩点", await _hook_rise(S3))

	_out("== ④ 腿部弹簧：+墙跳、墙滑 ==")
	var shaft := ""
	for w in range(32, 329, 16):
		shaft += "%d:%+.0f " % [w, await _shaft(S4, float(w), false)]
	_out("墙跳井 内宽:每跳净升", shaft)
	var single := await _shaft(S4, 0.0, true)
	_out("单面墙连跳每跳净升", "不能（推开后回不到墙）" if single < -900.0 else "%+.0f" % single)

	_out("== ⑤ 气阀：+二段跳、冲刺 ==")
	var apex_double := [_at("jump"), _at("double", {"vy_ge": 0.0})]
	_out("二段最高（顶点接二段）", await _rise(S5, apex_double))
	# 台阶测试是贴墙起跳：有墙跳能力时，顶点按跳会被判成墙跳（代码里墙跳优先于二段），
	# 所以这里去掉 wall_jump，量的是纯二段高度。
	_out("二段上台阶（顶点接二段）", await _step_max(["double_jump", "dash"], apex_double))
	_out("二段+抓边上台阶", await _step_max(["climb", "double_jump", "dash"], apex_double + [vault]))
	_out("钩到点后再跳+二段，脚底高出钩点", await _hook_rise(S5))
	var dash := await _dash()
	_out("地面冲刺位移（含收步）", dash["ground"])
	_out("空中冲刺位移 / 冲刺中下坠", "%.1f / %.1f" % [dash["air_dx"], dash["air_dy"]])

	var gaps := {}
	gaps["二段·顶点"] = [_at("jump", {"air": true}), _at("double", {"vy_ge": 0.0})]
	for x in [10.0, 30.0, 60.0]:
		gaps["二段·落到 %d 再按" % x] = [_at("jump", {"air": true}), _at("double", {"rise_le": x})]
	_out("二段越缺口（取最优时机）", await _best_gap(S5_NO_LEDGE, gaps))
	var combos := {}
	for x in [10.0, 30.0, 60.0]:
		combos["跳·顶点冲刺·落到 %d 二段" % x] = [
			_at("jump", {"air": true}), _at("dash", {"vy_ge": 0.0}),
			_at("double", {"rise_le": x, "not_dash": true})]
	for x in [10.0, 30.0]:
		combos["跳·落到 %d 二段·落到 30 冲刺" % x] = [
			_at("jump", {"air": true}), _at("double", {"rise_le": x}),
			_at("dash", {"rise_le": 30.0})]
	combos["冲刺离台·二段"] = [_at("dash", {"x_ge": -30.0, "floor": true}), _at("double", {"not_dash": true})]
	_out("二段+冲刺越缺口（取最优组合）", await _best_gap(S5_NO_LEDGE, combos))

	get_tree().quit(0)


func _out(label: String, value: Variant = null) -> void:
	if value == null:
		print(label)
	elif value is float:
		print("  %-30s %.1f" % [label, value])
	else:
		print("  %-30s %s" % [label, str(value)])


func _at(act: String, when: Dictionary = {}, tap: bool = false) -> Dictionary:
	return {"act": act, "when": when, "tap": tap}


# --- 场地 --------------------------------------------------------------------

func _spawn(rects: Array, pos: Vector2, abilities: Array, anchors: Array = []) -> Player:
	GameState.abilities = {}
	for id in abilities:
		GameState.abilities[id] = true
	_arena = Node2D.new()
	_arena.name = "Arena"
	add_child(_arena)
	for r: Rect2 in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = r.size
		shape.shape = rect_shape
		body.position = r.get_center()
		body.add_child(shape)
		_arena.add_child(body)
	for a: Vector2 in anchors:
		var anchor := Node2D.new()
		anchor.position = a
		anchor.add_to_group("hook_anchors")
		_arena.add_child(anchor)
	var p: Player = PLAYER.instantiate()
	p.name = "Player"
	p.position = pos
	_arena.add_child(p)
	for i in range(3):
		await get_tree().physics_frame
	return p


func _despawn() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "hook"]:
		Input.action_release(a)
	InputBuffer.clear()
	_arena.queue_free()
	await get_tree().process_frame


# --- 输入与执行 ----------------------------------------------------------------

## 只写输入缓冲来触发一次按键，不动 Input 的按住状态：Input.action_press 在下一个
## 物理帧仍算 just_pressed，会把一次起跳变成"起跳 + 立刻二段"。跳键从不按住/松开，
## 也就不会触发跳跃截断（截断只看 just_released），等于长按跳。
## 例外：钩索要按住 H 才持续拉近；点按跳要靠松开触发截断。
func _press(act: String, tap: bool = false) -> void:
	var action := "jump" if act == "double" else act
	InputBuffer._stamps[action] = Time.get_ticks_msec()
	_flush_actions.append(action)
	if action == "hook" or tap:
		Input.action_press(action)


## 逐帧执行 plan：每步在 when 条件满足时按一次键。judge 返回 1 成功 / -1 失败 / 0 继续。
func _run(p: Player, plan: Array, frames: int, judge: Callable) -> bool:
	var ctx := {"start_y": p.global_position.y, "air": false}
	var i := 0
	var tap_release := false
	for f in range(frames):
		await get_tree().physics_frame
		# 实时时钟下缓冲窗口会跨很多帧：上一步按的键处理完就清掉，免得之后误触发。
		for a in _flush_actions:
			InputBuffer.clear_action(a)
		_flush_actions.clear()
		if tap_release:
			Input.action_release("jump")
			tap_release = false
		if i < plan.size() and _cond(p, plan[i]["when"], ctx):
			_press(plan[i]["act"], plan[i]["tap"])
			tap_release = plan[i]["tap"]
			i += 1
		if not p.is_on_floor():
			ctx["air"] = true
		var r: int = judge.call(p, ctx)
		if r != 0:
			return r > 0
	return false


func _cond(p: Player, when: Dictionary, ctx: Dictionary) -> bool:
	if when.get("air", false) and p.is_on_floor():
		return false
	if when.get("floor", false) and not p.is_on_floor():
		return false
	if when.has("vy_ge") and p.velocity.y < when["vy_ge"]:
		return false
	if when.has("rise_le"):
		if p.velocity.y <= 0.0 or ctx["start_y"] - p.global_position.y > when["rise_le"]:
			return false
	if when.has("x_ge") and p.global_position.x < when["x_ge"]:
		return false
	if when.get("not_dash", false) and p.state == Player.State.DASH:
		return false
	if when.has("state") and p.state != when["state"]:
		return false
	if when.has("near"):
		if p.state != Player.State.HOOK or not is_instance_valid(p.hook_target):
			return false
		if p.global_position.distance_to(p.hook_target.global_position) > when["near"]:
			return false
	return true


# --- 量测 --------------------------------------------------------------------

## 平地起跳，脚底最大上升。
func _rise(abilities: Array, plan: Array) -> float:
	var p := await _spawn([Rect2(-600, 0, 1200, 400)], Vector2(0, -HALF_H), abilities)
	var ctx_min := {"y": p.global_position.y}
	var start := p.global_position.y
	await _run(p, plan, 300, func(q: Player, c: Dictionary) -> int:
		ctx_min["y"] = minf(ctx_min["y"], q.global_position.y)
		return 1 if c["air"] and q.is_on_floor() else 0)
	await _despawn()
	return start - ctx_min["y"]


## 贴着高 h 的台阶起跳、按住朝台阶方向，最后站上台阶即成功。
## thick > 0 时台阶换成悬空薄台（厚 thick），量台沿。
func _try_step(h: float, abilities: Array, plan: Array, thick := 0.0) -> bool:
	var rects := [Rect2(-600, 0, 600, 400), Rect2(0, -h, 600, h + 400)]
	if thick > 0.0:
		rects = [Rect2(-600, 0, 1200, 400), Rect2(0, -h, 600, thick)]
	var p := await _spawn(rects, Vector2(-HALF_W - 0.5, -HALF_H), abilities)
	# 薄台下面是空的：一开始就按右会钻到台底撞头。到顶点再按右，等于从侧面够台沿。
	if thick <= 0.0:
		Input.action_press("move_right")
	var ok := await _run(p, plan, 300, func(q: Player, c: Dictionary) -> int:
		if c["air"] and q.velocity.y >= 0.0:
			Input.action_press("move_right")
		# 只看高度：站在台沿拐角上时中心 x 可能还不到 0，也算站上去了。
		if c["air"] and q.is_on_floor():
			return 1 if q.global_position.y < -h else -1
		return 0)
	await _despawn()
	return ok


## 助跑过宽 gap 的缺口，落在同高的对岸即成功。
func _try_gap(gap: float, abilities: Array, plan: Array) -> bool:
	var rects := [Rect2(-600, 0, 600, 400), Rect2(gap, 0, 600, 400)]
	var p := await _spawn(rects, Vector2(-120, -HALF_H), abilities)
	Input.action_press("move_right")
	var ok := await _run(p, plan, 300, func(q: Player, c: Dictionary) -> int:
		if q.global_position.y > 150.0:
			return -1
		if c["air"] and q.is_on_floor():
			return 1 if q.global_position.x > gap - HALF_W else -1
		return 0)
	await _despawn()
	return ok


func _step_max(abilities: Array, plan: Array, thick := 0.0) -> float:
	return await _search(func(v: float) -> bool: return await _try_step(v, abilities, plan, thick))


func _gap_max(abilities: Array, plan: Array) -> float:
	return await _search(func(v: float) -> bool: return await _try_gap(v, abilities, plan))


func _best_gap(abilities: Array, plans: Dictionary) -> String:
	var best := -1.0
	var best_name := ""
	for plan_name in plans:
		var v := await _gap_max(abilities, plans[plan_name])
		print("      %-26s %.1f" % [plan_name, v])
		if v > best:
			best = v
			best_name = plan_name
	return "%.1f（%s）" % [best, best_name]


## 二分找最大可行值（单调：v 可行则更小也可行），精度 1 px。
func _search(ok_at: Callable) -> float:
	var lo := 0.0
	var hi := 1000.0
	while hi - lo > 1.0:
		var mid := (lo + hi) * 0.5
		if await ok_at.call(mid):
			lo = mid
		else:
			hi = mid
	return lo


## 墙跳：内宽 w 的竖井里左右交替（single 时只有左墙、贴回同一面墙），
## 一碰墙就按跳。返回每跳平均净升（负数 = 越跳越低）。
func _shaft(abilities: Array, w: float, single: bool) -> float:
	var rects := [Rect2(-300, -3000, 300, 3400), Rect2(-300, 0, maxf(w, 600) + 600, 400)]
	if not single:
		rects.append(Rect2(w, -3000, 300, 3400))
	var p := await _spawn(rects, Vector2(HALF_W + 1.0, -800), abilities)
	p.facing = -1
	Input.action_press("move_left")
	var ys: Array[float] = []
	var last_wall := 0
	var since := 99
	for f in range(900):
		await get_tree().physics_frame
		for a in _flush_actions:
			InputBuffer.clear_action(a)
		_flush_actions.clear()
		since += 1
		if p.is_on_floor() or ys.size() >= 10:
			break
		var wd := MovementProbe.wall_dir(p.get_world_2d(), p.global_position, p.facing)
		var fresh := wd != 0 and since > 6 and (single or wd != last_wall)
		if fresh:
			_press("jump")
			ys.append(p.global_position.y)
			last_wall = wd
			since = 0
			Input.action_release("move_left")
			Input.action_release("move_right")
			# 交替井：朝对面墙按；单面墙：锁定 0.1s 过后再按回同一面墙（锁定期间输入无效）。
			var hold := wd if single else -wd
			Input.action_press("move_right" if hold > 0 else "move_left")
	await _despawn()
	if ys.size() < 3:
		return -999.0
	return (ys[0] - ys[ys.size() - 1]) / float(ys.size() - 1)


## 钩点在头顶 250 处：拉到点后跳，或拉近途中跳（钩跳），取脚底能高出钩点的最大值。
func _hook_rise(abilities: Array) -> float:
	var best := -999.0
	for mode in ["arrive", "mid"]:
		var anchor := Vector2(0, -HALF_H - 250.0)
		var p := await _spawn([Rect2(-600, 0, 1200, 400)], Vector2(0, -HALF_H), abilities, [anchor])
		var plan := [_at("hook")]
		if mode == "arrive":
			plan.append(_at("jump", {"state": Player.State.FALL}))
		else:
			plan.append(_at("jump", {"near": 60.0}))
		if abilities.has("double_jump"):
			plan.append(_at("double", {"vy_ge": 0.0}))
		var top := {"y": INF}
		await _run(p, plan, 300, func(q: Player, c: Dictionary) -> int:
			if c["air"] and q.state != Player.State.HOOK:
				Input.action_release("hook")
			top["y"] = minf(top["y"], q.global_position.y + HALF_H)
			return 1 if c["air"] and q.is_on_floor() else 0)
		best = maxf(best, anchor.y - top["y"])
		await _despawn()
	return best


func _dash() -> Dictionary:
	var res := {}
	var p := await _spawn([Rect2(-600, 0, 1200, 400)], Vector2(0, -HALF_H), S5)
	var x0 := p.global_position.x
	await _run(p, [_at("dash")], 60, func(q: Player, _c: Dictionary) -> int:
		return 1 if q.state != Player.State.DASH and absf(q.velocity.x) < 1.0 and q.global_position.x > x0 + 1.0 else 0)
	res["ground"] = p.global_position.x - x0
	await _despawn()

	p = await _spawn([Rect2(-600, 0, 1200, 400)], Vector2(0, -HALF_H), S5)
	var seen := {"x": 0.0, "y": 0.0, "dx": 0.0, "dy": 0.0, "in": false}
	await _run(p, [_at("jump"), _at("dash", {"vy_ge": 0.0})], 120, func(q: Player, _c: Dictionary) -> int:
		if q.state == Player.State.DASH and not seen["in"]:
			seen["in"] = true
			seen["x"] = q.global_position.x
			seen["y"] = q.global_position.y
		elif seen["in"] and q.state != Player.State.DASH:
			seen["dx"] = q.global_position.x - seen["x"]
			seen["dy"] = q.global_position.y - seen["y"]
			return 1
		return 0)
	res["air_dx"] = seen["dx"]
	res["air_dy"] = seen["dy"]
	await _despawn()
	return res
