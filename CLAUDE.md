# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目

《无缝》SEAMLESS：Godot 4.7.2 · 2D · GDScript 单人动作游戏，目标是 25–30 分钟独立短篇《无缝：序章·雨市》。仓库同时纳管策划、美术、工程、构建。

- 先读 `00_项目看板.md`：当前阶段、已冻结范围（含「明确不做」清单）、已拍板决策 D1–D10、待决问题。范围外的功能不要做。
- Godot 工程本体在 `05_游戏工程/`。所有 godot 命令、`tools/*.sh` 都在这个目录下运行。
- 工程细节（分层、数据分离、踩过的坑）以 `05_游戏工程/README.md` 和 `05_游戏工程/docs/architecture-v1.md` 为准，本文件只摘要。

## 常用命令

在 `05_游戏工程/` 下运行：

```bash
godot --path . --editor --quit          # 全新 checkout 首次导入（生成 .godot/）
godot --path .                          # 运行（入口 scenes/prologue.tscn）
godot --path . -- --log                 # 运行 + 会话日志 user://logs/
godot --path . -- --hook-debug          # 输入密集调试 user://hook_debug.log

bash tools/test_all.sh                  # 门禁：全部 22 个无头测试套件
bash tools/test_all.sh test_scene       # 只跑指定套件（可多个，名字 = tests/ 下文件名去扩展名）
bash tools/lint.sh                      # gdlint + 全量编译检查
bash tools/export_check.sh              # Windows/Linux/Web 三平台导出（需导出模板）

godot --headless --path . -s res://tools/gen_data.gd -- --force   # 重新生成 data/ 下数据文件
godot --headless --path . -s res://tools/export_level.gd -- rain_market   # 关卡编辑场景 → JSON
godot --headless --path . -s res://tools/perf_probe.gd            # 帧时间基线
```

- **跑测试只用 `tools/test_all.sh`，不要手敲 godot 命令。** `extends SceneTree` 的测试要用 `-s` 跑，`extends Node` 的要用 `.tscn` 跑。模式选错时 autoload 不加载、脚本编译失败，Godot 却仍返回 0，造成假绿。脚本会先 `--import` 重建 class_name 缓存，再按文件头自动判型，并把 `Compile Error`/`SCRIPT ERROR` 计为失败。
- 新测试放 `tests/` 即可，不需要注册。
- 本机 `godot` 由 Homebrew 装在 PATH 中；也可用 `GODOT=/path/to/godot` 指定。看板里的 WinGet 路径是旧 Windows 环境遗留。
- 本机未装 gdlint 时 `lint.sh` 会跳过 gdlint 部分；CI 强制跑（`pip install "gdtoolkit==4.5.0"`）。
- CI（`.github/workflows/gate.yml`）：push/PR 跑 import → test_all → lint；导出只在手动触发时跑。

## 架构要点

分层（详见工程 README「架构分层」）：L0 世界（`level_manager`/`save_manager`）→ L1 规则（`rules/game_loop.gd`）→ L2 实体（player/enemies/boss）→ L3 表现（`ui/`）→ L4 基础设施（`autoload/`）。改代码时要守的硬规则：

- `change_scene_to_file` 只出现在 `level_manager.gd`。
- `game_state.gd` 没有 `_process`，规则推进只在 GameLoop。
- UI 只消费 `GameEvents` 快照，不引用 Player 类型。
- 敌人状态用 `enum`，迁移只走 `_set_state()`。敌人继承链 `EnemyBase → MeleeChaser → Sweeper/Lancer`，Boss 不继承。
- autoload 固定 12 个，有依赖顺序（`DebugLog → Fonts → Settings → Loc → InputSetup → InputRebind → InputBuffer → GameState → GameEvents → LevelManager → SaveManager → HitStop`）。加第 13 个要写明理由。
- 暂停用 `get_tree().paused`，顿帧/慢动作用 `hit_stop.gd` 的 `push_scale/pop_scale` 栈，不要直接写 `Engine.time_scale`。
- 空间查询 `MovementProbe`/`AttackProbe` 全 static、只读，不持有节点，可脱离 `main.tscn` 单测。
- 键盘绑定唯一真相是 `InputRebind`，`InputSetup` 只管手柄；动作由代码注册，不迁回 InputMap（ADR-011）。
- 战斗判定、取消窗、顿帧只由帧表驱动；接入动画后动画只跟随帧号，不用 AnimationPlayer 方法轨道触发命中或状态迁移（ADR-012）。
- 存档原子写（`.tmp` → rename），走版本链迁移。版本号有两层：`SaveManager.SAVE_VERSION` 管文件格式，`GameState.STATE_VERSION` 管状态结构。加字段只动对应那一层。

**关卡**：在 `level_src/<id>.tscn` 里摆（`LevelAuthoring` 根 + 按 JSON 键命名的容器 + `LevelEntry` 条目），用 `tools/export_level.gd` 导出成 `data/levels/<id>.json`，运行时只读 JSON。不要手改关卡 JSON；改了场景必须导出，`test_level_authoring` 会检查两者一致。

**数据分离**：数值和内容不写在脚本里。攻击帧表、玩家数值、同步规则用 `data/**/*.tres`；关卡几何、关卡清单、对白用 `.json`；界面文案用 `data/loc/strings.csv`。加载失败时静默回退到脚本内置默认值，只 `push_warning`。

- 轻击三段数值分两处：帧表（判定帧、取消窗、顿帧、终结技 punch）在 `scripts/combat/attack_spec.gd` + `data/combat/light_frames.tres`；时长、判定时刻、距离、伤害、击退在 `data/player/player_stats.tres` 的 `COMBO_*`。两边由 `tests/test_combo_consistency.gd` 对齐，改一边必须改另一边。改帧数/判定/取消窗口时，还要同步 `03_美术/24_*`、`03_美术/26_*` 生产规格和 `01_GDD/08_主角形象与动作系统_v0.1.md` 的对应章节。
- `AttackFrames` 默认值是中性哨兵（0/false/[]），真实数值必须显式写进 `.tres`，否则 `validate()` 失败、回退内置帧表。
- 敌人 layer 4、玩家 layer 2 互不碰撞，位移相关的距离下限要用数值兜底。

## 已知陷阱（改动后自查）

- 字符串状态改成 `enum` 后，全项目 grep `state == "`、`state != "`、`state = "`，`tests/` 和 `scripts/prototype/` 也要搜。
- `ConfigFile.get_value()` 缺键时传 `null` 默认值会报错，先 `has_section_key()`。断言默认值时不要传第三参。
- 代码里新建的、会被 `get_node` 查找的节点，`add_child` 前显式设置 `name`。
- `extends SceneTree` 的脚本逻辑放进 `_run() -> int`，由 `_init()`/`_initialize()` 统一 `quit(code)`，否则抛错后进程空转挂死 CI。
- HitStop 在 headless 下自动禁用，测试里不要依赖顿帧时长。

## 工作流约定

- 「headless 门禁通过」不等于「GO」。手感类任务（攀爬、钩索、战斗、关卡计时）需要用户真人手测确认后，才能在看板标 GO。
- 完成一项任务后更新 `00_项目看板.md`（顶部「当前阶段」+ 对应任务行 + 测试计数），并在 `09_项目看板/src/data/project.json` 的 `changelog` 记一条，然后 `cd 09_项目看板 && node scripts/build.mjs` 重建看板。
- 测试记录写到 `06_测试/`（编号递增的 md + `screenshots/`、`logs/`）。
- 提交信息：Conventional Commits 前缀 + 中文描述，例如 `feat(ui): ...`、`refactor(arch): ...`。
- 美术方向是**横版 Q 版赛博朋克**（不是赛璐璐、不是像素），规格见 `03_美术/16_Q版赛博朋克风格规范_v1.0.md`（ADR-014）；动画标注一律 60 fps 逻辑帧；空中攻击 = 平刺；动作分解图逐张意见见 `03_美术/27_动作逐帧分解11张评审_v1.0.md`。
- 尺度：角色精灵世界高 64、碰撞 28×56、相机 `base_zoom` 2.0、可视 960×540。摆关卡按 `01_GDD/09_角色与世界尺度_v1.0.md` §3 的净高/台阶/缺口/钩点规则（ADR-013）。玩家目前是锁定形象 v4 的静态占位贴图，敌人与场景仍是几何占位，尚未接入动画、音频。
