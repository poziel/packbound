# In-game developer tools

Press **F8** during a run (or click the DEV TOOLS hint). Escape closes the panel. The shortcut can be rebound in Options. Available in debug builds; an intentional release testing session can opt in with `-- --packbound-dev`.

**Edits affect the active run and its normal saves.** Items, relics, health, resource budgets, enemy state and travel results persist normally. Save failures appear in the result message. Session cheats and unapplied commands are never serialized. Changing install directories does not isolate Godot user data.

## Controls

- **Items:** search display names or stable IDs, give 1-100 items to stash, give and auto-pack, remove selected owned equipment, add/remove relics. Switch the catalog selector to Relics. Quiver arrow choices/upgrades use their special rules. Class restrictions and permanent equipment remain enforced. Failed auto-placement leaves the new item in stash.
- **Player:** explicit Apply buttons for health, maximum health, mana, stamina/energy, Block, Momentum, Necromancer companions and Bowmaster volley countdown. Mana/stamina/Block edits set saved starting and round budgets so the next computed round uses the requested values; Reset budgets restores normal equipment/class budgets. Restore health, refill resources and clear poison are separate actions.
- **Cheats:** invulnerability, healing at each round start, infinite mana and infinite stamina. These flags reset when the app closes or a different run starts. Invulnerability blocks all health-loss sources. Round healing does not prevent lethal damage within an exchange. Infinite resources bypass their item costs without inflating remaining mana or conversion bonuses. Active switches remain visible when the panel closes.
- **Combat:** search the full enemy roster, fight the selected enemy on the current floor, restart the current encounter retaining player health/equipment/relics, defeat an enemy with normal rewards, inspect/edit enemy conditions, start/resume/pause combat, choose turn-based playback and step one exchange.
- **World:** jump instantly to floor 1-20 and a valid room type, or return to the entrance. The final floor has no next-floor selector. Travel keeps equipment, current health and earned reward queues, abandons the current fight/room, and initializes a new valid destination. It does not grant victory rewards for skipped enemies.

## Combat checkpoints

Opening pauses combat. Closing resumes only combat that the panel paused, preserving a fight that was already paused. Closing cancels any unapplied edits.

If an enemy response or its feedback is outstanding, ordinary edits queue. **Finish exchange & apply** lets that exchange finish and applies edits at a paused boundary. **Cancel edits** drops them. Replacing a fight or travelling explicitly cancels old playback and queued commands. Input and mutation controls lock during a step; no old response is replayed against a replacement encounter.

## Ownership

`dev_menu.tscn` is editable and owns layout. `dev_menu.gd` presents controls. `dev_menu_host.gd` coordinates the application's existing run, playback, world, refresh and save owners. `systems/development/dev_commands.gd` validates mutations; `dev_session.gd` owns transient policy. Catalogs, inventory placement, eligibility, quiver configuration, room initialization and enemy-completion rules remain with their existing owners.

The four maintained tests are `dev_commands`, `dev_cheats`, `dev_menu_flow`, and `dev_menu`. Run them with `./tests/run_tests.ps1 -Suite all -Test 'dev_*'`. Add `-Render` to the `dev_menu` test to exercise two window sizes and capture all five tabs. Captures are review evidence; automatic checks do not establish visual correctness.
