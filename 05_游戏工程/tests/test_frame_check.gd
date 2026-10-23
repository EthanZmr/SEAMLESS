extends SceneTree
## FrameSet 帧序与 FrameCheck 单张检查（`03_美术/28`）。
## Run: bash tools/test_all.sh test_frame_check

var _total := 0
var _fails := 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	_test_frame_set()
	_test_check_image()
	_test_sheets()
	if _fails == 0:
		print("TEST_FRAME_CHECK: PASS (%d assertions)" % _total)
		return 0
	print("TEST_FRAME_CHECK: FAIL (%d)" % _fails)
	return 1


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fails += 1
		print("  FAIL  ", label)


func _test_frame_set() -> void:
	var spec := FrameSet.load_or_default("res://data/anim/zhen_run.tres")
	_check(spec.validate().is_empty(), "zhen_run.tres 合法")
	_check(spec.count == 8 and spec.cycle_frames() == 40, "8 张 × 5 帧 = 40 帧循环")
	_check(spec.canvas == Vector2i(768, 576) and spec.anchor == Vector2i(384, 560), "画布 768x576、锚点 (384,560)")
	_check(spec.path_of(3) == "res://assets/characters/zhen/run/char_zhen_run_03.png", "第 3 张路径")
	_check(spec.index_at(0) == 0 and spec.index_at(4) == 0 and spec.index_at(5) == 1, "每张停 5 帧")
	_check(spec.index_at(39) == 7 and spec.index_at(40) == 0, "第 40 帧回到第 1 张")
	_check(spec.anchor_from_center() == Vector2(0, 272), "锚点相对画布中心 (0,272)")

	var once := FrameSet.new()
	once.loop = false
	_check(once.index_at(1000) == 7, "不循环的动作停在最后一张")

	var bad := FrameSet.new()
	bad.holds = PackedInt32Array([5, 5])
	_check(not bad.validate().is_empty(), "holds 长度不等于 count → 不合法")
	_check(FrameSet.load_or_default("res://data/anim/missing.tres").count == 8, "文件缺失 → 内建默认值")


## 造一张合规的帧：透明画布上一块不透明矩形，底边落在 bottom 行。
func _frame(spec: FrameSet, bottom: int, left := 300, right := 470, top := 120) -> Image:
	var img := Image.create(spec.canvas.x, spec.canvas.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(left, top, right - left, bottom - top + 1), Color(0.3, 0.25, 0.22, 1.0))
	return img


func _test_check_image() -> void:
	var spec := FrameSet.new()
	_check(FrameCheck.check_image(_frame(spec, 560), 1, spec).is_empty(), "基线 560 → 通过")
	_check(FrameCheck.check_image(_frame(spec, 562), 1, spec).is_empty(), "基线 562（容差 2）→ 通过")
	_check(not FrameCheck.check_image(_frame(spec, 565), 1, spec).is_empty(), "基线 565 → 不通过")
	_check(not FrameCheck.check_image(_frame(spec, 540), 2, spec).is_empty(), "着地张悬空 20px → 不通过")
	_check(FrameCheck.check_image(_frame(spec, 520), 4, spec).is_empty(), "腾空张高于基线 → 通过")
	_check(not FrameCheck.check_image(_frame(spec, 566), 4, spec).is_empty(), "腾空张低于基线 → 不通过")
	_check(not FrameCheck.check_image(_frame(spec, 560, 0), 1, spec).is_empty(), "碰到左边 → 不通过")
	_check(not FrameCheck.check_image(_frame(spec, 560, 300, 470, 0), 1, spec).is_empty(), "碰到顶边 → 不通过")

	var wrong := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	_check(not FrameCheck.check_image(wrong, 1, spec).is_empty(), "画布 512x512 → 不通过")
	var opaque := Image.create(spec.canvas.x, spec.canvas.y, false, Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	_check(not FrameCheck.check_image(opaque, 1, spec).is_empty(), "没有透明底 → 不通过")
	var empty := Image.create(spec.canvas.x, spec.canvas.y, false, Image.FORMAT_RGBA8)
	_check(not FrameCheck.check_image(empty, 1, spec).is_empty(), "整张透明 → 不通过")


func _test_sheets() -> void:
	var spec := FrameSet.new()
	var images: Array[Image] = []
	for k in range(spec.count):
		images.append(_frame(spec, 560 - k))
	var sheet := FrameCheck.contact_sheet(images, 0.5)
	_check(sheet.get_size() == Vector2i(384 * 8, 288), "并排图 8 格，每格缩到一半")
	var onion := FrameCheck.onion(images, 0.5)
	_check(onion.get_size() == Vector2i(384, 288), "洋葱皮与单格同尺寸")
	_check(onion.get_pixel(192, 200).r > onion.get_pixel(5, 5).r, "洋葱皮里角色比底色亮")
