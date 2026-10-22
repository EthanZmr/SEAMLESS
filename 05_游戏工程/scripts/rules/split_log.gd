class_name SplitLog
extends Node
## 分段计时：把关卡节拍事件写进会话日志（`--log` 运行时），试玩后按时间读节拍长度。
## 行格式：INFO SPLIT <秒> <事件> <细节>；秒从本节点进树开始算。

var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	GameEvents.level_loaded.connect(func(id: String) -> void: _split("level_loaded", id))
	GameEvents.checkpoint_reached.connect(func(p: Vector2) -> void: _split("checkpoint", "%d,%d" % [p.x, p.y]))
	GameEvents.ability_unlocked.connect(func(id: String) -> void: _split("ability_unlocked", id))
	GameEvents.arena_cleared.connect(func(id: String) -> void: _split("arena_cleared", id))
	GameEvents.player_died.connect(func() -> void: _split("player_died", ""))


func _split(what: String, detail: String) -> void:
	var t := float(Time.get_ticks_msec() - _t0) / 1000.0
	DebugLog.info("SPLIT", "%.1f %s %s" % [t, what, detail])
