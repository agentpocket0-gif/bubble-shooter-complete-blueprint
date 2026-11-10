extends Control

const NODE_SPACING := 92.0
const NODE_COUNT := 100

func node_position(local_level: int) -> Vector2:
    var index := clampi(local_level - 1, 0, NODE_COUNT - 1)
    var x := 250.0 + sin(float(index) * 0.33) * 150.0
    var y := 56.0 + float(index) * NODE_SPACING
    return Vector2(x, y)

func _draw() -> void:
    var previous := node_position(1)
    for local_level in range(2, NODE_COUNT + 1):
        var current := node_position(local_level)
        draw_line(previous, current, Color(0.55, 0.88, 1.0, 0.52), 10.0, true)
        previous = current
    for local_level in range(1, NODE_COUNT + 1):
        var point := node_position(local_level)
        var glow := Color("#ffe58a") if local_level == 1 or local_level == 100 else Color("#7bd5f4")
        draw_circle(point, 11.0, glow)
