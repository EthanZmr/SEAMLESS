# 钩跳 DEBUG 模式与复测记录

日期：2026-10-20
对应版本：Godot 4.7.2 · W3 B 区路线
目的：把“钩中二段跳偶发失败”从主观手感变成可读日志，定位真实输入路径。

## 1. 如何开启

- DEBUG 构建启动即开启（`DebugLog.enabled = OS.is_debug_build()`）。
- 主场景 HUD 右上角出现 `DEBUG · player.gd hook trace` 面板，实时显示：
  - `STATE` / `VEL` / `DOUBLE`
  - `LOCK` / `CHARGE` / `HOOK` / `DIST`
  - `BUF JUMP` / `BUF HOOK` 的输入缓冲时间戳
- 日志文件（每次启动覆盖）：
  `%APPDATA%\Godot\app_userdata\无缝 SEAMLESS\hook_debug.log`
  对应 Godot 路径 `user://hook_debug.log`；启动时输出绝对路径。
- 日志事件：`SESSION`、`INPUT`、`PRESS`、`CONSUME`、`CLEAR`、`HOOK_START`、`HOOK_JUMP`、`END_HOOK`、`FREE_JUMP`、`DOUBLE_JUMP`、`HOOK_BLOCKED`、`COLLISION`、`RESPAWN`。

## 2. 本次新增的固定可复现测试

### 2.1 输入时序扫描（168 组）

脚本：`tests/hook_sweep.gd` + `tests/hook_sweep.tscn`
- 钩索按住时长：6 帧（约 100ms）到 20 帧（约 333ms）
- H 松开到 Space 的延迟：0 / 2 / 5 帧
- 钩中 Space 相对断钩的时机：`-2 / -1 / 0 / +1 / +2 / +4` 帧
- 第二下 Space 相对第一下：`+10 / +20 / +30` 帧
- 全部组合：168；失败：0
- 日志：`06_测试/logs/hook_sweep_W3.log`（`HOOK_SWEEP cases=168 fails=0`）

### 2.2 定向测试

- `test_movement`：69/69 PASS，含重叠锚点、同帧起手、立即二段、钩中遮挡断钩、到达后延迟按 Space。
- `test_scene`：39/39 PASS，含序章/雨市/Boss/HUD。
- `test_runner`：16/16 PASS，逻辑层。
- `main.tscn` / `hook_sweep.tscn` headless 退出 0。

## 3. 目前结论与限制

- 确定性时序下，钩中二段跳全部通过；未复现失败。
- 因此下一轮不再猜“时序公式”，改为读取真实输入日志：看失败瞬间是否出现 `HOOK_JUMP`，以及当时 `DOUBLE` / `LOCK` / `BUF JUMP` 的值。
- 已知限制：扫描使用 `InputEventAction`，不等于真实键盘/焦点/按键重复；真人复测仍是最终判据。
- 已知限制：日志是逐事件写盘并 flush，极长会话会变大；当前一次会话约几十 KB，可接受。

## 3.1 一次真实输入日志的观察

在一次脚本化的真实输入会话中，日志已经能完整串起成功路径：

- `HOOK_JUMP`：`state=HOOK`，`double=true`，起跳后速度 `-520`。
- 约 450ms 后第二次 Space：`DOUBLE_JUMP source=normal`，`double=true`，说明钩跳后的二段确实走通。
- 另一次会话中 `HOOK_COLLISION` 在 `pos=(845.9,253.1)` 触发，随后 `HOOK_END arrived=false`，这是“隔着小跳台按 H 被卡住”的修复路径，不是二段跳输入丢失。

因此目前不再猜“时序公式”；失败时以日志里是否出现 `HOOK_JUMP`、以及 `DOUBLE`/`BUF JUMP` 的值为准。

## 3.2 用户复现日志的根因与修复（2026-10-20）

用户复现时 HUD 为 `STATE FALL / DOUBLE NO`。日志里对应路径：

- `[135714] HOOK_END arrived=true`：钩索到达锚点，`double=true`。
- `[135893] INPUT jump`：**179ms** 后按 Space。
- `[135897] DOUBLE_JUMP source=normal`：这次 Space 被当成普通二段跳消费，`double` 变 `false`。
- 下一次 Space 就没有二段了。

根因是断钩后的“免费跳”窗口只有 **0.15s**；玩家在到达后约 0.18s 按 Space，窗口已过期，于是按普通二段跳处理，直接烧掉空中跳。不是输入丢失，也不是钩跳分支没走。

修复：

- 新增常量 `HOOK_FREE_JUMP_TIME := 0.45`，断钩/到达后的第一次 Space 都按免费跳处理。
- 断钩和到达都恢复 `double_jump_available=true`；免费跳不消耗二段。
- 新增“到达后 14 帧再按 Space”定向测试：第一次免费跳、第二次二段，连续跑 3 次全过。
- 移动测试 69/69；集成 39/39；168 组时序扫描 0 失败；main headless 0。

## 4. 复测步骤

1. 从 DEBUG 构建启动游戏，确认右上角 `DEBUG · player.gd hook trace`。
2. 走到 B 区，按 H 钩住锚点，钩中按 Space 跳，再按一次 Space。
3. 如果失败：记下面板上的 `STATE / DOUBLE / LOCK / BUF JUMP`，然后正常退出游戏。
4. 把 `%APPDATA%\Godot\app_userdata\无缝 SEAMLESS\hook_debug.log` 发给制作人。
5. 日志里搜索 `HOOK_JUMP`；若没有，说明第一跳没走钩跳分支；若有但 `DOUBLE false`，说明二段被提前消费或未恢复。

## 5. 验收

- [x] 真人完整走一次 B 区钩索段，无“钩中按 Space 没反应”。（2026-10-20 用户确认测试通过）
- [x] 失败时能在 `hook_debug.log` 中找到对应时间戳与状态。
- [x] 修复后 168 组扫描 0 失败，69/39/16 全过。
