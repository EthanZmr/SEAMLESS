# 雨市中庭重设计 · 总排期 + 第一阶段（可试玩切片）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 50 周总排期落到文档，并做出雨市第一个可试玩切片——诊所 + 吊桥市场（中庭）+ 排水沟，带能力解锁、零件、升降梯捷径、战斗锁门、沟爬子——用它验证"时长按必须完成的节拍算"是否成立。

**Architecture:** 能力集合存在 `GameState`（只存值、可序列化），`player.gd` 在每个动作入口查询；新关卡条目（零件、升降梯、战斗锁门、沟爬子）沿用"`level_src` 编辑场景 → `LevelExporter` → JSON → `level.gd` 生成"这条既有管线；新关卡 `rain_hub` 与旧 `rain_market` 并存，旧关卡在第五阶段结束后删除。

**Tech Stack:** Godot 4.7.2 / GDScript；门禁 `bash tools/test_all.sh`（headless，按文件头自动判型）+ `bash tools/lint.sh`（gdlint 4.5.0）。

**Spec:** `01_GDD/10_雨市地图重设计_v1.0.md`（已批准）；尺度规则 `01_GDD/09_角色与世界尺度_v1.0.md`。

## Global Constraints

- 所有命令在 `05_游戏工程/` 下运行；测试只用 `bash tools/test_all.sh [suite]`，不手敲 godot。
- 不改任何已 GO 的手感参数和帧表（`player_stats.tres`、`light_frames.tres`、`attack_spec.gd`）。
- 几何遵守 `09` §3：可站立净高 ≥ 96；单跳台阶 ≤ 110；二段跳台阶 130–210；单跳缺口 ≤ 160；钩点竖直高差 ≤ 260；可视 960 × 540。
- autoload 维持 12 个，不新增。
- 新 `extends Node` 测试配 `.tscn`；`extends SceneTree` 测试用 `_init` + `quit(code)`。
- 代码新建并会被 `get_node` 查找的节点，`add_child` 前显式设 `name`。
- 存档：只升 `GameState.STATE_VERSION`（2 → 3），不动 `SaveManager.SAVE_VERSION`。
- 提交信息：Conventional Commits 前缀 + 中文；结尾 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。

## Review Focus

1. **旧存档读入**：没有 `abilities` 字段的旧档应视为全部能力已解锁，旧档继续可玩（Task 1 测试）。
2. **复活不丢能力**：`GameState.reset()` 在每次断线复活时调用，绝不能清空能力（Task 1 测试）。
3. **重进关卡不重复拿零件**：已安装的零件在关卡重载后不再出现（Task 3 测试）。
4. **战斗锁门不能锁死**：锁门范围内没有活着的敌人时绝不关门；死在锁门里复活后门是开的（Task 5 测试）。
5. **未解锁时同步率满 100 不接管**：只有剧本调用 `start_takeover()` 才接管（Task 2 测试）。

---

## 总排期（50 周，W06 起）

每周约 21h 有效（25h × 85%）。W06–W50 剩余约 935h；下表计划约 810h，缓冲约 125h（13%，低于原计划的 21%，需在阶段门禁处盯紧）。

| 周 | 阶段 | 交付 | 门禁 |
|---|---|---|---|
| W06–W09 | **第一阶段：可试玩切片**（本计划） | 能力开关、零件、升降梯、战斗锁门、沟爬子、分段计时、诊所+中庭+排水沟白盒 | W09 末：开发者 ≥ 8 分钟、首次玩家 ≥ 15 分钟、攀爬爪 ≤ 8 分钟拿到 |
| W10–W13 | 第二阶段：地图 + 碎件 | 外卖骑手、残图、针眼"缝进地图"、锁标记、碎件/线头、买卖界面骨架 | 迷路约束：连续 5 分钟无进展 = 0 次 |
| W14–W17 | 第三阶段：上分支 | 霓虹巷屋顶白盒、跳闸工、量尺、吊线工头（③钩索）、单向门捷径 | 上分支首次 ≈ 12 分钟 |
| W18–W20 | 第四阶段：右分支 | 磁轨站白盒、盾卫、④墙跳、交易所/老猫（⑤气阀）、换人解锁剧情点 | 右分支 + 交易所首次 ≈ 14 分钟 |
| W21–W22 | 第五阶段：收束 | 裁断广场接入、线海残响、可选回访内容、删除旧 `rain_market` | 全程连跑 |
| W23 | **雨市 GO/NO-GO** | 首次玩家全程计时 | 40–60 分钟；第 9 节三条约束全过 |
| W24–W25 | Boss 重做 | 裁断者 P1–P3 按全能力重调 | 3–5 分钟强度 |
| W26–W37 | 美术 | 角色切件、6 种新敌人 + 小头目、雨市手绘分层环境、UI/VFX、零件安装演出 | 动作可读；截图可读 |
| W38–W41 | 音频 / 叙事 | 剧本按中庭结构重排、零件/线头/骑手台词、音效与音乐层 | 内容锁定前齐 |
| W42 | 内容锁定 | — | 不再加功能 |
| W43–W45 | 试玩与修复 | 5 人完整试玩、60fps、阻断 bug | 6 条验收全过 |
| W46–W47 | 构建 / 商店 | Windows 包、itch 页面 | 干净 PC 启动 |
| W48–W50 | 缓冲 / 发布 | — | 可发布 |

第二阶段起每个阶段开工前单独写详细计划（依赖第一阶段门禁结论）。

---

## 文件结构（第一阶段）

| 文件 | 责任 |
|---|---|
| `scripts/autoload/game_state.gd`（改） | 能力集合、零件表、`begin_new_game`、序列化与旧档迁移 |
| `scripts/autoload/game_events.gd`（改） | 新信号 `ability_unlocked`、`arena_cleared` |
| `scripts/player/player.gd`（改） | 每个能力入口的门控；完美弹反换人门控 |
| `scripts/level/part_pickup.gd` + `scenes/level/part_pickup.tscn`（新） | 零件拾取 → 安装 |
| `scripts/level/lift.gd` + `scenes/level/lift.tscn`（新） | 升降梯捷径 |
| `scripts/level/arena_gate.gd`（新） | 战斗锁门 |
| `scripts/enemies/crawler.gd` + `scenes/enemies/crawler.tscn`（新） | 沟爬子 |
| `scripts/rules/split_log.gd`（新，挂在 `main.tscn`） | 分段计时写进会话日志 |
| `scripts/level/authoring/level_entry.gd`、`level_exporter.gd`（改） | 新分类与可选字段 |
| `scripts/level/level.gd`（改） | 生成新条目 |
| `level_src/rain_hub.tscn`、`data/levels/rain_hub.json`、`data/levels/index.json`（新/改） | 切片关卡 |
| `scripts/ui/prologue.gd`、`scripts/autoload/level_manager.gd`（改） | 新游戏从无能力开始、默认关卡改为 `rain_hub` |
| `tests/test_abilities.*`、`tests/test_level_entries.*`、`tests/test_crawler.*`、`tests/test_rain_hub.*`（新） | 对应测试 |

**与 spec 的一处偏差（设计者的决定）**：spec §4 写"现有测试开头统一调用全部解锁"。改为：`GameState.abilities` 的**初始值是全部解锁**，只有"新游戏"（序章结束进入雨市）调用 `begin_new_game()` 清空。这样现有 10 个用到玩家的测试套件和原型场景零改动，新游戏路径仍从无能力开始。

---

### Task 0：排期与看板同步，提交上一轮未提交的改动

**Files:**
- Modify: `01_企划/03_预算与排期.md`（§2 周表、§3 工时、§4 "永远不砍"、§6 交付节点按上面的总排期改写；文首注明"v2：50 周，取代 32 周版"）
- Modify: `00_项目看板.md`（顶部当前阶段；§3 里程碑表换成总排期的阶段；§6 新增 D15）
- Modify: `09_项目看板/src/data/project.json`（`meta.weeks` 50、`meta.duration` "40–60 min（雨市首通）"、`milestones` 按总排期、`decisions` 追加 D15、D11 的 why 末尾加"；2026-10-22 由 D15 取代"、`changelog` 一条、`nextGate`）

- [ ] **Step 1：先提交上一轮的改动（两个提交）**

```bash
cd ~/Documents/SEAMLESS
git add 05_游戏工程/scripts/camera/game_camera.gd 01_GDD/09_角色与世界尺度_v1.0.md 01_GDD/04_ADR.md 01_GDD/08_主角形象与动作系统_v0.1.md 03_美术/16_赛璐璐风格规范_v0.1.md 06_测试/screenshots/SCALE_collision_fit_z2.png 06_测试/screenshots/SCALE_zoom_1_1.5_2.png CLAUDE.md
git commit -m "feat(camera): 角色尺度定稿，相机基础缩放 2.0（ADR-013）"
git add 01_GDD/10_雨市地图重设计_v1.0.md 01_GDD/10_雨市地图结构草图.html 06_测试/13_W6-01_A区扩段.md .gitignore 00_项目看板.md 09_项目看板 docs/superpowers/plans
git commit -m "docs(design): 雨市中庭辐射重设计与第一阶段计划"
```

- [ ] **Step 2：改写排期与看板（内容取自本计划"总排期"）**；D15 文本："雨市为第一关，首次通关 40–60 分钟，总排期 50 周"，why："W6-01 A 区不到 1 分钟；改按节拍算时长；见 `01_GDD/10`"。
- [ ] **Step 3：重建看板**：`node 09_项目看板/scripts/build-local.mjs` → 输出 `OK ...`。
- [ ] **Step 4：提交** `docs(plan): 排期改为 50 周，看板同步`。

---

### Task 1：GameState 能力集合与存档迁移

**Files:**
- Modify: `scripts/autoload/game_state.gd`、`scripts/autoload/game_events.gd`
- Create: `tests/test_abilities.gd`、`tests/test_abilities.tscn`
- Modify: `tests/test_save_migration.gd`（加一个用例）

**Interfaces:**
- Produces（`GameState`）：
  - `const ABILITIES := ["climb", "parry", "hook", "wall_jump", "double_jump", "dash", "switch"]`
  - `const PARTS := {"claw": ["climb"], "buffer": ["parry"], "launcher": ["hook"], "spring": ["wall_jump"], "valve": ["double_jump", "dash"]}`
  - `const PART_NAMES := {"claw": "攀爬爪", "buffer": "缓冲片", "launcher": "纤维发射器", "spring": "腿部弹簧", "valve": "气阀"}`
  - `var abilities: Dictionary`（键 = 能力 id，值 true；**初始值 = 全部 ABILITIES**）
  - `func has_ability(id: String) -> bool`
  - `func unlock_ability(id: String) -> bool`（新解锁返回 true 并发 `GameEvents.ability_unlocked(id)`；已有返回 false；未知 id `push_error` 并返回 false）
  - `func install_part(part_id: String) -> bool`（解锁该零件的全部能力；任一新解锁即返回 true；未知零件 `push_error` 返回 false）
  - `func unlock_all_abilities() -> void`
  - `func begin_new_game() -> void`（`abilities = {}`、`flags = {}`、然后 `reset()`）
  - `STATE_VERSION := 3`；`to_dict()` 增加 `"abilities": Array`（按 ABILITIES 顺序）；`from_dict()`：有 `abilities` 键则按它设置（忽略未知 id），**没有该键 → 全部解锁**
- Produces（`GameEvents`）：`signal ability_unlocked(id: String)`

- [ ] **Step 1：写失败测试** `tests/test_abilities.gd`（`extends Node`，结构照 `test_save_migration.gd` 的 `_check` 计数风格；`.tscn` 根节点挂此脚本）：
  - `_test_default_all()`：`GameState.unlock_all_abilities()` 后每个 ABILITIES 都 `has_ability`。
  - `_test_new_game_empty()`：`begin_new_game()` 后 7 个都为 false；`GameState.flags.is_empty()`。
  - `_test_unlock()`：`unlock_ability("climb") == true`；再调一次 `== false`；`unlock_ability("fly") == false`。
  - `_test_install_part()`：`begin_new_game()`；`install_part("valve") == true`；`has_ability("double_jump") and has_ability("dash")`；`install_part("valve") == false`。
  - `_test_reset_keeps()`：解锁 climb → `reset()` → 仍 `has_ability("climb")`。
  - `_test_roundtrip()`：解锁 climb、hook → `d := to_dict()` → `begin_new_game()` → `from_dict(d)` → 只有 climb、hook 为 true；`d["version"] == 3`。
  - `_test_legacy_without_abilities()`：`begin_new_game()` → `from_dict({"version": 2, "sync": 30.0})` → 7 个全 true。
  - 结束打印 `TEST_ABILITIES: PASS (N assertions)` / `FAIL`，`get_tree().quit(code)`；末尾 `GameState.unlock_all_abilities()` 复原，避免影响同进程后续内容。
- [ ] **Step 2：运行确认失败**：`bash tools/test_all.sh test_abilities` → FAIL（`has_ability` 不存在的编译错误也计失败）。
- [ ] **Step 3：实现上面 Interfaces 列出的全部成员**（`reset()` 不碰 `abilities`）。
- [ ] **Step 4：`test_save_migration.gd` 加 `_test_legacy_state_keeps_all_abilities()`**：照该文件现有"旧档升级"用例写一个 `state` 无 `abilities` 的旧档，`load_slot` 后断言 7 个能力全为 true。
- [ ] **Step 5：全量门禁**：`bash tools/test_all.sh` → `套件：通过 23，失败 0`；`bash tools/lint.sh` → 无问题。
- [ ] **Step 6：提交** `feat(state): 能力集合、零件表与旧档迁移`。

---

### Task 2：玩家能力门控 + 双意识门控

**Files:**
- Modify: `scripts/player/player.gd`、`scripts/autoload/game_state.gd`
- Modify: `tests/test_abilities.gd`（追加用例）

**Interfaces:**
- Consumes: `GameState.has_ability(id)`、`begin_new_game()`、`unlock_ability(id)`
- 门控位置（`player.gd`）：
  - `climb`：`_try_enter_climb()` 与 `_check_ledge_grab()` 开头未解锁即返回 false/不处理
  - `wall_jump`：`_handle_input` 里的墙跳分支，以及 `_apply_gravity` 里进入 `State.WALL_SLIDE` 的分支
  - `hook`：`_try_start_hook()` 开头
  - `double_jump`：`_handle_input` 里三处二段跳分支（post-hook-lock、`hook_air_charge`、normal）
  - `dash`：冲刺分支；`parry`：弹反分支；`switch`：`_switch_form` 输入分支
  - 完美弹反：`_on_perfect_parry()` 里 `GameState.set_form(1)` 仅在 `has_ability("switch")` 时执行（顿帧、同步率、反击窗口照旧）
- `GameState.add_sync()`：满 `MAX_SYNC` 时仅在 `has_ability("switch")` 时自动 `start_takeover()`；`start_takeover()` 本身不加门控（剧本调用）。

- [ ] **Step 1：追加失败测试**（`test_abilities.gd`，玩家用 `climb_prototype.tscn` 生成，输入模拟照 `test_movement.gd` 现有写法）：
  - `_test_locked_climb()`：`begin_new_game()`；玩家放在原型的攀爬区内按上 10 帧 → `state != Player.State.CLIMB`。
  - `_test_locked_hook()`：锚点在射程内按钩索 → `state != Player.State.HOOK`。
  - `_test_locked_double_jump()`：起跳到最高点再按跳 → 速度没有被重置为 `DOUBLE_JUMP_VERTICAL`（`velocity.y >= 0` 持续下落）。
  - `_test_locked_wall_jump()`：贴墙空中按跳 → `state != State.WALL_SLIDE` 且没有横向弹开（`absf(velocity.x) < WALL_JUMP_HORIZONTAL * 0.5`）。
  - `_test_locked_dash_parry_switch()`：分别按冲刺/弹反/换人 → `state` 不是 DASH/PARRY，`GameState.form == 0`。
  - `_test_sync_no_auto_takeover()`：`begin_new_game()`；`GameState.add_sync(100.0, true)` → `GameState.sync == 100.0` 且 `is_takeover == false`；`start_takeover()` → `is_takeover == true`（剧本路径可用）；收尾调用 `GameState.reset()`。
  - `_test_unlocked_climb()`：`unlock_ability("climb")` 后同一场景按上 → `state == State.CLIMB`。
- [ ] **Step 2：运行确认失败**：`bash tools/test_all.sh test_abilities` → FAIL。
- [ ] **Step 3：按 Interfaces 加门控。**
- [ ] **Step 4：全量门禁**：`bash tools/test_all.sh` → 23 套 0 失败（`test_movement` 等依赖默认全解锁，必须仍全绿）；`bash tools/lint.sh` 通过。
- [ ] **Step 5：提交** `feat(player): 能力门控与换人解锁前的双意识规则`。

---

### Task 3：关卡条目扩展 + 零件拾取

**Files:**
- Modify: `scripts/level/authoring/level_entry.gd`、`level_exporter.gd`、`scripts/level/level.gd`
- Create: `scripts/level/part_pickup.gd`、`scenes/level/part_pickup.tscn`、`tests/test_level_entries.gd`、`.tscn`
- Modify: `tests/test_level_authoring.gd`（追加用例）

**Interfaces:**
- `LevelEntry` 新导出字段：`point_b := Vector2.ZERO`、`has_point_b := false`、`surface := ""`、`drops := ""`（编辑器里 `point_b` 同样是世界坐标，`shift_east` 换算规则同 `boss_spawn`）。
- `LevelExporter.CATEGORIES` 在 `labels` 之前追加：`["parts", "point"]`、`["lifts", "point"]`、`["arenas", "rect"]`。
- JSON 键序：
  - `parts`：`{"kind": <零件 id>, "pos", "shift"}`
  - `lifts`：`{"kind": <升降梯 id>, "pos", "pos_b", "shift"}`
  - `arenas`：`{"rect", "kind": <锁门 id>, "shift"}`
  - `enemies`：在 `"shift"` 之后按需追加 `"pos_b"`（仅 `has_point_b`）、`"surface"`（非空）、`"drops"`（非空）；**都没有时与现有格式逐字节一致**。
- `PartPickup`（`scripts/level/part_pickup.gd`，`extends Area2D`）：`@export var part_id := ""`；`_ready` 里若该零件对应能力已全部拥有则 `queue_free()`；玩家进入 → `GameState.install_part(part_id)` → `GameEvents.message.emit("零件：%s。" % PART_NAMES[part_id])` 再 `emit("……嗯。能用。")` → 释放。安装演出（3–5 秒动作）留到美术阶段。
- `level.gd`：新增 `_spawn_parts()`、对应 `PART_SCENE` 预载；`_ready` 里在 `_spawn_patch()` 之后调用。

- [ ] **Step 1：失败测试**
  - `test_level_authoring.gd` 加 `_check_new_categories_roundtrip()`：构造含 `parts` 1 条、`lifts` 1 条（带 `pos_b`）、`arenas` 1 条、`enemies` 1 条（带 `pos_b`/`surface: "ceiling"`/`drops: "claw"`）的字典 → `dict_to_scene` → `scene_to_dict` → `to_json_text` 两次相等，且对应键存在。
  - `test_level_entries.gd`（`extends Node`）`_test_part_pickup()`：`begin_new_game()`；实例化 `part_pickup.tscn`（`part_id = "claw"`）与一个在 `player` 组里的 `CharacterBody2D` 重叠 → 两个物理帧后 `has_ability("climb")`、拾取物已释放；再实例化一个同 id 的拾取物 → `_ready` 后已排队释放。
- [ ] **Step 2：运行确认失败**：`bash tools/test_all.sh test_level_authoring test_level_entries` → FAIL。
- [ ] **Step 3：实现 Interfaces。**
- [ ] **Step 4：`rain_market` 回归**：`godot --headless --path . -s res://tools/export_level.gd -- rain_market --check` → `OK ... 一致`。
- [ ] **Step 5：全量门禁** → 24 套 0 失败；lint 通过。
- [ ] **Step 6：提交** `feat(level): 零件拾取与关卡条目扩展`。

---

### Task 4：升降梯捷径

**Files:** Create `scripts/level/lift.gd`、`scenes/level/lift.tscn`；Modify `scripts/level/level.gd`、`tests/test_level_entries.gd`

**Interfaces:**
- `Lift`（`extends AnimatableBody2D`，平台 96 × 16）：`@export var lift_id := ""`、`@export var stop_a := Vector2.ZERO`（JSON `pos`，激活开关所在端）、`@export var stop_b := Vector2.ZERO`（JSON `pos_b`）、`@export var speed := 160.0`。
- 激活：`stop_a` 处有一个开关区域，玩家在区域内按 `interact` → `GameState.set_flag("lift:" + lift_id)`。`_ready` 时若已有该 flag 则直接是激活状态。
- 行为：未激活时不动。激活后玩家站上平台 0.3 秒 → 驶向另一端；任一端的呼叫区域里有玩家而平台不在该端 → 驶来。
- `level.gd`：`_spawn_lifts()`。

- [ ] **Step 1：失败测试** `_test_lift()`：`begin_new_game()`；生成升降梯（`stop_a=(0,0)`、`stop_b=(0,-320)`）与站在平台上的测试玩家 → 1.0 秒后平台 y 不变；`GameState.set_flag("lift:t1")` 后重新生成 → 站上去 `320/160 + 0.3 + 0.5 = 2.8` 秒内到达 `stop_b`（误差 2px）。
- [ ] **Step 2：确认失败** → **Step 3：实现** → **Step 4：全量门禁全绿、lint 通过** → **Step 5：提交** `feat(level): 升降梯捷径`。

---

### Task 5：战斗锁门

**Files:** Create `scripts/level/arena_gate.gd`；Modify `scripts/level/level.gd`、`scripts/autoload/game_events.gd`、`tests/test_level_entries.gd`

**Interfaces:**
- `ArenaGate`（`extends Node2D`）：`@export var arena_id := ""`、`@export var rect := Rect2()`；在 `rect` 左右两边各建一扇门（`StaticBody2D`，宽 24、高 = `rect.size.y`，`name` 为 `DoorL`/`DoorR`），初始碰撞关闭。
- 玩家进入 `rect` 且 `rect` 内有存活的 `EnemyBase`（`not is_dead()`）→ 关门；`rect` 内敌人全部死亡 → 开门、`GameState.set_flag("arena:" + arena_id)`、发 `GameEvents.arena_cleared(arena_id)`。
- `_ready` 时已有 flag → 永不关门。玩家死亡（`GameEvents.player_died`）→ 开门，复活后可重新触发。
- `GameEvents`：`signal arena_cleared(id: String)`。

- [ ] **Step 1：失败测试**
  - `_test_arena_closes_and_opens()`：锁门 `rect=(0,0,600,300)`、一只清道夫在其中；测试玩家移入 → 两扇门碰撞开启；调用清道夫 `die()` → 门碰撞关闭、`has_flag("arena:a1")`。
  - `_test_arena_empty_never_closes()`：`rect` 内无敌人，玩家进入 → 门保持开。
  - `_test_arena_opens_on_death()`：关门后发 `GameEvents.player_died` → 门开。
- [ ] **Step 2：确认失败** → **Step 3：实现** → **Step 4：全量门禁、lint** → **Step 5：提交** `feat(level): 战斗锁门`。

---

### Task 6：沟爬子

**Files:** Create `scripts/enemies/crawler.gd`、`scenes/enemies/crawler.tscn`、`tests/test_crawler.gd`、`.tscn`；Modify `scripts/enemies/enemy_base.gd`、`scripts/level/level.gd`

**Interfaces:**
- `Crawler`（`class_name Crawler extends EnemyBase`，碰撞 28 × 20）：`@export var surface := "floor"`（`floor`/`wall`/`ceiling`）、`@export var point_a`/`point_b: Vector2`、`@export var crawl_speed := 60.0`、`@export var drop_dx := 40.0`；`max_hp = 20`、`attack_damage = 8`、`enemy_name = "沟爬子"`。
- 行为：贴附表面时不受重力，在 `point_a`/`point_b` 之间往返；`ceiling` 时玩家在其下方且 `|dx| < drop_dx` → 脱落下落；落地后按 `floor` 朝玩家爬行；与玩家重叠时每 0.8 秒一次 `player.receive_attack({"damage": attack_damage, "source": self, "parryable": false})`。
- 掉落放在基类：`EnemyBase` 增加 `@export var drops_part := ""`，`die()` 里非空则在死亡位置生成 `part_pickup.tscn`（`part_id = drops_part`）。所有敌人（含截线者）共用。
- `level.gd`：`enemies` 里 `kind == "crawler"` → 生成 `Crawler`，用 `pos`/`pos_b`/`surface`；任何 `kind` 的条目带 `drops` 时设置该敌人的 `drops_part`。

- [ ] **Step 1：失败测试** `test_crawler.gd`（`extends Node`，自建一条地面 + 一块天花板）：
  - `_test_patrol()`：天花板沟爬子 2 秒内 x 始终在 `[a.x-2, b.x+2]`，y 不变。
  - `_test_drop()`：玩家放到其正下方 → 1.5 秒内沟爬子 y 增大并落地（`is_on_floor()`）。
  - `_test_contact_damage()`：落地后与玩家重叠 1 秒 → `GameState.integrity` 下降 8（允许一次）。
  - `_test_drops_part()`：`drops_part = "claw"`，调用 `die()` → 场景中出现 `part_id == "claw"` 的 `PartPickup`；对一只 `lancer.tscn` 设 `drops_part = "buffer"` 后 `die()` 同样生成。
- [ ] **Step 2：确认失败** → **Step 3：实现** → **Step 4：全量门禁、lint** → **Step 5：提交** `feat(enemy): 沟爬子`。

---

### Task 7：分段计时日志

**Files:** Create `scripts/rules/split_log.gd`；Modify `scenes/main.tscn`（挂一个 `SplitLog` 节点）、`tests/test_level_entries.gd`

**Interfaces:**
- `SplitLog`（`extends Node`）：`_ready` 记 `t0 = Time.get_ticks_msec()`；订阅 `level_loaded`、`checkpoint_reached`、`ability_unlocked`、`arena_cleared`、`player_died`，每次 `DebugLog.log_event("SPLIT", {"t": 秒（1 位小数）, "what": 事件名, "detail": 字符串})`。
- 用 `--log` 运行时会话日志里出现 `SPLIT` 行，试玩后按时间读节拍。

- [ ] **Step 1：失败测试** `_test_split_log()`：生成 `SplitLog`，发 `GameEvents.ability_unlocked.emit("climb")` → `DebugLog` 收到一条 tag 为 `SPLIT` 且 `what == "ability_unlocked"` 的事件（照 `test_log.gd` 现有的日志断言方式取最近事件）。
- [ ] **Step 2：确认失败** → **Step 3：实现** → **Step 4：全量门禁、lint** → **Step 5：提交** `feat(debug): 分段计时日志`。

---

### Task 8：切片白盒 `rain_hub`

**Files:**
- Create: `level_src/rain_hub.tscn`（用 `LevelAuthoring` 摆）、`data/levels/rain_hub.json`（由导出器生成）、`tests/test_rain_hub.gd`、`.tscn`
- Modify: `data/levels/index.json`（加 `rain_hub`，`order` 1、`scene` `res://scenes/main.tscn`、`data` `res://data/levels/rain_hub.json`；`rain_market` 的 `order` 改 2）、`scripts/autoload/level_manager.gd`（`DEFAULT_LEVEL_ID = "rain_hub"`）、`scripts/ui/prologue.gd`（`start_level` 之前调用 `GameState.begin_new_game()`）、`tests/test_level_save.gd`（"第一关"断言改为 `rain_hub`，原 `rain_market` 断言改为按 id 查）

**节拍清单（必须全部出现；坐标由搭建者定，遵守 `09` §3）**

| # | 区域 | 节拍 | 必须性 | 首次时长预算 |
|---|---|---|---|---|
| 1 | 诊所（2 × 1 屏） | 出生、针眼 | — | — |
| 2 | 诊所后门 | 战斗锁门 `clinic_back`：2 清道夫 | 必须 | 1 分钟 |
| 3 | 中庭（3 × 4 屏）下层 | 初探三层；能看到：上方绿色梯缝（需攀爬）、右侧 ≥ 420 宽缺口与对岸粉色锚点（需钩索）、远处交易所招牌（远景标签占位） | — | 2 分钟 |
| 4 | 中庭中层 | 针眼 | — | — |
| 5 | 中庭下层 → 排水沟 | 开局唯一能走的出口 | 必须 | — |
| 6 | 排水沟（6 × 2 屏）一段 | 天花板沟爬子走廊（≥ 3 只） | 必须 | 3 分钟 |
| 7 | 排水沟二段 | 战斗锁门 `drain_mid`：2 沟爬子 + 1 清道夫 | 必须 | 2 分钟 |
| 8 | 排水沟尽头 | 精英沟爬子 `drops: "claw"` → ①攀爬爪 | 必须 | 1 分钟 |
| 9 | 排水沟出口 | 绿色梯缝（需攀爬）→ 升降梯 `drain_lift` 开关 | 必须 | 1 分钟 |
| 10 | 升降梯 → 中庭中层 | 捷径打开 | — | — |
| 11 | 中庭 | 截线者 `drops: "buffer"` → ②弹反（掉落逻辑在 `EnemyBase`，见 Task 6） | 必须 | 2 分钟 |
| 12 | 中庭上层入口 | 攀爬后可上；第一阶段在此放"未完成"墙 | — | — |

合计首次约 12–15 分钟（开发者目标 ≥ 8 分钟）。任何位置到最近针眼 ≤ 2 分钟路程。

- [ ] **Step 1：失败测试** `test_rain_hub.gd`（`extends Node`，读 `rain_hub.json` 做结构断言）：
  - 针眼 == 2；`arenas` 至少含 `clinic_back`、`drain_mid`；`lifts` 含 `drain_lift` 且带 `pos_b`；`enemies` 中恰有 1 个 `drops == "claw"`、1 个 `drops == "buffer"`；`kind == "crawler"` 的敌人 ≥ 6。
  - 中庭右侧缺口：不存在任何平台的水平区间落在缺口内（缺口两端 x 由 `labels` 中 `kind == "gap_marker"` 的两条标记给出；搭建者在编辑场景里放这两条标记；`level.gd` 生成文字时跳过 `gap_marker`，游戏里不显示）。
  - `LevelManager.level_ids()[0] == "rain_hub"`。
- [ ] **Step 2：确认失败** → **Step 3：在 `level_src/rain_hub.tscn` 摆放**，`godot --headless --path . -s res://tools/export_level.gd -- rain_hub` 导出；按 Files 改 index / level_manager / prologue / test_level_save。
- [ ] **Step 4：全量门禁**：`bash tools/test_all.sh` 全绿（含 `test_level_authoring` 对 `rain_hub` 的一致性检查）；lint 通过。
- [ ] **Step 5：手动冒烟**：`godot --path . -- --log` 从序章进入，确认无能力开局、能走通 1–11。
- [ ] **Step 6：提交** `feat(level): 雨市切片白盒 rain_hub`。

---

### Task 9：切片试玩与第一阶段门禁

**Files:** Create `06_测试/14_W09_雨市切片.md`；Modify `00_项目看板.md`、`09_项目看板/src/data/project.json`

- [ ] **Step 1：开发者试玩**：`godot --path . -- --log`，从序章开始到中庭拿到弹反；从 `user://logs/` 最新会话日志取全部 `SPLIT` 行。
- [ ] **Step 2：首次玩家试玩**（至少 1 人，没玩过本作），同样取 `SPLIT`。
- [ ] **Step 3：写记录**：每个节拍的实际用时、死亡位置、是否出现"连续 5 分钟无进展"；对照门禁——开发者 ≥ 8 分钟、首次玩家 ≥ 15 分钟、攀爬爪 ≤ 8 分钟（首次玩家）。
- [ ] **Step 4：GO/NO-GO 结论写进看板**（`node 09_项目看板/scripts/build-local.mjs` 重建）。NO-GO 时在记录里写明哪类节拍偏短，第二阶段计划开工前先调整节拍清单。
- [ ] **Step 5：提交** `test(playtest): 雨市切片试玩记录`。
