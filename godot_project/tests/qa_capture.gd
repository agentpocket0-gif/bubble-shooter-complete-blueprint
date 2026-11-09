extends SceneTree

const SEQUENCE := [
    ["01_splash_screen.png", "res://scenes/Splash.tscn", ""],
    ["02_saga_world_map.png", "res://scenes/SagaMap.tscn", ""],
    ["03_settings_popup.png", "res://scenes/SagaMap.tscn", "settings"],
    ["04_booster_shop_popup.png", "res://scenes/SagaMap.tscn", "store"],
    ["05_level_1_gameplay.png", "res://scenes/Gameplay.tscn", ""]
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
    var current: Node = null
    for item in SEQUENCE:
        if current != null:
            current.queue_free()
            await process_frame
        current = load(item[1]).instantiate()
        root_window.add_child(current)
        await process_frame
        await create_timer(0.35).timeout
        if item[2] == "settings":
            current.call("qa_open_settings")
        elif item[2] == "store":
            current.call("qa_open_store")
        await _save_frame(output_dir.path_join(item[0]))
    if current != null:
        current.queue_free()
        await process_frame
    current = load("res://scenes/Gameplay.tscn").instantiate()
    root_window.add_child(current)
    await process_frame
    await create_timer(0.4).timeout
    current.call("qa_set_stage", "aim")
    await _save_frame(output_dir.path_join("06_level_1_aim_preview.png"))
    current.call("qa_set_stage", "shoot")
    await _save_frame(output_dir.path_join("07_projectile_shot.png"))
    current.call("qa_set_stage", "booster")
    current.call("qa_set_stage", "pop")
    await _save_frame(output_dir.path_join("08_cluster_pop_effect.png"))
    current.call("qa_show_result")
    await _save_frame(output_dir.path_join("09_level_win_result_popup.png"))
    print("Captured nine full-HD QA screenshots in ", output_dir)
    quit(0)

func _save_frame(path: String) -> void:
    await process_frame
    await process_frame
    var image: Image = get_root().get_texture().get_image()
    if image.get_width() != 1080 or image.get_height() != 1920:
        image.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
    var error := image.save_png(path)
    if error != OK:
        push_error("Unable to save QA frame: " + path + " error " + str(error))
