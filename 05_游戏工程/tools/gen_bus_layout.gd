extends SceneTree
## 生成 default_bus_layout.tres（音频总线布局）。
##
## 为什么不手写 .tres：AudioBusLayout 的字段名与 StringName 序列化格式容易写错，
## 写错了不会报错，只会让总线悄悄消失。让 Godot 自己序列化最稳。
##
## 运行：godot --headless --path . -s res://tools/gen_bus_layout.gd
##      加 -- --force 覆盖已有文件。
##
## 注意：`_init` 里一旦抛错，SceneTree 没有场景就会一直空转不退出。
## 所以所有逻辑都收进 `_run()` 返回退出码，`_init` 只负责 quit。

const OUT_PATH := "res://default_bus_layout.tres"

## 总线表：名字 → 父总线。顺序即创建顺序（索引 0 是内置 Master）。
const BUSES := [
	{"name": "Music", "send": "Master"},
	{"name": "SFX", "send": "Master"},
	{"name": "UI", "send": "Master"},
	{"name": "Ambience", "send": "Master"},
]


func _init() -> void:
	quit(_run())


func _run() -> int:
	var force := "--force" in OS.get_cmdline_args() or "--force" in OS.get_cmdline_user_args()
	if FileAccess.file_exists(OUT_PATH) and not force:
		print("已存在 %s，加 --force 才覆盖" % OUT_PATH)
		return 0

	# AudioBusLayout 没有 set_bus_name/set_bus_count（只有 get_* 与 add/remove_bus）。
	# 直接操作 AudioServer 再 generate_bus_layout() 取快照，是官方推荐路径。
	AudioServer.set_bus_count(BUSES.size() + 1)
	AudioServer.set_bus_name(0, "Master")

	for i in BUSES.size():
		var entry: Dictionary = BUSES[i]
		var idx := i + 1
		AudioServer.set_bus_name(idx, str(entry["name"]))
		AudioServer.set_bus_send(idx, str(entry["send"]))

	var layout := AudioServer.generate_bus_layout()

	var err := ResourceSaver.save(layout, OUT_PATH)
	if err != OK:
		printerr("GEN_FAILED: 保存失败 err=%d" % err)
		return 1

	# round-trip：AudioBusLayout 只有属性路径（`bus/<n>/name`），没有 get_bus_* 方法，
	# 所以直接校对文本 —— 格式稳定，也顺带确认真的写进去了。
	var text := FileAccess.get_file_as_string(OUT_PATH)
	if text.is_empty():
		printerr("GEN_FAILED: 读不回文件内容")
		return 1
	for i in BUSES.size():
		var want := str(BUSES[i]["name"])
		var needle := 'bus/%d/name = &"%s"' % [i + 1, want]
		if not text.contains(needle):
			printerr("GEN_FAILED: 文件里找不到 %s" % needle)
			return 1

	print("GEN_OK: %s（%d 条总线）" % [OUT_PATH, BUSES.size() + 1])
	print("  [0] Master")
	for i in BUSES.size():
		print("  [%d] %s → %s" % [i + 1, str(BUSES[i]["name"]), str(BUSES[i]["send"])])
	return 0
