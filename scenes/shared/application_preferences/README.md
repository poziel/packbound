# Application preferences

Instanced by MenuFlow, this always-processing overlay applies saved preferences
even while menus are hidden or gameplay is paused. MenuFlow owns persistence,
default values, reset and option controls; this component owns runtime effects.

- `max_fps`: 0 means unlimited; otherwise 1–1000. V-sync can impose a lower limit.
- `reduce_unfocused_fps`: cap background rendering at 10 FPS, retaining any lower
  foreground cap. Focus gain restores the foreground setting. Game speed is unchanged.
- `mute_unfocused`: mute Master while unfocused, preserving bus volumes and
  intentional zero-volume mute on return.
- `show_fps`: show a small FPS counter in the upper right across menus and gameplay.
- `software_cursor`: hide the OS pointer and render the authored fallback arrow
  at viewport coordinates. System is the default. Leaving the window or losing
  focus restores the OS pointer. Replace the Cursor artwork when custom art is ready.

All additions default off, with unlimited foreground FPS. Focus signals come
from the owning Window. `application_preferences_test.gd` covers persistence,
reset, focus transitions, actual rendered throttling and cursor visibility.
