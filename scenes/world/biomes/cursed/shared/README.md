# Cursed room kit

Floors 11–20 use the cursed combat room, rest room, relic room and encounter room. The selector leading into floor 11 already uses this biome.

`activity_chamber.tscn` composes the inherited masonry pieces, entrance/exit staircases, violet torches and `ambience.tscn`. Rest, relic and encounter scenes instance this chamber and retain their physical activity scripts and root-level furniture anchors. `selector_door.tscn` combines the same arch and staircase with readable plaques and violet hover illumination. The selector uses the dungeon's current spacing and camera registration.

The wall, floor, roof, column, arch, staircase and pedestal variants inherit the dungeon kit's saved geometry. Their overrides reference four shared editable materials: `dark.tres`, `stone.tres`, `edge.tres` and `pale.tres`. Editing the dungeon source geometry propagates to these variants; editing these palette resources changes only the cursed variants. `wall_span.tscn` retains the shared clipping controller and instances cursed wall chunks. No runtime geometry generation is used.

`ambience.tscn` contains editable rune strokes, the existing animated curse shader and local violet lights. Instance it in another room to reuse the effect. The room environment remains `../cursed_environment.tres`; activity furniture and campfire lighting can be tuned in each room scene.

Open `demo.tscn` and press F6 to inspect the composed chamber with the shared free camera and player lantern. Z enables free movement; WASD moves, Space/Ctrl rises/descends, Shift boosts and R resets. The separate `../demo.tscn` continues to showcase the existing combat room.

Verification: `tests/scenes/world/floor_selector_scene_test.gd` covers scene loading, environments, runes, travel markers and optional keeper combat. `tests/scenes/world/physical_room_activity_test.gd` covers real activity targets, tooltips, rewards, retirement and deeper-biome routing. Review captures live under `workspace/logs/physical-later-*.png` and `workspace/logs/selector-cursed-*.png`.
