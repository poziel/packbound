# Replaceable inventory feedback

`item_pickup.wav`, `item_drop.wav` and `ui_hover.wav` are original synthesized
placeholder tones made for Packbound (44.1 kHz, mono, 16-bit PCM). They contain
no third-party samples. Pickup rises, drop falls, and UI hover is a short high
tick. Replace these files with preferred effects at the same paths and reimport.

`scenes/menus/menu_audio/menu_audio.tscn` owns their separate FX-bus players and
volume settings. Playback uses the shared random-pitch helper. The development
generator is retained in `workspace/tasks/inventory-hover-feedback/`; production
loads only these WAV files and has no dependency on that generator.
