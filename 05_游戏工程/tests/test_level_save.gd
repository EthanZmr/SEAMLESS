extends Node
## 架构改造回归：关卡生命周期 + 存档 + 时间缩放栈 + 敌人基类。
##
## 这四块是"加内容时会不会被迫回头改架构"的直接指标，所以要钉住契约，
## 而不是钉住某张关卡的具体坐标（那在 test_scene 里）。
##
## 运行：godot --headless --path . res://tests/test_level_save.tscn

const INDEX_PATH := "res://data/levels/index.json"
const SAVE_SLOT := 9

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_LEVEL_SAVE: start")

	_test_level_index()
	_test_level_manager_queries()
	_test_level_manager_rejects_unknown()
	await _test_save_roundtrip()
	_test_save_rejects_bad_version()
	_test_timescale_stack()
	await _test_enemy_base_contract()
	await _test_lancer_shares_base()

	# 收尾：别把 time_scale 留在半速，否则后续测试全部变慢。
	HitStop.clear_scales()
	Engine.time_scale = 1.0
	SaveManager.delete_slot(SAVE_SLOT)
	GameState.reset()

	print("TEST_LEVEL_SAVE: %s (%d assertions)" % [
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


# --- 关卡清单 -----------------------------------------------------------------

func _test_level_index() -> void:
	_check(FileAccess.file_exists(INDEX_PATH), "index.json 已落到 data/levels/")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "index.json 是合法 JSON 对象")
	var dict: Dictionary = parsed
	var levels: Array = dict.get("levels", [])
	_check(levels.size() >= 1, "清单至少有一关（got %d）" % levels.size())
	if levels.size() > 0:
		var first: Dictionary = levels[0]
		_check(first.has("id"), "关卡条目带 id")
		_check(first.has("scene"), "关卡条目带 scene")
		_check(first.has("data"), "关卡条目带 data")
		_check(str(first.get("id", "")) == "rain_hub", "第一关是 rain_hub（雨市切片）")


func _test_level_manager_queries() -> void:
	_check(LevelManager.index_source == "json", "LevelManager 从 JSON 读到清单")
	_check(LevelManager.level_count() >= 1, "LevelManager 至少知道一关")

	var ids := LevelManager.level_ids()
	_check(ids.has("rain_market"), "按 id 能查到雨市")
	_check(LevelManager.has_level("rain_market"), "has_level 认得雨市")
	_check(not LevelManager.has_level("no_such_level"), "has_level 拒绝不存在的关")

	var path := LevelManager.current_data_path()
	_check(path == "res://data/levels/rain_market.json", "当前关数据路径正确（got %s）" % path)
	_check(FileAccess.file_exists(path), "该路径对应的文件真的存在")
	_check(LevelManager.display_name() == "雨市", "显示名来自清单")
	_check(LevelManager.next_level_id() == "", "只有一关时没有下一关")

	var scene_path := LevelManager.scene_of("rain_market")
	_check(scene_path == "res://scenes/main.tscn", "关卡场景指向 main.tscn")


func _test_level_manager_rejects_unknown() -> void:
	# 这条必须不切场景：start_level 对未知关卡要当场拒绝。
	var before := LevelManager.current_id
	var ok := LevelManager.start_level("no_such_level")
	_check(not ok, "未知关卡被拒绝，不会切场景")
	_check(LevelManager.current_id == before, "拒绝后当前关不变")
	_check(not LevelManager.is_busy(), "被拒绝时不会进入 busy 状态")


# --- 存档 ---------------------------------------------------------------------

func _test_save_roundtrip() -> void:
	GameState.reset()
	SaveManager.delete_slot(SAVE_SLOT)
	_check(not SaveManager.has_slot(SAVE_SLOT), "起始时槽位是空的")

	GameState.set_form(1)
	GameState.add_sync(31.0)
	GameState.damage(12.0)
	GameState.set_flag("saw_ending", true)
	GameState.checkpoint = Vector2(880, 640)

	_check(SaveManager.save_slot(SAVE_SLOT), "存档写入成功")
	_check(SaveManager.has_slot(SAVE_SLOT), "槽位现在被占用")

	var info := SaveManager.slot_info(SAVE_SLOT)
	_check(int(info.get("version", 0)) == 1, "存档版本号 1")
	_check(str(info.get("level", "")) == LevelManager.current_id, "存档记下了关卡 id")
	_check(float(info.get("sync", -1)) > 0.0, "slot_info 能读出同步率")

	# 破坏现场，再读回来。
	GameState.reset()
	_check(GameState.form == 0, "reset 后回到针形态")
	_check(SaveManager.load_slot(SAVE_SLOT), "读档成功")
	_check(GameState.form == 1, "读档恢复了形态")
	_check(GameState.has_flag("saw_ending"), "读档恢复了 flags")
	_check(GameState.checkpoint.is_equal_approx(Vector2(880, 640)), "读档恢复了检查点")

	_check(SaveManager.used_slots().has(SAVE_SLOT), "used_slots 列出该槽位")
	_check(SaveManager.delete_slot(SAVE_SLOT), "删除槽位成功")
	_check(not SaveManager.has_slot(SAVE_SLOT), "删除后槽位为空")
	await get_tree().process_frame


func _test_save_rejects_bad_version() -> void:
	# 手写一份 version=99 的文件，读档必须拒绝而不是崩。
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var path := SaveManager.slot_path(SAVE_SLOT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	_check(f != null, "能写测试用存档文件")
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 99,
		"saved_at": 0,
		"level": "rain_market",
		"state": {"sync": 50.0},
	}))
	f.close()

	GameState.reset()
	GameState.add_sync(7.0)
	var before := GameState.sync
	_check(not SaveManager.load_slot(SAVE_SLOT), "版本过新的存档被拒绝（不降级读）")
	_check(is_equal_approx(GameState.sync, before), "拒绝时没有污染 GameState")
	SaveManager.delete_slot(SAVE_SLOT)


# --- 时间缩放栈 ---------------------------------------------------------------

func _test_timescale_stack() -> void:
	HitStop.clear_scales()
	var base := HitStop.base_scale
	_check(is_equal_approx(HitStop.current_scale(), base), "空栈时等于基准速度")
	_check(HitStop.stack_size() == 0, "起始栈为空")

	HitStop.push_scale("slowmo", 0.5)
	_check(is_equal_approx(HitStop.current_scale(), 0.5), "压入 0.5 后生效")
	_check(HitStop.stack_size() == 1, "栈里有 1 条")

	HitStop.push_scale("freeze", 0.05)
	_check(is_equal_approx(HitStop.current_scale(), 0.05), "两条并存时取最慢的")

	# 关键：弹出慢动作不能把顿帧一起抹掉。这正是旧实现会犯的错。
	HitStop.pop_scale("slowmo")
	_check(is_equal_approx(HitStop.current_scale(), 0.05), "弹出 slowmo 后 freeze 仍生效")
	_check(HitStop.stack_size() == 1, "栈里剩 1 条")

	HitStop.push_scale("freeze", 0.2)
	_check(HitStop.stack_size() == 1, "同名 id 是更新不是叠加")

	HitStop.pop_scale("freeze")
	_check(is_equal_approx(HitStop.current_scale(), base), "全部弹出后回到基准")

	# 重复 pop 必须安全（结束顺序不保证）。
	HitStop.pop_scale("freeze")
	_check(is_equal_approx(HitStop.current_scale(), base), "重复 pop 不会把速度改坏")

	HitStop.clear_scales()
	Engine.time_scale = 1.0


# --- 敌人基类 -----------------------------------------------------------------

func _test_enemy_base_contract() -> void:
	var scene := load("res://scenes/enemies/sweeper.tscn") as PackedScene
	_check(scene != null, "sweeper.tscn 可加载")
	if scene == null:
		return
	var enemy: EnemyBase = scene.instantiate()
	add_child(enemy)
	await get_tree().physics_frame

	_check(enemy is EnemyBase, "清道夫继承 EnemyBase")
	_check(enemy is MeleeChaser, "清道夫继承 MeleeChaser")
	_check(enemy.state == EnemyBase.State.PATROL, "初始状态是 patrol（enum）")
	_check(enemy.state_name() == "PATROL", "state_name 返回可读名（got %s）" % enemy.state_name())
	_check(not enemy.is_dead(), "初始未死亡")

	# 状态迁移必须走 _set_state，且同值不重复触发。
	enemy._set_state(EnemyBase.State.CHASE)
	_check(enemy.state == EnemyBase.State.CHASE, "_set_state 生效")

	# 标签契约：标签层只靠这四个方法，不认识敌人类型。
	_check(enemy.label_text().contains("清道夫"), "label_text 带名字")
	_check(enemy.label_anchor() is Vector2, "label_anchor 返回世界坐标")
	_check(enemy.label_alpha() > 0.0, "label_alpha 在合理区间")
	_check(enemy.label_tint() is Color, "label_tint 返回颜色")

	# 敌人身上不该再有 Info Label（P1-4 的目标）。
	var has_info := false
	for child in enemy.get_children():
		if child is Label and str(child.name) == "Info":
			has_info = true
	_check(not has_info, "敌人不再自建 Info 标签节点")

	enemy.queue_free()
	await get_tree().process_frame


func _test_lancer_shares_base() -> void:
	var scene := load("res://scenes/enemies/lancer.tscn") as PackedScene
	var enemy: EnemyBase = scene.instantiate()
	add_child(enemy)
	await get_tree().physics_frame

	_check(enemy is EnemyBase, "截线者继承 EnemyBase")
	_check(enemy.get_script() == load("res://scripts/enemies/lancer.gd"), "截线者用自己的脚本，不再复用 sweeper.gd")
	_check(is_equal_approx(enemy.attack_range, 112.0), "截线者臂长 112（来自场景覆盖）")
	_check(is_equal_approx(enemy.move_speed, 48.0), "截线者移速 48")
	# 长柄的语义：判定更高，不只是数字更大。
	_check(enemy._attack_height() > 70.0, "截线者判定高度大于短兵")

	enemy.queue_free()
	await get_tree().process_frame
