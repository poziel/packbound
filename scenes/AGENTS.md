# Scene architecture and authoring

Read the root [guidelines](../AGENTS.md) and shared [Godot authoring rules](../docs/godot-authoring.md). Reusable units belong in [components](../components/AGENTS.md); rules and state belong in [systems](../systems/AGENTS.md).

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

## World contracts

- **Keep world ownership consistent.** The shared world owns the camera, actor collection and room swapping. Rooms own scenery, environment/lens parameters and editor-visible travel/enemy placement markers. Extend `room_definition.gd` or its existing derived behavior and preserve the marker/staircase interface instead of putting independent cameras and combat actors in every room.
