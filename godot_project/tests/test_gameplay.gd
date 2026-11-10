extends SceneTree

const HexGrid = preload("res://scripts/HexGrid.gd")

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var checks := 0
    assert(HexGrid.neighbours(Vector2i(4, 2)).size() == 6)
    checks += 1
    assert(HexGrid.neighbours(Vector2i(4, 3)).size() == 6)
    checks += 1
    assert(HexGrid.row_pitch(48.0) > 41.5 and HexGrid.row_pitch(48.0) < 42.0)
    checks += 1
    assert(HexGrid.center(Vector2i(0, 1), Vector2.ZERO, 48.0).x == 24.0)
    checks += 1
    var board := {Vector2i(0, 0): "red", Vector2i(1, 0): "red", Vector2i(2, 0): "red", Vector2i(2, 1): "blue", Vector2i(3, 1): "blue"}
    assert(HexGrid.find_cluster(board, Vector2i(0, 0)).size() == 3)
    checks += 1
    assert(HexGrid.find_floating(board, 11, 20).is_empty())
    checks += 1
    board[Vector2i(8, 12)] = "green"
    assert(HexGrid.find_floating(board, 11, 20).size() == 1)
    checks += 1
    var point := HexGrid.center(Vector2i(3, 4), Vector2(10, 20), 42.0)
    assert(HexGrid.cell_from_point(point, Vector2(10, 20), 42.0, 11, 20) == Vector2i(3, 4))
    checks += 1

    var state_script = load("res://autoload/GameState.gd")
    var state = state_script.new()
    assert(state.MAX_LEVELS == 600)
    checks += 1
    for mode in ["classic", "hard", "challenge"]:
        var first: Dictionary = state.get_level_data(1, mode)
        var last: Dictionary = state.get_level_data(600, mode)
        assert(int(first.get("id", 0)) == 1 and str(first.get("mode", "")) == mode)
        assert(int(last.get("id", 0)) == 600 and str(last.get("mode", "")) == mode)
        checks += 2
    var classic: Dictionary = state.get_level_data(100, "classic")
    var hard: Dictionary = state.get_level_data(100, "hard")
    var challenge: Dictionary = state.get_level_data(100, "challenge")
    assert(int(hard.get("shots", 0)) <= int(classic.get("shots", 0)))
    assert(not challenge.get("objectives", []).is_empty())
    checks += 2
    state.free()
    print("Godot core tests passed: ", checks)
    quit(0)
