extends Area2D
## One-shot trigger that spawns the boss.

var boss_scene: PackedScene
var boss_spawn := Vector2.ZERO
var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered or not body is Player:
		return
	triggered = true
	if boss_scene:
		var boss := boss_scene.instantiate()
		boss.position = boss_spawn
		get_parent().call_deferred("add_child", boss)
		GameEvents.message.emit("前面的路被剪断了。")
	queue_free()
