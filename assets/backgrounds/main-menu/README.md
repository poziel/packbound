# Packbound main-menu background

Editable source: [packing-table.pxo](sources/packing-table.pxo). Earlier projects remain in [the background archive](../../../workspace/archives/backgrounds/main-menu.zip). This is the current artwork, formerly storm revision 03.

This project has **17 editable layers, 128 frames, and an 8 FPS / 16-second timeline**. Static artwork uses linked cels across all 128 frames.

## Targeted changes

- Replaced every old branching plume cel with irregular, overlapping smoke billows. Drifting fragments are on a second smoke layer; neither layer retains the old effect.
- Replaced the bag's heavy black contour with plum leather and brown strap colors. The contact/cast shadow is a separate, warmer wood shadow. The bag's base remains fixed.
- Moved the complete window **29 pixels right**, including all lightning, illumination, and pane masking. At y=108 the stone section extends from x=501 to the exclusive canvas edge x=640; both the wall midpoint and window-surround center are **x=570.5**. The surround is now (531,51,79,115). Nearby mortar joints meet the new surround, and the complete underlying wall restores the previous location.
- The potion, coins, book, spare strap, dagger, room, table, candle body, candle animation, dust, flap motion, and localized purple reflection are unchanged.

## Assets and placement

Top-left positions are integer coordinates on the 640 × 400 source canvas. Transparent RGBA sheets use row-major order, no padding, and 125 ms per frame.

| Asset | Cell size | Grid | Frames | Top-left | Cycle |
|---|---:|---:|---:|---:|---|
| packing-table-base.png | 640 × 400 | 1 × 1 | 1 | (0, 0) | Static base |
| window-lightning.png | 44 × 80 | 8 × 16 | 128 | (545, 64) | 16 s |
| storm-light-on-stone.png | 88 × 120 | 8 × 16 | 128 | (529, 48) | 16 s |
| satchel-flap.png | 132 × 74 | 8 × 8 | 64 | (42, 230) | 8 s |
| curse-reflection.png | 48 × 64 | 8 × 8 | 64 | (136, 244) | 8 s |
| candle-flame.png | 26 × 34 | 8 × 1 | 8 | (551, 197) | 1 s |
| candlelight.png | 168 × 168 | 4 × 4 | 16 | (472, 176) | 2 s |
| purple-smoke-billows.png | 76 × 108 | 8 × 8 | 64 | (144, 168) | 8 s |
| purple-smoke-fragments.png | 80 × 112 | 8 × 8 | 64 | (140, 164) | 8 s |
| candlelit-dust.png | 112 × 128 | 8 × 8 | 64 | (512, 184) | 8 s |

Each sheet has a matching Godot SpriteFrames resource. [animation.json](animation.json) records every atlas rectangle, placement, timing, and verification result.

The animated base omits the movable flap and all effects. Render the flap track with it. For a complete static background without animated effects, use `packing-table-static.png`, which includes the flap at rest. Do not use that complete static image beneath the moving flap.

## Playback and Godot

Start all nine AnimatedSprite2D tracks together at frame 0, above the base, in the table order. Turn Centered off; use Offset (0,0), white Modulate, normal alpha blending, and the documented positions. Use Nearest filtering, lossless texture imports, no mipmaps, and integer display scaling.

All resources loop. The smoke, fragments, leather reflection, and flap share an eight-second cycle. Smoke is visible at zero-based frames 8–39, then completely absent for four seconds across the wrap. Emergence occupies 8–13, billowing 14–25, and breakup/fade 26–39. The full native timeline repeats this emission at frames 72–103. Quiet time is already present in the sheets; no extra delay is needed.

Lightning starts at 6.000 seconds with a bolt, quick fade, and weaker restrike. A softer cloud flash starts at 12.375 seconds. The storm remains local to the window and adjacent stone. Its onset gaps alternate between 6.375 and 9.625 seconds across the 16-second loop.

## Main menu integration

The game uses `res://scenes/menus/packing_table_background.tscn` as the first child of `main_menu.tscn`, behind the existing logo and buttons. Its native sprites retain the positions and compositing order above, with nearest filtering and a 2× scale into the 1280 × 800 menu canvas. The source `.pxo` and exports remain unchanged.

`res://scripts/packing_table_background.gd` advances all nine tracks from one 8 FPS clock. The complete timeline repeats every 16 seconds, retaining the authored quiet intervals. Playback pauses while the main menu is hidden and resumes at the same phase when it returns. Existing menu music remains in use; no thunder sound is added.

## Thunder cues

No audio is embedded. Suggested subdued distant thunder:
- First event: delay 1.2–2.3 seconds after the 6.000-second flash; cue at 7.2–8.3 seconds.
- Second event: delay 1.7–3.1 seconds after the 12.375-second flash; cue at 14.075–15.475 seconds.

Schedule one rumble per event, not per restrike, and allow tails to continue across the image loop.

## Review and verification

`packing-table-still-preview.png` shows peak smoke. `packing-table-animation-preview.png` is the complete 16-second APNG.

Native MCP canvas captures were inspected at normal size and enlarged nearest-neighbor scale, including smoke breakup, complete disappearance, lightning, and the revised bag edges. Pixel comparisons confirmed that the potion and other preserved layers remain unchanged across all frames. No new pixels enter either reserved menu rectangle, no old dark contour colors remain in the bag surfaces, and both translated storm tracks match their previous cels after reversing the 29-pixel offset.

All 600 exported atlas frames match their native cels, with no clipped content. Native playback covered all 128 frames and nine complete wraps with zero unexpected transitions. Godot 4.7.2 loaded all nine SpriteFrames resources and validated all 600 atlas frames. Full results are recorded in animation.json.
