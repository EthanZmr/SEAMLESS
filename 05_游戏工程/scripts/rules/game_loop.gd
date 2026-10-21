class_name GameLoop
extends Node
## 时间推进器：唯一调用 SyncRules.tick() 的地方，也是唯一的暂停开关。
##
## 责任边界：
##   · 持有当前规则资源（可换 .tres 做难度/手感变体）；
##   · 每帧推进一帧；
##   · 暂停时不推进 —— 并且真正把整棵场景树冻住（get_tree().paused）。
##
## 为什么暂停放在这里而不是 autoload：
##   暂停是"这一局游戏"的概念，不是"这个程序"的概念。序章没有暂停，
##   测试场景不该被一个全局开关影响。它挂在 main.tscn 上，天然只覆盖一局。
##
## 为什么 process_mode = ALWAYS：
##   暂停时 _process 会被引擎停掉，那样这一帧就收不到"取消暂停"的输入。
##   设成 ALWAYS 后 _process 照跑，靠 paused 标志自己决定要不要推进规则 ——
##   既保住了输入，又不会在暂停时偷偷走时间。
##
## 为什么不用 Engine.time_scale 做暂停：
##   顿帧（HitStop）已经在用 time_scale，两套东西叠在一起会互相覆盖。
##   time_scale 管"这一瞬间的慢动作"，get_tree().paused 管"整局停住"。

@export var rules_path := "res://data/rules/sync_rules.tres"

## 当前规则。始终非 null；文件缺失时用内建默认值。
var rules: Resource
## "resource" = 已从 .tres 加载；"builtin" = 用脚本默认值；"override" = 运行时换过。
var rules_source := "builtin"
var paused := false


func _ready() -> void:
	# 暂停后仍要收输入，否则按不出取消暂停。
	process_mode = Node.PROCESS_MODE_ALWAYS
	rules = _load_rules()
	rules.apply_to(GameState)
	set_process(true)
	GameEvents.pause_changed.connect(_on_pause_changed)


func _load_rules() -> Resource:
	var res: Resource = SyncRules.load_from(rules_path)
	if res == null:
		rules_source = "builtin"
		return SyncRules.new()
	rules_source = "resource"
	return res


## 换规则（例如进 Boss 房降速）。会立刻把新边界注入 GameState。
func set_rules(new_rules: Resource) -> void:
	if new_rules == null or not new_rules.has_method("tick"):
		return
	rules = new_rules
	rules_source = "override"
	rules.apply_to(GameState)


func _process(delta: float) -> void:
	# 暂停时 _process 仍在跑（PROCESS_MODE_ALWAYS），所以这里必须自己拦。
	if paused or rules == null:
		return
	rules.tick(GameState, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	set_paused(not paused)
	get_viewport().set_input_as_handled()


## 暂停/恢复的唯一入口。会同步整棵场景树，并广播 pause_changed。
func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value
	GameEvents.pause_changed.emit(value)
	if value:
		GameEvents.message.emit("已暂停 · ESC 继续")


## 给 UI 按钮用：直接切。
func toggle_pause() -> void:
	set_paused(not paused)


## 监听外部（例如菜单）发的暂停请求，避免 UI 和 GameLoop 各存一份标志。
func _on_pause_changed(value: bool) -> void:
	if paused == value:
		return
	paused = value
	get_tree().paused = value


func _exit_tree() -> void:
	# 退出这一局时别把整棵树留在暂停态。
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
