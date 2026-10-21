extends SceneTree
## 性能基线探针：跑固定帧数，输出可对比的数字。
##
## 运行：
##     godot --headless --path . -s res://tools/perf_probe.gd
##     godot --path . -s res://tools/perf_probe.gd -- --frames=600
##
## 为什么要这个：手感问题（掉帧、输入延迟）在有数字之前全是猜。这个探针
## 不判断"快还是慢"——headless 的数字和真机差一个数量级，它只负责把
## 帧时间分布、物理回调耗时、对象数写下来，用来做"改之前 vs 改之后"的对比。
##
## 注意：headless 下没有渲染，draw_calls / video mem 永远是 0。
## 要测真机性能请带窗口跑（去掉 --headless），别拿 headless 的 fps 下结论。

const DEFAULT_FRAMES := 480
const WARMUP_FRAMES := 60
const SCENE_PATH := "res://scenes/main.tscn"

var _frames := DEFAULT_FRAMES
var _samples: Array[float] = []
var _objects_start := 0
var _objects_peak := 0
var _nodes_start := 0
var _nodes_peak := 0


## 逻辑必须收在一个函数里：_init/_initialize 抛错时 quit() 不执行，进程会空转挂死。
## 又因为 _run 里有 await（等帧），它本身是协程，所以只能 deferred 起，
## 不能在 _initialize 里直接 await —— 那会把主循环的第一个帧卡住。
func _initialize() -> void:
	_run.call_deferred()


func _run() -> int:
	_parse_args()
	var scene_path := SCENE_PATH
	if not ResourceLoader.exists(scene_path):
		print("PERF_FAILED: 找不到 %s" % scene_path)
		quit(1)
		return 1
	var packed: Variant = load(scene_path)
	if not (packed is PackedScene):
		print("PERF_FAILED: %s 不是 PackedScene" % scene_path)
		quit(1)
		return 1
	var instance := (packed as PackedScene).instantiate()
	if instance == null:
		print("PERF_FAILED: 实例化失败")
		quit(1)
		return 1
	root.add_child(instance)
	current_scene = instance

	var tree: SceneTree = self
	for i in range(WARMUP_FRAMES):
		await tree.process_frame

	_objects_start = Performance.get_monitor(Performance.OBJECT_COUNT)
	_nodes_start = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_objects_peak = int(_objects_start)
	_nodes_peak = int(_nodes_start)

	var start_usec := Time.get_ticks_usec()
	for i in range(_frames):
		await tree.process_frame
		var frame_usec := Performance.get_monitor(Performance.TIME_PROCESS) * 1_000_000.0
		_samples.append(frame_usec)
		_objects_peak = maxi(_objects_peak, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		_nodes_peak = maxi(_nodes_peak, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	var total_usec := Time.get_ticks_usec() - start_usec

	_report(total_usec)
	quit(0)
	return 0


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			var value := arg.split("=")[1]
			if value.is_valid_int() and int(value) > 0:
				_frames = int(value)


func _report(total_usec: int) -> void:
	_samples.sort()
	var count := _samples.size()
	if count == 0:
		print("PERF_FAILED: 没有采到帧")
		quit(1)
		return

	var sum := 0.0
	for s in _samples:
		sum += s
	var mean := sum / float(count)
	var p50 := _samples[count / 2]
	var p95 := _samples[mini(count - 1, int(float(count) * 0.95))]
	var p99 := _samples[mini(count - 1, int(float(count) * 0.99))]
	var worst := _samples[count - 1]
	var over_16 := 0
	var over_33 := 0
	for s in _samples:
		if s > 16667.0:
			over_16 += 1
		if s > 33333.0:
			over_33 += 1

	print("== PERF ==")
	print("frames        %d（预热 %d 帧后）" % [count, WARMUP_FRAMES])
	print("wall          %.1f ms  (%.1f fps)" % [
		total_usec / 1000.0, float(count) * 1_000_000.0 / float(maxi(1, total_usec))])
	print("process mean  %.3f ms" % (mean / 1000.0))
	print("p50           %.3f ms" % (p50 / 1000.0))
	print("p95           %.3f ms" % (p95 / 1000.0))
	print("p99           %.3f ms" % (p99 / 1000.0))
	print("worst         %.3f ms" % (worst / 1000.0))
	print(">16.7ms       %d 帧（%.1f%%）" % [over_16, 100.0 * float(over_16) / float(count)])
	print(">33.3ms       %d 帧（%.1f%%）" % [over_33, 100.0 * float(over_33) / float(count)])
	print("objects       %d → 峰值 %d" % [int(_objects_start), _objects_peak])
	print("nodes         %d → 峰值 %d" % [int(_nodes_start), _nodes_peak])
	print("render        %s" % ("headless（无绘制数据）"
		if DisplayServer.get_name() == "headless" else "窗口模式"))
	print("PERF_OK")


func _finalize() -> void:
	pass
