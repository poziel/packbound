# Combat keyword icons

Latest correction: Accuracy uses the selected bullseye formerly labeled Crit
chance; Crit chance uses the user's rising-arrow/corner reference. Their sources
are in `workspace/docs/art/concepts/semantic-icons/effects-v3/`; only those two mappings
were revised. Colors and the other 21 symbols remain unchanged.

The current user-requested v2 family has **23 symbols** with uniform 16 × 16
sources and centered 14 × 14 artwork. Block uses a shield, Mana a blue gem and
Slow a snowflake. Damage/Cleanse are illustrated; the nine new identities are
available to the formatter without invented mechanics or dead glossary links.
Sources and review: `workspace/docs/art/concepts/semantic-icons/effects-v2/README.md`.
V1 remains preserved. The paragraphs below describe the original integration.

`registry.json` is the runtime authority for all 23 current effect/stat symbols,
their labels, aliases, palette tokens and source provenance. `v2/masks/` holds
the centered master masks and baseline-corrected inline derivatives; all are
16 × 16. Editable SVG and per-icon Pixelorama documents are under
`workspace/docs/art/concepts/semantic-icons/effects-v2/`. The original `masks/` and v1
sources are preserved as the previously accepted revision.

`PackKeywords` resolves identities, colors and masks. `PackGlossary.rich()`
formats effect words and adjacent amounts, placing the icon **before** the
word with a nonbreaking space and word joiner. Native image size is 16 × 16;
consumers use nearest filtering. A word and its icon stay together when a
paragraph wraps. Surrounding prose stays neutral. Existing BBCode tags,
image paths, colored spans and glossary links are preserved on repeated calls.

Use `PackGlossary.rich(copy, "", false)` for passive labels and logs. Inspector
bodies use links; an excluded self term still receives its icon and color
without linking to its own definition. Passive labels use `RichTextLabel`,
`fit_content = true`, `scroll_active = false` and an empty normal StyleBox.

Integrated surfaces include statistics and values (including Slow), player
Mana/Block captions, player/enemy health badges, nested inspection headings
and bodies, item descriptions/costs, character selection details, rewards,
combat history, enemy detail copy and result HP copy. Item and relic artwork
retain their identity. Numeric health badges use the compact icon/value form.

The legacy glossary `armor` term remains shield protection and receives no
Block or Plating glyph. The distinct shield icon was not part of this set.
This integration does not change combat rules or the meaning of aliases.

PixelStatBar's optional `badge_icon` and `badge_icon_color` properties are
generic component inputs; the game supplies the accepted health identity.
Existing value text remains plain and accessible.

Verification scripts: `tests/keyword_icons_test.gd` (formatting, idempotence,
aliases and wrapping) and `tests/keyword_ui_test.gd` (real consumers, catalog
tooltips, rewards and screenshots). Rendered review artifacts are saved in
`workspace/docs/art/reviews/semantic-icons-v1/`.
