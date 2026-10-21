class_name HitSpark
extends Node2D
## Short-lived hand-drawn impact burst. No textures, no allocation after spawn.

var life := 0.16
var age := 0.0
var spark_color := Color("#FFE6A8")
var radius := 30.0


func setup(at: Vector2, color: Color, size: float) -> void:
	global_position = at
	spark_color = color
	radius = size


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var alpha := 1.0 - t
	var outward := lerpf(9.0, radius, sqrt(t))
	var rays := 6 if radius < 40.0 else 10
	var width := 2.4 if radius < 40.0 else 3.4
	for i in rays:
		var angle := TAU * float(i) / float(rays) + 0.18
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * (outward * 0.40), dir * outward, Color(spark_color, alpha), width)
	if radius >= 40.0:
		draw_arc(Vector2.ZERO, outward * 1.08, 0.0, TAU, 28, Color(spark_color, alpha * 0.55), 2.0)
	draw_circle(Vector2.ZERO, lerpf(6.0, 1.0, t), Color(1.0, 0.96, 0.82, alpha * 0.9))
