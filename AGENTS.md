# Project Art Guidelines

## Workspace and retained material

- Use `workspace/` for unofficial Codex work: research, design notes, sketches, proof-of-concept files, working scripts, render reviews and diagnostic logs. Keep production assets and their editable authority in their active runtime folders.
- Store archived material as verified ZIPs under `workspace/archives/<category>/` (characters, items, backgrounds, branding, themes, audio, and other categories as needed). Do not recreate archive folders under `assets/`.
- Write diagnostic logs to `workspace/logs/`, using an explicit absolute `--log-file` path for Godot commands. `workspace/.gdignore` excludes retained and working material from Godot imports.
- Active UI themes live at `themes/gameplay/` and `themes/menu/`. Preserve both themes and existing per-instance overrides when editing.

## spritex source documents

- All five art skills (characters, items, monsters, UI icons and keyword icons) use the [spritex skill](D:/Dev/5-tools/spritex/skills/spritex/SKILL.md) to author layered JSON and generate production PNG/SVG through the CLI. Follow its schema and executable discovery/local-build instructions. Image generation may supply concepts, but the editable production source is the numeric JSON grid.
- Validate authoring JSON before export. Preserve meaningful layers, explicit animation frame timelines, durations and intentional editing links. Deliver JSON alongside exports; optional `.pxo`/`.aseprite` builds are compatibility outputs. Pixelorama and its MCP are not required, and the former Pixelorama availability approval gate no longer applies.
- Inspect rendered pixels at native/UI size, layer order, transparency, dimensions and animation timing. Preserve existing artwork/source provenance and describe editability honestly: one flattened grid is not a reconstruction of separate body parts. Keep concurrent JSON/output paths separate.

## Source pixel density

- New and redrawn character art defaults to a **256 source-pixel visible body height**, measured from the top of the head/headwear to the sole of the feet. Held weapons, detached effects, and transparent padding do not count toward body height.
- Use a **384 × 320 source-pixel cell** for each character at this default. The body starts at `y = 32`, stands on the shared baseline `y = 288`, and is centered around `x = 192`. Keep the same registration across classes and animation frames; leave unused canvas transparent.
- Author exact pixel grids in spritex JSON and generate native SVG through its CLI at **1 SVG unit = 1 source pixel**. Use stepped silhouettes and verify crisp integer-grid rendering; avoid fractional coordinates and antialiased curves. JSON is the editable authority, not separately maintained SVG paths.
- Derive related asset dimensions with `round(body_height × relative_length)`. At 256 px body height, nominal weapon length including hilt and pommel is: long sword `1/2 = 128 px`, short sword `1/3 ≈ 85 px`, dagger `1/4 = 64 px`. Measure along the weapon's length, independently of its pose or bounding-box height.
- Keep UI display sizing separate from source resolution, use nearest-neighbor texture filtering, and prefer integer display scaling for sharp pixels. A larger source must contain intentionally resolved detail; enlarging existing pixels alone does not provide it.
- Apply this density when creating or explicitly redrawing assets. Existing accepted 128 px bodies in 192 × 160 cells keep their original bytes, registration and approval status until explicitly revised. Preserve source files, original artwork provenance, and editable asset workflows.

## Character sprites and portraits

- Use the project skill [packbound-character-art](.agents/skills/packbound-character-art/SKILL.md) for new or explicitly redrawn characters and matching portraits.
- Follow the character skill's [current visual references](.agents/skills/packbound-character-art/references/visual-direction.md): cohesive fantasy proportions, convincing weapon grips, and an upright, relaxed, slight three-quarter pose. The latest user references supersede conflicting older proportion and face guidance; the first Pixelorama roster was rejected.
- Closed helmets, masks, shadowed hoods and nonhuman heads are valid character identities. For exposed faces and detailed close-ups, use deliberate anime-inspired pixel facial design. Do not force a realistic human face onto every class.
- Generate the complete head-to-toe character. Prepare a separate **64 × 64** detailed face portrait from the original generated concept or other sufficiently detailed identity source. Center the head/face optically, preserve hair/headwear and chin, and remove incidental full-body equipment, effects and distracting fragments from the close-up. If equipment overlaps the head, remove it and reconstruct the hidden head details so the portrait is unobstructed. Retain defining costume and identity features, including intentional helmets and masks.
- Inspect the portrait at its intended UI size. Do not enlarge a tiny sprite-face crop and claim added detail. Label an untouched crop as an exact crop, a resized or cleaned concept crop as a concept-derived matching portrait, and independently drawn/generated artwork as a separately drawn matching portrait. Record the source, framing and edits.
- Review proportions, face/head readability and actual hand-to-weapon contact against the references. Technical grid/layer checks do not establish visual quality or user approval.

## Inventory item art

- Use the project skill [packbound-item-art](.agents/skills/packbound-item-art/SKILL.md) for new or explicitly redrawn inventory items.
- Each occupied inventory cell is **32 x 32 source pixels**, with **no artwork gap**. A two-cell-tall canvas is 64 px, a 2 x 2 canvas is 64 x 64 px, and a four-cell-tall canvas is 128 px tall.
- Define placement with equal-width `#`/`.` mask rows. Canvas dimensions are the mask's bounding width and height multiplied by 32. Empty mask cells stay fully transparent; adjacent occupied cells form a continuous art surface.
- Inventory items use restrained shading within their material colors. Avoid colored reflection accents, cyan/blue rim pixels, orange edge lighting and isolated specular glints. Deliberate blue materials or magical effects require them in the item brief.
- Prioritize a clear silhouette, readable thickness, broad material shading, one or two defining details and connected pixel clusters. Resolve muddy shapes and competing details before increasing resolution. Inspect at actual inventory and reward display sizes; extra surface texture is not evidence of higher quality.
- Larger UI views reuse the footprint-derived base canvas when it is sufficient. Optional 64 px selection and 128 px detail targets refer to the complete image's longest edge, not each cell. Higher-detail variants preserve the same placement mask; do not create redundant copies of already-large items.
- This item-art contract is separate from character proportions, held-weapon lengths and UI display sizes. Preserve the existing 96 px item atlas until its assets are explicitly redrawn or migrated.

## Monster art

- Use [packbound-monster-art](.agents/skills/packbound-monster-art/SKILL.md) for whole-body monsters and enemies. Share the character rendering style while preserving species-specific anatomy, proportions and poses. No portrait is required by default.
- Monster body width and height are each **at most 256 source pixels**, including anatomical appendages but excluding detached effects, held equipment and transparent padding. This is a maximum, not a target: rats, slimes and other small creatures use smaller bodies. Preserve natural proportions and record dimensions and anchor. Canvas padding may extend beyond the body limit. Keep a consistent display scale across monsters so small creatures stay visibly smaller; do not auto-fit every monster to fill the battle area.
- Preserve the complete silhouette, native editable sources and transparent PNG/integer-grid SVG exports. Judge appearance beside accepted characters at intended display size; source dimensions alone do not establish style consistency or acceptance.

## UI and keyword icons

- Use [packbound-ui-icons](.agents/skills/packbound-ui-icons/SKILL.md) for menu/navigation icons and the single block, spell and attack button glyphs. Keep the symbol separate from button backgrounds, borders, labels and notification badges. Match the actual control slot; current menu slots use 24 px and action/reward slots commonly use 32 px.
- Use [packbound-keyword-icons](.agents/skills/packbound-keyword-icons/SKILL.md) for small inline stat, status and effect symbols, including health, armor, block, shield, poison and burn. These have their own native size and text-alignment rules; the inventory item footprint contract does not apply.
- **Keyword links** are hoverable words with nested definitions; **keyword stats** are compact icon-and-value pairs, used by relic tooltips. **Keyword lists** show an item's attributes one per line as value, icon, keyword name. Item tooltips use keyword lists instead of compact keyword stats or duplicate numeric sentences. Preserve explicit booster and special-rule descriptions; affected items identify adjacency bonus sources. Keyword lists color the icon and keyword name with the keyword color; numbers and signs use the default font color. Every positive value has a + sign; negatives and costs keep a minus sign. List entries have no underline and retain the same darker hover behavior. Use these names consistently.
- Resolve keyword labels, aliases, icon IDs and colors from one shared mapping when implementing them. Keyword links use the same keyword color for text and icon; surrounding prose stays neutral. Keyword stats use the consuming label's default color for both icon and value, with no underline, including on hover. Both keyword links and keyword stats darken their icon and text on hover and restore on exit. Preserve distinct recognizable silhouettes; do not rely on color alone to communicate meaning.
- Inspect current keyword/combat definitions before assigning mechanics: the legacy `armor` key currently represents shield protection, while `plating` and `block` have different rules. Keep visual armor/equipment identity distinct from shield protection without silently changing mechanics or aliases.
- Preserve the supplied [UI icon references](workspace/docs/art/references/ui-icons/provenance.json) as visual examples, not accepted production assets or a requirement to copy their low-contrast colors. Judge new glyphs at actual UI size and in context; enlarged previews alone do not establish readability.
