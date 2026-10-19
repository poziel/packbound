# Decorated menu buttons

The menu theme (`themes/menu/theme.tres`) supplies the skin to ordinary Godot `Button` nodes. Instance `menu_button.tscn` for a 280 x 64 starting control, or add a native Button under a Control using the menu theme. Connect its normal `pressed` signal. Text, icons, toggle state, shortcuts and focus navigation remain native Button properties.

## Simple rounded buttons

For compact actions and groups of adjacent controls, use the menu theme's
`SimpleMenuButton` family. These are plain rectangular faces with softly rounded
corners and a thin iron-gray outline; they have no notches, diamonds, or extra
decoration. `SimpleMenuButton` supports text and optional icons,
`SimpleMenuIconButton` is sized for an icon, and the `HoldSimpleMenuButton` and
`HoldSimpleMenuIconButton` variations require a 1.2-second hold and emit
`confirmed` after release. Use the reusable scenes
`simple_menu_button.tscn`, `simple_menu_icon_button.tscn`,
`hold_simple_menu_button.tscn`, and `hold_simple_menu_icon_button.tscn`.
Set `hold_seconds` and accessible name/description for the specific protected
action. `DangerSimpleMenuIconButton` and `SuccessSimpleMenuIconButton` provide
red and green icon-control states. The simple icon scenes use the gameplay
theme's compact `TooltipPanel` and `TooltipLabel` for their native tooltip text.
These button faces are separate from the gameplay theme's transparent icon
buttons.

The design takes its notched ends, double outlines and diamond ornaments from the user-supplied Megaloot screenshots, with Packbound's darker slate default palette. The geometry is newly implemented procedural UI styling; it does not copy or replace sprite artwork. The StyleBox draws integer pixel rows without antialiasing. No generated textures or third active Theme are needed. Author button labels in uppercase; keep descriptive tooltips and accessibility text in normal sentence case.

## Theme editing

In the menu Theme Editor, open **Button > Styles > normal > Palette**. All default-state resources reference this same palette. Edit face, hover face, pressed face and disabled face there; the resource updates every menu button. Border Matches Face defaults to true, so the trim follows the face in each state. Turn it off to use a separate Trim color. Font colors and hold-progress color live under **Button > Colors**. Light-green Start and Resume variants share their own palette and dark text.

- Normal: darker slate face, matching trim and hollow diamonds positioned close to the notches.
- Hover: brighter face widens by two pixels at each decorated end; diamonds fill.
- Pressed: darker inset face shifted down two pixels.
- Focus: brighter filled diamonds; no overlay lines across the button face.
- Disabled: muted face, border and lettering.

Set `theme_type_variation = &"CompactMenuButton"` for the short one-ornament shape. It accepts native `icon` and/or `text`; start at 112 x 56. Ornaments stay inside the control rectangle, with reserved text margins, so adjacent controls and container clipping remain predictable. Hit regions intentionally retain the full native rectangular button target.

Use `LeftMenuButton` and `RightMenuButton` in an HBoxContainer for paired halves. Each retains its outer notch and diamond; the inside edge is plain with small stepped corners. `ResumeRightMenuButton` adds the green palette to a right half, and `StartMenuButton` uses it on a full button. Keep a 6-8 px container gap. The editable showcase includes a paired example. Main-menu Library and its existing backpack-icon companion are inactive placeholders; Start has an 18 px gap above that row, while Library and Quit use 6 px.

`DangerRightMenuButton` supplies a shared red palette for destructive right-hand
actions, including the Options footer's RESET TO DEFAULT. That footer uses the
menu theme explicitly while the form retains the gameplay theme. Icon-only left
halves use at least 112 px width and centered icon alignment, leaving room for
the outer ornament and inner border.

Delver portrait tiles retain their separate `DelverTileButton` variation. Gameplay `PackPixelButton` skins and the Options form's gameplay theme remain independent.

Use `PlainMenuButton` for a button with no side ornaments or notches. It shares the menu palette and interaction states, with a narrow outer border indicating keyboard focus. The death screen combines `LeftMenuButton`, `PlainMenuButton` and `RightMenuButton` in one row, leaving decoration only at the outer ends. The showcase includes the plain center variant between its paired halves.

## Hold to confirm

Hold progress fills a centered 12-segment pixel ring clockwise from the top,
temporarily replacing the label without changing button size. It works with
full, left, right, and plain middle buttons. A full ring arms the action; releasing
over the button confirms it. Early release or leaving the button cancels and
restores the label. There is no continuous rotation or reserved icon space.
`set_hold_required(false)` removes
the indicator and forwards normal clicks to `confirmed`; the saved Gameplay
setting applies this mode to Restart and Reset to Default without changing skins.

Instance `hold_menu_button.tscn` under the menu theme. Set `hold_seconds` (default **1.2 s**) and update its text, tooltip and accessibility description to describe the real action and duration.

**Connect `confirmed`, not `pressed`, to the protected action.** The component extends native Button, so `pressed` still exists and represents an ordinary click, not a successful hold. `confirmed` fires once when a completed hold is released. `hold_progress_changed(progress)` and `hold_cancelled` are available for supporting UI.

Mouse and keyboard input use native Button handling; controllers work when bound to `ui_accept`. The component does not change the project's input mappings. Releasing early, leaving the button, losing control/application focus, hiding or disabling the control cancels the hold and clears the ring.

The in-game pause menu uses a 1.2-second hold with the label RESTART. Its tooltip and accessibility description explain the hold requirement. Confirmation starts a fresh run with the same character, resets progress and cancels pending combat. RESUME is a normal button using `ResumeRightMenuButton`. The two share a row above LIBRARY, RECIPES, OPTIONS and MAIN MENU; Library and Recipes are currently unconnected placeholders. Menu rows use a six-pixel gap, with eight pixels between Restart and Resume.

Open `themes/menu/showcase.tscn` and run with F6 to try the buttons and hold example. `tests/scenes/menus/menu_button_test.gd` exercises real input events in an isolated SubViewport and saves normal, hover, focus, hold and main-menu renderings under `workspace/tasks/test-runs/<run-id>/<test-id>/menu-buttons/`. Pre-change theme/scene copies remain in `workspace/tasks/test-organization/previous-output/menu-buttons/originals/`.
