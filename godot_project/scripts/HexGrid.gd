extends RefCounted
class_name HexGrid

const SQRT3_HALF := 0.8660254037844386

static func row_pitch(diameter: float) -> float:
    return diameter * SQRT3_HALF

static func center(cell: Vector2i, origin: Vector2, diameter: float) -> Vector2:
    var offset := diameter * 0.5 if cell.y % 2 == 1 else 0.0
    return origin + Vector2(float(cell.x) * diameter + offset, float(cell.y) * row_pitch(diameter))

static func neighbours(cell: Vector2i) -> Array:
    var result: Array = [Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y)]
    if cell.y % 2 == 0:
        result.append_array([Vector2i(cell.x - 1, cell.y - 1), Vector2i(cell.x, cell.y - 1), Vector2i(cell.x - 1, cell.y + 1), Vector2i(cell.x, cell.y + 1)])
    else:
        result.append_array([Vector2i(cell.x, cell.y - 1), Vector2i(cell.x + 1, cell.y - 1), Vector2i(cell.x, cell.y + 1), Vector2i(cell.x + 1, cell.y + 1)])
    return result

static func cell_from_point(point: Vector2, origin: Vector2, diameter: float, cols: int, rows: int) -> Vector2i:
    var estimate_row := roundi((point.y - origin.y) / row_pitch(diameter))
    var best := Vector2i(-1, -1)
    var best_distance := INF
    for r in range(maxi(0, estimate_row - 1), mini(rows, estimate_row + 2)):
        var offset := diameter * 0.5 if r % 2 == 1 else 0.0
        var estimate_col := roundi((point.x - origin.x - offset) / diameter)
        for c in range(maxi(0, estimate_col - 1), mini(cols, estimate_col + 2)):
            var cell := Vector2i(c, r)
            var distance := center(cell, origin, diameter).distance_squared_to(point)
            if distance < best_distance:
                best_distance = distance
                best = cell
    return best

static func find_cluster(board: Dictionary, start: Vector2i) -> Array:
    if not board.has(start):
        return []
    var target := str(board[start])
    var seen: Dictionary = {start: true}
    var queue: Array = [start]
    var cluster: Array = []
    var index := 0
    while index < queue.size():
        var cell: Vector2i = queue[index]
        index += 1
        cluster.append(cell)
        for next_cell in neighbours(cell):
            if seen.has(next_cell) or not board.has(next_cell) or str(board[next_cell]) != target:
                continue
            seen[next_cell] = true
            queue.append(next_cell)
    return cluster

static func find_floating(board: Dictionary, cols: int, rows: int) -> Array:
    var anchored: Dictionary = {}
    var queue: Array = []
    for col in range(cols):
        var top := Vector2i(col, 0)
        if board.has(top):
            anchored[top] = true
            queue.append(top)
    var index := 0
    while index < queue.size():
        var cell: Vector2i = queue[index]
        index += 1
        for next_cell in neighbours(cell):
            if next_cell.x < 0 or next_cell.x >= cols or next_cell.y < 0 or next_cell.y >= rows:
                continue
            if anchored.has(next_cell) or not board.has(next_cell):
                continue
            anchored[next_cell] = true
            queue.append(next_cell)
    var floating: Array = []
    for cell in board.keys():
        if not anchored.has(cell):
            floating.append(cell)
    return floating

static func nearest_attach(point: Vector2, board: Dictionary, cols: int, rows: int, origin: Vector2, diameter: float) -> Vector2i:
    if board.is_empty():
        return cell_from_point(point, origin, diameter, cols, rows)
    var candidates: Dictionary = {}
    for occupied in board.keys():
        for candidate in neighbours(occupied):
            if candidate.x < 0 or candidate.x >= cols or candidate.y < 0 or candidate.y >= rows:
                continue
            if not board.has(candidate):
                candidates[candidate] = true
    var best := Vector2i(-1, -1)
    var best_distance := INF
    for candidate in candidates.keys():
        var distance := center(candidate, origin, diameter).distance_squared_to(point)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best if best.x >= 0 else cell_from_point(point, origin, diameter, cols, rows)
