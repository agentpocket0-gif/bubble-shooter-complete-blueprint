# Asset rights and provenance

## Current pack

`godot_project/assets/real_pack/REAL_PACK_MANIFEST.json` states:
- provenance: third-party APK resources;
- `publishable: false`;
- total measured files: 1,595, including 69 animation resources, 142 audio files, 116 branding, 85 bubbles, 49 level/font resources, 110 map backgrounds, 497 sliced sprites and 527 UI items.

This inventory is evidence that an extracted resource pack exists. It is not proof that the assets are owned by the user or licensed for redistribution.

## Required handling

- Do not copy these extracted assets into the shipping Godot project, Android APK/AAB, Play Store screenshots, public asset packs or generated app icons.
- Private study may use measurements and high-level behaviour only to the extent permitted by the app's terms and applicable law.
- Make original replacements: bubble spheres, boosters, cannon, world map, panels, icons, particles, animation frames and sounds.
- For every shipped file, record creator, source URL, exact license, date, modifications and attribution.
- Reject unknown, non-commercial, no-derivatives or unclear licences.
- Do not publish private reverse-engineering output.

## Repository visibility warning

At the time of this audit the GitHub repository API reports `private: false`. This repository includes the `real_pack` directory whose own manifest says it is third-party content and not publishable, plus decompiled study data. The repo owner should make it private before further analysis and review repository history/releases for sensitive files. This branch deliberately does not change repository visibility.

## Original visual target

The user's later request was for a polished, glossy, dimensional look. Replace the existing simple generated SVG placeholders with original assets that have a consistent light source, reflections, inner gradients, rim shading, shadows, high-quality UI panels and a real particle/animation system. Avoid copying the source game's distinctive logo, characters, artwork, layouts or exact level boards.
