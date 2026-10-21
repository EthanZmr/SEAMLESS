# 字体目录

这里的字体文件由 `Fonts` autoload 自动发现，**文件名即槽位**：

| 文件名 | 槽位 | 用在哪 |
| --- | --- | --- |
| `ui.ttf` / `ui.otf` / `ui.woff2` | `ui` | HUD、菜单、对话框正文（默认） |
| `display.ttf` | `display` | 标题、章节大字（序章 SEAMLESS、暂停菜单标题） |
| `mono.ttf` | `mono` | 调试面板、数值读数 |

## 当前状态

目录里**没有字体文件**，`Fonts.ui()` 走 `SystemFont` 回退链：
`Microsoft YaHei → PingFang SC → Noto Sans CJK SC → Source Han Sans SC → SimHei → WenQuanYi Micro Hei → Arial`。

也就是说现在界面上看到的是系统字体。丢一个 `ui.ttf` 进来，重启即生效，**不需要改代码**。

## 选字体的硬要求

1. **必须有中文字形**。只有拉丁字形的字体放进来，中文会变成豆腐块。
2. **许可要能商用**。推荐 OFL 授权：
   - 思源黑体 / Source Han Sans（OFL）
   - Noto Sans CJK（OFL）
   - 霞鹜文楷 LXGW WenKai（OFL）
3. 放进来的同时在 `CREDITS.md` 里记一笔：字体名、版本、授权、来源 URL。

## 为什么不在仓库里直接放字体

字体动辄 5–20MB，塞进 git 会让每次 clone 都变慢，而白盒阶段根本不需要。
等美术定稿再放，或者改用 Git LFS。
