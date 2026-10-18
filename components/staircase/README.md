# Shared entrance and exit staircases

Use `entrance_stairs.tscn` and `exit_stairs.tscn` as reusable scene components. Both use the same controller and standard dimensions: **4 units wide, fourteen 0.28-high / 0.85-deep steps, 3.92 units of rise and 11.9 units of run**. Camera eye height is 3 units; the default extra downward tilt is 10 degrees.

The entrance root sits at the corridor floor at the foot of the stairs. The exit root sits at the upper floor at the stair opening. Both descend along local -Z. Move or rotate the whole root to carry the artwork, travel markers and shadow field together. Keep the root scale at one to preserve the shared dimensions. The `Top` and `Bottom` markers define the camera route automatically.

## Designing your own version

1. Create an inherited scene from the appropriate entrance/exit scene.
2. Hide `Visuals/DefaultStone` and add your own saved meshes or an instanced artwork scene under `Visuals`.
3. Design around the standard stair envelope and `Top`/`Bottom` markers. The faint editor guide marks the tread volume and stays hidden in gameplay. Keep the passage clear around the camera route.
4. Save your variant and drop it into a room. The controller never rebuilds the artwork. Open the artwork scene directly for unrestricted mesh/material editing; use Make Unique when changing only one shared material.

Artwork coordinates describe stairs descending from an upper floor at (0,0,0). The entrance controller offsets the `Visuals` subtree up and back to place its lower landing at the root. Edit meshes below `Visuals`, leaving that subtree's placement to the controller.

The darkness is a continuous material pass in staircase-local space. It darkens toward the lower end on exits and toward the upper passage on entrances, following translation and rotation. StandardMaterial3D appearances retain their colors and shading. Custom ShaderMaterial artwork can implement the same local depth field if needed.

An opaque, unlit black `EndWall` seals the dark end: behind the upper arrival point on entrances, beyond the bottom landing on exits. Its side, landing and ceiling returns overlap the stairs to close the seams around the end wall. It belongs to the shared scene, separate from `Visuals`, so replacing the artwork keeps the end closed. The camera route stops before the wall.

## Room integration

Rooms derived from `scripts/gameplay/room_definition.gd` expose `entrance_stairs_path` and `exit_stairs_path`, defaulting to `EntryStairs` and `ExitStairs`. Camera travel reads the staircase markers directly. The shared world owns the camera, walking sway, encounter actors and speed-scaled transitions. `CameraStart` remains the room's final encounter viewpoint. Legacy `Travel/*` markers remain supported for older or custom rooms without these components.

The dungeon and basement both instance the two roles. Their existing exit artwork, bricks, lights and manual transforms were moved into each room's `stairs/exit_visuals.tscn`; their linked `stairs/exit_stairs.tscn` variants supply the artwork. The basement also has a wooden entrance variant. Existing room decorations and candle fixtures remain editable.

Open `components/staircase/demo.tscn` and press F6. Press **1** to preview entrance descent, **2** for exit descent, **Z** to inspect freely and **R** to reset the view. Scene changes propagate through inherited variants; artwork changes stay local to their source scene.
