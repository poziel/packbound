# Game Audio

## Organization

- `sfx/combat/`: enemy hits/deaths, player damage and shield reactions.
- `sfx/ui/`: button activation and item/relic hover.
- `sfx/transitions/`: loading-screen cover and reveal.
- `sfx/candidates/`: supplied audition clips without an assigned production event. Do not load this folder as a random effect pool.
- `audio_bus_layout.tres`: shared Master, Music, FX and Ambience routing.
- `sound-effects-provenance.json`: original supplied names and hashes for the active UI/enemy effects.

Filenames describe playback purpose. Audio bytes and import settings are preserved.
Music and ambience tracks remain in `music/` and `ambience/`.

`music/menu/shadows_in_the_backpack.mp3` is **Shadows in the Backpack**, composed and
provided by the project owner for this game. It is copied unchanged from the
provided MP3. The source WAV and M4A remain untouched and are not duplicated
into the project. No third-party music license is implied.

The 48 kHz stereo MP3 is approximately 3:12 long and 4.6 MB. Godot's native
AudioStreamMP3 repeats it from the start indefinitely. No re-encoding or trimming
is applied to the composition. Playback crossfades between lobby and gameplay
over one second, then pauses the outgoing player at its current position.

Lobby music continues across title, lobby Options and delver selection, pauses
during gameplay, and resumes at its previous position on returning to the lobby.
Gameplay music and looping ambience continue through pause and in-game Options.
Master, Music, FX and Ambience levels are saved in the user's local options file. FX controls
all UI clicks, item/relic hover, enemy hit and enemy death sounds.

`sfx/transitions/loading_screen_cover.wav` and `sfx/transitions/loading_screen_reveal.wav` are the loading
screen's dedicated sounds, played by `AppearSound` (`appear_sound`) and
`DisappearSound` (`disappear_sound`). They are compatible 16-bit PCM playback
copies of the owner's `loading_screen_on.wav` and `loading_screen_off.wav`.
The originals, their import metadata and `provenance.json` are preserved unchanged
in `../../../workspace/archives/audio/loading-screen-originals-2026-10-18.zip`.
The ZIP includes a verified SHA-256 manifest and retains their former relative paths.
Only the compatible playback copies remain in the asset tree. The disappear sound's lead is
`disappear_sound_lead_seconds` (0.1 seconds by default); existing -2 dB player
volume and FX/Master controls apply.

`sfx/ui/button_activate.wav` replaces the previous UI click. It is the owner's supplied
`FL_GFX_UI_Click_27 (ui click).wav`, renamed without changing its audio bytes.
Button activation throughout menus and gameplay plays this sound on the FX bus,
including keyboard/controller activation and checkboxes. Opening a window-size
selector and choosing an entry each play one click. Slider drag completion keeps
the existing FX preview behavior. Programmatic checkbox/selection restoration is
silent. A scene-tree listener also covers dynamically created UI buttons.

`sfx/combat/enemy_hit.wav` is the supplied `FL_GFX_8Bit_Sfx_Shot_01 (enemy hit).wav`.
It plays on actual enemy hit reactions for every class, including damage from
status effects and retaliation. Zero-damage actions do not trigger it.

`sfx/combat/enemy_death.wav` is `FL_GFX_8Bit_Sfx_Explosion_01 (monster death sounds).wav`.
Its independent player starts exactly when the monster begins its pixel
disintegration, after the killing-blow reaction. Combat pause also pauses both
combat effect tails. Returning to the lobby, starting a new run, or opening
Options stops remaining combat effects.

Both combat sounds use FX at -6 dB with up to four overlapping voices, without
trimming, re-encoding, looping or pitch changes.

`sfx/ui/item_hover.wav` is `FL_GFX_UI_Click_14 (hover item).wav`. It plays once on pointer
entry into a backpack item, occupied storage/relic slot, or item/relic reward
choice. Moving inside the same backpack item does not retrigger the sound;
empty slots and dragging stay silent. It has a separate FX player, so it does
not interrupt UI clicks or combat sounds. All four WAVs were renamed unchanged;
`sound-effects-provenance.json` records their original names and SHA-256 hashes.

The previous `ui_click.mp3` is archived as an unused historical asset, originally
copied unchanged from `UIClick-Create_a_0.09_second-Elevenlabs.mp3`.
The unused `warrior_slash.wav` was copied byte-for-byte from the owner's
`the_sounds_of_a_warr_#2-1792084984090.wav` (48 kHz, stereo, 16-bit PCM,
0.4865 seconds). The accompanying `the_sounds_of_a_warr_#2-1792084981961.mp3`
has the same duration and a 0.9946 decoded waveform correlation; these are
treated as two exports of the same slash; the lossless WAV was used previously.
Both original uploads remain untouched in Downloads.

These historical assets and the other unused root clips are preserved in
`../../../workspace/archives/audio/unused-effects-2026-10-18.zip`, with original
filenames, import settings and a SHA-256 manifest. Every archived entry was
verified before its working copy was removed. They have no production players.
