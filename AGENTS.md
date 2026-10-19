# Packbound project guidelines

## Project orientation

**Packbound: The Cursed Descent** is a single-player fantasy inventory roguelike built in Godot 4.7 with GDScript and the Compatibility renderer. Its presentation combines pixel-art 2D controls with a 3D dungeon viewed through a shared viewport. The player builds an inventory and chooses routes rather than directly steering a combat character.

The core mechanic is packing and rotating equipment on an 8 x 7 satchel grid. Footprints, adjacency bonuses, activation priorities, mana/stamina budgets, crafting recipes and relics determine the build's behavior. Relics have separate slots; loose equipment can be kept in the stash. Delvers provide different starting equipment and mechanics: Warmonger Momentum, Bowmaster Volley/quiver upgrades, Elementalist reactions, Assassin Shadowstep and Necromancer companions. Resolve names and numerical rules through the catalog and run systems rather than duplicating them in UI code.

The core loop is:

1. Start a new descent and choose a Delver, or resume a local saved run.
2. Prepare equipment: claim available rewards, pack/rotate items, arrange bonuses and recipes, and set priorities.
3. Start combat. Valid crafting resolves at combat start; equipment and enemy responses resolve in paced rounds. Combat can run automatically or wait between rounds in the turn-based mode, with pause and playback-speed settings.
4. Carry the outcome and earned rewards forward, choose a route, and enter the next room. Routes can lead to combat, rest, relics or encounters; activity rooms can resolve without a fight or lead into one.
5. Adapt the build and continue until defeat or completion of the descent. Runs and preferences are stored locally; resumed combat is restored paused.

Room/floor progression and combat playback are separate state machines. Not every floor is a fight, and rewards may remain pending rather than opening immediately after victory. Inspect `PackRun.Phase`, `CombatState` and the relevant transition methods before changing a flow; do not infer state from which panel is visible.

### Runtime entry points and authorities

| Task area | Start here |
| --- | --- |
| Engine configuration and startup | [project.godot](project.godot) selects [scenes/main.tscn](scenes/main.tscn); [scenes/main.gd](scenes/main.gd) coordinates menus, run UI, playback, world transitions and saves. |
| Run state, placement rules, resources, combat and progression | [systems/runs/run_state.gd](systems/runs/run_state.gd), the `PackRun` model. |
| Delver/item/relic/enemy definitions | [systems/content/pack_catalog.gd](systems/content/pack_catalog.gd), then its owning content loaders and asset records. |
| Crafting rules and commit point | [systems/crafting/pack_crafting.gd](systems/crafting/pack_crafting.gd), invoked by `PackRun.start_combat()`. |
| Round scheduling, pause and response timing | [systems/combat/combat_playback.gd](systems/combat/combat_playback.gd); it drives the run model rather than defining a second combat simulation. |
| Menus, options and navigation | [scenes/menus/menu_flow/menu_flow.gd](scenes/menus/menu_flow/menu_flow.gd). |
| Inventory input and stash presentation | [backpack_board.gd](scenes/run/inventory/backpack/backpack_board.gd) and [storage_inventory.gd](scenes/run/inventory/storage_inventory/storage_inventory.gd); the run model owns item state. |
| World/biome selection and travel | [gameplay_background.gd](scenes/world/gameplay_background/gameplay_background.gd), [gameplay_world.gd](scenes/world/gameplay_world/gameplay_world.gd) and [room_definition.gd](scenes/world/rooms/shared/room_definition.gd). |
| Save capture, restore and compatibility | [systems/runs/run_saves.gd](systems/runs/run_saves.gd); route choices are owned by [room_routes.gd](systems/runs/room_routes.gd). |
| Shared keyword identity and formatting | [combat_keywords.gd](systems/ui/keywords/combat_keywords.gd) and [keyword_links.gd](systems/ui/keywords/keyword_links.gd). |

These are starting points, not permission to put every new responsibility in `main.gd` or `PackRun`. Follow their existing owners and dependencies; keep focused scene behavior and shared systems separate.

## Starting a task

1. Read these instructions and the relevant scoped `AGENTS.md`, local README and applicable skill instructions. Use the orientation and entry-point table to narrow the investigation instead of reading the entire project.
2. Inspect `git status` and the relevant diff before editing. Preserve unrelated/manual work, including changes made concurrently. Do not reset, overwrite or reorganize it as incidental cleanup.
3. Find the behavior's owning scene/component/system, its callers and consuming scenes/resources. For data or persistence changes, inspect both readers and writers, stable IDs and migration/version handling. Inspect authored properties and overrides before changing them in code.
4. Establish current behavior with the smallest relevant reproduction or registered test. Record existing failures separately from changes introduced by the task; do not assume the broad suite is green or use old workspace reports as proof of current behavior.
5. Put research, diagnostics, drafts and previews in `workspace/tasks/<task-name>/`. Requested production changes go directly to their owning folders. Keep migration work separate from behavioral refactors unless both are requested.
6. For editor/tool work, check that the relevant configured MCP is actually connected and exposes the needed tools. Use available tools within the authorized task without asking again merely whether to use them; report connection or capability failures accurately.
7. Make the focused change, then verify the affected contract and relevant consumers using the test instructions below. Update active documentation when ownership, entry points or behavior changes. Finish with the change, actual verification, useful artifact paths and any unresolved limitations.

## Project map

```text
scenes/       Application entry point and scene packages
  main.tscn   Root entry scene, beside main.gd
  menus/      Navigation and menu flows
  run/        Active-run interface and composition
  world/      World orchestration, actors and shared rooms
    biomes/   Biome-owned rooms, environment and building pieces
  shared/     Cross-screen scene packages
components/   Reusable units grouped by responsibility
systems/      Shared game rules, state, persistence and services
themes/       Gameplay and menu UI appearance
assets/       Production art, audio, fonts and content definitions
tests/        Regression suites, support, fixtures and runner
docs/         Maintained project documentation
addons/       Godot editor/runtime plugins
.agents/      Project skill definitions
.codex/       Project-specific Codex configuration
.godot/       Generated editor/import cache
workspace/    Temporary task work and retained development material
```

Choose the owning responsibility before choosing the file type. A new scene/controller pair belongs together; a reusable unit belongs in its component package; shared rules or services belong in a system. Put temporary investigations and generated output in the workspace. Use the detailed rules below instead of introducing a competing folder tree. Maintain reusable project documentation in `docs/`; task research belongs in `workspace/`. Generated `.godot/` data is not the authority for production scenes or resources.

## Ownership and placement

Organize by responsibility, not file extension or 2D versus 3D. Keep one authoritative copy. Production files belong with their owner; temporary Codex work belongs in `workspace/`.

- **Scenes** compose a particular screen, room, actor or flow. Keep scene-specific scripts and resources with their scene.
- **Components** are focused reusable units with an explicit interface. They may be 2D, 3D or logic-only. Bundle their scenes, scripts, local resources, documentation and maintained demos. Being referenced by several files alone does not make a game system a component.
- **Systems** define rules, state, persistence, catalogs or services independently of a particular scene. Group them by topic under `systems/`. Node-specific presentation belongs with its scene or component.
- **Assets** hold production artwork, audio, fonts, shaders and content definitions. Reuse shared assets instead of copying them into every consumer.

Find the existing owner and consumers before adding a file. Extend that owner rather than creating a parallel implementation. Add deeper folders only for real groups of responsibility; small topics stay flat.

## Scene organization

`scenes/main.tscn` and its controller `scenes/main.gd` live directly in `scenes/` as the root entry-point exception.

| Folder | Responsibility |
| --- | --- |
| `scenes/run/` | Active-run interface and composition: character panels, inventory, battle presentation, rewards and run interactions. |
| `scenes/world/` | World orchestration, cameras, actors, biome-independent rooms and world presentation. |
| `scenes/world/biomes/<biome>/` | Biome-specific rooms, architecture, environment and local reusable pieces. |
| `scenes/menus/` | Home, run/class selection, options, pause, death and other menu flows. |
| `scenes/shared/` | Scene packages used across screens or flows, such as loading and inspection. |

Each non-root scene has its own package folder, normally `<scene_name>/<scene_name>.tscn`. Put a dedicated controller beside its scene with the same basename. Keep scene-local resources and helpers in that package. Add subfolders for larger packages instead of mixing unrelated scenes. Reusable component families retain their own variants and maintained demos inside their component package.

Shared base scripts used by related scene variants live at their nearest common scene owner, in a clearly named `shared/` folder when appropriate. Reference the shared implementation rather than copying it. A scene may use shared behavior without having a dedicated controller.

Biomes use:

- `rooms/<room_name>/` for combat, encounter, floor selector, relic, rest and other biome-specific room packages.
- `shared/<piece_name>/` for construction pieces reused within the biome.
- Biome-wide resources and documentation at the biome root, grouped further when useful.

Biome-independent rooms live under `scenes/world/rooms/`. Cross-biome world pieces live under `scenes/world/shared/` when needed. A biome may reuse a common room or provide a variant. Room definitions choose the scene explicitly; folders do not implement fallback behavior.

## Components and systems

Keep components self-contained under `components/<category>/<component_name>/`. Preserve editable scenes, public interfaces, intentional instance overrides, README and maintained demos. Use these responsibility categories:

| Category | Responsibility |
| --- | --- |
| `components/ui/buttons/` | Button families and their shared frame helpers. |
| `components/ui/inputs/` | Search fields and scrolling controls. |
| `components/ui/layout/` | Panels, connected tabs and layout primitives. |
| `components/ui/indicators/` | Resource/stat bars and status glyphs. |
| `components/ui/shared/` | UI behavior shared across component categories, such as theme bindings. |
| `components/inventory/` | Reusable inventory controls and item slots. |
| `components/characters/` | Reusable character presentation controls. |
| `components/world/lighting/` | Reusable world lights and their fixtures, such as torches and lanterns. |
| `components/world/architecture/` | Reusable structural pieces, such as staircases. |
| `components/world/decorations/` | Reusable room props and decorative 3D elements. |
| `components/tools/` | Inspection and authoring components, such as the free camera. |

Biome-exclusive pieces stay with their biome. A reusable decoration owns its scene, behavior and local resources; shared production art remains in `assets/`. Scene-specific node wiring belongs in its scene package, and theme resource scripts belong with the consuming theme. Do not group components by 2D versus 3D or use `shared/` as a catch-all.

Use `systems/<topic>/` for shared systems such as combat rules, crafting, run state/saves, catalogs, item definitions and audio services. Nest by ownership when useful. Cross-domain catalogs and art lookup remain shared authorities until a deliberate refactor splits them.

Do not recreate `scripts/` as a second home for production code. Maintained project build tools belong with their owning subsystem in a clearly named tools folder; temporary helpers belong in `workspace/`.

## Godot authoring rules

- **Save stable structure in scenes.** Author screens, controls, room geometry, reusable pieces and important placement markers in `.tscn` files so they can be inspected and edited independently. Use runtime nodes for state-dependent instances, effects, generated content and intentional overlays. Do not recreate an authored layout on startup or overwrite editor changes to make code agree with an old layout assumption.
- **Preserve scene contracts.** Keep meaningful node names, exported properties, unique-name lookups, inheritance and resource UIDs stable. Inspect consumers before changing them. Use exports, signals and clear component interfaces for configurable behavior instead of adding brittle cross-scene lookups.
- **Respect node lifecycle and ownership.** Use `_ready()`/`@onready` for nodes that require the instantiated tree. Connect signals once and disconnect external bindings when their lifetime ends. Clean up temporary nodes, timers, tweens and audio according to their owning lifetimes. When packing generated authoring output, assign `owner` deliberately so intended nodes are saved without taking over inherited or externally owned children.
- **Keep authored objects intact.** Intentional runtime reparenting, such as projected enemy vitals or a drag overlay, must preserve node identity, references and the intended coordinate space. Update explicit parent/path contracts and tests together; do not replace nodes simply to satisfy a path lookup.
- **Respect UI layout ownership.** Containers own their children's layout. Preserve authored anchors, offsets, minimum sizes, focus behavior and explicit instance overrides. Avoid per-frame layout writes that fight containers or erase editor styling. Keep shared appearance in the two active themes or the owning reusable component.
- **Handle shared resources deliberately.** Loaded materials, styles and other resources may be shared by multiple instances. Make them unique when an instance needs local mutation; change the shared resource only when all consumers are intended to change. Preserve the editable source and reference chain rather than baking an accidental runtime state into production assets.
- **Keep editor previews safe.** `@tool` scripts should support editing and previewing without starting gameplay, consuming run RNG, writing player saves or repeatedly rebuilding authored content. Use `Engine.is_editor_hint()` where editor/runtime behavior differs. Preserve existing explicit authoring tools and preview controls.
- **Keep world ownership consistent.** The shared world owns the camera, actor collection and room swapping. Rooms own scenery, environment/lens parameters and editor-visible travel/enemy placement markers. Extend `room_definition.gd` or its existing derived behavior and preserve the marker/staircase interface instead of putting independent cameras and combat actors in every room.
- **Keep rules in their authority.** UI and animation consume model results; they must not implement a second damage, crafting, inventory or progression engine. Preview/inspection must not consume items, commit crafting, advance combat or mutate gameplay RNG. Keep state transitions and commit points explicit; timing and decorative randomness must not alter deterministic gameplay outcomes.
- **Preserve saved state.** Changes to run fields, content IDs or serialized formats require inspection of capture/restore and compatibility handling. Keep local preferences and player saves separate from test data; verification uses the isolated test runner.
- **Verify at the right level.** After scene/resource moves, import once before testing. Inspect changed scenes/components independently where supported, and verify their actual consuming flow. Use the real renderer for visual claims; a headless pass validates only its executed nonvisual contracts. Keep logs and review captures in the task workspace.

## Themes and assets

- Active UI themes remain in `themes/gameplay/` and `themes/menu/`. These names describe styling contexts independently of scene folders. Preserve both themes and intentional instance overrides.
- Keep shared appearance in its theme or reusable component; preserve explicitly authored scene-local art direction.
- Group `assets/` by purpose and content identity: characters, enemies, items, relics, backgrounds, UI/navigation, branding, fonts, shaders and audio/music.
- Keep accepted editable sources, exports, definition records and provenance in the owning active asset folder. Preserve stable IDs and existing formats during folder-only changes.
- Effects and the bus layout use `assets/audio/`; music and ambience use `assets/musics/`. Inspect local READMEs before adding material.
- Concepts, review candidates, screenshots, backups and superseded revisions belong in `workspace/`. Exploring art does not accept it as a runtime replacement.
- Do not redraw, rescale or replace accepted artwork during organization work. Detailed art contracts and creator-skill guidance will be revised separately.

## Workspace

`workspace/.gdignore` excludes working material from Godot imports. Production scenes, assets and systems must not depend on this folder. See [workspace/README.md](workspace/README.md) for the detailed convention.

Put all temporary work for one task in `workspace/tasks/<task-name>/`: research, drafts, scripts, concepts, logs, screenshots, previews, isolated environments and verification reports. Add subfolders as needed. Write Godot diagnostics to the task's `logs/` with an explicit absolute `--log-file` path.

Retain material useful across tasks in:

| Folder | Purpose |
| --- | --- |
| `workspace/docs/` | Reusable research, references, planning and design decisions. |
| `workspace/art/` | Unaccepted art studies and editable experiments retained for future work. |
| `workspace/reviews/` | Reusable comparisons, screenshots and review material. |
| `workspace/scripts/` | Reusable development helpers. |
| `workspace/logs/` | Diagnostics spanning tasks. |
| `workspace/archives/<category>/` | Verified ZIPs of superseded material and snapshots. |

Promote useful material when its ongoing purpose is clear. Do not recreate `working/`, `expansion/`, loose temporary root files or archive directories under production assets. Preserve historical logs and archive contents rather than rewriting their recorded paths.

## Tests

Read [tests/AGENTS.md](tests/AGENTS.md) before creating, changing or relocating any test, including component-local tests. [tests/README.md](tests/README.md) describes runner commands and reports; `tests/manifest.json` is the executable inventory.

| What is being tested | Location |
| --- | --- |
| Rules/state without application or presentation scene setup | `tests/systems/<topic>/` |
| One scene owner's behavior, input, layout or world composition | `tests/scenes/<owner>/` |
| Mixed rule/UI behavior, persistence journeys or multiple application scenes | `tests/integration/<topic>/` |
| A reusable component in isolation | `components/<category>/<component>/tests/` |
| Shared setup, assertions, input simulation or cleanup | `tests/support/` |
| Controlled, read-only test inputs | `tests/fixtures/` |

Register each runnable test with a stable ID, current path, suites, rendering requirement and realistic timeout. Extend a helper-only support base, never another runnable test. Use counted assertions and the shared result protocol; keep fixtures deterministic and waits bounded.

Always run through `tests/run_tests.ps1` so settings, saves and artifacts are isolated under `workspace/tasks/test-runs/<run-id>/<test-id>/`. Use the shared artifact helper rather than hardcoding `tests/output/`, `.tmp/`, real player data or a previous task's folder. Component tests follow the same registration, isolation and reporting rules.

Keep capture, preview, bake and migration utilities outside the regression suite. Screenshots are review evidence; rendering-dependent assertions need the real renderer. Preserve passed/failed/skipped/timed-out distinctions and report the actual scope tested. Do not remove assertions, hide failures, revise game behavior or mark tests skipped merely to make a suite green.

## Naming and migrations

- Use lowercase `snake_case` for new production directories and files. Name packages by responsibility and scene/controller pairs after their scene. Preserve established class names and content IDs unless a rename is requested.
- Use descriptive workspace task names and retain existing task naming conventions rather than renaming historical material for style alone.
- Move paired `.uid` files with scripts. Preserve resource UIDs, inheritance, exported properties and authored node paths.
- Update resource paths, preloads, dynamic path construction, test fixtures, build tools, documentation and active provenance references when moving files. Check filesystem-relative helper paths too.
- Preserve unrelated and uncommitted work. Keep folder migrations separate from behavior changes; do not retain duplicate old/new implementations.
- Validate moved files and references, then run relevant Godot import/tests when available. Report actual checks and runtime verification limits. Keep diagnostic output in `workspace/`.
