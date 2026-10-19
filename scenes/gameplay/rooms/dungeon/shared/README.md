# Dungeon construction kit

Reusable, editable `MeshInstance3D` assemblies extracted from the active dungeon room. These use the original meshes, material colors, spacing and depth-shadow treatment. They are not a procedural replacement for the dungeon's masonry.

| Scene | Construction and placement |
| --- | --- |
| `wall_chunk.tscn` | 25 staggered bricks over a recessed 4 x 3.4 x 0.12 mortar backing. Repeat every 4 units horizontally and 3.4 vertically. The staggered right edge extends beyond the nominal pitch. A positive `clip_width` trims bricks and backing together without stretching. |
| `wall_span.tscn` | Two rows of four self-backed wall chunks. `set_span(width)` fills up to 16 units, hiding unused chunks and clipping boundary bricks and backing. No separate oversized span backing. |
| `floor_chunk.tscn` | Four original flagstones over two adjoining foundation strips following the staggered footprint. Repeat every 3.9 units across and 4.2 units deep. Tile tops are 0.025 units above the recessed foundation surface. |
| `column.tscn` | Original base and ten shaft blocks surrounding a recessed 0.54 x 8.3 x 0.64 solid core. The core seals the joints while preserving projecting stone faces. |
| `door_frame.tscn` | 21 jamb, arch and keystone pieces with recessed connecting cores. One duplicate source block was removed. Jamb bricks inset 0.07 units into the nominal four-unit opening and project 0.10 units toward the room, avoiding flush faces against stair walls. Center at floor height, facing +Z. |
| `roof_chunk.tscn` | Four original ceiling stones beneath a 3.2 x 0.2 x 3.7 solid backing. Repeat every 3.2 units across and 3.7 units deep; root height 7.12 matches the existing dungeon ceiling. |

Open `demo.tscn` to inspect the pieces together. All production geometry is saved in these scenes; startup does not regenerate it. The five matching assemblies in `dungeon_room.tscn` now instance this kit in their original positions. `provenance.json` records the extracted node paths, component origins and source hashes. Each individual piece also retains its original node path as metadata.

The extraction provenance describes the initial source assemblies. Subsequent construction edits add the recessed cores and foundations described above and adjust the door-frame fit; these additions are authored directly in the component scenes. Their dark mortar uses the same depth-shadow pass as the original stone.

## Stairs and room integration

Use `shared/staircase.tscn` for all dungeon stairs and select **Role: Entrance / Exit** per instance. This scene inherits `components/staircase/staircase.tscn` and embeds the dungeon treads, brickwork, torch, solid backing and fitted ceiling. The separate dungeon entrance, exit and geometry scenes have been removed.

The dungeon staircase has a **4.4-unit** visual envelope, keeping root scale at one and preserving the fourteen steps, 3.92-unit rise, 11.9-unit run and `Top`/`Bottom` camera route. Guides and end-cap width match the wider geometry. The selector's saved 1.115 frame scale is preserved; the combat frame uses that same fit. Leave the root scale at one.

The combat room also replaces 230 matching loose meshes with 40 additional shared-kit instances: 19 floor chunks, 17 roof chunks, three wall chunks and one column. Per-piece material overrides preserve the source palette. Remaining partial edge pieces and bespoke scenery stay authored in place.

The dungeon selector instances the entry scene under `EntryStairs`. Every physical door instances the dungeon exit scene. `floor_selector.gd` resolves departure markers and tilt from the chosen door's `ExitStairs`, so the camera walks to that opening before descending. Its entry uses the same stair marker contract to descend first and then approach `CameraStart`.

The selector's camera faces the door bank straight on. Its off-axis frustum centers the doors on the left gameplay controls for every door count while the inventory uses the right half. Door spacing, wall limits and center are Inspector properties on the selector; the narrow cursed selector retains its own layout.

On `shared/selector_door.tscn`, configure **Hover Glow Color** and **Hover Glow Intensity** (0–1). **Staircase Path** targets the component root (`ExitStairs`), whose inherited controller owns the actual light; geometry children need no extra parameters. Hover forwards the color and animates that component's intensity, returning it to zero on exit. Dungeon doors have no second glow light or overlay. The complete unshaded sign, including its outline, transitions to the same glow color and restores its saved colors on exit.

Dungeon doors default to intensity **0.06** (12 light energy), four times the former hover brightness. The whole 0–1 range remains available.

Hover also reduces the staircase's configured depth strength to 35% and blends its depth color 12% toward the glow hue. This exposes the illuminated stone and gently colors the closed end of the passage. Leaving restores the original depth strength/color, including when a hover animation is interrupted. These adjustments belong to the door interaction; the shared staircase keeps its simple glow and depth properties.

Checks: `dungeon_selector_kit_test.gd`, `floor_selector_scene_test.gd`, `floor_selector_travel_test.gd`, `floor_flow_render_test.gd`, `staircase_component_test.gd` and `gameplay_world_test.gd`. Authoring/audit logs and rendered review captures belong under `workspace/logs/`.

## Activity rooms

`activity_chamber.tscn` is the shared dungeon shell for `../encounter_room.tscn`, `../relic_room.tscn` and `../rest_room.tscn`. It instances this kit for its floor, ceiling, walls, columns and frames, and uses `staircase.tscn` for both arrival and departure. Room-specific furniture stays in its own scene: the keeper's table and chair, three relic pedestals, or benches and a hearth.

Dungeon activity scenes are selected on floors 1–10; deeper floors retain the existing fallback scenes. Activities use the existing floor-flow choices and run rules. Encounter combat still reveals its enemy only after refusal. `dungeon_activity_rooms_test.gd` verifies scene selection and the shared travel contract; `room_activities_test.gd` verifies healing and rewards.
