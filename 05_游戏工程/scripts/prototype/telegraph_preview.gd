extends Node2D
## QA-only: hold both enemies at mid-windup so the range line and windup bar
## can be inspected without input timing or AI movement.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0B1220")
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	move_child(bg, 0)

	var sweeper: Sweeper = load("res://scenes/enemies/sweeper.tscn").instantiate()
	sweeper.position = Vector2(420, 520)
	add_child(sweeper)
	var lancer: Lancer = load("res://scenes/enemies/lancer.tscn").instantiate()
	lancer.position = Vector2(900, 520)
	add_child(lancer)

	await get_tree().process_frame
	for e in [sweeper, lancer]:
		e.passive = true
		e._set_state(EnemyBase.State.WINDUP)
		e.timer = e.windup_time * 0.55
		e._update_visuals()
		e.set_physics_process(false)
	# Lancer is held in its final 0.20s parry window to show the K prompt.
	lancer.timer = 0.10
	lancer._update_visuals()

	var cam := Camera2D.new()
	cam.position = Vector2(680, 420)
	add_child(cam)
	cam.make_current()
