# nfUI

A configurable HUD for Azeroth Survivors, loaded through the addon environment. Enable nfUI in the addon list, then use `/nfui` to open settings. Existing `nfUIDB` and `nfUIPlatesDB` settings are preserved; profiles from other addons are not imported.

## Controls

- Settings: player/target frames, character stats, nameplates, compass, minimap, chat, run panels, DPS meter and combat text.
- Unlock movers in settings to position elements. The grid snaps anchors; hold Shift to bypass snapping.
- Right-click a mover for adjustments and persistent Width Match / Height Match links. Choose a match, then click the element to follow.
- Numeric controls accept typed values; mover adjustments also have single-step buttons.
- Resize settings with the bottom-right grip. The control layout scales without wrapping.
- Run Stats and DPS unfold upward from their bottom headers. Their arrows follow the side of the screen.
- Minimap zoom buttons appear on hover. Feathering replaces its outer border.

## Feature controls

Open `/nfui` and select a section:

- **Run Stats:** show or hide the panel, expand or collapse it, and reset local hit/crit tracking. Resetting does not reset native run totals.
- **DPS Meter:** use **Expanded** to open or collapse the meter.
- **Combat text:** choose icon combat text, compact damage labels, native damage text or disabled.
- **Compass:** toggle **Show compass**.

These controls replace the former `/nfui` feature subcommands and `/sct` alias. `/nfui` opens settings.

## Behavior and limits

The compass tracks map landmarks and registered marker providers. Off-screen bearings stay at the nearest strip edge; icons shift vertically to remain on screen. Random world-only Battleground Caches cannot currently be located through the identified addon APIs, so automatic cache detection is not implemented.

Nameplate stacking prefers upward placement, with a downward fallback near the top of the screen. Movement and appearance transitions take two seconds. Projected scale and screen position approximate proximity; they are not exact world distance. Native nameplate hit regions remain at their original anchors.

Run, meter and character values use the client's available native data. The local run fallback can differ from native totals. Zero character stats are hidden; Health and Lives are hidden from the persistent display. Camera zoom limit factor 5 is applied at startup without changing the current zoom distance.

## Implementation

Shared widgets, a shared character-stat model and one localized combat-event parser serve the HUD modules. Unit frames, auras, character pane, ability tooltips, shield reading and compact damage labels have dedicated nfUI implementations. Selected adapted combat-text code remains credited in its source and in `third_party`.

The addon targets the legacy Lua interface. Simulated lifecycle and targeted regression checks run outside the shipped folder; live appearance and native hit testing still require in-game verification. Use `/reload` after updating.

Third-party notices are in [third_party/README.md](third_party/README.md). Backups and comparison material are kept outside this addon.
