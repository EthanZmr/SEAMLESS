class_name Sweeper
extends MeleeChaser
## 清道夫：白城里最基础的近战单位。
##
## 行为全在 MeleeChaser，数值全在 sweeper.tscn。
## 这个文件之所以存在，是为了让 `Sweeper` 这个类型名继续可用
## （测试、原型场景、旧代码都在用它），同时给未来"清道夫专有行为"
## 留一个落点 —— 要加就在这里覆盖 _do_attack()/_acquire_target()，
## 不要去改 MeleeChaser 把截线者一起带歪。
