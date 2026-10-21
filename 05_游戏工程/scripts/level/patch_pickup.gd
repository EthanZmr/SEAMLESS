extends Area2D
## A small one-use patch pickup. Walk into it to restore integrity or sync.

@export_enum("heal", "sync") var kind := "heal"

var used := false
var pulse := 0.0


func _ready() -> void:
	add_to_group("patches")
	body_entered.connect(_on_body_entered)
	monitoring = true
	queue_redraw()


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if used:
		return
	if not body.is_in_group("player"):
		return
	used = true
	set_deferred("monitoring", false)
	if kind == "heal":
		GameState.heal(25.0)
		GameEvents.message.emit("补丁：完整度 +25。")
	else:
		GameState.add_sync(15.0, true)
		GameEvents.message.emit("补丁：同步率 +15。")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.25)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.25)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var r := 16.0 + sin(pulse * 3.0) * 1.5
	var c := Color("#FFB13B") if kind == "heal" else Color("#3FE0D0")
	var points := PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.86, -r * 0.5), Vector2(r * 0.86, r * 0.5),
		Vector2(0, r), Vector2(-r * 0.86, r * 0.5), Vector2(-r * 0.86, -r * 0.5),
	])
	draw_colored_polygon(points, Color(c, 0.22))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), c, 1.5)
	draw_circle(Vector2.ZERO, 3.0, c)
