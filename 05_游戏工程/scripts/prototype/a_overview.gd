extends Node2D

## QA-only overview: freeze the follow camera and show the whole A zone.
func _ready() -> void:
	await get_tree().process_frame
	var cam: Camera2D = $Main/Camera
	cam.set_process(false)
	cam.position = Vector2(1200, 460)
	cam.zoom = Vector2(0.55, 0.55)
	cam.limit_left = -400
	cam.limit_right = 3000
	cam.limit_top = 0
	cam.limit_bottom = 1000
	cam.make_current()
