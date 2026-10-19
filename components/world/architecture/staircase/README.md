# Shared entrance and exit staircases

## Configurable staircase

Instance `staircase.tscn` directly and select **Role: Entrance / Exit** in the Inspector. Generic entrance/exit presets have been removed. The dungeon's `scenes/world/biomes/dungeon/shared/staircase/staircase.tscn` inherits this component, embeds its own artwork, and supports both roles while widening the geometry without changing travel dimensions.

**Appearance** exposes `wall_color`, `step_color`, `ceiling_color`, `depth_color` and `depth_strength`. Surface colors set material base colors directly, preserving textures and other material settings. They do not multiply the old gray. Custom artwork can tag meshes with `metadata/stair_surface` set to `step`, `wall` or `ceiling`. Otherwise Tread/Nosing/Landing names are steps, Ceiling/Roof names are ceilings, and other meshes are walls. Materials are duplicated per instance.

**Interior light** has only `glow_color` and `glow_intensity` (0–1). Zero switches the light off; one produces 200 light energy, twice the former maximum. There are no normal/selected states or highlight amount on the staircase. Shared editable artwork lives in `staircase_geometry.tscn`.

`depth_strength` also stays within 0–1, with twice the previous fade strength: 0.5 matches the former 1.0. Opacity is capped at one, so the stronger fade reaches the chosen passage color sooner along the stairs. To convert an old glow intensity to the new scale, divide it by 200. Dungeon selector doors default to 0.06 (12 light energy).

The selector door owns hover detection and animation. It applies its `hover_glow_color` and animates the staircase intensity to `hover_glow_intensity` while hovered, then back to zero on exit. Passage depth color stays independent. The light is positioned near the room-side landing: the bottom of an entrance and the top of an exit. Switching Role updates that position automatically.

`show_guides` only toggles an editor box indicating stair width, rise and run for aligning custom geometry. It has no collision or gameplay role and is always hidden during play. Keep it available as an authoring aid; turn it off when it obstructs the editor view.

Both roles use the same controller and standard dimensions: **4 units wide, fourteen 0.28-high / 0.85-deep steps, 3.92 units of rise and 11.9 units of run**. Camera eye height is 3 units; the default extra downward tilt is 10 degrees.

The entrance root sits at the corridor floor at the foot of the stairs. The exit root sits at the upper floor at the stair opening. Both descend along local -Z. Move or rotate the whole root to carry the artwork, travel markers and shadow field together. Keep the root scale at one to preserve the shared dimensions. The `Top` and `Bottom` markers define the camera route automatically.

## Designing your own version

1. Instance `staircase.tscn` and choose its Role. Enable Editable Children to replace the artwork within a room, or create an inherited scene for a reusable art variant.
2. Hide `Visuals/DefaultStone` and add your own saved meshes or an instanced artwork scene under `Visuals`.
3. Design around the standard stair envelope and `Top`/`Bottom` markers. The faint editor guide marks the tread volume and stays hidden in gameplay. Keep the passage clear around the camera route.
4. Save your variant and drop it into a room. The controller never rebuilds the artwork. Open the artwork scene directly for unrestricted mesh/material editing; use Make Unique when changing only one shared material.

Artwork coordinates describe stairs descending from an upper floor at (0,0,0). The entrance controller offsets the `Visuals` subtree up and back to place its lower landing at the root. Edit meshes below `Visuals`, leaving that subtree's placement to the controller.

The darkness is a continuous material pass in staircase-local space. It darkens toward the lower end on exits and toward the upper passage on entrances, following translation and rotation. StandardMaterial3D appearances retain their colors and shading. Custom ShaderMaterial artwork can implement the same local depth field if needed.

An opaque, unlit black `EndWall` seals the dark end: behind the upper arrival point on entrances, beyond the bottom landing on exits. Its side, landing and ceiling returns overlap the stairs to close the seams around the end wall. It belongs to the shared scene, separate from `Visuals`, so replacing the artwork keeps the end closed. The camera route stops before the wall.

## Room integration

Rooms derived from `scenes/world/rooms/shared/room_definition.gd` expose `entrance_stairs_path` and `exit_stairs_path`, defaulting to `EntryStairs` and `ExitStairs`. Camera travel reads the staircase markers directly. The shared world owns the camera, walking sway, encounter actors and speed-scaled transitions. `CameraStart` remains the room's final encounter viewpoint. Legacy `Travel/*` markers remain supported for older or custom rooms without these components.

The basement and cursed rooms instance the component with explicit roles and custom artwork under `Visuals/RoomDesign`. Dungeon rooms and selector doors instance the single dungeon staircase with their required role. `DefaultStone` stays hidden where custom artwork replaces it. Existing room decorations and fixtures remain editable.

Open `components/world/architecture/staircase/demo.tscn` and press F6. Press **1** to preview entrance descent, **2** for exit descent, **Z** to inspect freely and **R** to reset the view. Scene changes propagate through inherited variants; artwork changes stay local to their source scene.
