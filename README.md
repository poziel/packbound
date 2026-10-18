<p align="center">
  <img src="assets/branding/packbound-title.png" alt="Packbound: The Cursed Descent" width="696">
</p>

---

<p align="center">
  A fantasy inventory roguelike where the way you pack your satchel shapes every fight.
</p>

<p align="center">
  <a href="project.godot"><img src="https://img.shields.io/badge/Godot-4.7-478CBF?style=flat" alt="Godot 4.7"></a>
  <a href="scripts/"><img src="https://img.shields.io/badge/Language-GDScript-355570?style=flat" alt="Written in GDScript"></a>
</p>

Choose a Delver, pack weapons and supplies into your satchel, and descend into the dungeon. Item placement, neighboring bonuses, and limited mana and stamina determine how your build performs. Prepare between encounters, then start the fight and watch your equipment resolve automatically.

Packbound is being developed in Godot. This repository contains the game project and its source assets; you can run it from the editor.

## Pack for the descent

- **Build inside the bag.** Arrange and rotate items on the satchel grid. Place boosters beside compatible equipment to strengthen your build, and keep spare items in your stash.
- **Choose your Delver.** Warrior, Ranger, Mage, Assassin, and Necromancer each bring their own ability and starting equipment, from counterattacks to persistent undead companions.
- **Make resources count.** Set item priorities to control which attacks spend mana and stamina first. Both refill each round; health and protection follow their own rules.
- **Change the rules with relics.** Collect effects that alter adjacency, resource costs, repeated attacks, and survival. Relics have their own slots outside the satchel.
- **Prepare, fight, adapt.** Claim rewards, rearrange your inventory, and take on the next encounter. Pause combat or adjust its playback speed to follow your build in action.
- **Return to a run.** Local saves keep separate unfinished descents, including their inventory and combat progress. Resumed combat starts paused.

Pixel artwork, a dungeon soundtrack, and ambient creatures give the descent its atmosphere. Hover items and highlighted keywords for explanations of their effects.

## Play from source

1. Install **Godot 4.7** with GDScript support. The project uses the Compatibility renderer and does not require the .NET edition.
2. Download or clone this repository, keeping its directory structure intact.
3. Import [project.godot](project.godot) in Godot and open the project. Allow the initial asset import to finish.
4. Press **F5** to launch the main menu, then choose **New Run** and select a Delver.

If your Godot executable is available as `godot`, you can also launch from the project directory:

```powershell
godot --path .
```

Game preferences and runs are stored locally in Godot's `user://` data directory. Options includes audio levels, window and fullscreen settings, tooltip preferences, and combat playback settings.

## Work on the game

Start with these files:

| Area | Entry point |
| --- | --- |
| Main scene | [scenes/main.tscn](scenes/main.tscn) |
| Classes, items, relics, and enemies | [scripts/pack_catalog.gd](scripts/pack_catalog.gd) |
| Run progression and combat rules | [scripts/run_state.gd](scripts/run_state.gd) |
| Inventory placement and input | [scripts/backpack_board.gd](scripts/backpack_board.gd) |
| Regression checks | [tests/](tests/) |
| Artwork conventions | [AGENTS.md](AGENTS.md) |
| Branding sources and provenance | [assets/branding/README.md](assets/branding/README.md) |

Tests are Godot scripts. For example, from the project directory in PowerShell, run a deferred-reward regression check with an absolute diagnostic log path:

```powershell
New-Item -ItemType Directory -Force workspace/logs | Out-Null
$logFile = Join-Path (Get-Location).Path 'workspace/logs/deferred-rewards.log'
godot --headless --path . --log-file $logFile --script res://tests/deferred_rewards_test.gd
```

Some UI tests require a graphics-enabled Godot process. See the individual scripts in [tests/](tests/) for their fixtures and checks.
