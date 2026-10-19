# Navigation icons v1

Eight standalone white-mask pixel icons, integrated at the user's request. Rewards use 32 px canvases; tabs, unused items, and pause use 24 px canvases. Existing controls supply state tints, backgrounds, focus treatment, and reward badges.

`registry.json` maps stable IDs to PNG, integer-grid SVG, and layered Pixelorama sources. Original generated concepts, exact prompts, subagent geometry, and provenance are preserved under `workspace/docs/art/concepts/ui-icons/navigation-v1/`. Native drawings were authored from explicit pixel geometry in Pixelorama, not resized from the generated concepts. Each document has two or three meaningful layers.

Consumers are `scenes/run/battle_area/battle_area.tscn` and `scenes/run/character/character_panel/character_panel.tscn`. The original `assets/navigation/` artwork remains intact. This set does not replace the proposed fight or block action glyphs.

Validation:

- All eight PNGs have the requested native dimensions, alpha 0/255, and exact pixel agreement with their SVG geometry.
- All eight saved `.pxo` files were reopened successfully with expected sizes and layers.
- Godot imports are lossless, with no mipmaps; live controls use nearest filtering and report 24/32 px textures as intended.
- Existing battle UI test: 287 checks, zero failures. Existing deferred rewards test: 32 checks, zero failures. Logs are preserved in the review folder.
- Live game inspection verified all four tab icons and tooltips, reward/unused-items slots, and pause icon placement. Emitting the existing pause button signal opened the pause menu and resumed successfully.
- Contact sheet and live tab/pause screenshots are saved under `workspace/docs/art/concepts/ui-icons/navigation-v1/review/`.

Status: integrated for user review; no visual acceptance is implied. Existing color/state behavior is preserved; no new semantic palette or mechanic was added.
