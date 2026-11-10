extends Control

const NODE_SPACING := 92.0
const NODE_COUNT := 600

func node_position(level_id: int) -> Vector2:
    var index := maxi(0, level_id - 1)
    var x := 250.0 + sin(float(index) * 0.33) * 150.0
    var y := 56.0 + float(index) * NODE_SPACING
    return Vector2(x, y)

func _draw() -> void:
    var previous := node_position(1)
    for level_id in range(2, NODE_COUNT + 1):
        var current := node_position(level_id)
        draw_line(previous, current, Color(0.55, 0.88, 1.0, 0.52), 10.0, true)
        previous = current
    for level_id in range(1, NODE_COUNT + 1):
        var point := node_position(level_id)
        var glow := Color("#ffe58a") if level_id % 100 == 1 else Color("#7bd5f4")
        draw_circle(point, 11.0, glow)
