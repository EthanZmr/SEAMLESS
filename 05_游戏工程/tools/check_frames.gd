extends SceneTree
## 逐帧图检查（`03_美术/28` §6）：画布尺寸、透明底、出界、着地张基线；输出并排图和洋葱皮。
## Run: godot --headless --path . -s res://tools/check_frames.gd [-- --spec res://data/anim/zhen_run.tres]
## 退出码：0 = 全过，1 = 有问题或缺图。

const DEFAULT_SPEC := "res://data/anim/zhen_run.tres"
const OUT_DIR := "user://frame_check"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var spec_path := DEFAULT_SPEC
	var args := OS.get_cmdline_user_args()
	var at := args.find("--spec")
	if at >= 0 and at + 1 < args.size():
		spec_path = args[at + 1]
	var spec := FrameSet.load_or_default(spec_path)
	print("== 检查 %s（%d 张，画布 %dx%d，基线 %d）==" % [
		spec.anim_name, spec.count, spec.canvas.x, spec.canvas.y, spec.anchor.y])

	var images: Array[Image] = []
	var failed := 0
	for i in range(1, spec.count + 1):
		var path := spec.path_of(i)
		var abs_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(path):
			print("  FAIL  %02d  缺图：%s" % [i, abs_path])
			failed += 1
			continue
		var img := Image.load_from_file(abs_path)
		var errs := FrameCheck.check_image(img, i, spec)
		if errs.is_empty():
			print("  ok    %02d  脚底最低行 %d%s" % [i, FrameCheck.lowest_row(img), "（腾空）" if spec.is_airborne(i) else ""])
			images.append(img)
		else:
			print("  FAIL  %02d  %s" % [i, "；".join(errs)])
			failed += 1
			if img != null and not img.is_empty():
				images.append(img)

	if images.size() == spec.count and _same_size(images):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		var sheet_path := "%s/%s_sheet.png" % [OUT_DIR, spec.anim_name]
		var onion_path := "%s/%s_onion.png" % [OUT_DIR, spec.anim_name]
		FrameCheck.contact_sheet(images, 0.5).save_png(sheet_path)
		FrameCheck.onion(images, 0.5).save_png(onion_path)
		print("并排图：", ProjectSettings.globalize_path(sheet_path))
		print("洋葱皮：", ProjectSettings.globalize_path(onion_path))

	if failed == 0:
		print("CHECK_FRAMES: PASS")
		return 0
	print("CHECK_FRAMES: FAIL (%d)" % failed)
	return 1


func _same_size(images: Array[Image]) -> bool:
	for img in images:
		if img.get_size() != images[0].get_size():
			return false
	return true
