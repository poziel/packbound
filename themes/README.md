# Shared surface tokens

Edit `PackSurface` in the gameplay or menu `theme.tres` using Godot's Theme editor:

- Constant `content_padding` (22): the content inset in UI pixels.
- Color `background`: the navy surface shared by panels, selected tabs, frosted backdrops and screen backgrounds.
- Color `header`: the grey shared by inactive tabs, selected-tab corner joins and the application border.

Each theme owns its values so gameplay and menus can be styled independently.

`components/ui/shared/surface_theme.gd` is an opt-in scene child that connects authored layouts to these tokens in the editor and at runtime. Configure its node paths and padding edge bindings; `reference_padding` records the inset used in the original scene. Header height, gaps between controls, fixed inventory-cell geometry and intentional leftover space are separate from the outer content inset. Surface opacity remains local to each panel. Frosted backdrops read `background` directly.

Reward panels, unused-item storage, statistics, logs, relic layouts, character-tab surfaces, options, pause and death screens use these bindings. The backpack grid remains centered at its fixed pixel dimensions to preserve its item and drag geometry.
