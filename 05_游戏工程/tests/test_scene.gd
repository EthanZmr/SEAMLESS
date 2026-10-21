extends Node
## Integration tests with autoloads and the player scene.
## Run: bash tools/test_all.sh test_scene
## 直接跑也行：godot --headless --path . res://tests/test_scene.tscn
## 切勿用 -s 跑本文件：脚本模式不加载 autoload，会报 Identifier not found 并静默返回 0。
## Exits non-zero on failure.

var failures := 0


func _ready() -> void:
	GameState.reset()
	_test_game_state()
	await _test_player_parry()
	await _test_scene_loads()
	await _test_a_route()
	await _test_a_vertical()
	await _test_a_v4_routes()
	await _test_parried_enemy_recovers()
	await _test_b_route()
	await _test_prologue()
	await _test_boss_trigger()
	await _test_hud_choice()
	await _test_level_boss_spawn()
	if failures == 0:
		print("TEST_SCENE: PASS")
	else:
		print("TEST_SCENE: FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_game_state() -> void:
	GameState.reset()
	_check(GameState.sync == 30.0, "reset sync is 30")
	_check(GameState.integrity == 100.0, "reset integrity is 100")

	GameState.add_sync(100.0)
	_check(GameState.sync == 100.0, "sync clamps at 100")
	_check(GameState.is_takeover, "sync at 100 starts takeover")
	_check(GameState.form == 1, "takeover forces A-Ling form")

	GameState.end_takeover()
	_check(not GameState.is_takeover, "takeover ends")
	_check(GameState.sync == 50.0, "takeover exits at 50 sync")
	_check(GameState.integrity == 80.0, "takeover costs 20 integrity")
	_check(GameState.form == 0, "takeover returns A-Zhen")

	GameState.reset()
	var died := [false]
	var on_died := func() -> void: died[0] = true
	GameEvents.player_died.connect(on_died)
	GameState.damage(150.0)
	_check(GameState.integrity == 0.0, "damage clamps integrity at 0")
	_check(died[0], "zero integrity emits player_died")
	GameEvents.player_died.disconnect(on_died)
	GameState.reset()


func _test_player_parry() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)

	# Perfect parry: 0.05s into the active window.
	GameState.reset()
	player.state = Player.State.PARRY
	player.parry_elapsed = 0.05
	player.invuln = 0.0
	var before := GameState.sync
	var negated: bool = player.receive_attack({"damage": 10.0, "source": player, "parryable": true})
	_check(negated, "perfect parry negates the hit")
	_check(GameState.sync > before, "perfect parry adds sync")
	_check(player.perfect_parry_count == 1, "perfect parry counter increments")

	# Normal parry: 0.12s.
	GameState.reset()
	player.state = Player.State.PARRY
	player.parry_elapsed = 0.12
	player.invuln = 0.0
	negated = player.receive_attack({"damage": 10.0, "source": player, "parryable": true})
	_check(negated, "normal parry negates the hit")
	_check(is_equal_approx(GameState.sync, 36.0), "normal parry adds 6 sync")

	# Unparryable red attack: parry window does not save you.
	GameState.reset()
	player.state = Player.State.PARRY
	player.parry_elapsed = 0.0
	player.invuln = 0.0
	negated = player.receive_attack({"damage": 10.0, "source": player, "parryable": false})
	_check(not negated, "unparryable attack is not negated")
	_check(is_equal_approx(GameState.integrity, 90.0), "unparryable attack deals damage")

	# Late parry: no active window.
	GameState.reset()
	player.state = Player.State.PARRY
	player.parry_elapsed = 0.30
	player.invuln = 0.0
	negated = player.receive_attack({"damage": 15.0, "source": player, "parryable": true})
	_check(not negated, "late parry fails")
	_check(is_equal_approx(GameState.integrity, 85.0), "late parry takes full damage")
	_check(is_equal_approx(GameState.sync, 40.0), "late parry adds 10 sync")

	player.queue_free()
	GameState.reset()


func _test_scene_loads() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "main scene loads")
	if scene:
		var main := scene.instantiate()
		_check(main.get_node_or_null("Player") != null, "main scene has Player")
		_check(main.get_node_or_null("Level") != null, "main scene has Level")
		_check(main.get_node_or_null("HUDLayer/HUD") != null, "main scene has HUD")
		main.queue_free()
	await get_tree().process_frame


func _test_a_route() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var level := main.get_node_or_null("Level")
	_check(level != null and level.data_source == "json", "关卡几何来自 data/levels/rain_market.json")
	if level:
		_check((level.data.get("platforms", []) as Array).size() == 34, "JSON 内含 34 块平台")
		_check((level.data.get("enemies", []) as Array).size() == 11, "JSON 内含 11 个敌人")
	var bridge_seam: Node = null
	var second_bridge: Node = null
	var bridge_count := 0
	for seam in get_tree().get_nodes_in_group("seams"):
		if seam.kind == "bridge" and seam.position.x < 2000.0:
			bridge_count += 1
			if bridge_seam == null:
				bridge_seam = seam
			elif second_bridge == null:
				second_bridge = seam
	_check(bridge_count == 2, "A route has two bridge seams")
	_check(get_tree().get_nodes_in_group("seams").size() == 4, "A–C keeps four seams")
	if bridge_seam:
		bridge_seam.activate()
		await get_tree().physics_frame
		_check(bridge_seam.used, "A bridge seam stitches the first gap")
	if second_bridge:
		second_bridge.activate()
		await get_tree().physics_frame
		_check(second_bridge.used, "A second bridge seam stitches the second gap")
	main.queue_free()
	GameState.reset()
	await get_tree().process_frame


func _test_a_vertical() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("climbable").size() >= 2, "A and B have climb zones")
	var high_seam: Node = null
	for seam in get_tree().get_nodes_in_group("seams"):
		if seam.kind == "bridge" and seam.global_position.distance_to(Vector2(1300, 240)) < 2.0:
			high_seam = seam
			break
	_check(high_seam != null, "A high route has a bridge seam")
	_check(get_tree().get_nodes_in_group("arena_gates").size() == 0, "A has no combat gates")
	main.queue_free()
	GameState.reset()
	await get_tree().process_frame

func _test_a_v4_routes() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: Player = main.get_node("Player")
	player.invuln = 999.0
	# Entry green ladder.
	player.global_position = Vector2(920, 560)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	Input.action_press("move_up")
	for i in range(5):
		await get_tree().physics_frame
	_check(player.state == Player.State.CLIMB, "A2 entry ladder enters CLIMB")
	Input.action_release("move_up")
	# A1 clinic ladder.
	player.global_position = Vector2(160, 560)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	Input.action_press("move_up")
	for i in range(5):
		await get_tree().physics_frame
	_check(player.state == Player.State.CLIMB, "A1 clinic ladder enters CLIMB")
	Input.action_release("move_up")
	# A3 rooftop ladder.
	player.global_position = Vector2(2000, 560)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	Input.action_press("move_up")
	for i in range(5):
		await get_tree().physics_frame
	_check(player.state == Player.State.CLIMB, "A3 rooftop ladder enters CLIMB")
	Input.action_release("move_up")
	# High route: left roof -> hook anchor above the billboard.
	player.global_position = Vector2(980, 250)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	InputBuffer._stamps["hook"] = Time.get_ticks_msec()
	Input.action_press("hook")
	for i in range(3):
		await get_tree().physics_frame
	_check(player.state == Player.State.HOOK, "A high route hook enters HOOK")
	Input.action_release("hook")
	InputBuffer.clear()
	# Drain exit ladder: the failure route must not strand the player.
	player.global_position = Vector2(1488, 780)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	Input.action_press("move_up")
	for i in range(5):
		await get_tree().physics_frame
	_check(player.state == Player.State.CLIMB, "A drain exit ladder enters CLIMB")
	Input.action_release("move_up")
	var drain_patch: Node = null
	for p in get_tree().get_nodes_in_group("patches"):
		if p.global_position.distance_to(Vector2(1300, 780)) < 2.0:
			drain_patch = p
			break
	_check(drain_patch != null, "A drain has a patch reward")
	main.queue_free()
	GameState.reset()
	await get_tree().process_frame


func _test_parried_enemy_recovers() -> void:
	var sweeper: Node = load("res://scenes/enemies/sweeper.tscn").instantiate()
	add_child(sweeper)
	await get_tree().process_frame
	sweeper.on_parried(false)
	await get_tree().physics_frame
	for i in range(50):
		await get_tree().physics_frame
	_check(sweeper.state != EnemyBase.State.STAGGER, "parried enemy leaves stagger when the timer expires")
	sweeper.queue_free()
	await get_tree().process_frame


func _test_b_route() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("climbable").size() >= 1, "B route has a climb zone")
	_check(get_tree().get_nodes_in_group("hook_anchors").size() >= 1, "B route has a hook anchor")
	var player: Player = main.get_node("Player")
	player.invuln = 999.0
	player.global_position = Vector2(2610, 470)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	Input.action_press("move_up")
	for i in range(5):
		await get_tree().physics_frame
	_check(player.state == Player.State.CLIMB, "B route climb zone enters CLIMB")
	Input.action_release("move_up")
	player.global_position = Vector2(2760, 80)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	InputBuffer._stamps["hook"] = Time.get_ticks_msec()
	Input.action_press("hook")
	for i in range(3):
		await get_tree().physics_frame
	_check(player.state == Player.State.HOOK, "B route hook enters HOOK")
	Input.action_release("hook")
	InputBuffer.clear()
	_check(get_tree().get_nodes_in_group("seams").size() == 4, "A–C keeps four seams after C upper")
	_check(get_tree().get_nodes_in_group("patches").size() == 2, "A/B have two patches")
	# C upper route: the roof below the second anchor must start a hook. This
	# exercises the W6-1 vertical layer, not just the B tower.
	player.global_position = Vector2(3360, 200)
	player.velocity = Vector2.ZERO
	player.state = Player.State.FALL
	InputBuffer.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	InputBuffer._stamps["hook"] = Time.get_ticks_msec()
	Input.action_press("hook")
	for i in range(3):
		await get_tree().physics_frame
	_check(player.state == Player.State.HOOK, "C roof hook enters HOOK")
	Input.action_release("hook")
	InputBuffer.clear()
	var power_seam: Node = null
	for seam in get_tree().get_nodes_in_group("seams"):
		if seam.kind == "power":
			power_seam = seam
			break
	_check(power_seam != null, "C upper route has a power seam")
	var lancer: Node = null
	var lancers: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("enemy_name") == "截线者":
			lancers.append(enemy)
	if not lancers.is_empty():
		# The last lancer is B's; the first is A's high-route sentry now.
		lancer = lancers[lancers.size() - 1]
	_check(lancer != null, "B route has a lancer enemy")
	var short_seam: Node = null
	for seam in get_tree().get_nodes_in_group("seams"):
		if seam.kind == "short":
			short_seam = seam
			break
	_check(short_seam != null, "B route has a short-circuit seam")
	if short_seam and lancer:
		short_seam.activate()
		await get_tree().physics_frame
		_check(lancer.stagger_timer > 0.0, "short seam stuns nearby lancer")
	# The lancer uses the same parryable swing contract; verify it directly,
	# independent of the player's timing against the 0.68s windup.
	if lancer:
		player.invuln = 0.0
		player.global_position = lancer.global_position + Vector2(-60, 0)
		player.velocity = Vector2.ZERO
		player.state = Player.State.PARRY
		player.parry_elapsed = 0.10
		var integrity_before: float = GameState.integrity
		lancer._do_attack()
		await get_tree().physics_frame
		_check(GameState.integrity == integrity_before, "lancer attack can be parried")
		_check(lancer.stagger_timer > 0.0, "lancer parry staggers the lancer")
	var patch: Node = null
	for p in get_tree().get_nodes_in_group("patches"):
		if p.global_position.x > 1300.0:
			patch = p
			break
	if patch:
		player.global_position = patch.global_position
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(patch.used, "patch pickup consumes on player touch")
	main.queue_free()
	await get_tree().process_frame


func _test_prologue() -> void:
	var scene: PackedScene = load("res://scenes/prologue.tscn")
	_check(scene != null, "prologue scene loads")
	if scene:
		var prologue := scene.instantiate()
		add_child(prologue)
		await get_tree().process_frame
		_check(prologue.get_node_or_null("Speaker") != null, "prologue has speaker")
		_check(prologue.get_node_or_null("Body") != null, "prologue has body text")
		prologue._show_title()
		_check(prologue.title_mode, "prologue can reach title")
		_check(prologue.get_node("Title").text == "无缝", "title reads SEAMLESS")
		prologue.queue_free()
	await get_tree().process_frame


func _test_boss_trigger() -> void:
	var root := Node2D.new()
	add_child(root)
	var trigger: Area2D = load("res://scenes/level/boss_trigger.tscn").instantiate()
	trigger.boss_scene = load("res://scenes/boss/trimmer.tscn")
	trigger.boss_spawn = Vector2(200, 0)
	root.add_child(trigger)
	await get_tree().process_frame
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	trigger._on_body_entered(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(root.get_node_or_null("Trimmer") != null, "boss trigger spawns Trimmer")
	root.queue_free()
	GameState.reset()
	await get_tree().process_frame


func _test_hud_choice() -> void:
	var hud := Control.new()
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)
	await get_tree().process_frame
	hud._on_boss_defeated()
	hud._resolve_choice("unpick")
	_check(hud.ending_text.begins_with("切片结束"), "HUD shows ending after boss choice")
	_check(InputMap.has_action("restart"), "restart action exists")
	hud.queue_free()
	await get_tree().process_frame


func _test_level_boss_spawn() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: Player = main.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector2(4140, 560)
	_check(main.get_node_or_null("Level/BossTrigger") != null, "level builds boss trigger")
	for i in range(8):
		await get_tree().physics_frame
	await get_tree().process_frame
	_check(main.get_node_or_null("Level/Trimmer") != null, "walking into trigger spawns boss in level")
	main.queue_free()
	GameState.reset()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)
