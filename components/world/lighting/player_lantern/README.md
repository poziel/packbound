# Player lantern

Instance `player_lantern.tscn` under a Camera3D. It sits slightly below and to the right of the view. A stronger yellow SpotLight3D aims toward the encounter; a softer, short-range OmniLight3D spills onto nearby walls. The beam casts shadows from room geometry while leaving distant corners dark. The shared gameplay camera and Cursed Depths inspection demo already include it. Camera walking sway carries both lights naturally; intensity flicker stays subtle.

Select the component root to edit light color, beam intensity/radius/angle, spill intensity/radius and flicker. `power` ranges from 0 (both lights extinguished) to 1 (full strength). A future fuel controller can set `GameplayWorld.lantern.power`; this component does not consume fuel, create an inventory item or save fuel state. Its instance and power persist across room changes. This version supplies the carried light; a visible lantern model can be added separately.

The native `Light` (spot) and `Spill` (omni) nodes affect render layers 1 and 2. Only room geometry on layer 1 casts beam shadows, avoiding self-shadow artifacts from the flat monster billboards; their ground shadows remain. Room-specific fill lights remain gentle supporting light. Black stair end seals stay unlit, so carrying the lantern into the passage does not expose the scene ending.

Open `scenes/world/biomes/cursed/demo/demo.tscn` and press F6, then Z to fly around with the lantern. Preserved lit/on-off gameplay reviews are under `workspace/tasks/test-organization/previous-output/monster-lighting/`. New captures use the isolated runner artifact directory.
