extends Area2D
## A visible seam. A-Zhen can stitch it to change the level.

@export_enum("bridge", "power", "heal", "short") var kind := "bridge"

var used := false
var pulse := 0.0

@onready var visual: Polygon2D = $Visual
@onready var tag: Label = $Tag


func _ready() -> void:
	add_to_group("seams")
	_update_visual()


func _process(delta: float) -> void:
	pulse += delta
	if visual:
		visual.rotation = sin(pulse * 2.0) * 0.08
		visual.scale = Vector2.ONE * (1.0 + sin(pulse * 3.0) * 0.04)


func activate() -> void:
	if used:
		return
	used = true
	GameEvents.seam_used.emit(kind)
	_update_visual()
	match kind:
		"bridge":
			_spawn_bridge()
			GameEvents.message.emit("缝住承重缝。招牌成了桥。")
		"power":
			GameState.add_sync(-10.0, true)
			GameState.heal(10.0)
			GameEvents.message.emit("电力接缝短路。灯灭了，路亮了。")
		"heal":
			GameState.heal(30.0)
			GameEvents.message.emit("缝住自己。完整度回升。")
		"short":
			var hit := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node2D and global_position.distance_to(enemy.global_position) < 280.0:
					if enemy.has_method("stagger"):
						enemy.stagger(2.2)
					if "seam_timer" in enemy:
						enemy.seam_timer = 2.0
					hit += 1
			GameState.add_sync(4.0, true)
			GameEvents.message.emit("接缝短路。%d 个清道夫停机。" % hit)
		_:
			GameEvents.message.emit("缝住了。")


func _spawn_bridge() -> void:
	var bridge := StaticBody2D.new()
	bridge.collision_layer = 1
	bridge.collision_mask = 0
	bridge.position = global_position + Vector2(170, 40)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240, 22)
	shape_node.shape = rect
	bridge.add_child(shape_node)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-120, -11), Vector2(120, -11), Vector2(120, 11), Vector2(-120, 11)
	])
	poly.color = Color("#2E6B7A")
	bridge.add_child(poly)
	get_parent().add_child(bridge)


func _update_visual() -> void:
	if visual == null:
		return
	if used:
		visual.color = Color("#FFB13B")
		if tag:
			tag.text = "已缝"
			tag.modulate = Color("#FFB13B")
	else:
		visual.color = Color("#FF3E8A") if kind in ["power", "short"] else Color("#3FE0D0")
		if tag:
			tag.text = "接缝"
			tag.modulate = visual.color
