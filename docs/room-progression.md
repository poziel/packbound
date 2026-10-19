# Room progression and floor selectors

A numbered floor is a destination: one fight, a relic chamber, a rest area, or an encounter. The corridor between destinations does not consume a floor. After the opening fight, the player walks out to a selector, chooses a physical door, then descends into its destination.

Doors reveal only the activity type. Normal selectors offer two to four distinct eligible types, always including combat. Full health excludes rest; an exhausted relic pool excludes relic rooms. After two noncombat destinations, a single compulsory combat exit prevents an endless noncombat route. Floor 20 is always the final boss.

## State ownership

`scripts/run_state.gd` owns `floor_index`, room type, generated doors, event resolution, and reserved room relics. `fight` mirrors the zero-based floor for existing combat/catalog readers. `prepare_enemy()` synchronizes this mirror for tools and tests that directly select an enemy by depth.

`scripts/room_routes.gd` generates public door definitions and supplies authored dialogue. Contents are selected after commitment. `enter_selector()` accepts completed combat or activity rooms; `choose_destination(id)` advances depth once. `resolve_room(action)` applies a guarded activity choice. Combat uses the existing turn/playback engine.

Rest heals 30% of maximum health, rounded up and capped. Interrogation can grant an item choice, begin a fight on the same floor, or allow leaving. The blood altar costs 20% of maximum health, rounded up, and requires enough health to survive; it offers a relic choice. Activity outcomes resolve once.

The starting relic remains available. Later relics come from rooms rather than automatic floor milestones. Item rewards remain deferrable. Room relics are reserved separately from deferred relic rewards, including those retained by legacy saves.

## Scene ownership

`scripts/gameplay/gameplay_background.gd` maps logical state to scenes and handles travel with `travel_to()`. Scene replacement occurs under the fade; the shared camera, enemy actor, viewport, and lantern survive.

- `scenes/gameplay/rooms/dungeon/floor_selector.tscn` and `cursed/floor_selector.tscn` provide separately editable biome corridors. The selector leading to floor 11 uses the cursed biome.
- `scripts/gameplay/floor_selector.gd` configures eligible doors, wall infill, and chosen-exit travel markers.
- `scenes/gameplay/rooms/selector/selector_door.tscn` provides the compact doorway. The dungeon biome uses `scenes/gameplay/rooms/dungeon/shared/selector_door.tscn`, combining the shared dungeon arch with its designed exit staircase.
- `scenes/gameplay/rooms/rest/`, `relic/`, and `encounter/` contain activity scenes. The encounter room exposes its optional enemy slot only when dialogue becomes combat.
- `scenes/game/floor_flow.tscn` and `scripts/floor_flow.gd` provide invisible full-resolution door targets and activity controls. Destination labels live on physical 3D plaques. Mouse, Tab, and Enter use the same guarded actions.

All rooms retain the shared `room_definition.gd` camera/travel-marker contract. Edit the active TSCN scenes directly; runtime startup does not regenerate geometry. New biome selectors must be added to `scene_for_state()` explicitly.

Floors 1–10 use the dungeon's `encounter_room.tscn`, `relic_room.tscn` and `rest_room.tscn`. They inherit `dungeon/shared/activity_chamber.tscn`, which composes the shared masonry kit and the dungeon staircase in Entrance and Exit roles. Room-specific furniture stays in each activity scene. The relic room has three pedestals; rest retains the existing health recovery; encounters retain dialogue and optional keeper combat. Existing floor-flow controls drive these activities. Deeper floors keep their existing activity scenes.

Selectors use gray masonry, stone ceilings and ribs, iron-framed physical plaques and internal doorway glow. Door interactions retain invisible native controls for mouse, keyboard and accessibility, with all feedback rendered by the doorway. Selector `pixel_downscale = 2` keeps in-world lettering readable; other rooms retain the default of 3.

The dungeon selector reuses the construction kit in `scenes/gameplay/rooms/dungeon/shared/`. Both dungeon rooms instance these assemblies and the same `shared/staircase.tscn`, selecting Entrance or Exit per instance. The staircase embeds the 4.4-unit-wide dungeon art and preserves the native Top/Bottom route. The off-axis camera frustum centers every door count on the left gameplay controls without tilting the door wall. See `scenes/gameplay/rooms/dungeon/shared/README.md` and `demo.tscn` for reuse and placement details.

Inventory editing is permitted outside running or paused combat, with pending turn checkpoints and defeat also protected. Backpack click/drag, priority, crafting locks and stash transfers use the same run permission. Inspection remains available during live combat; routine combat refreshes preserve open tooltip windows. Loading and room travel temporarily suspend inspection.

## Physical activities

`scripts/gameplay/rooms/activity_room.gd` extends the shared room contract with physical activity anchors, hover lighting and relic retirement. `dungeon/shared/relic_pedestals.tscn` is an editable three-pedestal assembly shared by relic chambers and altar rewards. Each pedestal displays the actual offered relic as a nearest-filtered, camera-facing `Sprite3D`, with a small idle bob. Hover and keyboard focus illuminate the pedestal; its invisible full-resolution target uses the same inspector as inventory relics, including rarity and keyword stats.

Selecting a relic removes the offered sprites and lowers all three pedestals into the floor over 0.85 seconds. Room resolution is saved first, and departure stays locked until the animation completes. Restoring a completed room keeps the pedestals hidden. Skipping relics retracts the same assembly before leaving. The middle action button skips an unused activity or continues from a completed room, using the normal exit-stair travel.

Rest uses the campfire beside the central walking route. Its tooltip previews recovery, and clicking or keyboard activation heals once; full health disables resting while leaving remains available. Encounter furniture also sits beside the route. The dialogue panel opens only after interacting with the encounter object; blood offerings reveal the same physical relic offers. Inventory editing remains available while choosing activities.

Crafting opportunities, animated recipe trails and inventory resource previews use that same permission in every editable room. Mana, stamina and block previews reflect the current arrangement rather than resources left over from the previous fight. Live fights continue to display committed combat resources. `inventory_room_parity_test.gd` checks this consistency alongside priority, crafting-lock and stash operations across room phases.

## Saving and verification

Save version 2 stores generated choices, the committed destination, room rewards and applied event costs. Version 1 saves migrate at their existing depth and preserve combat playback, inventory, health and queued rewards. Reopening during travel loads its committed endpoint, without replaying the animation or advancing depth again.

Focused regressions are `room_routes_test.gd`, `room_activities_test.gd`, `room_save_test.gd`, `floor_selector_scene_test.gd`, `floor_flow_ui_test.gd`, `floor_selector_travel_test.gd`, and `floor_flow_render_test.gd`. The last two require graphics for actual door input/rendered bounds. Pass an absolute `--log-file` under `workspace/logs/` for each Godot run.

`physical_room_activity_test.gd` verifies projected relic targets, floating sprites, actual relic inspection, mouse claiming, keyboard resting, retirement, central skipping, completed-room restoration, both activity layouts and physical altar rewards. Run with graphics to check real hover tooltips and save review captures under `workspace/logs/physical-*.png`.
