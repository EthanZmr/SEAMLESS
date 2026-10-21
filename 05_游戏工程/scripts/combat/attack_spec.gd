class_name AttackSpec
extends RefCounted
## 轻击三段「刺—拉—钉」帧表（设计定稿 v8 的代码 SOT）。
##
## 帧号从 1 开始，按 60fps 逻辑帧计（第 N 帧 = 区间 [(N-1)/60, N/60)）。
## 帧号只用于动画与取消窗；判定与 hit-stop 用秒，两者通过 frame_of() 对齐。
##
## ## 数据来源（W7 重构）
## 数值已经搬到 data/combat/light_frames.tres，策划在编辑器里改数值即可。
## 本文件只负责读表、换算和供全体系统调用；下面的 LIGHT1/2/3 内置字典是
## 兜底默认值 —— 只有在 .tres 缺失或读取失败时才会用到，正常运行时由数据源覆盖。
## data_source 会告诉你当前用的是什么： "resource" = 读到了 .tres， "builtin" = 走兜底。
##
## 对应文档：
##   03_美术/24_轻击第一段生产规格_v1.0.md
##   03_美术/23_轻击第一段V8评审_v1.0.md
## 对应代码：scripts/player/player.gd 的 ATTACK 分支
## 测试：godot --headless --path . -s res://tests/test_attack_spec.gd

const FPS := 60.0
## 帧起点判定的 epsilon：8/60 这类边界在浮点里会掉到 7.9999，
## 加一点余量让 int() 落在正确的帧号上。
const FRAME_EPS := 0.0001

## 数据源路径。
const FRAMES_PATH := "res://data/combat/light_frames.tres"

## 当前生效的数据来源："resource" 或 "builtin"。
static var data_source := "builtin"

# --- 兜底默认值（正常运行时被 .tres 覆盖，改数值请改数据文件） ---

static var LIGHT1 := {
	"total_frames": 12,
	"startup_frames": 3,          # 1-3f 起手
	"hit_frame": 4,               # 判定发生帧（0.060s）
	"hit_time": 0.06,             # = COMBO_ACTIVE[0]
	"freeze_ms": 75,              # hit-stop，发生在 4f 内
	"recovery_start_frame": 6,    # 6f 才开始收手；5f 定格尾保持 4f 姿势
	"hitbox_forward": 84.0,       # 水平 0-84px（= COMBO_RANGE[0]）
	"hitbox_vertical": 62.0,      # 垂直 ±62px
	"needle_reach": 79.0,         # 针尖伸出（42 前伸 + 37 针身）
	"needle_body": 37.0,
	"body_lean": [12.0, 16.0],    # 躯干前倾
	"jump_cancel_start_frame": 5, # 命中后 5f 起可跳取消
	"jump_cancel_end_frame": 8,   # 最晚 8f（9f 起不可跳取消）
	"combo_input_start_frame": 9, # 9f 起接受连段输入（排队）
	"whiff_frames": 12,           # 空挥不可跳、不可连段，走完 12f
}

static var LIGHT2 := {
	"total_frames": 13,           # 0.2167s；代码 0.22s，动画慢放约 1.5% 对齐
	"startup_frames": 4,          # 1-4f 反手缠线、后坐
	"hit_frame": 5,               # 判定发生帧（0.070s）
	"hit_time": 0.07,             # = COMBO_ACTIVE[1]
	"freeze_ms": 105,             # hit-stop
	"recovery_start_frame": 6,    # 6-12f 回位，13f 收招
	"hitbox_forward": 88.0,       # = COMBO_RANGE[1]
	"hitbox_vertical": 62.0,
	"pull": true,                 # 二段「拽」：把敌人拉向玩家
	"pull_min_gap": 28.0,         # 玩家半宽 14 + 敌人半宽 14，防止穿模
	"pull_speed_cap": 160.0,      # = COMBO_KNOCKBACK[1]，方向取负
	"jump_cancel_start_frame": 6, # 命中帧 5f 之后：6-9f
	"jump_cancel_end_frame": 9,
	"combo_input_start_frame": 10, # 10f 起接受三段输入（排队）
}

static var LIGHT3 := {
	"total_frames": 18,           # 0.30s，整数帧
	"startup_frames": 5,          # 1f 起手过渡 + 2-5f 蓄力（前冲）
	"hit_frame": 6,               # 判定发生帧（0.090s）
	"hit_time": 0.09,             # = COMBO_ACTIVE[2]
	"freeze_ms": 160,             # hit-stop
	"recovery_start_frame": 7,    # 7-12f 收紧、13-17f 击退、18f 收招
	"hitbox_forward": 100.0,      # = COMBO_RANGE[2]
	"hitbox_vertical": 62.0,
	"knockback": 320.0,           # 320^2/(2*900) = 56.9px
	"punch": 0.055,
	"attack_cd_after": 0.30,      # 三段结束后的攻击冷却
	"jump_cancel_start_frame": 0, # 终结技不可取消（0 = 关闭）
	"jump_cancel_end_frame": 0,
	"combo_input_start_frame": 0,
}


static func _static_init() -> void:
	reload_frames()


## 从 .tres 重新读表。失败时保留内置兜底值，绝不抛错。
## 返回 true 表示数据源生效。
static func reload_frames() -> bool:
	if not ResourceLoader.exists(FRAMES_PATH):
		data_source = "builtin"
		return false
	var set_res: Variant = load(FRAMES_PATH)
	if set_res == null:
		data_source = "builtin"
		return false

	var loaded := {"light1": LIGHT1, "light2": LIGHT2, "light3": LIGHT3}
	for key in loaded:
		var frames: Variant = set_res.get(key)
		if frames == null or not frames.has_method("as_dict"):
			data_source = "builtin"
			return false
		# 数据文件里漏字段时，字段会保持 AttackFrames 的中性默认值（0/false），
		# validate() 会把它抓出来 —— 宁可回退内置表，也不静默用 0 帧去打人。
		if frames.has_method("validate"):
			var problems: Array = frames.validate()
			if not problems.is_empty():
				push_warning("AttackSpec: %s 的 %s 不完整，回退内置帧表：%s" % [
					FRAMES_PATH, key, ", ".join(problems)])
				data_source = "builtin"
				return false
		loaded[key] = frames.as_dict()

	LIGHT1 = loaded["light1"]
	LIGHT2 = loaded["light2"]
	LIGHT3 = loaded["light3"]
	data_source = "resource"
	return true


## 二段「拽」的落点速度：把敌人拉到 pull_min_gap 就停。
## 位移 s 由 v²/(2*900) 反解，v = sqrt(1800*s)；cap 到 COMBO_KNOCKBACK[1]。
static func pull_speed(distance: float) -> float:
	var room := maxf(0.0, absf(distance) - float(LIGHT2.pull_min_gap))
	return -minf(float(LIGHT2.pull_speed_cap), sqrt(1800.0 * room))


static func frame_of(elapsed: float) -> int:
	## 攻击内已用时间 → 帧号（1 起）。负时间钳到第 1 帧。
	return int(floor(maxf(elapsed, 0.0) * FPS + FRAME_EPS)) + 1


static func elapsed_of_frame(frame: int) -> float:
	## 帧号 → 该帧起点秒数（用于测试与文档换算）。
	return float(maxi(frame - 1, 0)) / FPS


static func jump_cancel_window(elapsed: float) -> bool:
	var f := frame_of(elapsed)
	return f >= int(LIGHT1.jump_cancel_start_frame) and f <= int(LIGHT1.jump_cancel_end_frame)


static func combo_input_allowed(elapsed: float) -> bool:
	return frame_of(elapsed) >= int(LIGHT1.combo_input_start_frame)


static func spec_of(index: int) -> Dictionary:
	## 按段取帧表。越界钳到 0-2，避免动画/测试传错段号时静默用错窗口。
	match clampi(index, 0, 2):
		1:
			return LIGHT2
		2:
			return LIGHT3
		_:
			return LIGHT1


static func jump_cancel_window_at(index: int, elapsed: float) -> bool:
	## 按段的跳取消窗。start <= 0 表示该段不可取消（三段）。
	var spec := spec_of(index)
	var start := int(spec.get("jump_cancel_start_frame", 0))
	var stop := int(spec.get("jump_cancel_end_frame", 0))
	if start <= 0 or stop < start:
		return false
	var f := frame_of(elapsed)
	return f >= start and f <= stop


static func combo_input_allowed_at(index: int, elapsed: float) -> bool:
	## 按段的连段输入窗。start <= 0 表示该段之后没有连段（三段）。
	var start := int(spec_of(index).get("combo_input_start_frame", 0))
	if start <= 0:
		return false
	return frame_of(elapsed) >= start


static func is_hit_frame(elapsed: float) -> bool:
	return frame_of(elapsed) == int(LIGHT1.hit_frame)


static func freeze_end_time() -> float:
	## 4f 起点 0.050s + 名义一帧 0.0167s + 冻结 0.075s = 0.1417s
	## 即 4f 真实持续 50-141.7ms、91.7ms；5f 从 0.1417s 开始。
	return elapsed_of_frame(int(LIGHT1.hit_frame)) + 1.0 / FPS + float(LIGHT1.freeze_ms) / 1000.0
