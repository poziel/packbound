# Cursed depths

The biome also has dedicated `rooms/rest_room.tscn`, `rooms/relic_room.tscn`, `rooms/encounter_room.tscn` and `rooms/floor_selector.tscn` scenes. They follow the dungeon's activity layouts and interactions with violet stone, torchlight, runes and the cursed environment. Their reusable assemblies and inspection demo live in [`shared/`](shared/README.md). Gameplay selects these activities on floors 11–20, including restored runs.

An editable deeper-dungeon room: fractured masonry, a broken vault, fallen pillars and violet curses leaking through the stone. Geometry is saved as native meshes; opening or running the room never rebuilds it.

Open `demo.tscn` and press F6 to inspect it. Z toggles the shared free camera; WASD moves, Space/Ctrl rises/descends, Shift boosts and R resets. Open `rooms/cursed_room.tscn` to edit individual stones, debris, runes and lights.

The inspection camera carries the same reusable lantern light as gameplay. Select `Camera/PlayerLantern` to tune its warm fill, radius, flicker or power.

The room uses `room_definition.gd`, shared entrance/exit staircases and `EnemySlots/Slot1`. Gameplay automatically uses the original stone dungeon on floors 1–10 and Cursed Depths on floors 11–20, including resumed runs. The biome switches under the black stair transition. `GameplayBackground` exposes `encounter_room` for floors 1–10 and `deeper_encounter_room` for floors 11–20.

`shared/stairs/` holds local inherited variants with desaturated violet stone. Their dimensions, end seals, shadows and camera travel come from the shared staircase component. The room's Environment is in `cursed_environment.tres`. Curse and dust shaders animate saved meshes; the root exposes subtle light-pulse controls.

Monsters receive the room's actual 3D lighting. `CurseLights/MonsterFill` adds a restrained lavender fill on actor layer 2 to preserve dark sprite details; its native color, energy and range are editable, and it pulses with the other curse lights.

`workspace/tasks/test-organization/retained-tools/authoring/cursed_room_builder.py` creates a separate candidate in `tests/output/cursed-depths/`. It is an authoring aid, not a runtime generator; rerunning it does not overwrite hand-edited production scenes.
