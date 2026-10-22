extends Node
## 能力解锁：GameState 的能力集合、零件、存档迁移，以及玩家各动作的门控。
##
## 运行：bash tools/test_all.sh test_abilities

const PROTO := preload("res://scenes/prototype/climb_prototype.tscn")

var _fail := 0
var _total := 0


func _ready() -> void:
	_test_default_all()
	_test_new_game_empty()
	_test_unlock()
	_test_install_part()
	_test_reset_keeps()
	_test_roundtrip()
	_test_legacy_without_abilities()
	await _test_locked_climb()
	await _test_locked_hook()
	await _test_locked_double_jump()
	await _test_locked_wall_jump()
	await _test_locked_dash_parry_switch()
	_test_sync_no_auto_takeover()
	await _test_unlocked_climb()
	await _test_climb_no_dash_without_part()
	GameState.unlock_all_abilities()
	if _fail == 0:
		print("TEST_ABILITIES: PASS (%d assertions)" % _total)
	else:
		print("TEST_ABILITIES: FAIL (%d failures)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _count_unlocked() -> int:
	var n := 0
	for id in GameState.ABILITIES:
		if GameState.has_ability(id):
			n += 1
	return n


func _test_default_all() -> void:
	GameState.unlock_all_abilities()
	_check(_count_unlocked() == GameState.ABILITIES.size(), "全部解锁后 7 个能力都有")


func _test_new_game_empty() -> void:
	GameState.set_flag("x")
	GameState.begin_new_game()
	_check(_count_unlocked() == 0, "新游戏没有任何能力")
	_check(GameState.flags.is_empty(), "新游戏清空剧情标记")


func _test_unlock() -> void:
	GameState.begin_new_game()
	_check(GameState.unlock_ability("climb"), "首次解锁 climb 返回 true")
	_check(GameState.has_ability("climb"), "解锁后 has_ability(climb)")
	_check(not GameState.unlock_ability("climb"), "重复解锁返回 false")
	_check(not GameState.unlock_ability("fly"), "未知能力返回 false")
	_check(not GameState.has_ability("fly"), "未知能力不会被记下")


func _test_install_part() -> void:
	GameState.begin_new_game()
	_check(GameState.install_part("valve"), "安装气阀返回 true")
	_check(GameState.has_ability("double_jump") and GameState.has_ability("dash"), "气阀解锁二段跳和冲刺")
	_check(not GameState.install_part("valve"), "重复安装返回 false")
	_check(not GameState.install_part("wing"), "未知零件返回 false")
	_check(GameState.PART_NAMES.get("claw", "") == "攀爬爪", "零件名：claw = 攀爬爪")


func _test_reset_keeps() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	GameState.reset()
	_check(GameState.has_ability("climb"), "断线复活（reset）不丢能力")


func _test_roundtrip() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	GameState.unlock_ability("hook")
	var d := GameState.to_dict()
	_check(int(d.get("version", 0)) == 3, "状态结构版本为 3")
	GameState.begin_new_game()
	GameState.from_dict(d)
	_check(GameState.has_ability("climb") and GameState.has_ability("hook"), "存读档保留已解锁能力")
	_check(_count_unlocked() == 2, "存读档不多出能力")


func _test_legacy_without_abilities() -> void:
	GameState.begin_new_game()
	GameState.from_dict({"version": 2, "sync": 30.0})
	_check(_count_unlocked() == GameState.ABILITIES.size(), "旧档（无 abilities 字段）视为全部解锁")


# --- 玩家门控（输入写法照 test_movement.gd） --------------------------------

func _spawn() -> Dictionary:
	var proto := PROTO.instantiate()
	add_child(proto)
	await get_tree().process_frame
	await get_tree().physics_frame
	return {"proto": proto, "player": proto.player}


func _cleanup(ctx: Dictionary) -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "jump", "hook"]:
		Input.action_release(a)
	InputBuffer.clear()
	ctx["proto"].queue_free()
	await get_tree().process_frame


func _stamp(action: String) -> void:
	InputBuffer._stamps[action] = Time.get_ticks_msec()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _test_locked_climb() -> void:
	GameState.begin_new_game()
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(406, 560)
	p.velocity = Vector2.ZERO
	p.state = Player.State.FALL
	await get_tree().physics_frame
	Input.action_press("move_up")
	await _frames(6)
	_check(p.state != Player.State.CLIMB, "未解锁攀爬：攀爬区按上不进 CLIMB")
	await _cleanup(ctx)


func _test_locked_hook() -> void:
	GameState.begin_new_game()
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(700, 560)
	p.velocity = Vector2.ZERO
	p.state = Player.State.FALL
	await get_tree().physics_frame
	InputBuffer.clear()
	_stamp("hook")
	Input.action_press("hook")
	await _frames(3)
	_check(p.state != Player.State.HOOK, "未解锁钩索：锚点在射程内也不进 HOOK")
	await _cleanup(ctx)


func _test_locked_double_jump() -> void:
	GameState.begin_new_game()
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(250, 588)
	p.velocity = Vector2.ZERO
	await _frames(14)
	p.state = Player.State.IDLE
	InputBuffer.clear()
	_stamp("jump")
	await _frames(2)
	_check(p.state == Player.State.JUMP and p.velocity.y < -500.0, "未解锁二段跳：地面跳照常")
	await _frames(5)
	_stamp("jump")
	await _frames(2)
	_check(p.velocity.y > -450.0, "未解锁二段跳：空中再按跳不起跳（vy=%.0f）" % p.velocity.y)
	await _cleanup(ctx)


func _test_locked_wall_jump() -> void:
	GameState.begin_new_game()
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(954, 400)
	p.velocity = Vector2(0, 100)
	p.facing = 1
	p.state = Player.State.FALL
	InputBuffer.clear()
	_stamp("jump")
	await _frames(2)
	_check(p.velocity.x <= 0.0, "未解锁墙跳：贴墙按跳不被弹开（vx=%.0f）" % p.velocity.x)
	_check(p.state != Player.State.WALL_SLIDE, "未解锁墙跳：不进 WALL_SLIDE")
	await _cleanup(ctx)


func _test_locked_dash_parry_switch() -> void:
	GameState.begin_new_game()
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(250, 588)
	p.velocity = Vector2.ZERO
	await _frames(14)
	p.state = Player.State.IDLE
	InputBuffer.clear()
	_stamp("dash")
	await _frames(2)
	_check(p.state != Player.State.DASH, "未解锁冲刺：不进 DASH")
	InputBuffer.clear()
	_stamp("parry")
	await _frames(2)
	_check(p.state != Player.State.PARRY, "未解锁弹反：不进 PARRY")
	InputBuffer.clear()
	_stamp("switch")
	await _frames(2)
	_check(GameState.form == 0, "未解锁换人：形态不变")
	await _cleanup(ctx)


func _test_sync_no_auto_takeover() -> void:
	GameState.begin_new_game()
	GameState.add_sync(100.0, true)
	_check(is_equal_approx(GameState.sync, 100.0), "未解锁换人：同步率照常涨到 100")
	_check(not GameState.is_takeover, "未解锁换人：满 100 不自动接管")
	GameState.start_takeover()
	_check(GameState.is_takeover, "剧本调用 start_takeover 仍可接管")
	GameState.reset()


func _test_unlocked_climb() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(406, 560)
	p.velocity = Vector2.ZERO
	p.state = Player.State.FALL
	await get_tree().physics_frame
	Input.action_press("move_up")
	await _frames(4)
	_check(p.state == Player.State.CLIMB, "解锁攀爬后：攀爬区按上进 CLIMB")
	await _cleanup(ctx)


## 审查 I1：有攀爬、没冲刺时，攀爬中按冲刺不能冲出去。
func _test_climb_no_dash_without_part() -> void:
	GameState.begin_new_game()
	GameState.unlock_ability("climb")
	var ctx := await _spawn()
	var p: Player = ctx["player"]
	p.global_position = Vector2(406, 560)
	p.velocity = Vector2.ZERO
	p.state = Player.State.FALL
	await get_tree().physics_frame
	Input.action_press("move_up")
	await _frames(4)
	InputBuffer.clear()
	_stamp("dash")
	await _frames(2)
	_check(p.state != Player.State.DASH, "未解锁冲刺：攀爬中按冲刺不进 DASH")
	await _cleanup(ctx)
