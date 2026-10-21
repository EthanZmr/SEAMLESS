class_name SyncRules
extends Resource
## 同步率 / 完整度 / 接管 的**数值规则**。
##
## 设计边界（P0-2 架构改造）：
##   · GameState 只存值，不决定值怎么变；
##   · 这里决定"每帧变多少"，不持有任何可变状态；
##   · GameLoop 是唯一的时间推进者，调用 tick()。
##
## 好处：换一份 .tres 就是换难度/换角色手感；不开引擎也能单测规则；
## 存档时 GameState.to_dict() 拿到的是一份完整快照，不依赖这个类。

## 同步率上限/下限。
@export var max_sync := 100.0
@export var min_sync := 0.0
## 完整度上限。
@export var max_integrity := 100.0

## 接管持续时长（秒）。
@export var takeover_duration := 8.0
## 接管结束时同步率被压回的值。
@export var takeover_exit_sync := 50.0
## 接管结束时代价（完整度）。
@export var takeover_integrity_cost := 20.0

## A-Zhen 每秒同步率变化（负 = 沉降）。
@export var zhen_sync_rate := -2.0
## A-Ling 每秒同步率变化（正 = 攀升）。
@export var ling_sync_rate := 4.0
## A-Zhen 形态每秒完整度回复。
@export var zhen_regen_rate := 1.0

const PATH := "res://data/rules/sync_rules.tres"

## 与 data/rules/sync_rules.tres 逐字段对应，生成器与测试共用。
const FIELD_NAMES: Array[String] = [
	"max_sync",
	"min_sync",
	"max_integrity",
	"takeover_duration",
	"takeover_exit_sync",
	"takeover_integrity_cost",
	"zhen_sync_rate",
	"ling_sync_rate",
	"zhen_regen_rate",
]


## 把边界值注入 GameState（GameState 自己不知道"上限是多少"）。
func apply_to(state: Variant) -> void:
	if state == null:
		return
	state.set("MAX_SYNC", max_sync)
	state.set("MIN_SYNC", min_sync)
	state.set("MAX_INTEGRITY", max_integrity)
	state.set("TAKEOVER_DURATION", takeover_duration)
	state.set("TAKEOVER_EXIT_SYNC", takeover_exit_sync)
	state.set("TAKEOVER_INTEGRITY_COST", takeover_integrity_cost)


## 推进一帧。只读写 state 的字段，不改规则自身。
## 参数用 Variant：允许传 GameState 单例，也允许传测试里的替身。
func tick(state: Variant, delta: float) -> void:
	if state == null or delta <= 0.0:
		return

	if state.sync_frozen > 0.0:
		state.sync_frozen = maxf(0.0, state.sync_frozen - delta)

	if state.is_takeover:
		state.takeover_timer -= delta
		if state.takeover_timer <= 0.0:
			state.end_takeover()
		return

	if state.sync_frozen <= 0.0:
		var rate: float = zhen_sync_rate if state.form == 0 else ling_sync_rate
		state.add_sync(rate * delta)

	if state.form == 0 and state.integrity < max_integrity:
		state.integrity = minf(max_integrity, state.integrity + zhen_regen_rate * delta)
		state.emit_integrity()


func as_dict() -> Dictionary:
	var out := {}
	for field_name in FIELD_NAMES:
		out[field_name] = get(field_name)
	return out


## 校验规则自身是否自洽。返回问题列表（空 = 通过）。
func validate() -> Array[String]:
	var problems: Array[String] = []
	if max_sync <= min_sync:
		problems.append("max_sync 必须大于 min_sync")
	if max_integrity <= 0.0:
		problems.append("max_integrity 必须为正")
	if takeover_duration <= 0.0:
		problems.append("takeover_duration 必须为正")
	if takeover_exit_sync < min_sync or takeover_exit_sync > max_sync:
		problems.append("takeover_exit_sync 必须落在 [min_sync, max_sync] 内")
	if takeover_integrity_cost < 0.0:
		problems.append("takeover_integrity_cost 不能为负")
	if zhen_regen_rate < 0.0:
		problems.append("zhen_regen_rate 不能为负")
	return problems


## 读取规则文件；缺失或损坏时返回 null，调用方决定回退策略。
static func load_from(path: String = PATH) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res == null or not res.has_method("tick"):
		push_warning("SyncRules 加载失败：%s" % path)
		return null
	var problems: Array = res.call("validate")
	if not problems.is_empty():
		push_warning("SyncRules 校验失败 %s：%s" % [path, str(problems)])
		return null
	return res
