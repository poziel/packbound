# Icon-only gameplay buttons

Instance `icon_button.tscn`, assign `icon`, and supply an accessible name and tooltip describing the action. The gameplay theme's `IconButton` variation owns all colors and transparent backgrounds: accent yellow normally, slightly lighter yellow on hover, darker yellow while focused or pressed, and dark grey while disabled. Native Button mouse, keyboard and disabled behavior is retained.

The default glyph width is 20 px within a 40 x 40 click target. Battle-log arrows use 48 x 48 targets. All states have no background or border; only the icon color changes. The settings gear uses the same variation with a 32 px icon. Use white glyph textures so the theme controls their color. Editable spritex JSON and validated PNG/SVG exports for previous, next and close live in `assets/icons/controls/common/`. The shared log scene applies these arrows in gameplay and in the death-screen modal.

Both log instances use the gameplay theme's LogScrollBar variation: a 2 px neutral rail and 6 px yellow thumb within a 16 px native hit target. The thumb grows to 8 px and brightens on hover or drag. The log scene applies this variation to its RichTextLabel scrollbar.
