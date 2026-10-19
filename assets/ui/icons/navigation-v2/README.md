# UI navigation icons v2

Fresh native redraw of all eight requested controls using `.agents/skills/ui-icons-art-creator/SKILL.md`, authored in Pixelorama with two or three meaningful layers per document. White masks use the existing theme tints. Tabs, unused items and pause are 24 px; the two reward controls are 32 px. The earlier v1 set is preserved.

The registry maps IDs to PNG, integer-grid SVG, layered `.pxo`, alpha bounds and provenance. Subagent drawing specifications and review images are under `workspace/docs/art/concepts/ui-icons/navigation-v2/`. These are newly drawn native designs, not resized v1 images. No image-generation concept pass was used for v2.

Integration changes only the eight icon resource paths in `scenes/run/battle_area/battle_area.tscn` and `scenes/run/character/character_panel/character_panel.tscn`. Existing labels, signals, badges, layout and control state behavior remain in place.

Verified:

- All eight saved Pixelorama documents reopen with the expected canvas and layer counts.
- All exports have binary alpha and white ink; PNGs match their SVG geometry pixel-for-pixel. Every icon differs from v1.
- Live controls and freshly loaded scenes resolve the v2 resources at native 24/32 px sizes. Buttons retain nearest filtering.
- In-game inspection includes selected/unselected tabs, enabled relic rewards with their separate badge, disabled item rewards, unused items, and pause.
- Battle UI regression: 288 checks, zero failures.

The separate deferred-rewards test could not complete: current `scenes/main.gd:232` accesses a missing `has_response` dictionary key during combat. Its log is retained in `workspace/docs/art/concepts/ui-icons/navigation-v2/review/rewards-test.log`. No combat code was changed in this icon revision. The live editor also reports existing scrollbar-style errors; this is not a claim that the whole editor is error-free.

Status: integrated for user review, not yet visually accepted. See the contact sheet and in-game screenshot in the review folder.
