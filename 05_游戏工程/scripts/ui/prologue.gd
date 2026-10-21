extends Control
## Text-first prologue: the clinic, the courier, Bai Lu's first visit.
## Whitebox presentation: system font, drawn rain/city, no external assets.

const LINES_PATH := "res://data/dialogue/prologue_01.json"

## 对白数据来自 data/dialogue/prologue_01.json。改文案只改 JSON，不碰脚本。
var LINES: Array[Dictionary] = []
## "json" = 数据文件生效；"fallback" = 文件缺失时的单行提示。
var lines_source := "fallback"

@onready var speaker: Label = $Speaker
@onready var body: Label = $Body
@onready var hint: Label = $Hint
@onready var progress: Label = $Progress
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var fade: ColorRect = $Fade

var index := -1
var typing := false
var char_timer := 0.0
var title_mode := false
var title_ready := 0.0
var rain: Array[Vector3] = []
var rng := RandomNumberGenerator.new()


## 从 data/dialogue/prologue_01.json 读对白。失败时退化成单行提示，
## 保证仍然能按 Enter 进入游戏，而不是卡在空序章。
func _load_lines() -> void:
	LINES.clear()
	var parsed: Variant = null
	if FileAccess.file_exists(LINES_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	var raw: Variant = (parsed as Dictionary).get("lines", []) if typeof(parsed) == TYPE_DICTIONARY else []
	if raw is Array and not (raw as Array).is_empty():
		for entry in raw:
			if entry is Dictionary:
				LINES.append({
					"who": String(entry.get("who", "")),
					"text": String(entry.get("text", "")),
					"color": String(entry.get("color", "#F2EFE6")),
				})
	if LINES.is_empty():
		push_error("Prologue: 无法从 %s 读到 lines，退化为单行提示" % LINES_PATH)
		LINES.append({
			"who": "旁白",
			"text": "（序章数据缺失：%s）" % LINES_PATH,
			"color": "#6F8FA8",
		})
		lines_source = "fallback"
		return
	lines_source = "json"


func _ready() -> void:
	_load_lines()
	rng.seed = 17
	for i in range(110):
		rain.append(Vector3(rng.randf_range(0.0, 1920.0), rng.randf_range(-120.0, 1080.0), rng.randf_range(0.65, 1.8)))
	_setup_fonts()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.9)
	_show_line(0)


func _setup_fonts() -> void:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	for label in [speaker, body, hint, progress, title, subtitle]:
		label.add_theme_font_override("font", sys)
	speaker.add_theme_font_size_override("font_size", 28)
	body.add_theme_font_size_override("font_size", 27)
	hint.add_theme_font_size_override("font_size", 18)
	progress.add_theme_font_size_override("font_size", 18)
	title.add_theme_font_size_override("font_size", 96)
	subtitle.add_theme_font_size_override("font_size", 28)


func _process(delta: float) -> void:
	if not title_mode:
		queue_redraw()
	if typing:
		char_timer += delta * 40.0
		body.visible_characters = int(char_timer)
		if body.visible_characters >= body.text.length():
			typing = false
	if title_mode:
		title_ready += delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not title_mode:
			_show_title()
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J, KEY_K]:
			_advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _show_line(i: int) -> void:
	index = i
	var line: Dictionary = LINES[i]
	speaker.text = line["who"]
	speaker.modulate = Color(line["color"])
	body.text = line["text"]
	body.modulate = Color("#F2EFE6") if line["who"] != "旁白" else Color("#9FB6C9")
	body.visible_characters = 0
	char_timer = 0.0
	typing = true
	progress.text = "%02d / %02d" % [i + 1, LINES.size()]
	hint.text = "Enter / J 继续 · Esc 跳过"
	title.visible = false
	subtitle.visible = false


func _advance() -> void:
	if fade.visible:
		return
	if title_mode:
		if title_ready < 0.8:
			return
		_enter_game()
		return
	if typing:
		body.visible_characters = -1
		typing = false
		return
	if index + 1 >= LINES.size():
		_show_title()
	else:
		_show_line(index + 1)


func _show_title() -> void:
	title_mode = true
	speaker.visible = false
	body.visible = false
	hint.visible = false
	progress.visible = false
	title.visible = true
	subtitle.visible = true
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 1.2)
	t.tween_property(subtitle, "modulate:a", 1.0, 1.6)
	hint.visible = true
	hint.text = "Enter / J 进入雨市"


func _enter_game() -> void:
	if fade.visible:
		return
	fade.visible = true
	fade.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.7)
	t.tween_callback(func() -> void: LevelManager.start_level(LevelManager.current_id))


func _draw() -> void:
	# Room.
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#060A12"))
	draw_rect(Rect2(0, 760, 1920, 320), Color("#0A111C"))
	# Window with the vertical city.
	draw_rect(Rect2(1080, 150, 660, 640), Color("#0B1626"))
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(9):
		var w := 48.0 + float((i * 37) % 50)
		var h := 180.0 + float((i * 83) % 300)
		var x := 1110.0 + float(i) * 70.0
		draw_rect(Rect2(x, 790.0 - h, w, h), Color("#12233A") if i % 2 == 0 else Color("#0F1C2E"))
		for j in range(2):
			draw_rect(Rect2(x + 10.0 + j * 18.0, 790.0 - h + 30.0, 8, 12), Color("#FF3E8A") if (i + j) % 3 == 0 else Color("#3FE0D0"))
	# Rain inside the window light.
	for drop in rain:
		var y: float = fmod(float(drop.y) + t * 320.0 * float(drop.z), 900.0) + 80.0
		var x: float = float(drop.x) * 0.34 + 1080.0
		if x > 1080.0 and x < 1740.0 and y < 790.0:
			draw_line(Vector2(x, y), Vector2(x - 3.0, y + 18.0), Color(0.55, 0.8, 0.9, 0.30), 1.0)
	# Desk, lamp, hanging cables.
	draw_rect(Rect2(120, 780, 760, 26), Color("#1A2A3E"))
	draw_rect(Rect2(180, 806, 18, 210), Color("#142236"))
	draw_rect(Rect2(800, 806, 18, 210), Color("#142236"))
	draw_line(Vector2(300, 0), Vector2(300, 300), Color("#1B3048"), 2.0)
	draw_line(Vector2(300, 300), Vector2(360, 420), Color("#1B3048"), 2.0)
	draw_circle(Vector2(360, 420), 10.0, Color(1.0, 0.69, 0.23, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(360, 430), Vector2(260, 780), Vector2(470, 780)]), Color(1.0, 0.69, 0.23, 0.05))
	# Vignette.
	draw_rect(Rect2(0, 0, 1920, 90), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, 990, 1920, 90), Color(0, 0, 0, 0.35))
