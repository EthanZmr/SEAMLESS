class_name ClimbZone
extends Area2D
## Invisible (or faintly marked) volume over a climbable wall. The player's
## ClimbSensor (mask 8) detects it; W/S enters the climb state.

@export var size := Vector2(36.0, 360.0)
@export var tint := Color(0.247, 0.878, 0.815, 0.10)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	add_to_group("climbable")
	if get_node_or_null("Collision") == null:
		var shape_node := CollisionShape2D.new()
		shape_node.name = "Collision"
		var rect := RectangleShape2D.new()
		rect.size = size
		shape_node.shape = rect
		add_child(shape_node)
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), tint, true)
	var rung := Color(0.247, 0.878, 0.815, 0.28)
	var y := -half.y + 12.0
	while y < half.y:
		draw_line(Vector2(-half.x + 3.0, y), Vector2(half.x - 3.0, y), rung, 1.0)
		y += 24.0
