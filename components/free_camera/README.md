# Free camera

Drag `components/free_camera/free_camera.tscn` into a 3D demo. Position and rotate its root to choose the starting view, then run the scene with F6. It is a Camera3D with its controller and compact hint included; no Input Map setup is required. Only the current camera handles controls.

- Z toggles fly mode and captures/releases the mouse.
- Mouse looks around; WASD moves relative to the camera.
- Space rises; Ctrl descends; Shift moves faster.
- R restores the starting view in either mode.
- Esc, losing application focus, or leaving the scene releases the pointer.

The small bottom-left hint shows "R reset view · Press Z to fly" while idle and the compact movement controls while flying. Disable `show_hint` on an instance to hide both hints. Movement speed, boost multiplier, mouse sensitivity and standard camera properties are editable on the root. Flying is collision-free and has no gravity.

The torch demo instances this same scene, so changes to it apply to other demos that use it. Keep gameplay cameras separate from this inspection component.
