# Milestone 1 status

## Implemented on this branch

- Godot 4 project scaffold in godot_project/.
- Portrait viewport: 1080 x 1920.
- Canvas-items stretch mode and 60 FPS cap.
- Android export preset records package ID com.classicblast.bubbleshooter.
- Global GameManager, SaveManager, AssetRegistry, and AudioManager autoloads.
- Versioned JSON save foundation with temporary-file replacement and backup fallback.
- Asset manifest schema and a static asset-integrity validator.
- Minimal bootstrap scene to confirm the project entry point.

## Blocked and not claimed as complete

- Link 3 production art/audio/font pack: not imported because the Drive folder could not be retrieved.
- Link 2 chh.zip: not inspected; it remains a code/logic reference only.
- Link 1 Drive folder: not independently retrieved. The ten original blueprint documents already present in this repository were used as the available specification source.
- Godot headless import/run: not executed in this environment. Run it in CI or a Godot 4 editor before accepting the milestone.

## Milestone 1 acceptance

| Check | Status |
|---|---|
| Project configuration and scene paths created | Ready for Godot validation |
| Autoload script files exist | Ready for Godot validation |
| Android package ID recorded | Ready for Godot export validation |
| Asset manifest parses | Static validator |
| Every production asset file exists | Blocked: zero imported assets |
| Code reference reviewed | Blocked: chh.zip inaccessible |
| Godot runtime launch verified | Not run |

This is a partial foundation commit, not a claim that Milestone 1 is complete.
