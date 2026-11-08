class_name AimLine
extends Node2D
## Dashed trajectory preview. Fed the exact polyline the shot will follow, so
## the preview can never disagree with the projectile.

var points := PackedVector2Array()
var offset := Vector2.ZERO
var colour := Color(1, 1, 1, 0.5)
var dash := 26.0
var radius := 5.0
var visible_line := true


func _draw() -> void:
	if not visible_line or points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a := points[i] + offset
		var b := points[i + 1] + offset
		var seg := b - a
		var length := seg.length()
		if length < 0.01:
			continue
		var dir := seg / length
		var t := 0.0
		while t < length:
			draw_circle(a + dir * t, radius, colour)
			t += dash
