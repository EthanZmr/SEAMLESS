extends Node
## 双意识状态：同步率、完整度、形态、接管、检查点、剧情标记。
##
## 架构约定（P0-2）：
##   · 这个类**只存值**，不跑时间。没有 _process。
##   · 值怎么变由 SyncRules 决定，时间由 GameLoop 推进。
##   · 因此本类可以被完整序列化（to_dict / from_dict），存档不丢过程量。
##   · 上限等边界值由 SyncRules.apply_to() 注入，不写死在这里。

## 边界值：由 SyncRules 注入；保留默认值以便没有 GameLoop 的场景（如序章）也能工作。
var MAX_SYNC := 100.0
var MIN_SYNC := 0.0
var MAX_INTEGRITY := 100.0
var TAKEOVER_DURATION := 8.0
var TAKEOVER_EXIT_SYNC := 50.0
var TAKEOVER_INTEGRITY_COST := 20.0

## 运行时状态。
var sync := 30.0
var integrity := 100.0
var form := 0  # 0 = A-Zhen, 1 = A-Ling
var is_takeover := false
var takeover_timer := 0.0
var sync_frozen := 0.0
var checkpoint := Vector2.ZERO
var flags: Dictionary = {}

## 能力解锁（01_GDD/10 §4）。初始值为全部解锁：测试、原型场景直接可用；
## 只有新游戏（序章结束进入雨市）调用 begin_new_game() 清空。
const ABILITIES := ["climb", "parry", "hook", "wall_jump", "double_jump", "dash", "switch"]
## 零件 → 它解锁的能力。换人不是零件，由剧情点解锁。
const PARTS := {
	"claw": ["climb"],
	"buffer": ["parry"],
	"launcher": ["hook"],
	"spring": ["wall_jump"],
	"valve": ["double_jump", "dash"],
}
const PART_NAMES := {
	"claw": "攀爬爪",
	"buffer": "缓冲片",
	"launcher": "纤维发射器",
	"spring": "腿部弹簧",
	"valve": "气阀",
}
var abilities: Dictionary = _all_abilities()


# --- 状态变更（不变量在这里，速率在 SyncRules） ---------------------------------

func add_sync(amount: float, ignore_freeze: bool = false) -> void:
	if amount == 0.0:
		return
	if sync_frozen > 0.0 and not ignore_freeze:
		return
	sync = clampf(sync + amount, MIN_SYNC, MAX_SYNC)
	GameEvents.sync_changed.emit(sync)
	if sync >= MAX_SYNC and not is_takeover:
		start_takeover()


func freeze_sync(duration: float) -> void:
	sync_frozen = maxf(sync_frozen, duration)


func set_form(new_form: int) -> void:
	if new_form == form:
		return
	form = clampi(new_form, 0, 1)
	GameEvents.form_changed.emit(form)


func start_takeover() -> void:
	if is_takeover:
		return
	is_takeover = true
	takeover_timer = TAKEOVER_DURATION
	sync = MAX_SYNC
	set_form(1)
	GameEvents.takeover_started.emit()
	_emit_snapshot()
	GameEvents.message.emit("同步率超载——她接管了。")


func end_takeover() -> void:
	if not is_takeover:
		return
	is_takeover = false
	takeover_timer = 0.0
	sync = TAKEOVER_EXIT_SYNC
	integrity = maxf(0.0, integrity - TAKEOVER_INTEGRITY_COST)
	set_form(0)
	GameEvents.sync_changed.emit(sync)
	GameEvents.integrity_changed.emit(integrity)
	GameEvents.takeover_ended.emit()
	GameEvents.message.emit("她退了。你的手在抖。")
	_emit_snapshot()
	if integrity <= 0.0:
		GameEvents.player_died.emit()


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	integrity = clampf(integrity - amount, 0.0, MAX_INTEGRITY)
	GameEvents.integrity_changed.emit(integrity)
	_emit_snapshot()
	if integrity <= 0.0:
		GameEvents.player_died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	integrity = clampf(integrity + amount, 0.0, MAX_INTEGRITY)
	GameEvents.integrity_changed.emit(integrity)
	_emit_snapshot()


## 供 SyncRules 每帧回复时使用：只发信号，不改值。
func emit_integrity() -> void:
	GameEvents.integrity_changed.emit(integrity)


## HUD/存档的单一数据源：广播一份完整快照，订阅者不需要认识 GameState。
func _emit_snapshot() -> void:
	GameEvents.state_snapshot.emit(to_dict())


func reset() -> void:
	sync = 30.0
	integrity = 100.0
	form = 0
	is_takeover = false
	takeover_timer = 0.0
	sync_frozen = 0.0
	GameEvents.sync_changed.emit(sync)
	GameEvents.integrity_changed.emit(integrity)
	GameEvents.form_changed.emit(form)
	_emit_snapshot()


# --- 能力 --------------------------------------------------------------------

static func _all_abilities() -> Dictionary:
	var d := {}
	for id in ABILITIES:
		d[id] = true
	return d


func has_ability(id: String) -> bool:
	return abilities.has(id)


## 新解锁返回 true；已有或未知能力返回 false。
func unlock_ability(id: String) -> bool:
	if not id in ABILITIES:
		push_error("GameState: 未知能力 %s" % id)
		return false
	if abilities.has(id):
		return false
	abilities[id] = true
	GameEvents.ability_unlocked.emit(id)
	return true


## 安装零件：解锁它对应的全部能力；任一新解锁即返回 true。
func install_part(part_id: String) -> bool:
	if not PARTS.has(part_id):
		push_error("GameState: 未知零件 %s" % part_id)
		return false
	var any := false
	for id in PARTS[part_id]:
		if unlock_ability(id):
			any = true
	return any


func unlock_all_abilities() -> void:
	abilities = _all_abilities()


## 新游戏：没有能力、没有剧情标记，其余状态回到初值。
func begin_new_game() -> void:
	abilities = {}
	flags = {}
	reset()


# --- 序列化：存档边界在这里 ---------------------------------------------------

## 状态结构版本，和 SaveManager.SAVE_VERSION（文件格式版本）是两层东西。
## 这里的数字只在**字段含义变了**（不是加字段——加字段有 from_dict 的
## 逐字段兜底）时才 += 1，用于诊断"这个档的 state 是哪一代结构"。
const STATE_VERSION := 3

## 完整快照。包含 takeover_timer / sync_frozen 这类过程量，
## 所以"接管第 4 秒存档"读回来仍然是接管第 4 秒。
func to_dict() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"sync": sync,
		"integrity": integrity,
		"form": form,
		"is_takeover": is_takeover,
		"takeover_timer": takeover_timer,
		"sync_frozen": sync_frozen,
		"checkpoint": [checkpoint.x, checkpoint.y],
		"flags": flags.duplicate(true),
		"abilities": ABILITIES.filter(func(id): return abilities.has(id)),
	}


## 从快照还原。缺失字段用当前值兜底，不认识的字段忽略。
## state 的结构版本比当前新时只警告不拒绝 —— 字段缺失已有兜底，
## 拒绝会让"更新版本保存、退回旧版本读"变成不可用；文件级版本由
## SaveManager 把关（那边版本过新是硬拒）。
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	var state_ver := int(data.get("version", STATE_VERSION))
	if state_ver > STATE_VERSION:
		push_warning("GameState: 快照结构版本 %d 高于当前 %d，缺失字段按默认值处理"
			% [state_ver, STATE_VERSION])
	sync = float(data.get("sync", sync))
	integrity = float(data.get("integrity", integrity))
	form = int(data.get("form", form))
	is_takeover = bool(data.get("is_takeover", is_takeover))
	takeover_timer = float(data.get("takeover_timer", takeover_timer))
	sync_frozen = float(data.get("sync_frozen", sync_frozen))
	var cp: Variant = data.get("checkpoint", null)
	if cp is Array and (cp as Array).size() >= 2:
		checkpoint = Vector2(float(cp[0]), float(cp[1]))
	var f: Variant = data.get("flags", null)
	if f is Dictionary:
		flags = (f as Dictionary).duplicate(true)
	# v3 起才有 abilities；旧档没有这个字段 = 能力系统之前的存档，视为全部解锁。
	var ab: Variant = data.get("abilities", null)
	if ab is Array:
		abilities = {}
		for id in ab:
			if String(id) in ABILITIES:
				abilities[String(id)] = true
	else:
		abilities = _all_abilities()
	GameEvents.sync_changed.emit(sync)
	GameEvents.integrity_changed.emit(integrity)
	GameEvents.form_changed.emit(form)
	_emit_snapshot()


# --- 剧情标记 ----------------------------------------------------------------

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, fallback: Variant = null) -> Variant:
	return flags.get(key, fallback)


func has_flag(key: String) -> bool:
	return flags.has(key)
