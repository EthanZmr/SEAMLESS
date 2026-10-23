extends Node2D
## 逐帧可读性预览（`03_美术/28` §6、`16` §3.5）：纯黑 / 纯白 / 雨市夜色三种背景，
## 128 px（游戏内）与 96 px（剪影压力测试）两个尺寸同步循环。
## Run: godot --path . res://tools/sprite_preview.tscn
## 按键：Space 暂停/继续，← → 暂停时逐张，O 轮廓光开关，F 翻转朝向。

const SPEC_PATH := "res://data/anim/zhen_run.tres"
const OUTLINE_SHADER := preload("res://assets/shaders/rim_outline.gdshader")
const PANEL := Vector2(600, 900)
const ORIGIN := Vector2(60, 140)
## 128 px：世界缩放 × 相机缩放 2.0；96 px 是它的 3/4。
const SIZES := [["128 px（游戏内）", 2.0], ["96 px（剪影压力测试）", 1.5]]

var _spec: FrameSet
var _textures: Array[Texture2D] = []
var _sprites: Array[Sprite2D] = []
var _tick := 0
var _paused := false
var _outline := true
var _facing := 1
var _status: Label


func _ready() -> void:
	_spec = FrameSet.load_or_default(SPEC_PATH)
	for i in range(1, _spec.count + 1):
		var path := _spec.path_of(i)
		if ResourceLoader.exists(path):
			_textures.append(load(path) as Texture2D)
	_build_panels()
	_status = _label("", Vector2(60, 70), 26)
	_label("跑步试点预览 · Space 暂停 · ← → 逐张 · O 轮廓光 · F 翻转", Vector2(60, 24), 26)
	if _textures.size() != _spec.count:
		_status.text = "缺帧（%d/%d）：把 8 张 PNG 放进 %s（见 03_美术/28）" % [
			_textures.size(), _spec.count, _spec.dir]
		return
	_apply()


func _build_panels() -> void:
	var backgrounds := [["纯黑", Color.BLACK], ["纯白", Color.WHITE], ["雨市夜色", Color("#0B1220")]]
	for col in range(backgrounds.size()):
		var at := ORIGIN + Vector2(col * (PANEL.x + 20), 0)
		var bg := ColorRect.new()
		bg.color = backgrounds[col][1]
		bg.position = at
		bg.size = PANEL
		add_child(bg)
		if col == 2:
			_neon(at)
		var ink := Color("#7FA8C9") if col != 1 else Color("#3A4A5C")
		_label(backgrounds[col][0], at + Vector2(16, 10), 22, ink)
		for row in range(SIZES.size()):
			var foot := at + Vector2(PANEL.x * 0.5, 380 + row * 420)
			_label(SIZES[row][0], at + Vector2(16, 60 + row * 420), 18, ink)
			var floor_line := ColorRect.new()
			floor_line.color = Color(ink, 0.5)
			floor_line.position = foot + Vector2(-200, 0)
			floor_line.size = Vector2(400, 2)
			add_child(floor_line)
			var s := Sprite2D.new()
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			s.material = ShaderMaterial.new()
			(s.material as ShaderMaterial).shader = OUTLINE_SHADER
			s.set_meta("foot", foot)
			s.set_meta("zoom", SIZES[row][1])
			add_child(s)
			_sprites.append(s)


## 雨市夜色：几条霓虹招牌色块，模拟角色身后的高对比环境。
func _neon(at: Vector2) -> void:
	var strips := [[Vector2(40, 160), Vector2(14, 260), Color("#3FE0D0")],
		[Vector2(470, 120), Vector2(90, 30), Color("#FF3E8A")],
		[Vector2(380, 560), Vector2(160, 22), Color("#FFB23A")],
		[Vector2(120, 620), Vector2(12, 200), Color("#FF3E8A")]]
	for st in strips:
		var r := ColorRect.new()
		r.color = Color(st[2], 0.55)
		r.position = at + st[0]
		r.size = st[1]
		add_child(r)


func _label(text: String, pos: Vector2, size: int, color := Color("#BFD4E6")) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _physics_process(_delta: float) -> void:
	if _textures.size() != _spec.count or _paused:
		return
	_tick += 1
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _textures.size() != _spec.count:
		return
	match key.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_RIGHT, KEY_LEFT:
			if _paused:
				_tick = _step_to(_spec.index_at(_tick) + (1 if key.keycode == KEY_RIGHT else -1))
		KEY_O:
			_outline = not _outline
		KEY_F:
			_facing = -_facing
	_apply()


## 第 index 张（可越界，按循环取模）开始时的 tick。
func _step_to(index: int) -> int:
	var target := posmod(index, _spec.count)
	var t := 0
	for i in range(target):
		t += _spec.holds[i]
	return t


func _apply() -> void:
	var idx := _spec.index_at(_tick)
	var a := _spec.anchor_from_center()
	for s in _sprites:
		var k: float = _spec.world_scale * float(s.get_meta("zoom"))
		s.texture = _textures[idx]
		s.scale = Vector2(k * _facing, k)
		s.position = Vector2(s.get_meta("foot")) - Vector2(a.x * k * _facing, a.y * k)
		(s.material as ShaderMaterial).set_shader_parameter("width", 8.0 if _outline else 0.0)
	_status.text = "第 %d/%d 张 · tick %d · %s · 轮廓光 %s · 朝%s" % [
		idx + 1, _spec.count, _tick, "暂停" if _paused else "播放",
		"开" if _outline else "关", "右" if _facing > 0 else "左"]
