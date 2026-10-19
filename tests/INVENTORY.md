# Test inventory

The executable inventory is authoritative in `tests/manifest.json`. IDs remain stable when files move. System tests avoid application scene setup; focused scene tests and mixed integration tests have separate owners. Component tests remain with their component.

171 runnable Godot tests are registered; 19 require rendering. The Python runner regression tests are run separately as documented in README.md.

| Owner | Tests |
| --- | ---: |
| `components/inventory/item_slot/tests` | 2 |
| `components/ui/buttons/pixel_button/tests` | 1 |
| `components/ui/buttons/shared/tests` | 1 |
| `components/ui/indicators/pixel_stat_bar/tests` | 2 |
| `components/ui/inputs/pixel_search_field/tests` | 1 |
| `components/ui/layout/frosted_panel/tests` | 1 |
| `components/world/lighting/torch/tests` | 2 |
| `tests/integration` | 9 |
| `tests/integration/application` | 2 |
| `tests/integration/audio` | 3 |
| `tests/integration/characters` | 3 |
| `tests/integration/combat` | 2 |
| `tests/integration/content` | 1 |
| `tests/integration/crafting` | 5 |
| `tests/integration/items` | 2 |
| `tests/integration/ui` | 3 |
| `tests/scenes/menus` | 12 |
| `tests/scenes/run` | 63 |
| `tests/scenes/shared` | 20 |
| `tests/scenes/world` | 20 |
| `tests/systems/application` | 1 |
| `tests/systems/characters` | 1 |
| `tests/systems/combat` | 4 |
| `tests/systems/content` | 5 |
| `tests/systems/items` | 1 |
| `tests/systems/runs` | 4 |

## Retained development material

Capture, preview, review, bake and migration scripts are retained under `workspace/tasks/test-organization/retained-tools/`. They are excluded from regression discovery. Existing generated outputs were preserved under `workspace/tasks/test-organization/previous-output/`.

Migration mappings and SHA-256 preservation records are in the same task folder. Historical records intentionally keep the paths used at the time.
