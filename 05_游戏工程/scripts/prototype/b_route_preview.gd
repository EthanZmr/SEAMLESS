extends Node2D
## QA-only preview of the W3 Rain Market B route. Loads the real main scene
## and places the player at the B entrance so the vertical route can be
## inspected without replaying the prologue and A lane.

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var player: Player = main.get_node("Player")
	player.global_position = Vector2(640, 560)
	player.velocity = Vector2.ZERO
	var cam: Camera2D = main.get_node("Camera")
	cam.global_position = Vector2(720, 420)
	cam.reset_smoothing()
	GameEvents.message.emit("W3 B 区预览：攀爬塔 / 墙跳井 / 钩索高桥")
