class_name PlayerStats
extends Resource
## Tunable player numbers, externalised from player.gd.
##
## Player.gd keeps the original literals as member defaults so the game runs
## even when this resource is missing; `Player._apply_stats()` overwrites them
## from `data/player/player_stats.tres` when present. Field names MUST stay
## identical to the Player member names — `apply_to()` writes by name.

const PATH := "res://data/player/player_stats.tres"

@export_group("Locomotion")
@export var SPEED: float = 220.0
@export var LING_SPEED_MULT: float = 1.2
@export var ACCEL: float = 1800.0
@export var FRICTION: float = 2200.0
@export var AIR_ACCEL: float = 1200.0
@export var JUMP_VELOCITY: float = -600.0
@export var GRAVITY: float = 1400.0
@export var MAX_FALL: float = 820.0
@export var COYOTE_TIME: float = 0.10
@export var JUMP_BUFFER: float = 0.12
## 上升中松开跳键，竖直速度截到这个值（决定小跳高度）
@export var JUMP_CUT_VELOCITY: float = -150.0

@export_group("Dash")
@export var DASH_SPEED: float = 560.0
@export var DASH_TIME: float = 0.16
@export var DASH_COOLDOWN: float = 0.35

@export_group("Ground attack")
@export var ATTACK_TIME: float = 0.22
@export var ATTACK_ACTIVE: float = 0.06
@export var ATTACK_COOLDOWN: float = 0.30
@export var ATTACK_RANGE: float = 84.0

@export_group("Combo")
@export var COMBO_TIMES: Array[float] = [0.20, 0.22, 0.30]
@export var COMBO_ACTIVE: Array[float] = [0.06, 0.07, 0.09]
@export var COMBO_DAMAGE: Array[float] = [10.0, 12.0, 20.0]
@export var COMBO_RANGE: Array[float] = [84.0, 88.0, 100.0]
@export var COMBO_KNOCKBACK: Array[float] = [120.0, 160.0, 320.0]
@export var COMBO_QUEUE_WINDOW: float = 0.16
@export var COMBO_GRACE: float = 0.40

@export_group("Launcher and air attack")
@export var LAUNCH_TIME: float = 0.28
@export var LAUNCH_ACTIVE: float = 0.07
@export var LAUNCH_DAMAGE: float = 7.0
@export var LAUNCH_RANGE: float = 76.0
@export var LAUNCH_FORCE: float = 520.0
@export var AIR_ATTACK_TIME: float = 0.20
@export var AIR_ATTACK_ACTIVE: float = 0.05
@export var AIR_ATTACK_DAMAGE: float = 9.0
@export var AIR_ATTACK_RANGE: float = 78.0
@export var AIR_ATTACK_BUFFER: float = 0.35

@export_group("Parry and stitch")
@export var PARRY_ACTIVE: float = CombatMath.ACTIVE_WINDOW
@export var PARRY_RECOVERY: float = CombatMath.RECOVERY_WINDOW
@export var PARRY_COOLDOWN: float = CombatMath.COOLDOWN
@export var INVULN_TIME: float = 0.80
@export var HURT_TIME: float = 0.28
@export var STITCH_RANGE: float = 90.0
@export var STITCH_COOLDOWN: float = 0.80

@export_group("Climb and wall")
@export var CLIMB_SPEED: float = 132.0
## 抓住梯缝后横向吸附到中线的最大速度（梯缝宽 26、感应框宽 44，最远偏 35px，约 0.1s 到位）
@export var CLIMB_SNAP_SPEED: float = 360.0
@export var CLIMB_JUMP_VERTICAL: float = -560.0
@export var CLIMB_JUMP_HORIZONTAL: float = 240.0
@export var WALL_SLIDE_SPEED: float = 150.0
@export var WALL_JUMP_HORIZONTAL: float = 600.0
@export var WALL_JUMP_VERTICAL: float = -560.0
@export var WALL_JUMP_LOCK: float = 0.10
@export var CLIMB_JUMP_LOCK: float = 0.22

@export_group("Air jump and ledge")
@export var DOUBLE_JUMP_VERTICAL: float = -540.0
@export var LEDGE_COOLDOWN: float = 0.28
@export var LEDGE_VAULT_HORIZONTAL: float = 240.0
@export var LEDGE_VAULT_VERTICAL: float = -430.0
@export var LEDGE_PROBE_FORWARD: float = 20.0
@export var LEDGE_PROBE_ABOVE: float = 26.0
## 抓边时按下，往下松手的初速度
@export var LEDGE_DROP_SPEED: float = 140.0

@export_group("Seam hook")
@export var HOOK_RANGE: float = 320.0
@export var HOOK_SPEED: float = 680.0
@export var HOOK_ARRIVE: float = 30.0
@export var HOOK_JUMP_LOCK: float = 0.08
@export var HOOK_FREE_JUMP_TIME: float = 0.45
## 钩索拉近途中按跳：竖直初速度、保留的水平速度比例
@export var HOOK_JUMP_VERTICAL: float = -520.0
@export var HOOK_JUMP_X_KEEP: float = 0.25
## 没到钩点就脱离（松开 H / 撞墙）时保留的速度比例
@export var HOOK_DETACH_KEEP: float = 0.35

const FIELD_NAMES := [
	"SPEED", "LING_SPEED_MULT", "ACCEL", "FRICTION", "AIR_ACCEL",
	"JUMP_VELOCITY", "GRAVITY", "MAX_FALL", "COYOTE_TIME", "JUMP_BUFFER", "JUMP_CUT_VELOCITY",
	"DASH_SPEED", "DASH_TIME", "DASH_COOLDOWN",
	"ATTACK_TIME", "ATTACK_ACTIVE", "ATTACK_COOLDOWN", "ATTACK_RANGE",
	"COMBO_TIMES", "COMBO_ACTIVE", "COMBO_DAMAGE", "COMBO_RANGE",
	"COMBO_KNOCKBACK", "COMBO_QUEUE_WINDOW", "COMBO_GRACE",
	"LAUNCH_TIME", "LAUNCH_ACTIVE", "LAUNCH_DAMAGE", "LAUNCH_RANGE", "LAUNCH_FORCE",
	"AIR_ATTACK_TIME", "AIR_ATTACK_ACTIVE", "AIR_ATTACK_DAMAGE",
	"AIR_ATTACK_RANGE", "AIR_ATTACK_BUFFER",
	"PARRY_ACTIVE", "PARRY_RECOVERY", "PARRY_COOLDOWN", "INVULN_TIME", "HURT_TIME",
	"STITCH_RANGE", "STITCH_COOLDOWN",
	"CLIMB_SPEED", "CLIMB_SNAP_SPEED", "CLIMB_JUMP_VERTICAL", "CLIMB_JUMP_HORIZONTAL",
	"WALL_SLIDE_SPEED", "WALL_JUMP_HORIZONTAL", "WALL_JUMP_VERTICAL",
	"WALL_JUMP_LOCK", "CLIMB_JUMP_LOCK",
	"DOUBLE_JUMP_VERTICAL", "LEDGE_COOLDOWN", "LEDGE_VAULT_HORIZONTAL",
	"LEDGE_VAULT_VERTICAL", "LEDGE_PROBE_FORWARD", "LEDGE_PROBE_ABOVE", "LEDGE_DROP_SPEED",
	"HOOK_RANGE", "HOOK_SPEED", "HOOK_ARRIVE", "HOOK_JUMP_LOCK",
	"HOOK_FREE_JUMP_TIME", "HOOK_JUMP_VERTICAL", "HOOK_JUMP_X_KEEP", "HOOK_DETACH_KEEP",
]


## 把本资源的所有字段按名字写到目标对象上。返回成功写入的字段数。
func apply_to(target: Object) -> int:
	if target == null:
		return 0
	var applied := 0
	for field_name in FIELD_NAMES:
		if not _has_property(target, field_name):
			continue
		target.set(field_name, get(field_name))
		applied += 1
	return applied


## 目标对象缺少哪些字段（用于发现 Player 改名后的漂移）。
func missing_fields(target: Object) -> Array[String]:
	var out: Array[String] = []
	if target == null:
		return out
	for field_name in FIELD_NAMES:
		if not _has_property(target, field_name):
			out.append(field_name)
	return out


func as_dict() -> Dictionary:
	var out := {}
	for field_name in FIELD_NAMES:
		out[field_name] = get(field_name)
	return out


static func _has_property(target: Object, field_name: String) -> bool:
	for info in target.get_property_list():
		if info.get("name", "") == field_name:
			return true
	return false


## 读取外部数据文件；失败时返回 null，由调用方保留内建默认值。
static func load_from(path: String = PATH) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res == null or not res.has_method("apply_to"):
		push_warning("PlayerStats: %s 格式不正确，沿用内建默认值" % path)
		return null
	return res
