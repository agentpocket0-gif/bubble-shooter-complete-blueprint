# Clean-room rebuild workstream

This branch is a corrective rebuild track, not a new release. It starts by recording evidence, missing features and acceptance gates before changing gameplay code.

## Source of truth

1. Read all ten documents in `blueprint/original/`.
2. Treat `blueprint/reference/` as unavailable until a complete, user-authorized reference APK is supplied and actually analyzed. The current folder contains only its README.
3. Use the user-established product target of **600 campaign levels and three game modes**. The written master spec says 100 levels; that older value is superseded for this rebuild. The names and exact rules of the three modes must come from verifiable user material, not guesses.
4. Art direction for the rebuild is the user's later request for a polished glossy / dimensional presentation. The original asset spec describes simpler vector art; the visual target must be reconciled against the user recordings and not reduced to flat placeholder shapes.
5. The Godot project remains the Android delivery target unless the project owner explicitly changes it.

## Documents in this folder

- `00_SOURCE_AUDIT.md` — what is actually present and what is missing.
- `01_RECON.md` — screen inventory and end-to-end flows.
- `02_FEATURE_MATRIX.csv` — auditable parity matrix.
- `03_BUILD_CONTRACT.md` — implementation order and definition of done.
- `04_ASSET_RIGHTS_AND_PROVENANCE.md` — asset rules and the current public-repository risk.
- `05_QA_GATES.md` — release gates that the previous pipeline did not enforce.

## Hard rule

A successful export is not proof of a completed game. A feature is complete only when it is implemented, playable, persisted correctly where required, covered by a test, and shown in a real Android-device capture for device-dependent behaviour.
