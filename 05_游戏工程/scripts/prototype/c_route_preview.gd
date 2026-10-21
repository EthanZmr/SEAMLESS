extends Node2D
## QA-only preview of the W6-1 C vertical route. Loads the real main scene,
## clears enemies, and parks the player on the C roof so the shaft/roof/catwalk
## sightline can be inspected without replaying A/B.

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var player: Player = main.get_node("Player")
	player.global_position = Vector2(1360, 200)
	player.velocity = Vector2.ZERO
	var cam: Camera2D = main.get_node("Camera")
	cam.global_position = Vector2(1260, 300)
	cam.reset_smoothing()
	GameEvents.message.emit("W6-1 C 区预览：墙跳井 / 屋顶 / 钩索猫道")
