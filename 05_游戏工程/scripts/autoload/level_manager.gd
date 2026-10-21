extends Node
## 关卡生命周期（P0-1）。
##
## 之前全项目只有一处场景跳转：prologue.gd 里硬编码 change_scene_to_file(
## "res://scenes/main.tscn")。加第二关时你会有第二处、第三处硬编码，
## 而"现在在哪一关/下一关是哪一关/死了从哪一关重开"没有任何地方知道。
##
## 这个单例只做三件事：
##   1. 读 data/levels/index.json，回答"有哪些关、这关的数据在哪"；
##   2. 切关（记当前关、发 level_unloaded/level_loaded、换场景）；
##   3. 让 level.gd 不必知道自己的路径 —— 它问 current_data_path()。
##
## 不做的事：不自己实例化关卡、不做加载动画、不管存档内容。
## 加载逻辑属于 level.gd，存档属于 SaveManager，保持各管一摊。

const INDEX_PATH := "res://data/levels/index.json"
## 没有任何 start_level 调用时的默认关（测试、编辑器直接跑 main.tscn 会走这里）。
const DEFAULT_LEVEL_ID := "rain_market"

var index: Dictionary = {}
var index_source := "empty"
var current_id := DEFAULT_LEVEL_ID

var _busy := false


func _ready() -> void:
	_load_index()


func _load_index() -> bool:
	if not FileAccess.file_exists(INDEX_PATH):
		push_error("LevelManager: 关卡清单缺失 %s" % INDEX_PATH)
		return false
	var text := FileAccess.get_file_as_string(INDEX_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("LevelManager: 关卡清单不是 JSON 对象 %s" % INDEX_PATH)
		return false
	var dict: Dictionary = parsed
	var list: Variant = dict.get("levels", [])
	if typeof(list) != TYPE_ARRAY:
		push_error("LevelManager: levels 字段不是数组")
		return false
	for entry in (list as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var id: String = str(e.get("id", ""))
		if id.is_empty():
			push_warning("LevelManager: 跳过没有 id 的关卡条目")
			continue
		index[id] = e
	index_source = "json"

	if not index.has(current_id) and not index.is_empty():
		current_id = level_ids()[0]
	return not index.is_empty()


# --- 查询 ---------------------------------------------------------------------

func level_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in index.keys():
		ids.append(str(key))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(info(a).get("order", 0)) < int(info(b).get("order", 0)))
	return ids


func has_level(id: String) -> bool:
	return index.has(id)


func info(id: String = "") -> Dictionary:
	var key := id if not id.is_empty() else current_id
	if not index.has(key):
		return {}
	var d: Dictionary = index[key]
	return d


func level_count() -> int:
	return index.size()


## level.gd 用这个决定读哪份关卡 JSON。缺失时回退到当前关，
## 再缺失就返回空串，让 level.gd 走自己的兜底地面。
func current_data_path() -> String:
	return data_path_of(current_id)


func data_path_of(id: String) -> String:
	var d := info(id)
	if d.is_empty():
		return ""
	return str(d.get("data", ""))


func scene_of(id: String) -> String:
	var d := info(id)
	if d.is_empty():
		return ""
	return str(d.get("scene", ""))


func display_name(id: String = "") -> String:
	var d := info(id)
	if d.is_empty():
		return ""
	return str(d.get("display_name", ""))


func next_level_id() -> String:
	var raw := str(info().get("next", ""))
	# next 为空或指向不存在的关，都表示"这是最后一关"。
	if raw.is_empty() or not index.has(raw):
		return ""
	return raw


# --- 切换 ---------------------------------------------------------------------

## 切到一个关卡。同步返回是否受理（参数校验通过），场景替换是下一次
## 空闲帧发生 —— 调用方不必 await。
func start_level(id: String) -> bool:
	if _busy:
		return false
	if not index.has(id):
		push_error("LevelManager: 没有这个关卡 %s" % id)
		return false
	var target_scene := scene_of(id)
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_error("LevelManager: 关卡 %s 的场景无效 %s" % [id, target_scene])
		return false

	var previous := current_id
	current_id = id
	GameState.set_flag("level:" + id, true)
	GameEvents.level_unloaded.emit(previous)
	GameEvents.level_loaded.emit(id)

	_busy = true
	GameEvents.message.emit("进入：%s" % display_name(id))
	call_deferred("_replace_scene", target_scene)
	return true


func _replace_scene(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	_busy = false
	if err != OK:
		push_error("LevelManager: 切换场景失败 %s (%d)" % [path, err])


## 重开当前关。死亡/读档后回到起点，但 GameState 里的 flags 仍保留。
func restart_level() -> bool:
	return start_level(current_id)


func goto_next_level() -> bool:
	var nxt := next_level_id()
	if nxt.is_empty():
		return false
	return start_level(nxt)


func is_busy() -> bool:
	return _busy
