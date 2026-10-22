# 无缝 SEAMLESS · 项目看板

## 本地看板 v2（推荐）

`local/index.html` 是零依赖的单文件看板，双击即开，不需要 Remotion 运行时、npm 或服务器。
数据仍来自 `src/data/project.json`，构建脚本只把 JSON 写进页面里的 `<script id="project-data">` 数据块：

```bash
node 09_项目看板/scripts/build-local.mjs
```

页面结构、样式、动效都在 `local/index.html` 里，直接改即可。动效：进度带从 W0 缝到当前周、指标数字滚动、测试条与风险点依次出现、背景雨；系统开启「减少动态效果」时全部关闭。

## Remotion 版 v1.2

《无缝》垂直切片（序章 + 雨市 + 裁断者）的项目控制台。  
一个**无需服务器、无需联网、双击即开**的静态 HTML：外壳是项目数据面板，中央四章是**页面内实时渲染的 DOM 动效**，不是视频。

- 产物：`dist/index.html`（单文件，含 CSS + JS；图片与图标在 `dist/assets/`）
- 数据源：`src/data/project.json`
- 动效：`src/chapters/*.jsx` + `src/live/LiveClock.jsx`
- 外壳：`src/main.jsx` + `src/styles.css`
- 构建：`node scripts/build.mjs`（复用 dsh-remotion 托管运行时里的 React / Remotion / esbuild，不安装依赖）

## 关键实现

- **不使用 `@remotion/player`，页面里没有 `<video>`、播放按钮、时间码或进度条。**
- `src/live/LiveClock.jsx` 用 `requestAnimationFrame` 提供帧号；四章组件直接读取该帧号。
- 动画曲线仍然使用 Remotion 的 `interpolate`、`spring`、`Easing`，所以是“Remotion 动效”，不是录好的视频。
- 中央舞台是一个 1600×900 的设计画布，按容器宽度 `transform: scale()`；双击或「全屏看板」放大同一个 DOM 节点，不切换视频源。
- 切章会重新挂载动效时钟并从头播放；「重播动效」只重置 DOM 动画。

## 构建

```bash
cd 09_项目看板
node scripts/build.mjs
```

然后双击 `dist/index.html`。构建会输出 `dist/manifest.json`（版本、构建时间、体积、资产清单）。

> 项目看板 / README / 测试报告链接是相对路径。用本地服务器预览时，请把 `无缝/` 作为根目录，再访问 `/09_项目看板/dist/index.html`；直接把 `dist/` 当根目录会导致这些 Markdown 链接 404。

如果运行时不在默认位置，设置：

```bash
REMOTION_RUNTIME=/path/to/dsh-remotion/runtime node scripts/build.mjs
```

## 后续更新流程

1. 打开 `src/data/project.json`：
   - `meta`：阶段、周数、下个门禁、更新时间
   - `kpis`：四个大数字
   - `milestones`：M0–M5 状态与门禁
   - `scope`：S0 / S1 / S2
   - `risks` / `decisions` / `changelog` / `nextGate`
2. 动画章节需要改叙事时，编辑 `src/chapters/` 对应文件；只改数据不用动动画。
3. 跑 `node scripts/build.mjs`，刷新页面。
4. 把这次变更写进 `project.json` 的 `changelog`，并在 `../../00_项目看板.md` 留一条对应记录。

## 四章动效

| 章节 | 文件 | 内容 |
| --- | --- | --- |
| 总览 | `src/chapters/Overview.jsx` | 项目坐标、M0–M5、范围冻结、W1 真实测试 |
| 流程 | `src/chapters/Pipeline.jsx` | 30 秒循环、雨市 A–F、裁断者三阶段、战后选择 |
| 战斗 | `src/chapters/Combat.jsx` | 同步率 / 完整度、弹反窗口、完美弹反自动换人 |
| 风险与日志 | `src/chapters/Risk.jsx` | 风险坐标、十条决策、六条更新记录、W2 门禁 |

## 设计约束

- 配色：近黑蓝底 + 青色数据 + 品红（阿绫）+ 琥珀（警告）+ 红色（风险）。
- 字体：系统中文无衬线 + 等宽数字，不联网加载字体。
- 数据以 `project.json` 为单一事实源；动画里的数字也尽量读它，避免“看板和文档对不上”。
- 不引入 npm 安装；使用本机 dsh-remotion 运行时，保证离线可复现。
- 页面在 2560×1305、1920×1080、1280×800 下可读；≤900px 隐藏动效画布，保留下方完整数据。
- 动画区域双击可全屏；右侧「重播动效 / 全屏看板 / 下一章」可用。

## 当前构建记录

- 2026-10-19：v1.2.0，移除 Player，四章改为 DOM 实时动效；51 条断言数据；5 条更新记录；`dist/index.html` 496.6 KB。
- 2026-10-19：v1.2 数据更新，同步范围 A（17 周 / 25–30 分钟 / 10 条决策 / 7 条更新记录）；`dist/index.html` 498.4 KB。
- 2026-10-19：v1.1.0，去左栏 / 全宽舞台 / 字号放大的可读性改版（已被 v1.2 取代）。
- 构建验证见 `../../06_测试/03_看板验收.md`。
