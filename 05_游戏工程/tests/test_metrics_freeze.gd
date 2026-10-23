extends "res://tools/measure_metrics.gd"
## 手感数值冻结守门（D18 第 2 层，2026-10-23 真人手测 GO）。
## 地图按 01_GDD/11_关卡度量表 摆；移动数值或移动代码一变，度量表和地图就可能失效。
## 失败时：重跑 tools/measure_metrics.tscn → 更新 01_GDD/11 → 复查地图 → 再改这里的冻结值。
## Run: bash tools/test_all.sh test_metrics_freeze

## 冻结时 player_stats.tres 里的移动数值。
const FROZEN := {
	"SPEED": 220.0, "ACCEL": 1800.0, "FRICTION": 2200.0, "AIR_ACCEL": 1200.0,
	"JUMP_VELOCITY": -600.0, "GRAVITY": 1400.0, "MAX_FALL": 820.0,
	"COYOTE_TIME": 0.10, "JUMP_BUFFER": 0.12, "JUMP_CUT_VELOCITY": -150.0,
	"DASH_SPEED": 560.0, "DASH_TIME": 0.16, "DASH_COOLDOWN": 0.35,
	"CLIMB_SPEED": 132.0, "CLIMB_SNAP_SPEED": 360.0,
	"CLIMB_JUMP_VERTICAL": -560.0, "CLIMB_JUMP_HORIZONTAL": 240.0, "CLIMB_JUMP_LOCK": 0.22,
	"WALL_SLIDE_SPEED": 150.0, "WALL_JUMP_HORIZONTAL": 600.0,
	"WALL_JUMP_VERTICAL": -560.0, "WALL_JUMP_LOCK": 0.10,
	"DOUBLE_JUMP_VERTICAL": -540.0,
	"LEDGE_COOLDOWN": 0.28, "LEDGE_VAULT_HORIZONTAL": 240.0, "LEDGE_VAULT_VERTICAL": -430.0,
	"LEDGE_PROBE_FORWARD": 20.0, "LEDGE_PROBE_ABOVE": 26.0, "LEDGE_DROP_SPEED": 140.0,
	"HOOK_RANGE": 320.0, "HOOK_SPEED": 680.0, "HOOK_ARRIVE": 30.0,
	"HOOK_JUMP_LOCK": 0.08, "HOOK_FREE_JUMP_TIME": 0.45,
	"HOOK_JUMP_VERTICAL": -520.0, "HOOK_JUMP_X_KEEP": 0.25, "HOOK_DETACH_KEEP": 0.35,
}
const TOL := 1.5

var _total := 0
var _fails := 0


func _ready() -> void:
	DebugLog.enabled = false
	await get_tree().process_frame
	_test_frozen_stats()
	await _test_measured()
	await _test_design_bounds()
	if _fails == 0:
		print("TEST_METRICS_FREEZE: PASS (%d assertions)" % _total)
	else:
		print("TEST_METRICS_FREEZE: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fails += 1
		print("  FAIL  ", label)


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= TOL, "%s = %.1f（冻结 %.1f）" % [label, actual, expected])


## 数据：改了 .tres 就失败。
func _test_frozen_stats() -> void:
	var stats: Resource = load("res://data/player/player_stats.tres")
	for key in FROZEN:
		var v: float = stats.get(key)
		_check(is_equal_approx(v, FROZEN[key]), "%s = %s（冻结 %s）" % [key, v, FROZEN[key]])


## 行为：改了移动代码就失败。值来自 01_GDD/11 §2。
func _test_measured() -> void:
	_near(await _rise(S0, [_at("jump")]), 133.7, "单跳最高")
	_near(await _rise(S0, [_at("jump", {}, true)]), 26.5, "小跳")
	_near(await _rise(S5, [_at("jump"), _at("double", {"vy_ge": 0.0})]), 233.2, "二段最高")
	var dash := await _dash()
	_near(dash["ground"], 150.7, "地面冲刺位移")
	_near(dash["air_dx"], 83.4, "空中冲刺水平")
	_near(await _hook_rise(S3), 72.4, "钩到点后再跳高出钩点")
	_near(await _shaft(S4, 128.0, false), 71.9, "墙跳井内宽 128 每跳净升")


## 01_GDD/11 §3 的主路必过 / 能力锁必不过。
func _test_design_bounds() -> void:
	var jump := [_at("jump")]
	var air_jump := [_at("jump", {"air": true})]
	var vault := _at("jump", {"state": Player.State.LEDGE})
	_check(await _try_step(112.0, S0, jump), "开局：台阶 112 能上")
	_check(not await _try_step(153.0, S0, jump), "开局：台阶 153 上不去（锁 ①）")
	_check(await _try_gap(180.0, S0, air_jump), "开局：缺口 180 能过")
	_check(not await _try_gap(246.0, S0, air_jump), "开局：缺口 246 过不去")
	_check(await _try_step(157.0, S1, [_at("jump"), vault], 24.0), "①：24 厚台沿 157 抓边能上")
	_check(not await _try_step(215.0, S1, [_at("jump"), vault]), "①：台阶 215 上不去（锁 ⑤）")
	_check(not await _try_gap(272.0, S1, [_at("jump", {"air": true}), vault]), "①：缺口 272 过不去（锁 ⑤）")
	var apex_double := [_at("jump"), _at("double", {"vy_ge": 0.0})]
	_check(await _try_step(197.0, ["double_jump", "dash"], apex_double), "⑤：台阶 197 能上")
	_check(await _try_gap(281.0, S5_NO_LEDGE,
		[_at("jump", {"air": true}), _at("double", {"vy_ge": 0.0})]), "⑤：缺口 281 顶点二段能过")
