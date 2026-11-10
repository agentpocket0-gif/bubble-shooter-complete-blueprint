extends SceneTree

const BASE_SEQUENCE := [
    ["01_splash_screen.png", "res://scenes/Splash.tscn", 0.18],
    ["02_intro_screen.png", "res://scenes/Intro.tscn", 0.0],
    ["03_loading_screen.png", "res://scenes/Loading.tscn", 0.0],
    ["04_mode_select_screen.png", "res://scenes/ModeSelect.tscn", 0.08],
    ["05_saga_world_map.png", "res://scenes/SagaMap.tscn", 0.08]
]
const OVERLAY_SEQUENCE := [
    ["06_settings_popup.png", "qa_open_settings"],
    ["07_booster_shop_popup.png", "qa_open_store"],
    ["08_daily_spin_popup.png", "qa_open_spin"],
    ["09_piggy_bank_popup.png", "qa_open_piggy"],
    ["10_events_popup.png", "qa_open_events"]
]

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var output_dir := OS.get_environment("QA_OUTPUT_DIR")
    if output_dir.is_empty():
        output_dir = ProjectSettings.globalize_path("res://../qa_proof")
    DirAccess.make_dir_recursive_absolute(output_dir)

    var root_window := get_root()
    root_window.size = Vector2i(1080, 1920)
    _ensure_autoloads(root_window)

    var current: Node = null
    for item in BASE_SEQUENCE:
        current = await _replace_scene(root_window, current, str(item[1]))
        var delay := float(item[2])
        if delay > 0.0:
            await create_timer(delay).timeout
        await _save_frame(output_dir.path_join(str(item[0])))

    # Keep one 600-node map alive while taking every overlay screenshot.
    for item in OVERLAY_SEQUENCE:
        current.call(str(item[1]))
        await process_frame
        await _save_frame(output_dir.path_join(str(item[0])))
        if current.has_method("_close_popup"):
            current.call("_close_popup")
        await process_frame

    current = await _replace_scene(root_window, current, "res://scenes/Gameplay.tscn")
    await create_timer(0.12).timeout
    current.call("qa_set_stage", "aim")
    await _save_frame(output_dir.path_join("12_level_1_aim_preview.png"))

    current.call("qa_set_stage", "shoot")
    await _save_frame(output_dir.path_join("13_projectile_shot.png"))

    current.call("qa_set_stage", "booster")
    current.call("qa_set_stage", "pop")
    await _save_frame(output_dir.path_join("14_booster_and_pop_effects.png"))

    current.call("_show_pause")
    await _save_frame(output_dir.path_join("15_pause_overlay.png"))

    current = await _capture_result(
        root_window,
        current,
        {
            "won": true,
            "level": 1,
            "mode": "classic",
            "score": 7420,
            "stars": 3,
            "reward": 140,
            "loss_reason": ""
        },
        output_dir.path_join("16_level_win_result.png")
    )
    current = await _capture_result(
        root_window,
        current,
        {
            "won": false,
            "level": 1,
            "mode": "classic",
            "score": 1180,
            "stars": 0,
            "reward": 0,
            "loss_reason": "Out of shots"
        },
        output_dir.path_join("17_level_lose_result.png")
    )

    print("Captured 17 full-HD app-flow screenshots in ", output_dir)
    quit(0)

func _ensure_autoloads(root_window: Window) -> void:
    var required := {
        "GameState": "res://autoload/GameState.gd",
        "AssetRegistry": "res://autoload/AssetRegistry.gd",
        "MonetizationConfig": "res://autoload/MonetizationConfig.gd"
    }
    for autoload_name in required.keys():
        if root_window.get_node_or_null(str(autoload_name)) != null:
            continue
        var script := load(str(required[autoload_name])) as Script
        if script == null:
            push_error("Cannot load autoload script: " + str(required[autoload_name]))
            continue
        var instance: Node = script.new()
        instance.name = str(autoload_name)
        root_window.add_child(instance)

func _capture_result(root_window: Window, current: Node, payload: Dictionary, path: String) -> Node:
    if current != null and is_instance_valid(current):
        current.queue_free()
        await process_frame
    var game_state := root_window.get_node_or_null("GameState")
    if game_state == null:
        push_error("GameState autoload was not available to the visual capture.")
        return null
    game_state.set("pending_result", payload)
    var packed := load("res://scenes/Result.tscn") as PackedScene
    if packed == null:
        push_error("Cannot load result scene during visual capture.")
        return null
    var instance := packed.instantiate()
    root_window.add_child(instance)
    await process_frame
    await _save_frame(path)
    return instance

func _replace_scene(root_window: Window, current: Node, scene_path: String) -> Node:
    if current != null and is_instance_valid(current):
        current.queue_free()
        await process_frame
    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_error("Unable to load QA scene: " + scene_path)
        return null
    var instance := packed.instantiate()
    root_window.add_child(instance)
    await process_frame
    return instance

func _save_frame(path: String) -> void:
    await process_frame
    await process_frame
    var image: Image = get_root().get_texture().get_image()
    if image.get_width() != 1080 or image.get_height() != 1920:
        image.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
    var error := image.save_png(path)
    if error != OK:
        push_error("Unable to save QA frame: " + path + " error " + str(error))
