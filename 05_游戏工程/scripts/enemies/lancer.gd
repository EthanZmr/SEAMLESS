class_name Lancer
extends MeleeChaser
## 截线者：长柄、慢、远、伤害高的近战单位。
##
## 数值来自 lancer.tscn（move_speed 48 / attack_range 112 / windup 0.68 /
## recover 0.75 / damage 14 / hp 55）。行为基线同 MeleeChaser，长柄让它的
## 判定更高一点 —— 上段也能扫到，这是"长"的实际含义，不只是数字更大。

## 长柄横扫比短刃高一截：跳起来躲短兵有效，躲截线者要跳更高或换位。
func _attack_height() -> float:
	return 96.0


## 臂长余量也按比例放大，否则 112 的范围实际只有 142。
func _attack_bonus() -> float:
	return 36.0
