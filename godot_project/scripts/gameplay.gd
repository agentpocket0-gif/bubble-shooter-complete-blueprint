extends Control

const HexGrid = preload("res://scripts/HexGrid.gd")
const COLS := 11
const ROWS := 20
const DIAMETER := 42.0
const GRID_ORIGIN := Vector2(24, 190)
const CANNON_POINT := Vector2(270, 820)
const NEXT_BUBBLE_POINT := Vector2(356, 833)
const SHOT_SPEED := 760.0

var board: Dictionary = {}
var blockers: Dictionary = {}
var blocker_hp: Dictionary = {}
var bubble_nodes: Dictionary = {}
var blocker_nodes: Dictionary = {}
var level_data: Dictionary = {}
var palette: Array = ["red", "blue", "green"]
var current_color := "blue"
var next_color := "red"
var shots_left := 30
var score := 0
var total_popped := 0
var aim_direction := Vector2(0, -1)
var aiming := false
var shooting := false
var projectile: Sprite2D
var projectile_velocity := Vector2.ZERO
var projectile_color := "blue"
var board_layer: Node2D
var aim_line: Line2D
var hud_label: Label
var popup_layer: Control
var booster_status: Label
var score_slots_label: Label
var cannon_barrel: Sprite2D

func _ready() -> void:
    var bg := TextureRect.new()
    bg.texture = AssetRegistry.ui("background")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(bg)
    board_layer = Node2D.new()
    add_child(board_layer)
    _load_level(GameState.current_level)
    _build_ui()
    _render_board()

func _build_ui() -> void:
    hud_label = Label.new()
    hud_label.position = Vector2(20, 28)
    hud_label.size = Vector2(500, 48)
    hud_label.add_theme_font_size_override("font_size", 17)
    hud_label.add_theme_color_override("font_color", Color("#fff4c5"))
    add_child(hud_label)
    booster_status = Label.new()
    booster_status.position = Vector2(20, 850)
    booster_status.size = Vector2(500, 24)
    booster_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    booster_status.add_theme_font_size_override("font_size", 12)
    booster_status.add_theme_color_override("font_color", Color("#bfeeff"))
    add_child(booster_status)
    score_slots_label = Label.new()
    score_slots_label.text = "SCORE DROP     ×1    ×2    ×3    ×5    ×3    ×2    ×1"
    score_slots_label.position = Vector2(18, 878)
    score_slots_label.size = Vector2(504, 24)
    score_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_slots_label.add_theme_font_size_override("font_size", 14)
    score_slots_label.add_theme_color_override("font_color", Color("#ffe89b"))
    add_child(score_slots_label)
    cannon_barrel = Sprite2D.new()
    cannon_barrel.texture = AssetRegistry.ui("cannon")
    cannon_barrel.position = CANNON_POINT + Vector2(0, 5)
    cannon_barrel.scale = Vector2(0.52, 0.52)
    add_child(cannon_barrel)
    aim_line = Line2D.new()
    aim_line.width = 3.0
    aim_line.default_color = Color(0.75, 0.95, 1.0, 0.78)
    aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
    aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
    add_child(aim_line)
    _refresh_cannon()
    _update_hud()
    var buttons := ["Bomb", "Fireball", "Rainbow", "+5 Moves"]
    for index in range(buttons.size()):
        var button := Button.new()
        button.text = buttons[index]
        button.position = Vector2(10 + index * 131, 914)
        button.size = Vector2(124, 44)
        button.add_theme_font_size_override("font_size", 12)
        _style_button(button)
        button.pressed.connect(_activate_booster.bind(buttons[index]))
        add_child(button)
    var map_button := Button.new()
    map_button.text = "MAP"
    map_button.position = Vector2(18, 85)
    map_button.size = Vector2(78, 44)
    _style_button(map_button)
    map_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/SagaMap.tscn"))
    add_child(map_button)

func _style_button(button: Button) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#195b8a")
    style.border_color = Color("#8de6ff")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", Color.WHITE)

func _load_level(level_id: int) -> void:
    var path := "res://levels/level_%03d.json" % clampi(level_id, 1, 120)
    if not FileAccess.file_exists(path):
        path = "res://levels/level_001.json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open level file: " + path)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid level JSON: " + path)
        return
    level_data = parsed
    palette = level_data.get("palette", ["red", "blue", "green"])
    shots_left = int(level_data.get("shots", 30))
    board.clear()
    blockers.clear()
    blocker_hp.clear()
    var layout: Array = level_data.get("layout", [])
    for row in range(layout.size()):
        var line := str(layout[row])
        for col in range(mini(line.length(), COLS)):
            var token := line.substr(col, 1)
            var cell := Vector2i(col, row)
            if token.is_valid_int():
                var palette_index := clampi(token.to_int() - 1, 0, palette.size() - 1)
                board[cell] = str(palette[palette_index])
            elif token == "x" or token == "i" or token == "c":
                var inline_kind := "stone" if token == "x" else ("ice" if token == "i" else "chain")
                blockers[cell] = inline_kind
                blocker_hp[cell] = 1
    for item in level_data.get("blockers", []):
        var cell := Vector2i(int(item.get("col", 0)), int(item.get("row", 0)))
        blockers[cell] = str(item.get("type", "ice"))
        blocker_hp[cell] = int(item.get("hp", 1))
    if palette.is_empty():
        palette = ["red", "blue", "green"]
    current_color = str(palette[0])
    next_color = str(palette[1]) if palette.size() > 1 else str(palette[0])

func _render_board() -> void:
    for child in board_layer.get_children():
        child.queue_free()
    bubble_nodes.clear()
    blocker_nodes.clear()
    for cell in board.keys():
        var sprite := Sprite2D.new()
        sprite.texture = AssetRegistry.bubble(str(board[cell]))
        sprite.position = HexGrid.center(cell, GRID_ORIGIN, DIAMETER)
        sprite.scale = Vector2(0.33, 0.33)
        board_layer.add_child(sprite)
        bubble_nodes[cell] = sprite
    for cell in blockers.keys():
        var sprite := Sprite2D.new()
        sprite.texture = AssetRegistry.blocker(str(blockers[cell]))
        sprite.position = HexGrid.center(cell, GRID_ORIGIN, DIAMETER)
        sprite.scale = Vector2(0.33, 0.33)
        board_layer.add_child(sprite)
        blocker_nodes[cell] = sprite
    _refresh_cannon()
    _update_hud()

func _refresh_cannon() -> void:
    if not is_inside_tree():
        return
    var old := get_node_or_null("CurrentBubble")
    if old != null:
        old.queue_free()
    var current := Sprite2D.new()
    current.name = "CurrentBubble"
    current.texture = AssetRegistry.bubble(current_color)
    current.position = CANNON_POINT + Vector2(0, -48)
    current.scale = Vector2(0.33, 0.33)
    add_child(current)
    var old_next := get_node_or_null("NextBubble")
    if old_next != null:
        old_next.queue_free()
    var next := Sprite2D.new()
    next.name = "NextBubble"
    next.texture = AssetRegistry.bubble(next_color)
    next.position = NEXT_BUBBLE_POINT
    next.scale = Vector2(0.24, 0.24)
    add_child(next)

func _update_hud() -> void:
    if hud_label != null:
        hud_label.text = "LEVEL %03d     MOVES %02d     SCORE %05d     COINS %d" % [GameState.current_level, shots_left, score, GameState.coins]
    if booster_status != null:
        booster_status.text = "DRAG TO AIM  •  RELEASE TO SHOOT  •  TAP NEXT BUBBLE TO SWAP"

func _unhandled_input(event: InputEvent) -> void:
    if popup_layer != null:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            _pointer_down(event.position)
        else:
            _end_aim(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _pointer_down(event.position)
        else:
            _end_aim(event.position)
    elif event is InputEventScreenDrag and aiming:
        _update_aim(event.position)
    elif event is InputEventMouseMotion and aiming:
        _update_aim(event.position)

func _pointer_down(point: Vector2) -> void:
    if point.distance_to(NEXT_BUBBLE_POINT) < 42.0:
        _swap_bubbles()
        return
    _begin_aim(point)

func _swap_bubbles() -> void:
    if shooting or aiming:
        return
    var previous := current_color
    current_color = next_color
    next_color = previous
    _refresh_cannon()
    var current := get_node_or_null("CurrentBubble") as Sprite2D
    if current != null:
        current.scale = Vector2(0.08, 0.33)
        var tween := create_tween()
        tween.tween_property(current, "scale", Vector2(0.33, 0.33), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _begin_aim(point: Vector2) -> void:
    if shooting or point.y > CANNON_POINT.y - 10.0:
        return
    aiming = true
    _update_aim(point)

func _update_aim(point: Vector2) -> void:
    var raw := (point - CANNON_POINT).normalized()
    if raw.y > -0.18:
        raw.y = -0.18
        raw = raw.normalized()
    var angle := clampf(atan2(raw.x, -raw.y), deg_to_rad(-75.0), deg_to_rad(75.0))
    aim_direction = Vector2(sin(angle), -cos(angle)).normalized()
    if cannon_barrel != null:
        cannon_barrel.rotation = angle
    _build_trajectory_preview()

func _build_trajectory_preview() -> void:
    aim_line.clear_points()
    var position := CANNON_POINT + Vector2(0, -38)
    var velocity := aim_direction * SHOT_SPEED
    aim_line.add_point(position)
    var bounces := 0
    for step in range(1, 260):
        position += velocity * (1.0 / 60.0)
        if position.x < DIAMETER * 0.5:
            position.x = DIAMETER * 0.5
            velocity.x = absf(velocity.x)
            bounces += 1
        elif position.x > 540.0 - DIAMETER * 0.5:
            position.x = 540.0 - DIAMETER * 0.5
            velocity.x = -absf(velocity.x)
            bounces += 1
        aim_line.add_point(position)
        if position.y < GRID_ORIGIN.y - 20.0 or _collides_with_board(position):
            break
        if bounces >= 3:
            break

func _collides_with_board(point: Vector2) -> bool:
    for cell in board.keys():
        if HexGrid.center(cell, GRID_ORIGIN, DIAMETER).distance_to(point) < DIAMETER * 0.84:
            return true
    for cell in blockers.keys():
        if HexGrid.center(cell, GRID_ORIGIN, DIAMETER).distance_to(point) < DIAMETER * 0.84:
            return true
    return false

func _end_aim(point: Vector2) -> void:
    if not aiming:
        return
    _update_aim(point)
    aiming = false
    aim_line.clear_points()
    _launch_shot()

func _launch_shot() -> void:
    if shooting or shots_left <= 0:
        return
    shooting = true
    projectile_color = current_color
    projectile = Sprite2D.new()
    projectile.texture = AssetRegistry.bubble(projectile_color)
    projectile.position = CANNON_POINT + Vector2(0, -38)
    projectile.scale = Vector2(0.33, 0.33)
    add_child(projectile)
    projectile_velocity = aim_direction * SHOT_SPEED
    shots_left -= 1
    _update_hud()

func _process(delta: float) -> void:
    if not shooting or projectile == null:
        return
    var remaining := delta
    while remaining > 0.0 and shooting:
        var step := minf(remaining, 1.0 / 120.0)
        remaining -= step
        projectile.position += projectile_velocity * step
        if projectile.position.x < DIAMETER * 0.5:
            projectile.position.x = DIAMETER * 0.5
            projectile_velocity.x = absf(projectile_velocity.x)
        elif projectile.position.x > 540.0 - DIAMETER * 0.5:
            projectile.position.x = 540.0 - DIAMETER * 0.5
            projectile_velocity.x = -absf(projectile_velocity.x)
        if projectile.position.y < GRID_ORIGIN.y - DIAMETER * 0.45 or _collides_with_board(projectile.position):
            _land_projectile(projectile.position)

func _nearest_open_cell(point: Vector2) -> Vector2i:
    var selected := HexGrid.nearest_attach(point, board, COLS, ROWS, GRID_ORIGIN, DIAMETER)
    if selected.x < 0 or not blockers.has(selected):
        return selected
    var best := Vector2i(-1, -1)
    var best_distance := INF
    for candidate in HexGrid.neighbours(selected):
        if candidate.x < 0 or candidate.x >= COLS or candidate.y < 0 or candidate.y >= ROWS:
            continue
        if board.has(candidate) or blockers.has(candidate):
            continue
        var distance := HexGrid.center(candidate, GRID_ORIGIN, DIAMETER).distance_squared_to(point)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

func _land_projectile(point: Vector2) -> void:
    shooting = false
    if projectile != null:
        projectile.queue_free()
        projectile = null
    var cell := _nearest_open_cell(point)
    if cell.x < 0 or board.has(cell) or blockers.has(cell):
        _show_result(false)
        return
    board[cell] = projectile_color
    _render_board()
    var cluster := HexGrid.find_cluster(board, cell)
    if cluster.size() >= 3:
        total_popped += cluster.size()
        score += cluster.size() * 10 + maxi(0, cluster.size() - 3) * 5
        for pop_cell in cluster:
            _spawn_pop_effect(pop_cell)
        _remove_cells(cluster)
        _damage_adjacent_blockers(cluster)
        var floating := HexGrid.find_floating(board, COLS, ROWS)
        score += floating.size() * 20
        total_popped += floating.size()
        for floating_cell in floating:
            _spawn_falling_bubble(floating_cell)
        _remove_cells(floating)
    _advance_colors()
    _update_hud()
    _check_objectives()

func _spawn_pop_effect(cell: Vector2i) -> void:
    var frames := SpriteFrames.new()
    frames.add_animation("pop")
    frames.set_animation_speed("pop", 18.0)
    for frame in range(1, 9):
        frames.add_frame("pop", AssetRegistry.pop_frame(frame))
    var effect := AnimatedSprite2D.new()
    effect.sprite_frames = frames
    effect.animation = "pop"
    effect.position = HexGrid.center(cell, GRID_ORIGIN, DIAMETER)
    effect.scale = Vector2(0.42, 0.42)
    board_layer.add_child(effect)
    effect.animation_finished.connect(effect.queue_free)
    effect.play("pop")

func _spawn_falling_bubble(cell: Vector2i) -> void:
    if not board.has(cell):
        return
    var falling := Sprite2D.new()
    falling.texture = AssetRegistry.bubble(str(board[cell]))
    falling.position = HexGrid.center(cell, GRID_ORIGIN, DIAMETER)
    falling.scale = Vector2(0.33, 0.33)
    board_layer.add_child(falling)
    var slot := clampi(roundi(float(cell.x) * 6.0 / float(COLS - 1)), 0, 6)
    var multipliers := [1, 2, 3, 5, 3, 2, 1]
    var slot_x := 38.0 + float(slot) * 77.3
    score += int(multipliers[slot]) * 10
    var tween := create_tween()
    tween.tween_property(falling, "position", Vector2(slot_x, 880.0), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(falling, "position:y", 846.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    tween.tween_property(falling, "position:y", 880.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
    tween.tween_callback(falling.queue_free)

func _remove_cells(cells: Array) -> void:
    for cell in cells:
        board.erase(cell)
        if bubble_nodes.has(cell):
            var node: Sprite2D = bubble_nodes[cell]
            if is_instance_valid(node):
                var tween := create_tween()
                tween.tween_property(node, "scale", Vector2.ZERO, 0.12)
                tween.tween_callback(node.queue_free)
            bubble_nodes.erase(cell)

func _damage_adjacent_blockers(cells: Array) -> void:
    for cell in cells:
        for neighbour in HexGrid.neighbours(cell):
            if not blockers.has(neighbour):
                continue
            var kind := str(blockers[neighbour])
            if kind == "stone":
                continue
            if kind == "chain":
                blockers.erase(neighbour)
                blocker_hp.erase(neighbour)
                _remove_blocker_visual(neighbour)
            else:
                var hp := int(blocker_hp.get(neighbour, 1)) - 1
                if hp <= 0:
                    blockers.erase(neighbour)
                    blocker_hp.erase(neighbour)
                    _remove_blocker_visual(neighbour)
                else:
                    blocker_hp[neighbour] = hp

func _remove_blocker_visual(cell: Vector2i) -> void:
    if blocker_nodes.has(cell):
        var node: Sprite2D = blocker_nodes[cell]
        if is_instance_valid(node):
            node.queue_free()
        blocker_nodes.erase(cell)

func _advance_colors() -> void:
    current_color = next_color
    var available: Array = []
    for value in board.values():
        if not available.has(str(value)):
            available.append(str(value))
    if available.is_empty():
        available = palette.duplicate()
    next_color = str(available[randi() % available.size()])
    _refresh_cannon()

func _check_objectives() -> void:
    var objectives: Array = level_data.get("objectives", [{"type": "clear_all"}])
    var won := true
    for objective in objectives:
        var kind := str(objective.get("type", "clear_all"))
        if kind == "clear_all":
            won = won and board.is_empty()
        elif kind == "clear_color":
            var target_color := str(objective.get("color", "red"))
            for value in board.values():
                if str(value) == target_color:
                    won = false
        elif kind == "pop_count":
            won = won and total_popped >= int(objective.get("count", 10))
        elif kind == "rescue":
            won = won and blockers.is_empty()
        elif kind == "score":
            won = won and score >= int(objective.get("target", 250))
        elif kind == "survive":
            won = won and shots_left <= 0
    if won:
        _show_result(true)
    elif shots_left <= 0:
        _show_result(false)

func _activate_booster(kind: String) -> void:
    var count := int(GameState.boosters.get(kind, 0))
    if count <= 0 or shooting:
        return
    GameState.boosters[kind] = count - 1
    if kind == "+5 Moves":
        shots_left += 5
    elif kind == "Rainbow":
        var most_common: Dictionary = {}
        for value in board.values():
            most_common[str(value)] = int(most_common.get(str(value), 0)) + 1
        var best_color := current_color
        for key in most_common.keys():
            if int(most_common[key]) > int(most_common.get(best_color, 0)):
                best_color = str(key)
        current_color = best_color
    elif kind == "Fireball":
        var column := clampi(roundi((CANNON_POINT.x - GRID_ORIGIN.x) / DIAMETER), 0, COLS - 1)
        for cell in board.keys().duplicate():
            if cell.x == column:
                board.erase(cell)
        for cell in blockers.keys().duplicate():
            if cell.x == column:
                blockers.erase(cell)
                blocker_hp.erase(cell)
    elif kind == "Bomb":
        var target := Vector2i(COLS / 2, 0)
        if not board.is_empty():
            target = board.keys()[0]
        var centre := HexGrid.center(target, GRID_ORIGIN, DIAMETER)
        for cell in board.keys().duplicate():
            if HexGrid.center(cell, GRID_ORIGIN, DIAMETER).distance_to(centre) < DIAMETER * 2.4:
                board.erase(cell)
        for cell in blockers.keys().duplicate():
            if HexGrid.center(cell, GRID_ORIGIN, DIAMETER).distance_to(centre) < DIAMETER * 2.4:
                blockers.erase(cell)
                blocker_hp.erase(cell)
    GameState.save_progress()
    _render_board()
    _check_objectives()

func _show_result(won: bool) -> void:
    if popup_layer != null:
        return
    popup_layer = Control.new()
    popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(popup_layer)
    var panel := Panel.new()
    panel.position = Vector2(34, 300)
    panel.size = Vector2(472, 360)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#174d7b")
    style.border_color = Color("#a1eeff")
    style.set_border_width_all(4)
    style.set_corner_radius_all(26)
    panel.add_theme_stylebox_override("panel", style)
    popup_layer.add_child(panel)
    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.025, 0.07, 0.82)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    popup_layer.add_child(shade)
    popup_layer.move_child(shade, 0)
    var title := Label.new()
    title.text = "LEVEL COMPLETE!" if won else "TRY AGAIN"
    title.position = Vector2(15, 35)
    title.size = Vector2(442, 60)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#ffe79a"))
    panel.add_child(title)
    var star_count := 1
    var thresholds: Dictionary = level_data.get("stars", {})
    if won and score >= int(thresholds.get("2", 999999)):
        star_count = 2
    if won and score >= int(thresholds.get("3", 999999)):
        star_count = 3
    var body := Label.new()
    body.text = "Score: %d\n%s\n+40 coins" % [score, "★".repeat(star_count)] if won else "Your next shot can do it.\nTry a different angle."
    body.position = Vector2(30, 115)
    body.size = Vector2(412, 108)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 22)
    body.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(body)
    if won:
        GameState.complete_level(GameState.current_level, star_count, 40)
    var button := Button.new()
    button.text = "NEXT LEVEL" if won else "RETRY"
    button.position = Vector2(118, 252)
    button.size = Vector2(236, 58)
    _style_button(button)
    button.pressed.connect(func():
        if won:
            GameState.current_level = mini(120, GameState.current_level + 1)
            get_tree().change_scene_to_file("res://scenes/Gameplay.tscn")
        else:
            get_tree().reload_current_scene()
    )
    panel.add_child(button)

func qa_set_stage(stage: String) -> void:
    if stage == "aim":
        aiming = true
        aim_direction = Vector2(-0.4, -0.9).normalized()
        _build_trajectory_preview()
    elif stage == "shoot":
        aiming = false
        aim_line.clear_points()
        _launch_shot()
        if projectile != null:
            projectile.position = Vector2(250, 460)
    elif stage == "booster":
        if projectile != null:
            projectile.queue_free()
            projectile = null
        shooting = false
        _activate_booster("Fireball")
    elif stage == "pop":
        if not board.is_empty():
            _spawn_pop_effect(board.keys()[0])
        score = 1240
        _update_hud()

func qa_show_result() -> void:
    _show_result(true)
