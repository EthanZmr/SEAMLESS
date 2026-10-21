extends Node
## 全局时间缩放栈（P1-2）。
##
## 之前是"设 0.08 → 等 50ms → 设 1.0"。单个顿帧没问题，但一旦有两个来源
## 同时想要慢动作（顿帧 + Boss 死亡演出 + 过场镜头），后结束的那个会把
## Engine.time_scale 硬写回 1.0，把还在跑的另一个效果一起抹掉。
##
## 现在改成栈：每个效果压一条 {id, scale}，实际 time_scale 取栈中最慢的一条；
## 谁结束谁就 pop 自己那条，剩下的自然接管。没有效果时回到 base_scale。
##
## 保留的两个原有语义：
##   · _generation 防重入 —— await 恢复时如果已被别人接管就什么都不做；
##   · 同一时刻只允许一次顿帧 —— 连击第二下不该把第一下的窗口重置。
##
## 暂停不在这里实现：暂停是 get_tree().paused，time_scale 只管"慢动作"。
## 两套东西分开，才不会出现"暂停取消后时间还是 0.1 倍"的经典 bug。

var enabled := true
## 正常速度。想整体做慢镜头演出时改这个，而不是改每个效果。
var base_scale := 1.0

var _stack: Array[Dictionary] = []
var _generation := 0
var _start_msec := 0
## 当前顿帧的栈 id；空串表示没有顿帧在跑。
var _active_id := ""


func _ready() -> void:
	# headless 下不做时间缩放，测试才是确定的。
	enabled = DisplayServer.get_name() != "headless"


# --- 栈操作 -------------------------------------------------------------------

## 压入一个缩放效果。同名 id 会更新而不是叠加两条。
func push_scale(id: String, scale: float) -> void:
	var s := clampf(scale, 0.01, 1.0)
	for entry in _stack:
		if str(entry.get("id", "")) == id:
			entry["scale"] = s
			_apply()
			return
	_stack.append({"id": id, "scale": s})
	_apply()


## 弹出指定 id 的效果。不存在时静默返回（重复 pop 是安全的）。
func pop_scale(id: String) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if str(_stack[i].get("id", "")) == id:
			_stack.remove_at(i)
			_apply()
			return


## 清空所有效果并回到基准速度。
func clear_scales() -> void:
	_stack.clear()
	_apply()


## 当前实际生效的缩放：栈里最慢的那条，没有就用 base_scale。
func current_scale() -> float:
	var slowest := base_scale
	for entry in _stack:
		slowest = minf(slowest, float(entry.get("scale", 1.0)))
	return slowest


func stack_size() -> int:
	return _stack.size()


func is_active() -> bool:
	return _active_id != ""


func _apply() -> void:
	Engine.time_scale = current_scale()


# --- 顿帧（原有接口） ---------------------------------------------------------

func stop(duration: float = 0.05, scale: float = 0.08) -> void:
	if not enabled or duration <= 0.0:
		return
	# 同一时刻只允许一次顿帧，否则三连的最后一下会把前面两下串成一整段长冻。
	if _active_id != "":
		return
	_generation += 1
	var generation := _generation
	var id := "hitstop_%d" % generation
	_active_id = id
	_start_msec = Time.get_ticks_msec()
	push_scale(id, scale)
	# ignore_time_scale=true：计时器必须在世界被冻住时照常走。
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation != _generation:
		return
	pop_scale(id)
	_active_id = ""
	# 冻结吃掉了真实时间，缓冲区里的按键要补回这段寿命。
	InputBuffer.add_age_grace(int(duration * 1000.0))


func _input(event: InputEvent) -> void:
	# 别让跳跃感觉迟钝：冻结期间按跳，立刻解冻让缓冲按键跑出去。
	if _active_id != "" and event.is_action_pressed("jump") and not event.is_echo():
		skip()


func skip() -> void:
	if _active_id == "":
		return
	_generation += 1
	var elapsed := Time.get_ticks_msec() - _start_msec
	var id := _active_id
	_active_id = ""
	pop_scale(id)
	InputBuffer.add_age_grace(elapsed)


func reset() -> void:
	_generation += 1
	_active_id = ""
	_stack.clear()
	_apply()


func _exit_tree() -> void:
	reset()
