class_name Lift
extends AnimatableBody2D
## 升降梯捷径（01_GDD/10 §3）：在 stop_a 端按交互激活一次（存进剧情标记），
## 之后站上去 0.3 秒驶向另一端；人在某一端而平台不在那里时，平台驶来。
## 未激活时平台停在 stop_b：把远端井口盖住，玩家不能从远端掉进来绕过路线。

const PLATFORM := Vector2(96, 16)
const RIDE_DELAY := 0.3
## 开关放在 stop_a 井口旁的平台上（井口本身是空的，人站不进去）。
const SWITCH_OFFSET := Vector2(100, -40)

@export var lift_id := ""
@export var stop_a := Vector2.ZERO
@export var stop_b := Vector2.ZERO
@export var speed := 160.0

var active := false
var _target := Vector2.ZERO
var _moving := false
var _ride_timer := 0.0
var _need_exit := false
var _rider: Area2D
var _switch: Area2D
var _switch_tag: Label
var _calls: Array[Area2D] = []


func _ready() -> void:
	sync_to_physics = false
	active = GameState.has_flag(_flag())
	position = stop_a if active else stop_b
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = PLATFORM
	shape.shape = rect
	add_child(shape)
	_rider = _make_area("Rider", Vector2(0, -20), Vector2(PLATFORM.x, 24))
	add_child(_rider)
	_switch = _make_area("Switch", stop_a + SWITCH_OFFSET, Vector2(120, 100))
	_switch_tag = Label.new()
	_switch_tag.name = "Tag"
	_switch_tag.text = "E 拉闸"
	_switch_tag.position = Vector2(-28, -70)
	_switch_tag.modulate = Color("#3FE0D0")
	_switch_tag.visible = not active
	_switch.add_child(_switch_tag)
	_calls = [_make_area("CallA", stop_a + Vector2(0, -40), Vector2(160, 120)),
		_make_area("CallB", stop_b + Vector2(0, -40), Vector2(160, 120))]
	# 开关与呼叫区固定在世界里，不跟平台走。
	for a in [_switch] + _calls:
		get_parent().add_child.call_deferred(a)


func _exit_tree() -> void:
	for a in [_switch] + _calls:
		if is_instance_valid(a):
			a.queue_free()


func _flag() -> String:
	return "lift:" + lift_id


func _make_area(n: String, at: Vector2, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = "%s_%s" % [n, lift_id]
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	return area


func _has_player(area: Area2D) -> bool:
	if not area.is_inside_tree():
		return false
	for body in area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _physics_process(delta: float) -> void:
	if not active:
		if Input.is_action_just_pressed("interact") and _has_player(_switch):
			active = true
			GameState.set_flag(_flag())
			_switch_tag.visible = false
			GameEvents.message.emit("升降梯：通了。")
			_go(stop_a)
		return
	if _moving:
		position = position.move_toward(_target, speed * delta)
		if position.is_equal_approx(_target):
			_moving = false
			_need_exit = true
		return
	var on_board := _has_player(_rider)
	if not on_board:
		_need_exit = false
		_ride_timer = 0.0
		for i in _calls.size():
			var stop: Vector2 = stop_a if i == 0 else stop_b
			if _has_player(_calls[i]) and not position.is_equal_approx(stop):
				_go(stop)
				return
		return
	if _need_exit:
		return
	_ride_timer += delta
	if _ride_timer >= RIDE_DELAY:
		_go(stop_b if position.is_equal_approx(stop_a) else stop_a)


func _go(to: Vector2) -> void:
	_target = to
	_moving = true
	_ride_timer = 0.0


func _draw() -> void:
	var c := Color("#3FE0D0") if active else Color("#4A5A6E")
	draw_rect(Rect2(-PLATFORM * 0.5, PLATFORM), Color(c, 0.35))
	draw_rect(Rect2(-PLATFORM * 0.5, PLATFORM), c, false, 2.0)
