class_name AttackFrames
extends Resource
## 单段攻击的帧数据（策划可编辑的唯一数据源）。
##
## 以前这些数值写死在 scripts/combat/attack_spec.gd 的 const 字典里，
## 改一个帧号要动代码、重跑测试、重新导出。现在挂在
## data/combat/light_frames.tres 上，在编辑器检查器里改数值即可生效。
##
## 帧号从 1 开始，按 60fps 逻辑帧计（第 N 帧 = 区间 [(N-1)/60, N/60)）。
## 帧号只用于动画与取消窗；判定与 hit-stop 用秒，两者通过 AttackSpec.frame_of() 对齐。
##
## ## 为什么默认值全是 0/false
## ResourceSaver 保存 Resource 时会省略“等于脚本默认值”的字段。如果默认值写成
## 真实配置（比如 total_frames = 12），导出的 .tres 里第一段会几乎空白，策划
## 打开看不到任何数值，也无法评审。所以这里所有默认值都是中性哨兵值，真实数值
## 必须显式写进 .tres；漏字段 → 加载后是 0 → validate() 报错 → 自动回退内置表，
## 不会静默用“看起来合理但其实是默认值”的数字。
##
## 可选字段（needle_* / pull_* / knockback / punch / attack_cd_after）只对特定段有意义，
## 其余段保持 0 即可。
## 生成/重置：godot --headless --path . -s res://tools/gen_data.gd -- --force

const FIELD_NAMES := [
	"total_frames",
	"startup_frames",
	"hit_frame",
	"hit_time",
	"freeze_ms",
	"recovery_start_frame",
	"hitbox_forward",
	"hitbox_vertical",
	"jump_cancel_start_frame",
	"jump_cancel_end_frame",
	"combo_input_start_frame",
	"whiff_frames",
	"needle_reach",
	"needle_body",
	"body_lean",
	"pull",
	"pull_min_gap",
	"pull_speed_cap",
	"knockback",
	"punch",
	"attack_cd_after",
]

@export_group("时长")
## 整段总帧数。
@export var total_frames: int = 0
## 起手帧数（1 到 startup_frames）。
@export var startup_frames: int = 0
## 判定发生帧。
@export var hit_frame: int = 0
## 判定发生时刻（秒），必须等于 COMBO_ACTIVE 对应段。
@export var hit_time: float = 0.0
## hit-stop 毫秒数，发生在 hit_frame 内。
@export var freeze_ms: int = 0
## 收手起始帧。
@export var recovery_start_frame: int = 0

@export_group("判定盒")
## 水平前伸像素（0 到该值）。
@export var hitbox_forward: float = 0.0
## 垂直半高像素（±该值）。
@export var hitbox_vertical: float = 0.0

@export_group("取消窗")
## 跳取消起始帧；0 表示该段不可跳取消（合法值）。
@export var jump_cancel_start_frame: int = 0
## 跳取消结束帧。
@export var jump_cancel_end_frame: int = 0
## 连段输入接受起始帧；0 表示该段之后没有连段（合法值）。
@export var combo_input_start_frame: int = 0
## 空挥时强制走完的帧数；0 表示不限制。
@export var whiff_frames: int = 0

@export_group("针（第一段专用）")
## 针尖伸出距离（前伸 + 针身）。
@export var needle_reach: float = 0.0
## 针身长度。
@export var needle_body: float = 0.0
## 躯干前倾的起止角度。
@export var body_lean: Array[float] = []

@export_group("拽（第二段专用）")
## 是否把敌人拉向玩家。
@export var pull: bool = false
## 玩家半宽 + 敌人半宽，防止穿模。
@export var pull_min_gap: float = 0.0
## 拉拽速度上限（取负方向）。
@export var pull_speed_cap: float = 0.0

@export_group("击退（第三段专用）")
## 击退初速度。
@export var knockback: float = 0.0
## 顿帧内推挤量。
@export var punch: float = 0.0
## 三段结束后的攻击冷却。
@export var attack_cd_after: float = 0.0


## 自检：返回问题描述列表，空数组表示这段帧表完整可用。
## 0 不在“错”里的字段（jump_cancel_* / combo_input_* / whiff_frames / 可选段字段）
## 是有语义的合法值，不参与校验。
func validate() -> Array[String]:
	var problems: Array[String] = []
	if total_frames < 1:
		problems.append("total_frames=%d（必须 >= 1）" % total_frames)
	if startup_frames < 1:
		problems.append("startup_frames=%d（必须 >= 1）" % startup_frames)
	if hit_frame < startup_frames or hit_frame > total_frames:
		problems.append("hit_frame=%d 不在 [%d, %d]" % [hit_frame, startup_frames, total_frames])
	if recovery_start_frame < hit_frame or recovery_start_frame > total_frames:
		problems.append("recovery_start_frame=%d 不在 [%d, %d]" % [
			recovery_start_frame, hit_frame, total_frames])
	if hit_time <= 0.0:
		problems.append("hit_time=%.3f（必须 > 0）" % hit_time)
	if freeze_ms < 0:
		problems.append("freeze_ms=%d（不能为负）" % freeze_ms)
	if hitbox_forward <= 0.0:
		problems.append("hitbox_forward=%.1f（必须 > 0）" % hitbox_forward)
	if hitbox_vertical <= 0.0:
		problems.append("hitbox_vertical=%.1f（必须 > 0）" % hitbox_vertical)
	if jump_cancel_start_frame > 0 and jump_cancel_end_frame < jump_cancel_start_frame:
		problems.append("跳取消窗反了：[%d, %d]" % [
			jump_cancel_start_frame, jump_cancel_end_frame])
	if whiff_frames < 0:
		problems.append("whiff_frames=%d（不能为负）" % whiff_frames)
	return problems


## 导出为字典。AttackSpec 的历史 API 一直返回 Dictionary，
## 保留这层转换可以让 player.gd 与既有测试一行不改。
func as_dict() -> Dictionary:
	return {
		"total_frames": total_frames,
		"startup_frames": startup_frames,
		"hit_frame": hit_frame,
		"hit_time": hit_time,
		"freeze_ms": freeze_ms,
		"recovery_start_frame": recovery_start_frame,
		"hitbox_forward": hitbox_forward,
		"hitbox_vertical": hitbox_vertical,
		"jump_cancel_start_frame": jump_cancel_start_frame,
		"jump_cancel_end_frame": jump_cancel_end_frame,
		"combo_input_start_frame": combo_input_start_frame,
		"whiff_frames": whiff_frames,
		"needle_reach": needle_reach,
		"needle_body": needle_body,
		"body_lean": body_lean.duplicate(),
		"pull": pull,
		"pull_min_gap": pull_min_gap,
		"pull_speed_cap": pull_speed_cap,
		"knockback": knockback,
		"punch": punch,
		"attack_cd_after": attack_cd_after,
	}
