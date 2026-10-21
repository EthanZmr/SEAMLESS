extends Control
## HUD：只画，不认识玩家，也不认识敌人。
##
## 解耦约束（P1-3）：
##   · 状态数值来自 GameEvents.state_snapshot 的快照字典，不是每帧直接读单例；
##   · 调试面板的数值来自 GameEvents.debug_snapshot，payload 里全是原始标量，
##     HUD 不知道 Player 类存在，玩家改内部字段也不会带崩 HUD；
##   · 只在数据变了才重绘 —— 之前是 _process 里无条件 queue_redraw()，
##     等于每帧重排 12 段文字，白盒期看不出来，正式美术上来就是白白烧 GPU。

var font: Font
var message_text := ""
var message_timer := 0.0
var choice_active := false
var choice_result := ""
var banner_text := ""
var ending_text := ""

## 最近一次全局状态快照。空字典表示还没有 GameLoop 在跑（序章等场景）。
var _state: Dictionary = {}
## 最近一次调试快照。空字典表示玩家没开 DebugLog。
var _debug: Dictionary = {}
var _dirty := true

const INK := Color("#BFF7F0")
const DIM := Color("#6F8FA8")
const DANGER := Color("#FF6B6B")
const SYNC_LOW := Color("#3FE0D0")
const SYNC_HIGH := Color("#FF3E8A")
const GOLD := Color("#FFB13B")


func _ready() -> void:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	font = sys
	# 只订真正会改变画面的事件；sync/integrity/form 已经包含在 snapshot 里，
	# 不再各自单订一遍（之前那三个订阅只是 queue_redraw，而 _process 每帧都画）。
	GameEvents.state_snapshot.connect(_on_state_snapshot)
	GameEvents.debug_snapshot.connect(_on_debug_snapshot)
	GameEvents.message.connect(_on_message)
	GameEvents.parry_result.connect(_on_parry_result)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.boss_phase_changed.connect(_on_boss_phase)
	set_process(true)


func _process(delta: float) -> void:
	var needs_redraw := _dirty
	_dirty = false
	if message_timer > 0.0:
		message_timer -= delta
		needs_redraw = true
	if choice_active:
		if Input.is_action_just_pressed("choice_unpick"):
			_resolve_choice("unpick")
			needs_redraw = true
		elif Input.is_action_just_pressed("choice_stitch"):
			_resolve_choice("stitch")
			needs_redraw = true
	if ending_text != "" and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		needs_redraw = true
	# 接管倒计时是唯一需要逐帧刷新的数值（它每秒都在变）。
	if _takeover_active():
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _on_state_snapshot(payload: Dictionary) -> void:
	_state = payload
	_dirty = true


func _on_debug_snapshot(payload: Dictionary) -> void:
	_debug = payload
	_dirty = true


# --- 快照取值（缺失时回退到单例，保证序章/测试场景也显示正确） ----------------

func _num(key: String, fallback: float) -> float:
	if _state.has(key):
		return float(_state[key])
	return fallback


func _flag(key: String, fallback: bool) -> bool:
	if _state.has(key):
		return bool(_state[key])
	return fallback


func _takeover_active() -> bool:
	return _flag("is_takeover", GameState.is_takeover)


func _on_message(text: String) -> void:
	message_text = text
	message_timer = 3.2
	_dirty = true


func _on_parry_result(result: String, perfect: bool) -> void:
	if perfect:
		message_text = "完美弹反 · 她替你出手"
		message_timer = 1.6
	elif result == "normal":
		message_text = "弹反"
		message_timer = 1.0
	_dirty = true


func _on_boss_phase(phase: int) -> void:
	banner_text = "裁断者 · 第 %d 阶段" % phase
	message_text = banner_text
	message_timer = 2.0
	_dirty = true


func _on_boss_defeated() -> void:
	choice_active = true
	message_text = "裁断者：为什么……不拆？  U 拆 / I 缝"
	message_timer = 999.0
	_dirty = true


func _resolve_choice(choice: String) -> void:
	if not choice_active:
		return
	choice_active = false
	choice_result = choice
	GameEvents.choice_made.emit(choice)
	if choice == "unpick":
		message_text = "你拔掉了她的控制芯片。她死。只有一下。"
		ending_text = "切片结束 · 你拆了她\n\nR 重开雨市\n完整版会记住这一针。"
	else:
		message_text = "你把她的神经接回自主。她活着，但不记得你。"
		ending_text = "切片结束 · 你缝了她\n\nR 重开雨市\n完整版会记住这一针。"
	message_timer = 5.0
	_dirty = true


func _draw() -> void:
	if font == null:
		return
	var vp := size
	var integrity := _num("integrity", GameState.integrity)
	var sync_v := _num("sync", GameState.sync)
	var form := int(_num("form", float(GameState.form)))

	# Top-left status cluster
	draw_rect(Rect2(28, 28, 380, 118), Color(0.02, 0.04, 0.07, 0.72))
	draw_rect(Rect2(40, 44, 356, 22), Color("#2A1A1A"))
	var integ_w := 356.0 * clampf(integrity / 100.0, 0.0, 1.0)
	draw_rect(Rect2(40, 44, integ_w, 22), DANGER if integrity < 35.0 else Color("#B4472F"))
	draw_string(font, Vector2(42, 61), "完整度 %d" % int(integrity), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#F2EFE6"))

	draw_rect(Rect2(40, 78, 356, 16), Color("#10202E"))
	var sync_w := 356.0 * clampf(sync_v / 100.0, 0.0, 1.0)
	var sync_color := SYNC_HIGH if sync_v >= 70.0 else SYNC_LOW
	draw_rect(Rect2(40, 78, sync_w, 16), sync_color)
	draw_string(font, Vector2(42, 92), "同步率 %d" % int(sync_v), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#CFE9F2"))

	var form_text := "阿针 · 控场" if form == 0 else "阿绫 · 爆发"
	draw_string(font, Vector2(40, 124), form_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK if form == 0 else SYNC_HIGH)

	if _takeover_active():
		var timer_left := _num("takeover_timer", GameState.takeover_timer)
		draw_string(font, Vector2(40, 150), "接管中 %.1fs" % maxf(0.0, timer_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DANGER)

	# Controls hint
	draw_string(font, Vector2(vp.x - 460, 40), "A/D 移动  Space 跳/二段  J 攻击", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DIM)
	draw_string(font, Vector2(vp.x - 460, 62), "K 弹反  L 换人  U 缝  Shift 冲刺", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DIM)

	_draw_debug(vp)

	# Message
	if message_timer > 0.0 and message_text != "":
		var tw := font.get_string_size(message_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var pos := Vector2((vp.x - tw) * 0.5, vp.y - 54.0)
		draw_rect(Rect2(pos.x - 26, pos.y - 26, tw + 32, 38), Color(0.02, 0.04, 0.07, 0.66))
		draw_string(font, pos, message_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD)

	# Choice panel
	if choice_active:
		var panel := Rect2(vp.x * 0.5 - 320, vp.y * 0.5 - 90, 640, 180)
		draw_rect(panel, Color(0.02, 0.04, 0.07, 0.86))
		draw_rect(panel, GOLD, false, 2.0)
		draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 46), "她也是补丁。", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#F2EFE6"))
		draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 88), "U  拆：拔掉控制芯片。她死。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#FF8FB0"))
		draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 120), "I  缝：接回自主神经。她活，但失忆。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#7FE7FF"))
		draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 154), "没有第三种。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)

	# Ending card
	if ending_text != "":
		var card := Rect2(vp.x * 0.5 - 360, vp.y * 0.32, 720, 300)
		draw_rect(card, Color(0.02, 0.04, 0.07, 0.9))
		draw_rect(card, GOLD, false, 2.0)
		var lines := ending_text.split("\n")
		for i in range(lines.size()):
			var line_size := 30 if i == 0 else 22
			var line_color := GOLD if i == 0 else Color("#CFE9F2")
			draw_string(font, Vector2(card.position.x + 32, card.position.y + 62 + i * 44), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, line_color)


## 调试面板：只吃 debug_snapshot 里的标量，不认识 Player。
func _draw_debug(vp: Vector2) -> void:
	if not DebugLog.enabled or _debug.is_empty():
		return
	var box := Rect2(vp.x - 460, 78, 430, 104)
	draw_rect(box, Color(0.02, 0.04, 0.07, 0.78))
	draw_rect(box, Color("#3FE0D0"), false, 1.0)
	draw_string(font, box.position + Vector2(10, 18), "DEBUG · player trace", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	draw_string(font, box.position + Vector2(10, 38), "STATE %s   VEL %.0f,%.0f   DOUBLE %s" % [
		str(_debug.get("state", "?")),
		float(_debug.get("vel_x", 0.0)),
		float(_debug.get("vel_y", 0.0)),
		"YES" if bool(_debug.get("double_jump", false)) else "NO",
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F2EFE6"))
	draw_string(font, box.position + Vector2(10, 56), "LOCK %.3f  CHARGE %d  HOOK %s  DIST %.0f" % [
		float(_debug.get("hook_lock", 0.0)),
		int(_debug.get("hook_charge", 0)),
		"YES" if bool(_debug.get("hooked", false)) else "NO",
		float(_debug.get("hook_dist", 0.0)),
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F2EFE6"))
	draw_string(font, box.position + Vector2(10, 74), "BUF JUMP %d  BUF HOOK %d" % [
		int(_debug.get("buf_jump", 0)),
		int(_debug.get("buf_hook", 0)),
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	draw_string(font, box.position + Vector2(10, 92), str(_debug.get("log_hint", "日志: user://hook_debug.log")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
