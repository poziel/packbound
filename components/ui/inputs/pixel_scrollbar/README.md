# Pixel scrollbar

Native Godot scrolling with pixel StyleBoxes supplied by the surrounding menu or gameplay theme. `pixel_scroll_container.tscn` is a script-free ScrollContainer preset; `pixel_scrollbar_style.gd` draws the track/thumb resources. See [theme configuration](../../themes/README.md).

## Use

1. Instance pixel_scroll_container.tscn under a themed Control.
2. Give it a bounded viewport or Expand + Fill in a bounded Container.
3. Add one content Container (VBoxContainer, HBoxContainer, etc.).
4. Add rows/cards inside that content Container.

The default is vertical automatic overflow with focus-following. Enable Horizontal Scroll Mode for horizontal content. Wheel input, track paging, dragging, range/page calculations and ensure_control_visible() remain native Godot behavior. No custom keyboard steps or scrollbar focus settings are applied.

Native VScrollBar, HScrollBar and RichTextLabel controls inherit the same styles. Assign a menu/gameplay theme to an ancestor, rather than a private scrollbar theme.

Edit the scrollbar StyleBoxes inside either theme to change colors, thickness or minimum thumb length. Make a resource unique before changing only one instance. Defaults are 24 px interaction thickness and 32 px minimum thumb length.

Use F6 on demo.tscn for live overflow, or open either theme showcase. tests/scenes/run/pixel_scrollbar_test.gd checks overflow, scrolling, native defaults, focus-following and game/menu integration.
