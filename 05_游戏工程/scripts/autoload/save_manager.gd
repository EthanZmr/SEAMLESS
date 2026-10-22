extends Node
## 存档（P0-1 的另一半）。
##
## 拆 GameState 之后，全局状态已经能 to_dict()/from_dict() 往返了；
## 这里只负责"写到磁盘、读回来、别写坏、旧档能升级"。
##
## 五条硬规矩：
##   1. 原子写 —— 先写 .tmp 再 rename，中途断电不会留下半个 JSON；
##   2. 版本链 —— 文件里带 version，旧版本按 MIGRATIONS 逐级升上来，
##      不是"不匹配就拒绝"（那等于每次加字段都让玩家存档作废）；
##   3. 版本过新要拒绝 —— 玩家的档来自更新版本的游戏，降级打开会静默丢数据；
##   4. 存档只记录状态，不记录"谁在哪个节点上" —— 节点由场景重建；
##   5. 迁移成功立刻回写 —— 否则每次读档都要重跑一遍迁移链。
##
## 两层版本，别混：
##   - SAVE_VERSION：**文件格式**版本（本文件说了算）
##   - GameState.STATE_VERSION：**状态结构**版本（game_state.gd 说了算）
## 加字段只改对应的那一层。状态结构变了但字段缺省有兜底时，不必动 SAVE_VERSION。

const SAVE_DIR := "user://saves"

## 文件格式版本。改动 payload 结构（加/删/改顶层键的语义）时 += 1，
## 并在 _migration_steps() 里挂一条"从上一版升到这一版"的函数。
const SAVE_VERSION := 1

## 没有 version 字段的存档视为这一版：早期手写档、外部工具生成的档都会落在这里。
const LEGACY_VERSION := 0

const SLOT_MIN := 1
const SLOT_MAX := 9


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_slot(slot: int) -> bool:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		return false
	return FileAccess.file_exists(slot_path(slot))


# --- 版本链 ------------------------------------------------------------------

## 目标版本 → 升级函数。键是"升到哪一版"，值收一个 Dictionary 并原地改它。
## 加版本的固定动作：
##   1. SAVE_VERSION += 1
##   2. 写 func _vN_to_vN1(data: Dictionary) -> bool
##   3. 在这里加 N+1: _vN_to_vN1
## 忘了第 3 步的后果：旧档读到就报"没有从 vN 升到 vN1 的路径"，不会静默损坏。
func _migration_steps() -> Dictionary:
	return {
		1: _v0_to_v1,
	}


## v0 → v1：补上 v1 之后才存在的顶层键。
## v0 的形态是"可能什么都没有"——所以这里只保证结构存在，
## 具体数值缺失交给 GameState.from_dict() 的逐字段兜底，不在这里硬编码默认值。
func _v0_to_v1(data: Dictionary) -> bool:
	if typeof(data.get("state", {})) != TYPE_DICTIONARY:
		data["state"] = {}
	if not data.has("level"):
		data["level"] = ""
	if not data.has("level_name"):
		data["level_name"] = ""
	if not data.has("saved_at"):
		data["saved_at"] = 0
	return true


## 逐级升级到 SAVE_VERSION。返回 {} 表示升不上去（缺路径或某步失败）。
func _migrate(data: Dictionary, from_ver: int) -> Dictionary:
	var steps := _migration_steps()
	var ver := from_ver
	while ver < SAVE_VERSION:
		var target := ver + 1
		if not steps.has(target):
			push_error("SaveManager: 没有从 v%d 升到 v%d 的路径" % [ver, target])
			return {}
		var step: Callable = steps[target]
		if not step.call(data):
			push_error("SaveManager: v%d → v%d 迁移失败" % [ver, target])
			return {}
		data["version"] = target
		ver = target
	return data


## 这个槽位是不是需要迁移（供存档界面提示"旧存档将自动升级"）。
func needs_migration(slot: int) -> bool:
	if not has_slot(slot):
		return false
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = parsed
	return int(dict.get("version", LEGACY_VERSION)) != SAVE_VERSION


## 所有需要迁移的槽位，升序。
func migratable_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in used_slots():
		if needs_migration(slot):
			out.append(slot)
	return out


# --- 写 ----------------------------------------------------------------------

## 原子写：先写 .tmp 再 rename。返回 false 表示没落盘（磁盘/参数问题）。
## 不发 GameEvents.message —— 迁移回写也用这条路径，不该弹"已存档"。
func _write_payload(slot: int, payload: Dictionary) -> bool:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		push_error("SaveManager: 槽位越界 %d" % slot)
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var final := slot_path(slot)
	var tmp := final + ".tmp"

	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 打不开临时文件 %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.flush()
	f.close()

	# rename 是替代操作：目标已存在时覆盖。
	var err := DirAccess.rename_absolute(tmp, final)
	if err != OK:
		# 某些平台不允许覆盖，先删再改名。
		DirAccess.remove_absolute(final)
		err = DirAccess.rename_absolute(tmp, final)
	if err != OK:
		push_error("SaveManager: 落盘失败 %s (%d)" % [final, err])
		DirAccess.remove_absolute(tmp)
		return false
	return true


## 存档。返回 false 表示没写成功，调用方据此提示。
func save_slot(slot: int) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"level": LevelManager.current_id,
		"level_name": LevelManager.display_name(),
		"state": GameState.to_dict(),
	}
	if not _write_payload(slot, payload):
		return false
	GameEvents.message.emit("已存档：槽位 %d" % slot)
	return true


# --- 读 ----------------------------------------------------------------------

## 读档。true = GameState 已被覆盖，调用方负责切关卡与重建场景。
## 旧版本存档会先迁移再回写；版本过新（来自更新版本的游戏）直接拒绝。
func load_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: 槽位 %d 内容不是 JSON 对象" % slot)
		return false
	var dict: Dictionary = parsed

	var ver := int(dict.get("version", LEGACY_VERSION))
	if ver > SAVE_VERSION:
		# 不降级读：新版本可能已经改了字段含义，硬读会静默丢数据。
		push_error("SaveManager: 槽位 %d 来自更新版本 (%d > %d)，拒绝读取"
			% [slot, ver, SAVE_VERSION])
		return false
	var migrated := false
	if ver < SAVE_VERSION:
		dict = _migrate(dict, ver)
		if dict.is_empty():
			push_error("SaveManager: 槽位 %d 迁移失败 (v%d)" % [slot, ver])
			return false
		migrated = true

	var state: Variant = dict.get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		push_error("SaveManager: 槽位 %d 缺少 state" % slot)
		return false
	GameState.from_dict(state)

	var level := str(dict.get("level", ""))
	if not level.is_empty() and LevelManager.has_level(level):
		LevelManager.current_id = level

	# 迁移成功立刻回写：否则每次读这个槽都要重跑一遍迁移链。
	if migrated:
		dict["saved_at"] = int(dict.get("saved_at", 0))
		if not _write_payload(slot, dict):
			push_warning("SaveManager: 槽位 %d 已迁移但回写失败，下次读档会再迁移一次" % slot)

	GameEvents.message.emit("已读档：槽位 %d" % slot)
	return true


## 读档并进入对应关卡。存档槽存在但关卡已从清单删除时返回 false。
func load_slot_and_enter(slot: int) -> bool:
	if not load_slot(slot):
		return false
	return LevelManager.start_level(LevelManager.current_id)


## 只读取元信息（用于存档界面列表），不触碰 GameState。
func slot_info(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var dict: Dictionary = parsed
	var ver := int(dict.get("version", LEGACY_VERSION))
	var state: Variant = dict.get("state", {})
	var sync_v := 0.0
	var integrity_v := 0.0
	if typeof(state) == TYPE_DICTIONARY:
		var s: Dictionary = state
		sync_v = float(s.get("sync", 0.0))
		integrity_v = float(s.get("integrity", 0.0))
	return {
		"slot": slot,
		"version": ver,
		"needs_migration": ver != SAVE_VERSION,
		"saved_at": int(dict.get("saved_at", 0)),
		"level": str(dict.get("level", "")),
		"level_name": str(dict.get("level_name", "")),
		"sync": sync_v,
		"integrity": integrity_v,
	}


func delete_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK


## 所有已占用的槽位，按槽号升序。存档界面直接遍历这个。
func used_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in range(SLOT_MIN, SLOT_MAX + 1):
		if has_slot(slot):
			out.append(slot)
	return out
