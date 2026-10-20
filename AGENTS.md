# Packbound project guidelines

## Project orientation

**Packbound: The Cursed Descent** is a single-player fantasy inventory roguelike built in Godot 4.7 with GDScript and the Compatibility renderer. Its presentation combines pixel-art 2D controls with a 3D dungeon viewed through a shared viewport. The player builds an inventory and chooses routes rather than directly steering a combat character.

The core mechanic is packing and rotating equipment on an 8 x 7 satchel grid. Footprints, adjacency bonuses, activation priorities, mana/stamina budgets, crafting recipes and relics determine the build's behavior. Relics have separate slots; loose equipment can be kept in the stash. Delvers provide distinct starting equipment and mechanics. Resolve names and numerical rules through the catalog and run systems rather than duplicating them in UI code.

The core loop is:

1. Start a new descent and choose a Delver, or resume a local saved run.
2. Prepare equipment: claim available rewards, pack/rotate items, arrange bonuses and recipes, and set priorities.
3. Start combat. Valid crafting resolves at combat start; equipment and enemy responses resolve in paced rounds. Combat can run automatically or wait between rounds in the turn-based mode, with pause and playback-speed settings.
4. Carry the outcome and earned rewards forward, choose a route, and enter the next room. Routes can lead to combat, rest, relics or encounters; activity rooms can resolve without a fight or lead into one.
5. Adapt the build and continue until defeat or completion of the descent. Runs and preferences are stored locally; resumed combat is restored paused.

Room/floor progression and combat playback are separate state machines. Not every floor is a fight, and rewards may remain pending rather than opening immediately after victory. Inspect `PackRun.Phase`, `CombatState` and the relevant transition methods before changing a flow; do not infer state from which panel is visible.

Startup: [project.godot](project.godot) selects [scenes/main.tscn](scenes/main.tscn); [main.gd](scenes/main.gd) coordinates application flows. [PackRun](systems/runs/run_state.gd) owns run state and rules. Detailed runtime authorities live in the owner guides below; do not put every new responsibility in these entry points.

## Starting a task

1. Read these instructions and the relevant scoped `AGENTS.md`, local README and applicable skill instructions. Use the orientation and linked owner guides to narrow the investigation instead of reading the entire project.
2. Inspect `git status` and the relevant diff before editing. Preserve unrelated/manual work, including changes made concurrently. Do not reset, overwrite or reorganize it as incidental cleanup.
3. Find the behavior's owning scene/component/system, its callers and consuming scenes/resources. For data or persistence changes, inspect both readers and writers, stable IDs and migration/version handling. Inspect authored properties and overrides before changing them in code.
4. Establish current behavior with the smallest relevant reproduction or registered test. Record existing failures separately from changes introduced by the task; do not assume the broad suite is green or use old workspace reports as proof of current behavior.
5. Put research, diagnostics, drafts and previews in `workspace/tasks/<task-name>/`. Requested production changes go directly to their owning folders. Keep migration work separate from behavioral refactors unless both are requested.
6. For editor/tool work, check that the relevant configured MCP is actually connected and exposes the needed tools. Use available tools within the authorized task without asking again merely whether to use them; report connection or capability failures accurately.
7. Complete the requested behavior and verify the affected contract and relevant consumers using the test instructions below. Update active documentation when ownership, entry points or behavior changes. Before finishing, review the diff for unintended changes and confirm that requested work is complete or explicitly identify what remains blocked. Report the change, actual verification, useful artifact paths and unresolved limitations.

## Project map and placement

Organize by responsibility, not extension or 2D versus 3D. Keep one authoritative copy. Read the linked guide before working in that area; nested guides and READMEs should not be assumed to have loaded automatically.

| Root area | Ownership and guide |
| --- | --- |
| `scenes/` | Screens, rooms, actors and flows with dedicated scripts/resources. [Scene architecture](scenes/AGENTS.md). |
| `components/` | Focused reusable 2D, 3D or logic units with explicit interfaces. [Component packages and categories](components/AGENTS.md). |
| `systems/` | Shared rules, state, persistence, catalogs and services independent of a scene. [System ownership and authorities](systems/AGENTS.md). |
| `themes/` | Shared gameplay/menu UI appearance. [Theme conventions](themes/README.md). |
| `assets/` | Production art, audio, fonts, shaders and content definitions. [Asset placement](assets/AGENTS.md). |
| `tests/` | Regression suites, support, fixtures and runner. [Authoring](tests/AGENTS.md); [running and reports](tests/README.md). |
| `docs/` | Maintained project documentation; temporary research belongs in workspace. |
| `workspace/` | Temporary task work and retained development material. [Workspace conventions](workspace/README.md). Production must not depend on it. |
| `addons/` | Godot editor/runtime plugins. |
| `.agents/` | Project skills; read the applicable skill for specialized work. |
| `.codex/` | Project-specific Codex configuration. |
| `.godot/` | Generated editor/import cache, not production authority. |

Extend the existing owner before creating another. Add deeper folders only for meaningful groups. Do not recreate `scripts/` as a parallel production code tree.

## Shared working rules

- When code, documentation and tests disagree, investigate the intended contract using current requirements, owning implementations and consumers. Do not silently change one to match another. Ask for clarification only when the intended behavior remains ambiguous and affects the requested change.
- Keep changes within the requested scope. Implementation work does not by itself authorize replacing accepted artwork, changing game balance or rewriting adjacent systems; preserve those unless the task requires or explicitly requests their modification.
- Read [Godot authoring](docs/godot-authoring.md) when editing scenes, node-based components, resources or editor tools. Preserve authored structure, interfaces, overrides and editable sources.
- UI and playback consume model results. Previews must not commit actions or consume gameplay RNG.
- Read [test authoring](tests/AGENTS.md) before creating, changing or relocating **any test, including component-local tests**. Run through `tests/run_tests.ps1` for isolation; use the [runner guide](tests/README.md) to select scope and renderer.
- Report actual verification. Headless checks do not establish visual acceptance; skipped tests are not passes. Do not hide failures or change gameplay merely to make tests green.

## Naming and migrations

- Use lowercase `snake_case` for new production directories and files. Name packages by responsibility and scene/controller pairs after their scene. Preserve established class names and content IDs unless a rename is requested.
- Use descriptive workspace task names and retain existing task naming conventions rather than renaming historical material for style alone.
- Move paired `.uid` files with scripts. Preserve resource UIDs, inheritance, exported properties and authored node paths.
- Update resource paths, preloads, dynamic path construction, test fixtures, build tools, documentation and active provenance references when moving files. Check filesystem-relative helper paths too.
- Preserve unrelated and uncommitted work. Keep folder migrations separate from behavior changes; do not retain duplicate old/new implementations.
- Validate moved files and references, then run relevant Godot import/tests when available. Report actual checks and runtime verification limits. Keep diagnostic output in `workspace/`.
