extends Node
## 存档版本迁移的契约测试。
##
## 钉住的不是"某个字段能存下来"（那在 test_level_save 里），而是
## **加字段之后旧存档还能不能读**——这是唯一一类"等有玩家存档了再修就一定出事故"
## 的问题，所以必须有测试压着。
##
## 运行：godot --headless --path . res://tests/test_save_migration.tscn

const SAVE_SLOT := 9
const SAVE_SLOT_B := 8

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_SAVE_MIGRATION: start")

	_test_version_constants()
	_test_legacy_save_upgrades()
	_test_migration_writes_back()
	_test_newer_version_rejected()
	_test_unknown_legacy_version()
	_test_missing_state_survives()
	_test_legacy_state_keeps_all_abilities()
	_test_batch_queries()

	# 收尾
	SaveManager.delete_slot(SAVE_SLOT)
	SaveManager.delete_slot(SAVE_SLOT_B)
	GameState.reset()

	print("TEST_SAVE_MIGRATION: %s (%d assertions)" % [
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


## 直接落一份"外部生成"的旧档，绕开 save_slot 走一遍真实读档路径。
func _write_raw(slot: int, payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var f := FileAccess.open(SaveManager.slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true


func _read_raw(slot: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SaveManager.slot_path(slot)))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# --- 常量语义 -----------------------------------------------------------------

func _test_version_constants() -> void:
	_check(SaveManager.SAVE_VERSION >= 1, "文件格式版本从 1 起（got %d）" % SaveManager.SAVE_VERSION)
	_check(SaveManager.LEGACY_VERSION == 0, "无 version 字段的档记为 v0")
	_check(SaveManager.SAVE_VERSION != GameState.STATE_VERSION
		or SaveManager.SAVE_VERSION == 1,
		"文件格式版本与状态结构版本是两层（%d / %d）"
			% [SaveManager.SAVE_VERSION, GameState.STATE_VERSION])
	_check(GameState.STATE_VERSION >= 1, "状态结构版本已提成常量（got %d）" % GameState.STATE_VERSION)


# --- v0 存档能升上来 ----------------------------------------------------------

func _test_legacy_save_upgrades() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	# v0：没有 version 字段。sync 写在 state 里，读档后应该能恢复。
	_check(_write_raw(SAVE_SLOT, {
		"level": "rain_market",
		"level_name": "雨市",
		"state": {"sync": 77.0, "integrity": 41.0, "form": 1},
	}), "写入一份无 version 字段的 v0 存档")

	_check(SaveManager.has_slot(SAVE_SLOT), "v0 存档被识别为存在")
	_check(SaveManager.needs_migration(SAVE_SLOT), "v0 存档标记为需要迁移")
	_check(SaveManager.slot_info(SAVE_SLOT).get("needs_migration", false),
		"slot_info 报告 needs_migration")

	GameState.reset()
	_check(SaveManager.load_slot(SAVE_SLOT), "v0 存档能直接读（迁移后）")
	_check(is_equal_approx(GameState.sync, 77.0), "迁移后 sync 恢复（got %.1f）" % GameState.sync)
	_check(is_equal_approx(GameState.integrity, 41.0), "迁移后 integrity 恢复（got %.1f）" % GameState.integrity)
	_check(GameState.form == 1, "迁移后 form 恢复")
	_check(not SaveManager.needs_migration(SAVE_SLOT), "读完后不再需要迁移")


# --- 能力系统之前的存档：全部能力视为已解锁 ---------------------------------

func _test_legacy_state_keeps_all_abilities() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	_check(_write_raw(SAVE_SLOT, {
		"version": SaveManager.SAVE_VERSION,
		"level": "rain_market",
		"level_name": "雨市",
		"state": {"version": 2, "sync": 30.0, "integrity": 100.0, "form": 0},
	}), "写入一份 state v2（无 abilities 字段）的存档")
	GameState.begin_new_game()
	_check(SaveManager.load_slot(SAVE_SLOT), "state v2 存档能读")
	var all_on := true
	for id in GameState.ABILITIES:
		all_on = all_on and GameState.has_ability(id)
	_check(all_on, "旧档读入后全部能力已解锁")
	SaveManager.delete_slot(SAVE_SLOT)


# --- 迁移后必须回写 ----------------------------------------------------------

func _test_migration_writes_back() -> void:
	var disk := _read_raw(SAVE_SLOT)
	_check(int(disk.get("version", -1)) == SaveManager.SAVE_VERSION,
		"迁移结果已回写磁盘（got %s）" % str(disk.get("version", "缺失")))
	_check(disk.has("saved_at"), "回写补上了 saved_at")
	_check(str(disk.get("level", "")) == "rain_market", "回写保留了原 level 字段")
	var state: Variant = disk.get("state", {})
	_check(typeof(state) == TYPE_DICTIONARY, "回写保留了 state 结构")


# --- 版本过新必须拒绝 --------------------------------------------------------

func _test_newer_version_rejected() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	var future := SaveManager.SAVE_VERSION + 1
	_check(_write_raw(SAVE_SLOT, {
		"version": future,
		"level": "rain_market",
		"state": {"sync": 12.0},
	}), "写入一份来自未来版本的存档（v%d）" % future)

	GameState.reset()
	GameState.add_sync(3.0)
	var before := GameState.sync
	_check(not SaveManager.load_slot(SAVE_SLOT), "版本过新的存档被拒绝")
	_check(is_equal_approx(GameState.sync, before), "拒绝时没有污染 GameState")
	_check(int(_read_raw(SAVE_SLOT).get("version", 0)) == future, "拒绝时没有改动磁盘文件")


# --- 没有升级路径时拒绝而不是猜 ----------------------------------------------

func _test_unknown_legacy_version() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	# version = -1：目标版本 0 在 _migration_steps() 里没有对应函数。
	_check(_write_raw(SAVE_SLOT, {
		"version": -1,
		"level": "rain_market",
		"state": {"sync": 5.0},
	}), "写入一份版本号为负的畸形存档")

	GameState.reset()
	var before := GameState.sync
	_check(not SaveManager.load_slot(SAVE_SLOT), "没有升级路径的存档被拒绝")
	_check(is_equal_approx(GameState.sync, before), "畸形存档没有污染 GameState")
	SaveManager.delete_slot(SAVE_SLOT)


# --- v0 缺 state 也不能崩 -----------------------------------------------------

func _test_missing_state_survives() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	_check(_write_raw(SAVE_SLOT, {
		"level": "rain_market",
	}), "写入一份完全缺 state 的 v0 存档")

	GameState.reset()
	GameState.add_sync(9.0)
	var before := GameState.sync
	_check(SaveManager.load_slot(SAVE_SLOT), "缺 state 的 v0 存档仍可读（补成空 dict）")
	_check(is_equal_approx(GameState.sync, before), "缺 state 时保持当前状态而不是清零")

	# 缺 level 的档：迁移补 ""，不该把 current_id 改坏。
	var keep := LevelManager.current_id
	SaveManager.delete_slot(SAVE_SLOT)
	_write_raw(SAVE_SLOT, {"state": {"sync": 10.0}})
	_check(SaveManager.load_slot(SAVE_SLOT), "完全空壳档也能读")
	_check(LevelManager.current_id == keep, "缺 level 字段时不改动当前关卡")
	SaveManager.delete_slot(SAVE_SLOT)


# --- 批量查询 -----------------------------------------------------------------

func _test_batch_queries() -> void:
	SaveManager.delete_slot(SAVE_SLOT)
	SaveManager.delete_slot(SAVE_SLOT_B)
	_write_raw(SAVE_SLOT, {"level": "rain_market", "state": {"sync": 1.0}})
	_write_raw(SAVE_SLOT_B, {
		"version": SaveManager.SAVE_VERSION,
		"level": "rain_market",
		"state": {"sync": 2.0},
	})

	var list := SaveManager.migratable_slots()
	_check(list.has(SAVE_SLOT), "migratable_slots 包含旧档")
	_check(not list.has(SAVE_SLOT_B), "migratable_slots 不包含同版本档")
	_check(SaveManager.used_slots().has(SAVE_SLOT) and SaveManager.used_slots().has(SAVE_SLOT_B),
		"used_slots 两个都列出来")
	_check(SaveManager.needs_migration(SAVE_SLOT_B) == false, "同版本档不需要迁移")
	_check(SaveManager.needs_migration(SaveManager.SLOT_MAX + 1) == false,
		"越界槽位不算需要迁移")

	SaveManager.delete_slot(SAVE_SLOT)
	SaveManager.delete_slot(SAVE_SLOT_B)
