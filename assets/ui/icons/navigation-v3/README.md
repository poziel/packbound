# UI icons v3: consistent 32px visible height

All eight icons were deliberately redrawn in Pixelorama on 32x32 native canvases. Every exported glyph has exactly32 source pixels of visible height (y0 through31); widths preserve each motif. This follows the user's explicit override of the UI skill's default24px menu canvas and outer padding.

| Icon | Visible width x height |
| --- | --- |
| Statistics | 30 x 32 |
| Logs | 28 x 32 |
| Pause | 20 x 32 |
| Unused items | 32 x 32 |
| Character / Backpack | 28 x 32 |
| Relics tab | 20 x 32 |
| Item rewards | 32 x 32 |
| Relic rewards | 31 x 32 |

The registry links PNG masks, editable integer-grid SVGs, layered Pixelorama documents and drawing provenance. V1 and V2 remain preserved. Subagent pixel specifications are in `workspace/docs/art/concepts/ui-icons/navigation-v3/`.

Runtime changes:

- All eight scene resources now point to v3.
- The tab icon cap is32. Tab margins changed from36/16 to32/12 horizontally/vertically, preserving96x56 tab rectangles and the56px header height.
- The unused-items and pause caps are32. Pause is48x48 rather than48x36; the other button dimensions are unchanged.
- Pause/Resume remains the accessible label and existing tooltip, with no text painted over the pause glyph. Combat behavior is unchanged.

Verification:

- All eight PNGs are32x32, binary alpha, white masks, exactly32px visible height, and pixel-identical to SVG geometry.
- Native Pixelorama projects reopen; saved layer metadata matches each icon's two or three drawing layers.
- Live native textures and available content rectangles were inspected. All controls accommodate32px icons; nearest filtering is preserved.
- `review/check-layout.gd` passed with zero failures, checking all8 native/visible heights, tab/button sizing, and both pause accessible-label states.
- Existing battle UI suite:288 checks,1 failure: `Record includes latest turn`. This combat-log assertion is outside the changed icon and layout files; no combat-log code was modified.
- Screenshots, contact sheet and logs are in `workspace/docs/art/concepts/ui-icons/navigation-v3/review/`.

Status: integrated for user review, not yet visually accepted.
