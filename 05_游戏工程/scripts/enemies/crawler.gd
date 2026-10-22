class_name Crawler
extends EnemyBase
## 沟爬子（01_GDD/10 §7）：义体坏到只剩爪子的拆件客。
## 贴在天花板/墙上时不受重力，在 point_a 与 point_b 之间往返；
## 天花板上的发现玩家在正下方就脱落，落地后像地面爬虫一样朝玩家爬，靠接触伤人。

const CONTACT_CD := 0.8

@export var surface := "floor"
@export var point_a := Vector2.ZERO
@export var point_b := Vector2.ZERO
@export var crawl_speed := 60.0
@export var drop_dx := 40.0

var attached := false
var _toward_b := true


func _on_ready() -> void:
	attached = surface == "ceiling" or surface == "wall"


func _physics_process(delta: float) -> void:
	if not attached or state == State.DEAD:
		super._physics_process(delta)
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var goal := point_b if _toward_b else point_a
	global_position = global_position.move_toward(goal, crawl_speed * delta)
	if global_position.is_equal_approx(goal):
		_toward_b = not _toward_b
	if surface == "ceiling" and _player_below():
		attached = false
		velocity = Vector2.ZERO
	_update_visuals()


func _player_below() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return player.global_position.y > global_position.y \
		and absf(player.global_position.x - global_position.x) < drop_dx


## 落地后：朝玩家爬，接触造成伤害；没有玩家时在 a/b 的 x 之间巡逻。
func _update_ai(_delta: float) -> void:
	if not is_on_floor():
		return
	var target_x := global_position.x
	if player != null and is_instance_valid(player) \
			and global_position.distance_to(player.global_position) <= detect_range:
		target_x = player.global_position.x
	else:
		target_x = point_b.x if _toward_b else point_a.x
		if absf(global_position.x - target_x) < 2.0:
			_toward_b = not _toward_b
	var dir := signf(target_x - global_position.x)
	facing = int(dir) if dir != 0.0 else facing
	velocity.x = dir * crawl_speed
	_try_contact()


func _try_contact() -> void:
	if attack_cd > 0.0 or player == null or not is_instance_valid(player):
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < 24.0 and absf(d.y) < 40.0 and player.has_method("receive_attack"):
		player.receive_attack({"damage": attack_damage, "source": self, "parryable": false})
		attack_cd = CONTACT_CD
