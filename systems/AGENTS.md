# Shared systems

Read the root [guidelines](../AGENTS.md). Node-specific presentation belongs in its [scene](../scenes/AGENTS.md) or [component](../components/AGENTS.md).

Use `systems/<topic>/` for shared systems such as combat rules, crafting, run state/saves, catalogs, item definitions and audio services. Nest by ownership when useful. Cross-domain catalogs and art lookup remain shared authorities until a deliberate refactor splits them.

Do not recreate `scripts/` as a second home for production code. Maintained project build tools belong with their owning subsystem in a clearly named tools folder; temporary helpers belong in `workspace/`.

## Runtime authorities

| Task area | Start here |
| --- | --- |
| Run state, placement rules, resources, combat and progression | [systems/runs/run_state.gd](runs/run_state.gd), the `PackRun` model. |
| Delver/item/relic/enemy definitions | [systems/content/pack_catalog.gd](content/pack_catalog.gd), then its owning content loaders and asset records. |
| Crafting rules and commit point | [systems/crafting/pack_crafting.gd](crafting/pack_crafting.gd), invoked by `PackRun.start_combat()`. |
| Round scheduling, pause and response timing | [systems/combat/combat_playback.gd](combat/combat_playback.gd); it drives the run model rather than defining a second combat simulation. |
| Save capture, restore and compatibility | [systems/runs/run_saves.gd](runs/run_saves.gd); route choices are owned by [room_routes.gd](runs/room_routes.gd). |
| Shared keyword identity and formatting | [combat_keywords.gd](ui/keywords/combat_keywords.gd) and [keyword_links.gd](ui/keywords/keyword_links.gd). |

Room/floor progression and combat playback are separate state machines. Not every floor is a fight; rewards may remain pending. Inspect `PackRun.Phase`, `CombatState` and transitions rather than visible panels. Avoid accumulating unrelated responsibilities in `PackRun`.

- **Keep rules in their authority.** UI and animation consume model results; they must not implement a second damage, crafting, inventory or progression engine. Preview/inspection must not consume items, commit crafting, advance combat or mutate gameplay RNG. Keep state transitions and commit points explicit; timing and decorative randomness must not alter deterministic gameplay outcomes.
- **Preserve saved state.** Changes to run fields, content IDs or serialized formats require inspection of capture/restore and compatibility handling. Keep local preferences and player saves separate from test data; verification uses the isolated test runner.
