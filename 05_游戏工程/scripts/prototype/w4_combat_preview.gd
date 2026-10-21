extends Node2D
## QA entry for W4-02: spawn directly in the B combat room with the two real
## enemy types, the short-circuit seam and the patch pickup present.

var player: Player
var combat_started := false

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	player = main.get_node("Player")
	player.global_position = Vector2(620, 560)
	player.velocity = Vector2.ZERO
	GameState.checkpoint = player.global_position
	var cam: Camera2D = main.get_node("Camera")
	cam.global_position = Vector2(860, 440)
	cam.reset_smoothing()
	# Enemies stand down until the player commits to the room.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.passive = true
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var legend := Label.new()
	legend.position = Vector2(32, 138)
	legend.size = Vector2(430, 52)
	legend.add_theme_font_size_override("font_size", 16)
	legend.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	legend.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	legend.add_theme_constant_override("shadow_offset_x", 1)
	legend.add_theme_constant_override("shadow_offset_y", 1)
	legend.text = "清道夫  快 0.45s · 短 62px\n截线者  慢 0.68s · 长 112px"
	layer.add_child(legend)
	GameEvents.message.emit("W4-02：先往右走。看敌人头顶的前摇条——越短越快，横线越长越远。")

func _process(_delta: float) -> void:
	if combat_started or player == null:
		return
	if player.global_position.x > 780.0:
		combat_started = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.passive = false
		GameEvents.message.emit("战斗开始。清道夫快而短；截线者慢而长，先读前摇再弹反。")
