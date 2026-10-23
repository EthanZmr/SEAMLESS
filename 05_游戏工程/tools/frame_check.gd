class_name FrameCheck
extends RefCounted
## 逐帧图的自动检查与审图拼图（`03_美术/28` §6）。全部 static，check_frames.gd 与测试共用。


## 单张检查：返回问题列表（空 = 通过）。i 从 1 起。
static func check_image(img: Image, i: int, spec: FrameSet) -> PackedStringArray:
	var errs := PackedStringArray()
	if img == null or img.is_empty():
		errs.append("读不到图")
		return errs
	if img.get_size() != spec.canvas:
		errs.append("画布 %dx%d，应为 %dx%d" % [img.get_width(), img.get_height(), spec.canvas.x, spec.canvas.y])
		return errs
	if not img.detect_alpha():
		errs.append("没有透明底")
		return errs
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		errs.append("整张是空的")
		return errs
	if used.position.x <= 0 or used.position.y <= 0 \
			or used.end.x >= spec.canvas.x or used.end.y >= spec.canvas.y:
		errs.append("碰到画布边（不透明范围 %s）" % str(used))
	var lowest := used.end.y - 1
	if spec.is_airborne(i):
		if lowest > spec.anchor.y + spec.baseline_tolerance:
			errs.append("腾空张最低像素在第 %d 行，低于基线 %d" % [lowest, spec.anchor.y])
	elif absi(lowest - spec.anchor.y) > spec.baseline_tolerance:
		errs.append("脚底基线在第 %d 行，应为 %d ±%d" % [lowest, spec.anchor.y, spec.baseline_tolerance])
	return errs


## 最低不透明像素行（-1 = 空图）。
static func lowest_row(img: Image) -> int:
	var used := img.get_used_rect()
	return used.end.y - 1 if used.size != Vector2i.ZERO else -1


## 并排图：各张缩到 scale 后横排在灰底上。
static func contact_sheet(images: Array[Image], scale: float) -> Image:
	var cell := Vector2i((Vector2(images[0].get_size()) * scale).round())
	var sheet := Image.create(cell.x * images.size(), cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.45, 0.47, 0.5))
	for k in range(images.size()):
		var small := _scaled(images[k], cell)
		sheet.blend_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * k, 0))
	return sheet


## 洋葱皮：各张按 1/n 透明度叠在深底上，头发、下摆抖动会显成重影。
static func onion(images: Array[Image], scale: float) -> Image:
	var cell := Vector2i((Vector2(images[0].get_size()) * scale).round())
	var out := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.08, 0.12))
	var fade := 1.0 / float(images.size()) * 2.0
	for img in images:
		var small := _scaled(img, cell)
		for y in range(cell.y):
			for x in range(cell.x):
				var c := small.get_pixel(x, y)
				if c.a > 0.0:
					small.set_pixel(x, y, Color(c.r, c.g, c.b, minf(c.a * fade, 1.0)))
		out.blend_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i.ZERO)
	return out


static func _scaled(img: Image, size: Vector2i) -> Image:
	var copy := img.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	copy.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return copy
