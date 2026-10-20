# Sound playback

Use `sound_playback.gd` for reusable cosmetic pitch variation:

```gdscript
const SOUND = preload("res://systems/audio/sound_playback.gd")
SOUND.play_random_pitch($AudioStreamPlayer) # 0.9–1.1 times normal pitch
SOUND.play_random_pitch($AudioStreamPlayer, 0.95, 1.05, 1.0)
```

The helper accepts AudioStreamPlayer, AudioStreamPlayer2D and AudioStreamPlayer3D.
The caller owns the player, stream, bus, volume and lifetime. Bounds are positive
pitch multipliers relative to the explicit base pitch (default 1.0); repeated
playback does not accumulate pitch changes. Cosmetic RNG is separate from game RNG.
Shared item hover playback uses this helper through `PackMenuAudio.play_item_hover()`.
UI hover, inventory pickup and inventory drop use the same helper through
`play_ui_hover`, `play_item_pickup` and `play_item_drop`. Buttons are connected
automatically, including dynamically added icon buttons; disabled buttons stay
silent. Item reward buttons retain only their item-hover sound. Inventory
handoffs between board and gravity stash do not repeat pickup feedback.
