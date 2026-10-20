# Music and ambience

`menu/shadows_in_the_backpack.mp3` is the owner's existing lobby composition,
moved here without changing its audio bytes. It loops continuously in the lobby.

`gameplay/` contains only four replacement songs: **Vault of Ash**, **Crypt Below
the Hollow**, **Vaults Beneath Ash**, and **Cavern Oath**. Ogg playback files use
FFmpeg `-map 0:a:0 -c:a libvorbis -q:a 5`, without trimming or changing tempo.
Original WAVs remain unchanged in the owner's Downloads folder.

Entering gameplay starts a random track after a random 3–4-second delay. Tracks
play once; after each ends, a random real-time 10–30-second gap precedes another choice, excluding
the immediately previous track. Pause and in-game Options preserve both playback
and the gap. The playlist uses its own random generator, independent of combat.

Lobby/gameplay transitions use a one-second crossfade on the Music bus. After
fading out, the outgoing track pauses instead of restarting. Returning to
gameplay resumes its track or remaining gap. Lobby Options keep lobby music.
Master/Music volume and mute settings apply to both music players; FX stays separate.

`../ambience/` contains two dungeon recordings layered continuously during gameplay.
Both loop independently, including during song gaps, pause and in-game Options.
Each layer has a 0.5 playback gain for shared headroom. Their independent Ambience
bus defaults to 15%, compared with Music's 70%; saved options control each bus
separately, and both route through Master. Muting Music leaves ambience audible.
Ambience fades out and pauses in the lobby, resuming its position in gameplay.
Old settings without an ambience value receive the 15% default.

The six owner-supplied WAV sources in `C:/Users/poziel/Downloads/` map as follows:

| Source WAV | Playback file |
| --- | --- |
| `Vault_of_Ash_2026-10-16T000523.wav` | `gameplay/Vault_of_Ash.ogg` |
| `Crypt_Below_the_Hollow_2026-10-16T000523.wav` | `gameplay/Crypt_Below_the_Hollow.ogg` |
| `Vaults_Beneath_Ash_2026-10-16T000424.wav` | `gameplay/Vaults_Beneath_Ash.ogg` |
| `Cavern_Oath_2026-10-16T000424.wav` | `gameplay/Cavern_Oath.ogg` |
| `dungeon_ambiance,_da_#1-1792108890897.wav` | `../ambience/Dungeon_Ambience_1.ogg` |
| `dungeon_ambiance,_da_#2-1792108876026.wav` | `../ambience/Dungeon_Ambience_2.ogg` |

The replaced 22-track playlist and its original M4A sources are preserved in
`workspace/docs/audio/archive/previous-gameplay-2026-10-15/`, excluded from Godot's resource
scan by `.gdignore`. None remain in the active playlist.

No third-party music license is implied; see [audio README](../README.md) for existing
audio provenance and sound effects.
