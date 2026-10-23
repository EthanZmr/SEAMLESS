class_name FrameSet
extends Resource
## 一个逐帧动作的规格：去哪找图、几张、每张停几帧、画布与锚点（`03_美术/28` §3）。
## 引擎接入（PlayerFrames）、检查工具（check_frames）、预览场景共用这一份。
##
## 脚本默认值 = 跑步试点规格，资源文件缺失时照样能用。

@export var anim_name := "run"
@export var dir := "res://assets/characters/zhen/run"
@export var prefix := "char_zhen_run_"
@export var count := 8
## 每张停留的逻辑帧数（60 fps），长度必须等于 count。
@export var holds := PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
@export var loop := true
## 画布像素尺寸，所有张必须相同。
@export var canvas := Vector2i(768, 576)
## 锚点：x = 躯干中线，y = 着地张的脚底基线（最低不透明像素行）。
@export var anchor := Vector2i(384, 560)
## 腾空张（1 起），不检查基线。
@export var airborne := PackedInt32Array([4, 8])
@export var baseline_tolerance := 2
## 源稿 → 世界的缩放：512 px = 世界 64（`01_GDD/09`）。
@export var world_scale := 0.125


static func load_or_default(path: String) -> FrameSet:
	if ResourceLoader.exists(path):
		var res := load(path) as FrameSet
		if res != null and res.validate().is_empty():
			return res
		push_warning("FrameSet: %s 格式不正确，沿用内建默认值" % path)
	return FrameSet.new()


## 返回问题列表；空 = 合法。
func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	if count <= 0:
		errs.append("count 必须 > 0")
	if holds.size() != count:
		errs.append("holds 长度 %d ≠ count %d" % [holds.size(), count])
	for h in holds:
		if h <= 0:
			errs.append("holds 里有 ≤ 0 的停留帧数")
			break
	if canvas.x <= 0 or canvas.y <= 0:
		errs.append("canvas 尺寸非法")
	return errs


## 第 i 张（1 起）的文件路径。
func path_of(i: int) -> String:
	return "%s/%s%02d.png" % [dir, prefix, i]


func cycle_frames() -> int:
	var total := 0
	for h in holds:
		total += h
	return total


## 动作开始后第 tick 个逻辑帧该显示第几张（0 起）。不循环的动作停在最后一张。
func index_at(tick: int) -> int:
	var total := cycle_frames()
	var t := tick % total if loop else mini(tick, total - 1)
	for i in range(holds.size()):
		t -= holds[i]
		if t < 0:
			return i
	return holds.size() - 1


func is_airborne(i: int) -> bool:
	return i in airborne


## 锚点相对画布中心的偏移（源稿像素）。Sprite2D 居中绘制时，用它把锚点对到节点原点。
func anchor_from_center() -> Vector2:
	return Vector2(anchor) - Vector2(canvas) * 0.5
