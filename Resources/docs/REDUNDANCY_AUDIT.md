# nfUI redundancy audit — 2026-10-14

Reviewed the loaded Lua modules, settings categories, mover registrations, command/apply wrappers and referenced local textures.

Changes:

- Merged Player display into Player frame and Target display into Target frame. Each setting appears once; existing saved sizing/appearance values remain in their original profile tables. Old section links redirect to the merged section. Reset section resets both groups together.
- Removed minimap zone-font controls, zone mover and font updates after removal of the clock/zone strip.
- Removed a duplicate compass layout call from the command apply wrapper; the primary layout owns it.
- Removed unused inherited frame-killing/texture-hiding helpers, obsolete settings drag handling, a duplicate slash declaration and the unused ornate timer-texture builder.
- Centralized region scale lookup used by unit text and both dimension-match paths.
- Removed nine unused ornate timer textures from the addon. Recoverable copies are in `D:/Games/AzerothSurvivors/analysis/backups/nfUI-unused-timer-art`; the active gradient and minimap feather masks remain.

The quick/native/SCT damage modes are alternatives selected through Combat text settings, not concurrent duplicate renderers. The character-sheet stats, persistent character stats, run statistics and source breakdown have separate contexts; the audit did not remove requested features because they share underlying data. Fine adjustments and main settings edit the same saved values. Native HUD replacements restore the game HUD when valid data is unavailable.

Validation: complete simulated TOC boot/HUD lifecycle, unified settings callbacks/reset and dimension-link regression checks. Live UI rendering remains unverified.

## Standalone cleanup

Removed cross-addon profile imports, the embedded profile seed, comparison files and the legacy slash alias. Existing nfUI saved variables remain. Replaced character pane, ability tooltip and shield reader implementations; rebuilt unit/aura rendering and compact damage text around shared widgets and the localized parser. Both character-stat views now use one declarative model. Nameplate skin/debuff rendering uses the same widgets. Private runtime fields use nfUI names. Replaced accumulated historical README content with current controls and limitations. Required source provenance and license notices remain.

## Folder organization

Core holds initialization, shared widgets and data helpers. Settings holds the configuration, movers and adjustment actions. HUD holds visual HUD modules. Combat holds damage parsing and renderers. Resources holds textures, notices, audit documentation and file hashes. nfUI.lua and nfUI.toc are the only visible root files; GitHub reads .github/README.md. TOC dependency order is unchanged.
