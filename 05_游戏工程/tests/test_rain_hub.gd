extends Node
## 雨市切片 rain_hub 的结构守门：第一阶段节拍清单里"必须"的东西都在数据里。
## 运行：bash tools/test_all.sh test_rain_hub

const DATA := "res://data/levels/rain_hub.json"

var _fail := 0
var _total := 0


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_check(parsed is Dictionary, "rain_hub.json 存在且可解析")
	if parsed is Dictionary:
		_test_structure(parsed)
		_test_hook_gap(parsed)
		_test_no_world_hole(parsed)
		_test_hints(parsed)
	_check(LevelManager.level_ids().size() > 0 and LevelManager.level_ids()[0] == "rain_hub", "第一关是 rain_hub")
	await _test_fall_out_dies()
	if _fail == 0:
		print("TEST_RAIN_HUB: PASS (%d assertions)" % _total)
	else:
		print("TEST_RAIN_HUB: FAIL (%d failures)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _kinds(d: Dictionary, key: String) -> Array:
	return (d.get(key, []) as Array).map(func(e): return String(e.get("kind", "")))


func _test_structure(d: Dictionary) -> void:
	_check((d.get("checkpoints", []) as Array).size() == 3, "针眼 3 个（诊所、中庭、排水沟）")
	var arenas := _kinds(d, "arenas")
	_check("clinic_back" in arenas and "drain_mid" in arenas, "战斗锁门 clinic_back、drain_mid")
	var lifts: Array = d.get("lifts", [])
	_check(lifts.any(func(l): return l.get("kind") == "drain_lift" and l.has("pos_b")), "升降梯 drain_lift 带 pos_b")
	var enemies: Array = d.get("enemies", [])
	_check(enemies.filter(func(e): return e.get("drops", "") == "claw").size() == 1, "恰有 1 个敌人掉攀爬爪")
	_check(enemies.filter(func(e): return e.get("drops", "") == "buffer").size() == 1, "恰有 1 个敌人掉缓冲片")
	_check(enemies.filter(func(e): return e.get("kind") == "crawler").size() >= 6, "沟爬子 ≥ 6")
	_check((d.get("meta", {}) as Dictionary).has("spawn"), "有出生点")


## 中庭右侧钩索缺口：两条 gap_marker 之间、缺口两侧平台高度附近不能有任何平台。
func _test_hook_gap(d: Dictionary) -> void:
	var xs: Array = (d.get("labels", []) as Array).filter(func(l): return l.get("kind") == "gap_marker") \
		.map(func(l): return float(l["pos"][0]))
	_check(xs.size() == 2, "有两条 gap_marker")
	if xs.size() != 2:
		return
	var x0: float = minf(xs[0], xs[1])
	var x1: float = maxf(xs[0], xs[1])
	_check(x1 - x0 >= 420.0, "缺口宽 ≥ 420（%.0f）" % (x1 - x0))
	var gap_y := float((d["labels"] as Array).filter(func(l): return l.get("kind") == "gap_marker")[0]["pos"][1])
	var blocked := false
	for p in d.get("platforms", []):
		var r: Array = p["rect"]
		var left := float(r[0])
		var right := left + float(r[2])
		var top := float(r[1])
		# 缺口高度上下 300 内、水平落在缺口里的平台都算"能借力"。
		if right > x0 + 1.0 and left < x1 - 1.0 and absf(top - gap_y) < 300.0:
			blocked = true
	_check(not blocked, "缺口内没有可借力的平台")


## 审查 C2：升降梯底端西侧那块不能是空的（x 1860–2016、y 800–1400 要有墙挡住）。
func _test_no_world_hole(d: Dictionary) -> void:
	var walled := false
	for p in d.get("platforms", []):
		var r: Array = p["rect"]
		if float(r[0]) <= 1900.0 and float(r[0]) + float(r[2]) >= 1860.0 \
				and float(r[1]) <= 800.0 and float(r[1]) + float(r[3]) >= 1400.0:
			walled = true
	_check(walled, "排水沟西墙从 y 800 起封住，升降梯底端西侧不漏")


func _hint_near(d: Dictionary, rect: Rect2) -> bool:
	for l in d.get("labels", []):
		if l.get("kind") == "hint" and rect.has_point(Vector2(float(l["pos"][0]), float(l["pos"][1]))):
			return true
	return false


## 审查 I2/I3：升降梯开关、两处长掉落都有提示。
func _test_hints(d: Dictionary) -> void:
	_check(_hint_near(d, Rect2(1900, 1300, 500, 250)), "升降梯开关旁有提示")
	_check(_hint_near(d, Rect2(4100, 400, 400, 250)), "中庭 → 排水沟的井口有下视提示")
	_check(_hint_near(d, Rect2(7200, 1100, 500, 250)), "排水沟上层 → 下层的井口有下视提示")


## 审查 C2：掉出关卡边界以下就断线，不会永远往下掉。
func _test_fall_out_dies() -> void:
	var prev: String = LevelManager.current_id
	LevelManager.current_id = "rain_hub"
	GameState.reset()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Node2D = main.get_node("Player")
	player.global_position = Vector2(1500, 2300)
	for i in range(10):
		await get_tree().physics_frame
	_check(GameState.integrity <= 0.0 or player.get("state") == Player.State.DEAD, "掉出边界以下：断线")
	main.queue_free()
	await get_tree().process_frame
	LevelManager.current_id = prev
	GameState.reset()
