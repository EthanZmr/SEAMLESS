from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

W, H = 1600, 900
img = Image.new("RGB", (W, H), "#08111F")
d = ImageDraw.Draw(img)
font_path = "C:/Windows/Fonts/msyh.ttc"


def F(n):
    try:
        return ImageFont.truetype(font_path, n)
    except Exception:
        return ImageFont.load_default()


f_title = F(30)
f_zone = F(22)
f = F(14)
f_small = F(12)
f_tiny = F(10)


def X(x):
    return int(60 + (x + 220) * 0.68)


def Y(y):
    return int(130 + (y + 120) * 0.82)


# zone bands
for x0, x1, color, label in [
    (-220, 620, "#241B12", "A  诊所后巷"),
    (620, 1260, "#0D2227", "B  雨市入口"),
    (1260, 1800, "#25101C", "C  霓虹巷"),
]:
    d.rectangle([X(x0), Y(-120), X(x1), Y(700)], fill=color)
    d.text((X(x0) + 14, Y(-108)), label, font=f_zone, fill="#E8F4FF")
    d.line([X(x1), Y(-120), X(x1), Y(700)], fill="#27405A", width=1)


def rect(x, y, w, h, fill, outline=None, width=2, label=None):
    d.rectangle([X(x), Y(y), X(x + w), Y(y + h)], fill=fill, outline=outline, width=width)
    if label:
        d.text((X(x) + 4, Y(y) - 18), label, font=f_small, fill="#A8C4DC")


# ground segments
rect(-220, 620, 640, 80, "#22364D", "#4A6A88")
rect(620, 620, 640, 80, "#22364D", "#4A6A88")
rect(1260, 620, 540, 80, "#22364D", "#4A6A88")
# A gap + bridge
d.line([X(420), Y(650), X(620), Y(650)], fill="#FF6B8A", width=2)
d.text((X(430), Y(660)), "200px 断桥 · U 缝桥", font=f_small, fill="#FF9CB2")
rect(470, 600, 240, 22, "#2E6B7A", "#3FE0D0", 2, "缝后桥")

# A
rect(40, 500, 100, 60, "#3A2E24", "#FFB454", 1, "诊所")
d.text((X(55), Y(520)), "A 安全屋", font=f_tiny, fill="#FFD9A0")
rect(300, 560, 22, 58, "#FF6B8A")
d.text((X(330), Y(535)), "清道夫", font=f_tiny, fill="#FFB3C2")
d.polygon(
    [(X(420), Y(554)), (X(432), Y(560)), (X(420), Y(566)), (X(408), Y(560))],
    fill="#3FE0D0",
)
d.text((X(368), Y(575)), "承重缝", font=f_tiny, fill="#3FE0D0")
d.polygon(
    [(X(640), Y(544)), (X(654), Y(560)), (X(640), Y(576)), (X(626), Y(560))],
    outline="#FFFFFF",
    width=2,
)
d.text((X(610), Y(585)), "针眼", font=f_tiny, fill="#FFFFFF")

# B tower / roof / climb
rect(700, 120, 32, 420, "#16263D", "#4A6A88")
rect(680, 80, 240, 20, "#2A4055", "#6C8EA8", 2, "塔顶")
for yy in range(180, 500, 24):
    d.line([X(736), Y(yy), X(754), Y(yy + 12)], fill="#3FE0D0", width=1)
d.text((X(765), Y(330)), "绿梯 W", font=f_small, fill="#3FE0D0")
rect(815, 42, 22, 38, "#FF6B8A")
d.text((X(842), Y(30)), "屋顶清道夫", font=f_tiny, fill="#FFB3C2")
d.line([X(920), Y(110), X(1120), Y(110)], fill="#FF6B8A", width=2)
d.text((X(930), Y(86)), "200px 屋顶缺口", font=f_small, fill="#FF9CB2")
ax, ay = X(1140), Y(180)
d.polygon([(ax, ay - 11), (ax + 11, ay), (ax, ay + 11), (ax - 11, ay)], fill="#FF3E8A", outline="#FFE8F2")
d.text((ax + 14, ay - 8), "H 钩点", font=f_small, fill="#FF9CB2")
rect(1120, 300, 140, 18, "#2A4055", "#6C8EA8", 2, "猫道")
rect(900, 560, 22, 58, "#FF6B8A")
d.text((X(895), Y(535)), "清道夫", font=f_tiny, fill="#FFB3C2")
rect(1000, 560, 22, 58, "#FFB454")
d.text((X(995), Y(535)), "截线者", font=f_tiny, fill="#FFD9A0")
rect(1070, 460, 30, 160, "#3A2430", "#FF3E8A", 2)
d.text((X(1038), Y(440)), "U 短路闸门", font=f_small, fill="#FF9CB2")
d.polygon(
    [(X(1240), Y(544)), (X(1254), Y(560)), (X(1240), Y(576)), (X(1226), Y(560))],
    outline="#FFFFFF",
    width=2,
)
d.text((X(1215), Y(585)), "C 入口针眼", font=f_tiny, fill="#FFFFFF")

# C shaft
rect(1380, 240, 24, 320, "#16263D", "#4A6A88")
rect(1520, 240, 24, 320, "#16263D", "#4A6A88")
rect(1320, 220, 80, 20, "#2A4055", "#6C8EA8", 2, "左屋顶")
rect(1520, 220, 80, 20, "#2A4055", "#6C8EA8", 2, "右屋顶")
rect(1380, 420, 40, 12, "#2A4055", "#6C8EA8", 1, "抓边")
rect(1480, 360, 40, 12, "#2A4055", "#6C8EA8", 1, "抓边")
rect(1560, 200, 22, 38, "#FF6B8A")
d.text((X(1585), Y(190)), "屋顶清道夫", font=f_tiny, fill="#FFB3C2")
rect(1320, 90, 360, 18, "#2A4055", "#6C8EA8", 2, "C 猫道")
ax, ay = X(1560), Y(70)
d.polygon([(ax, ay - 11), (ax + 11, ay), (ax, ay + 11), (ax - 11, ay)], fill="#FF3E8A", outline="#FFE8F2")
d.text((ax + 14, ay - 8), "H 钩点", font=f_small, fill="#FF9CB2")
d.polygon(
    [(X(1640), Y(64)), (X(1652), Y(70)), (X(1640), Y(76)), (X(1628), Y(70))],
    fill="#FF3E8A",
)
d.text((X(1658), Y(55)), "电力缝", font=f_small, fill="#FF9CB2")
rect(1480, 560, 22, 58, "#3FE0D0")
d.text((X(1460), Y(535)), "补丁", font=f_tiny, fill="#3FE0D0")
rect(1580, 560, 22, 58, "#FFB454")
d.text((X(1570), Y(535)), "截线者", font=f_tiny, fill="#FFD9A0")
d.polygon(
    [(X(1620), Y(554)), (X(1632), Y(560)), (X(1620), Y(566)), (X(1608), Y(560))],
    fill="#FF3E8A",
)
d.text((X(1590), Y(575)), "短路缝", font=f_tiny, fill="#FF9CB2")
rect(1660, 500, 30, 120, "#3A2430", "#FF3E8A", 2)
d.text((X(1660), Y(480)), "低路闸门", font=f_tiny, fill="#FF9CB2")
d.polygon(
    [(X(1720), Y(544)), (X(1734), Y(560)), (X(1720), Y(576)), (X(1706), Y(560))],
    outline="#FFFFFF",
    width=2,
)
d.text((X(1695), Y(585)), "D 入口针眼", font=f_tiny, fill="#FFFFFF")

# routes
low = [
    (100, 560), (320, 560), (440, 560), (590, 600), (700, 560),
    (900, 560), (1000, 560), (1070, 560), (1150, 560),
    (1280, 560), (1480, 560), (1580, 560), (1620, 560), (1720, 560),
]
high_b = [
    (640, 560), (700, 540), (744, 500), (744, 170), (760, 80),
    (900, 80), (920, 100), (1140, 180), (1140, 300), (1200, 300), (1260, 560),
]
high_c = [
    (1280, 560), (1400, 560), (1450, 560), (1450, 240), (1540, 220),
    (1560, 200), (1560, 70), (1640, 90), (1680, 560),
]


def line(points, color, width=3):
    for i in range(len(points) - 1):
        d.line(
            [X(points[i][0]), Y(points[i][1]), X(points[i + 1][0]), Y(points[i + 1][1])],
            fill=color,
            width=width,
        )


line(low, "#FFD27A", 3)
line(high_b, "#3FE0D0", 3)
line(high_c, "#FF6BC2", 3)

# legend
lx, ly = 1080, 760
d.text((lx, ly - 26), "路线", font=f, fill="#E8F4FF")
d.line([lx, ly, lx + 34, ly], fill="#FFD27A", width=3)
d.text((lx + 42, ly - 8), "低路 · 稳 / 战斗", font=f_small, fill="#FFD27A")
d.line([lx, ly + 24, lx + 34, ly + 24], fill="#3FE0D0", width=3)
d.text((lx + 42, ly + 16), "B 高路 · 爬 + 钩", font=f_small, fill="#3FE0D0")
d.line([lx, ly + 48, lx + 34, ly + 48], fill="#FF6BC2", width=3)
d.text((lx + 42, ly + 40), "C 高路 · 墙跳 + 钩 + 缝", font=f_small, fill="#FF6BC2")

# title
d.text((60, 36), "雨市 A–C 重设计 v2", font=f_title, fill="#F2FAFF")
d.text((60, 78), "一条主路 + 一条精通路 · 两路同点收束 · 12–15 分钟", font=f, fill="#9CB6CC")
d.text((60, 820), "◆ 粉色=钩点/电力缝   ◇ 白色=针眼   ▥ 绿色=可攀爬   ─ 红=闸门/缺口", font=f_small, fill="#7FA8C9")
d.text((60, 850), "坐标单位：px；地面 620；玩家跳高约 128、跳距约 188、钩索 320。", font=f_small, fill="#5F7E99")

out = Path("01_GDD/ABC_redesign_v2.png")
img.save(out)
print("saved", out.resolve())
