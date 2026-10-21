extends Node
## B3 回归：会话日志落盘 + 滚动清理。
##
## 运行：godot --headless --path . res://tests/test_log.tscn
##
## 用临时目录（user://logs_test）而不是 user://logs，避免测试把玩家真实日志覆盖掉。

const TEST_DIR := "user://logs_test"

var _fail := 0
var _total := 0


func _ready() -> void:
	print("TEST_LOG: start")
	_test_defaults()
	_test_write()
	_test_levels()
	_test_rotation()
	_test_cleanup()
	print("TEST_LOG: %s (%d assertions)" % [
		"FAIL" if _fail > 0 else "PASS", _total])
	await get_tree().process_frame
	get_tree().quit(1 if _fail > 0 else 0)


func _fresh_dir() -> void:
	DebugLog.close_session()
	var abs_dir := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.open(abs_dir).get_files():
			DirAccess.remove_absolute("%s/%s" % [abs_dir, f])
		DirAccess.remove_absolute(abs_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)


func _test_defaults() -> void:
	# headless 跑测试时没有 --log，所以默认不落盘。
	_check(DebugLog.logging == false, "未带 --log 时不写会话日志")
	_check(DebugLog.enabled == false, "未带 --hook-debug 时不写输入日志")
	# 未开时调 API 必须是安全空操作，不能崩也不能建文件
	DebugLog.info("T", "x")
	DebugLog.warn("T", "y")
	DebugLog.error("T", "z")
	_check(true, "未开日志时 info/warn/error 是空操作")
	var stats := DebugLog.stats()
	_check(int(stats.get("errors", -1)) == 0, "未开时不计错误数")


func _test_write() -> void:
	_fresh_dir()
	DebugLog.log_dir = TEST_DIR
	var opened := DebugLog.open_session()
	_check(opened, "open_session 成功")
	_check(DebugLog.logging, "logging 置为 true")
	_check(not DebugLog.session_path.is_empty(), "session_path 已赋值")
	_check(FileAccess.file_exists(DebugLog.session_path), "日志文件真的建出来了")

	DebugLog.info("TEST", "第一行")
	DebugLog.warn("TEST", "第二行")
	DebugLog.dump_state("DIAG", {"hp": 3, "state": "attack"})

	var text := FileAccess.get_file_as_string(DebugLog.session_path)
	_check(text.contains("SESSION"), "文件里有启动行")
	_check(text.contains("第一行"), "info 写进去了")
	_check(text.contains("第二行"), "warn 写进去了")
	# dump_state 走 JSON 序列化，键名会被引号包起来
	_check(text.contains("\"hp\""), "dump_state 写了结构化数据")
	_check(text.contains("INFO"), "行首有等级标记")


func _test_levels() -> void:
	var before := DebugLog.stats()
	DebugLog.error("TEST", "一个错误")
	DebugLog.error("TEST", "又一个错误")
	DebugLog.warn("TEST", "一个警告")
	var after := DebugLog.stats()
	_check(int(after["errors"]) - int(before["errors"]) == 2, "错误计数 +2")
	_check(int(after["warnings"]) - int(before["warnings"]) == 1, "警告计数 +1")
	var text := FileAccess.get_file_as_string(DebugLog.session_path)
	_check(text.contains("ERROR"), "错误行落盘")
	_check(text.contains("一个错误"), "错误内容落盘")


func _test_rotation() -> void:
	DebugLog.close_session()
	var abs_dir := ProjectSettings.globalize_path(TEST_DIR)
	# 造假 12 个旧日志，看打开新会话后是否只留 MAX_SESSION_LOGS 个
	for i in range(12):
		var f := FileAccess.open("%s/session_2026-01-%02d_00-00-00.log" % [abs_dir, i + 1],
			FileAccess.WRITE)
		f.store_line("old")
		f.close()
	DebugLog.log_dir = TEST_DIR
	var opened := DebugLog.open_session()
	_check(opened, "滚动后仍能开会话")
	var remaining := DirAccess.open(abs_dir).get_files().size()
	_check(remaining == DebugLog.MAX_SESSION_LOGS,
		"只保留 %d 个日志（got %d）" % [DebugLog.MAX_SESSION_LOGS, remaining])
	# 最老的几个应该被删掉，最新的还在
	_check(not FileAccess.file_exists("%s/session_2026-01-01_00-00-00.log" % abs_dir),
		"最老的日志被清理")
	_check(FileAccess.file_exists("%s/session_2026-01-12_00-00-00.log" % abs_dir),
		"最新的旧日志保留")


func _test_cleanup() -> void:
	DebugLog.close_session()
	_check(not DebugLog.logging, "close_session 后停止记录")
	DebugLog.log_dir = DebugLog.LOG_DIR
	var abs_dir := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.open(abs_dir).get_files():
			DirAccess.remove_absolute("%s/%s" % [abs_dir, f])
		DirAccess.remove_absolute(abs_dir)
	_check(not DirAccess.dir_exists_absolute(abs_dir), "测试目录已清理")


func _check(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
