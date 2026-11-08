# Visual QA report

| screenshot | size | mean brightness | stddev |
|---|---|---|---|
| 01_splash_screen.png | 1080x1920 | 28.5 | 36.0 |
| 02_saga_world_map.png | 1080x1920 | 33.0 | 24.5 |
| 03_piggy_bank_open.png | 1080x1920 | 26.5 | 38.5 |
| 04_piggy_bank_closed_back_to_map.png | 1080x1920 | 32.9 | 24.4 |
| 05_store_and_spin_wheel.png | 1080x1920 | 31.4 | 42.0 |
| 06_level_1_active_gameplay.png | 1080x1920 | 34.4 | 42.0 |
| 07_after_shot.png | 1080x1920 | 33.7 | 40.8 |

| pair | pixels differing | why it matters |
|---|---|---|
| 03_piggy_bank_open.png vs 04_piggy_bank_closed_back_to_map.png | 75.7% (min 2.0%) | the Close button must visibly close the popup |
| 02_saga_world_map.png vs 06_level_1_active_gameplay.png | 21.7% (min 2.0%) | tapping Level 1 must visibly open the board |
| 06_level_1_active_gameplay.png vs 07_after_shot.png | 1.5% (min 0.4%) | a shot must visibly change the board |

## Result: PASSED

Every screen rendered real content, and every pair that must differ does.
