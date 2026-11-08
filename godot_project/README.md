# Bubble Shooter: Classic Blast (Godot)

Godot 4 project foundation for the Android game.

## Project settings

- Portrait viewport: 1080 x 1920.
- Stretch: canvas_items.
- FPS cap: 60.
- Renderer: GL Compatibility for broad Android support.
- Android package ID: com.classicblast.bubbleshooter.

## Open and run

Open this folder in Godot 4 and run the main scene. The current splash is a bootstrap/diagnostic screen,
not a finished game screen.

## Global services

- GameManager: app state and overlay stack.
- SaveManager: versioned local JSON save.
- AssetRegistry: manifest-based resource lookup.
- AudioManager: simple sound-effect playback.

## Asset import

Production media is not bundled yet. See assets/README.md and ASSET_CREDITS.md before importing files.
