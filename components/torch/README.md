# Reusable torch and candle

Drag `components/torch/torch.tscn` into any 3D room, or use `candle.tscn` for a small wax candle. Move, rotate or duplicate the instance root to carry the handle, fire and light together. No textures are needed: the fixture uses simple 3D meshes and materials.

Select the root node to adjust its Inspector settings:

| Group | Settings |
| --- | --- |
| Handle | Length, width, handle color, collar visibility and color |
| Flame | Outer/core colors, width/height/depth, animation speed and frame rate |
| Editor preview | `animate_in_editor` under Flame; enabled by default |
| Light | Enabled, color, energy, range, offset, flicker amount and cast shadows |
| Stair darkness | Optional `depth_shadow_material` for the dungeon's depth shadow pass |

The handle starts at the root origin and extends along local +Y. Changing its length moves the fire to its upper end automatically. `flame_size` is independent of the handle dimensions. Light color is independent of flame color, so you can choose how the room is illuminated. Light offset is measured from the flame base.

The `@tool` controller updates saved mesh/light children and animates in the editor as well as the game. It never rebuilds the room. Meshes and materials are local to each scene instance, so parameter changes on one torch do not recolor the others. Use the root's parameters for appearance; expanding Editable Children is only needed for structural edits to the component itself. Save a customized instance as a new inherited scene to make another reusable preset.

Open or run `components/torch/demo.tscn` to compare four examples: warm wood, a long blue torch, a small candle and a short green torch.

Press F6 with the demo open, then Z to toggle fly mode. Mouse looks around, WASD moves, Space rises, Ctrl descends and Shift moves faster. Z or Escape releases the pointer; R restores the starting view in either mode, and F8 stops the demo. A small idle hint shows R and Z; flying shows the compact movement controls. The demo instances [the shared FreeCamera scene](../free_camera/README.md), which you can drop into any other room or asset demo.

The basement's existing candle stands now contain five candle instances each. Their cup, branch, stem and base meshes remain normal editable scene nodes. Each candle has its own light; the center candle supplies the stand's illumination by default and the four surrounding lights are disabled, preserving the former two-light setup. Enable any of them through the candle's Light settings. The center candle keeps the stand's saved light color, range, power and offset.

Existing dungeon wall torches retain their authored geometry and runtime `pixel_flame.gd` treatment. Use the reusable torch for new placements; the basement instances demonstrate integration without regenerating the room.

Verification: `tests/torch_component_test.gd` checks parameters, independent instances/duplicates, animation, movement and save/reopen behavior. `tests/torch_editor_preview.tscn` verifies actual editor animation only when launched in an isolated editor with `-- --verify-torch-editor`; opening it normally never exits your editor.
