extends Node
## 存档（P0-1 的另一半）。
##
## 拆 GameState 之后，全局状态已经能 to_dict()/from_dict() 往返了；
## 这里只负责"写到磁盘、读回来、别写坏"。
##
## 三条硬规矩：
##   1. 原子写 —— 先写 .tmp 再 rename，中途断电不会留下半个 JSON；
##   2. 版本号 —— 文件里带 version，读的时候不匹配就拒绝而不是崩；
##   3. 存档只记录状态，不记录"谁在哪个节点上" —— 节点由场景重建。

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
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


## 存档。返回 false 表示没写成功（磁盘/参数问题），调用方据此提示。
func save_slot(slot: int) -> bool:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		push_error("SaveManager: 槽位越界 %d" % slot)
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"level": LevelManager.current_id,
		"level_name": LevelManager.display_name(),
		"state": GameState.to_dict(),
	}
	var text := JSON.stringify(payload, "\t")
	var final := slot_path(slot)
	var tmp := final + ".tmp"

	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 打不开临时文件 %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
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
	GameEvents.message.emit("已存档：槽位 %d" % slot)
	return true


## 读档。true = GameState 已被覆盖，调用方负责切关卡与重建场景。
func load_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: 槽位 %d 内容不是 JSON 对象" % slot)
		return false
	var dict: Dictionary = parsed
	var ver := int(dict.get("version", 0))
	if ver != SAVE_VERSION:
		push_error("SaveManager: 槽位 %d 版本不匹配 (%d != %d)" % [slot, ver, SAVE_VERSION])
		return false
	var state: Variant = dict.get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		push_error("SaveManager: 槽位 %d 缺少 state" % slot)
		return false
	GameState.from_dict(state)

	var level := str(dict.get("level", ""))
	if not level.is_empty() and LevelManager.has_level(level):
		LevelManager.current_id = level
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
	var state: Variant = dict.get("state", {})
	var sync_v := 0.0
	var integrity_v := 0.0
	if typeof(state) == TYPE_DICTIONARY:
		var s: Dictionary = state
		sync_v = float(s.get("sync", 0.0))
		integrity_v = float(s.get("integrity", 0.0))
	return {
		"slot": slot,
		"version": int(dict.get("version", 0)),
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
