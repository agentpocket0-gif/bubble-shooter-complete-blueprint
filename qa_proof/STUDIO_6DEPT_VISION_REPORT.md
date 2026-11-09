# Six-Department Studio: Replica Vision QA

## Screenshot integrity
- 01_splash_screen.png: 1080x1920, mean=91.9, std=51.1
- 02_saga_world_map.png: 1080x1920, mean=72.8, std=33.8
- 03_settings_popup.png: 1080x1920, mean=37.0, std=32.9
- 04_booster_shop_popup.png: 1080x1920, mean=37.1, std=33.2
- 05_level_1_gameplay.png: 1080x1920, mean=88.4, std=43.1
- 06_level_1_aim_preview.png: 1080x1920, mean=89.3, std=44.5
- 07_projectile_shot.png: 1080x1920, mean=88.5, std=43.3
- 08_cluster_pop_effect.png: 1080x1920, mean=87.8, std=42.9
- 09_level_win_result_popup.png: 1080x1920, mean=39.2, std=35.0

## State transition visual differences
- 01_splash_screen.png -> 02_saga_world_map.png: mean pixel difference 30.08
- 02_saga_world_map.png -> 03_settings_popup.png: mean pixel difference 43.54
- 03_settings_popup.png -> 04_booster_shop_popup.png: mean pixel difference 1.82
- 04_booster_shop_popup.png -> 05_level_1_gameplay.png: mean pixel difference 57.98
- 05_level_1_gameplay.png -> 06_level_1_aim_preview.png: mean pixel difference 0.90
- 06_level_1_aim_preview.png -> 07_projectile_shot.png: mean pixel difference 1.11
- 07_projectile_shot.png -> 08_cluster_pop_effect.png: mean pixel difference 0.97
- 08_cluster_pop_effect.png -> 09_level_win_result_popup.png: mean pixel difference 55.14

## Optional multimodal vision inspection
Overlapping panel (the "LEVEL COMPLETE!" pop-up obscures the game area)

## Result

PASS
