extends Camera2D
## Follow camera with smooth damping, look-ahead, and a shake hook.

@export var target_path: NodePath
@export var smoothing := 8.0
@export var look_ahead := 60.0
@export var vertical_offset := -40.0
@export var shake_decay := 2.4
@export var shake_max_offset := Vector2(16.0, 10.0)
@export var shake_max_roll := 0.06
## 基础缩放：世界高 64 的角色在 1920×1080 内部分辨率下显示 128px（尺度约定见 01_GDD/09）。
@export var base_zoom := 2.0

var target: Node2D
var trauma := 0.0
var _shake_time := 0.0
var punch_strength := 0.0


func _ready() -> void:
	if target_path != NodePath():
		target = get_node_or_null(target_path)
	if target == null:
		target = get_parent().get_node_or_null("Player")
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var facing_value: Variant = target.get("facing")
	var look := 0.0
	if facing_value != null:
		look = float(facing_value) * look_ahead
	var desired := target.global_position + Vector2(look, vertical_offset)
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
	_shake_time += delta
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	if trauma > 0.0:
		var amount := trauma * trauma
		offset = Vector2(
			sin(_shake_time * 37.0) * shake_max_offset.x,
			sin(_shake_time * 53.0 + 1.3) * shake_max_offset.y
		) * amount / base_zoom  # offset 是世界单位；除以缩放，屏幕震幅保持 W5-01 定稿值
		rotation = sin(_shake_time * 23.0 + 0.7) * shake_max_roll * amount
	else:
		offset = Vector2.ZERO
		rotation = 0.0
	punch_strength = move_toward(punch_strength, 0.0, 0.30 * delta)
	zoom = Vector2.ONE * base_zoom * (1.0 - punch_strength)


func shake(amount: float) -> void:
	trauma = clampf(trauma + amount / 12.0, 0.0, 1.0)


func punch(amount: float) -> void:
	punch_strength = maxf(punch_strength, amount)
