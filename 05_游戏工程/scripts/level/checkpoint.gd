extends Area2D
## Needle-eye checkpoint. Restores integrity, updates respawn point.

var used := false

@onready var visual: Polygon2D = $Visual
@onready var tag: Label = $Tag


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual()


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	if used:
		return
	used = true
	GameState.checkpoint = global_position
	GameState.heal(35.0)
	GameEvents.checkpoint_reached.emit(global_position)
	GameEvents.message.emit("针眼。记住这里。")
	_update_visual()


func _update_visual() -> void:
	if visual == null:
		return
	visual.color = Color("#FFB13B") if used else Color("#7FA8C9")
	if tag:
		tag.text = "针眼" if not used else "已记录"
		tag.modulate = visual.color
