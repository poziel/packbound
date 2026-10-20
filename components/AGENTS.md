# Reusable components

Read the root [guidelines](../AGENTS.md), shared [Godot authoring rules](../docs/godot-authoring.md) and owning package README before changing interfaces or variants.

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

Components may be 2D, 3D or logic-only. Keep focused public interfaces, maintained demos and local resources in the package. Component-local tests follow [test authoring](../tests/AGENTS.md), including registration and isolation. Application composition belongs in [scenes](../scenes/AGENTS.md); rules and shared services belong in [systems](../systems/AGENTS.md).
