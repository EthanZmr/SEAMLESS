class_name PlayerFrames
extends Sprite2D
## 玩家逐帧动画（D21：逐帧单张图；`03_美术/28` 跑步试点）。
##
## 只负责显示：player.gd 每个物理帧告诉它当前动作，它按 FrameSet 帧表切张
## （ADR-012：动画只跟随，不驱动判定或状态）。某个动作的图没放齐时整组不用，
## show_anim 返回 false，player.gd 退回 v4 静态占位图。

const SPECS := {"run": "res://data/anim/zhen_run.tres"}
const OUTLINE_SHADER := preload("res://assets/shaders/rim_outline.gdshader")

## 碰撞体脚底相对玩家原点的 y（碰撞 28×56 的半高）。
@export var foot_y := 28.0

var _sets: Dictionary = {}
var _textures: Dictionary = {}
var _current := ""
var _start_frame := 0


func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	material = mat
	visible = false
	for anim in SPECS:
		_load_anim(anim, FrameSet.load_or_default(SPECS[anim]))


## 图没放齐（试点出图前的正常状态）就整组不用，不报警。
func _load_anim(anim: String, spec: FrameSet) -> void:
	var list: Array[Texture2D] = []
	for i in range(1, spec.count + 1):
		var path := spec.path_of(i)
		if not ResourceLoader.exists(path):
			return
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("PlayerFrames: %s 读不出贴图，%s 动作改用占位图" % [path, anim])
			return
		list.append(tex)
	set_anim(anim, spec, list)


## 登记一个动作的帧。测试也用它直接塞贴图。
func set_anim(anim: String, spec: FrameSet, textures: Array[Texture2D]) -> void:
	if textures.size() != spec.count:
		push_warning("PlayerFrames: %s 有 %d 张图，规格要 %d 张" % [anim, textures.size(), spec.count])
		return
	_sets[anim] = spec
	_textures[anim] = textures


func has_anim(anim: String) -> bool:
	return _textures.has(anim)


## 显示 anim 的当前张；anim 为空或没图时隐藏并返回 false。
## 张号按"进入该动作后的物理帧数"算，同一物理帧里重复调用结果不变。
func show_anim(anim: String, facing: int, tint: Color, outline: Color) -> bool:
	if anim == "" or not _textures.has(anim):
		visible = false
		_current = ""
		return false
	var spec: FrameSet = _sets[anim]
	if anim != _current:
		_current = anim
		_start_frame = Engine.get_physics_frames()
	var tick := Engine.get_physics_frames() - _start_frame
	texture = _textures[anim][spec.index_at(tick)]
	var s := spec.world_scale
	var a := spec.anchor_from_center()
	# 锚点（躯干中线、脚底）对到玩家原点正下方的碰撞底；翻转时绕锚点翻。
	scale = Vector2(s * float(facing), s)
	position = Vector2(-a.x * s * float(facing), foot_y - a.y * s)
	modulate = tint
	(material as ShaderMaterial).set_shader_parameter("outline_color", outline)
	visible = true
	return true
