# SHUCK Simulator

*Rake oysters. Shuck oysters. Sell oysters. Hire robots to do it for you.*

A number-go-up oyster simulator (the Roblox "simulator" loop) played in first person, in SHUCK's original
low-poly, foggy, dusk-lit pier style.
You start as a **Lowly Fisherman** with a rake and a red bucket on a muddy beach, and you work your
way up to an automated coastal empire run by deckhands, coordinators, ShuckBots and Sell Drones, with
a Golden Lobster floating behind your head.

Godot 4.7.2. Everything is primitives + code: no downloaded assets, procedural sound.

## The loop

1. **Catch.** Click oysters in the tidal beds to rake them loose (or hold the mouse button to keep raking). They fly into your bucket.
2. **Shuck.** Stand at a **SHUCK** bench and click to stab. A needle sweeps a meter. Click in the **gold** band for a **PERFECT** (triple damage, double meat, double pearl chance). String PERFECTs together for a streak: at x5 two oysters crack at once, at x10 four, all the way to 128 at x1000.
3. **Sell.** Walk onto a **SELL** dock. Your meat *and* everything in the crew's Meat Crate turns into cash.
4. **Upgrade.** Rake Power, Bigger Bucket, Sharper Knife, Meat Quality, Sneakers, Pearl Luck, Tide Magnet (auto-rakes around you) and Warehouse.
5. **Expand.** Buy open the gates along the coast. Each zone has a fancier oyster worth a lot more:
   Muddy Shallows → Rocky Point → Kelp Forest → Coral Reef → Neon Lagoon → Volcano Vent → Abyssal Trench → Golden Atoll.
6. **Automate.** At the Hiring Hall, hire **Deckhands** (rake into their beach's Dock Bin), **Shuckers**
   (Dock Bin → Meat Crate, exactly as fast as a Deckhand rakes) and one **Coordinator** per beach (sells
   that beach's whole crate and speeds up every worker by 50%). Every beach has its own crew outpost with
   a few slots per worker type; hires fill the Muddy Shallows first, then move up the coast, and opening
   a gate adds room. **Train** any worker type to make every one of them faster. You can dump your own
   bucket into a Dock Bin too. Build the **Robotics Lab** for **RakeBots**, **ShuckBot 3000s** and
   **Sell Drones**, then the **Mega-Factory** to double every robot per level. You can watch your crew
   work each beach. They keep working while the game is closed (half speed, up to 8 h).
7. **Pets.** Shucking turns up pearls. Spend them on Mystery Clams at the pet hatchery for pets (Common → SECRET)
   that multiply all cash. Three follow you around. Fuse three duplicates into the next rarity.
8. **Re-Shell.** Once a run has earned enough, sell the whole operation for a **Golden Shell** (+50% cash forever).
   You keep pets, pearls and your rank title.

Random events roll every few minutes: **Golden Tide** (x2 cash), **Pearl Storm** (x5 pearls),
**Oyster Frenzy** (instant regrowth) and **Crew Coffee Break** (crew x3).

The **NEXT UP** card in the top right always names one concrete thing to do next.

Rank titles follow all-time earnings: Lowly Fisherman, Mudlark, Deckhand, Head Shucker, Foreman, Harbourmaster,
Oyster Baron, Shellionaire, Oyster Emperor, Poseidon's Accountant.

## Controls

First person. Every binding below is the default; rebind any of them in **Esc → Controls**
(saved to `user://settings.json`).

| Action | Default |
| --- | --- |
| Look | Mouse |
| Walk | WASD / arrow keys |
| Sprint | Shift |
| Jump | Space |
| Rake / stab / buy a gate | Left mouse (hold to repeat) |
| Use booth / open gate | E |
| Shop · Crew · Pets · Re-Shell · Map | B · C · P · R · M |
| Pause (How to play, Controls, Settings, tutorial, quit) | Esc (fixed) |

The game opens on a title screen: **Continue**, **Load Save**, **New Game** (a new save slot, never
overwriting one), **Settings** and **Quit**. A 10-step tutorial runs when you start a new game and names
whatever keys you have bound; skip or replay it from the pause menu. Settings: volume, fullscreen,
VSync, FOV, head bob, mouse sensitivity, invert Y. Walking up to a booth at HQ also opens its menu.
Tabbing out does not pause: your crew keep working, and a click takes control again.

## Look

Each zone uses one of the original pier palettes (dusk, overcast, kelp, violet, teal, ember, night,
gold dawn); sky, fog and sunlight cross-fade as you walk the boardwalk between zones. Hands render in
their own viewport (rake on the flats, knife at the bench, the oyster you're working on in the off hand).

## Run

```sh
GODOT="C:/Users/gbart/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --path .
```

Saves live in `user://saves/slot_N.json` and autosave every 20 s and whenever a menu closes. The older
single save (`user://shuck_sim.json`) moves into slot 1 automatically. Shift-era saves (`user://save.json`)
are ignored.

Developer flags (after `--`) skip the title screen and start an unsaved session: `--fresh`, `--demo`
(mid-game state), `--menu=crew`, `--pause` + `--pause-page=controls`, `--at-bench`, `--look=x,z,yaw,pitch`,
`--shot=path.png` (+ `--shot-delay=N`, `--perfect`), and `--title` (+ `--title-page=load`) to capture the
title screen. AGENTS.md has the full list.

## Tests

```sh
"$GODOT" --headless --import --path .
"$GODOT" --headless --path . --script tests/smoke.gd     # economy rules + a simulated player for pacing
"$GODOT" --headless --path . -- --integration             # drives the real game: rake, shuck, sell, menus, crew, pets, Re-Shell
```

`tests/smoke.gd` prints how long a bot that plays the loop takes to reach each milestone (gates, first crew,
robots, Re-Shell). Use that when tuning numbers.

## Layout

```text
scripts/sim/catalog.gd       every number: zones, upgrades, crew, robots, pets, ranks, events
scripts/sim/empire.gd        the whole economy as one plain object (no nodes): testable headless
scripts/sim/num.gd           1.23K / 4.56M / 7.89B formatting
scripts/game/game_state.gd   autoload "Game": owns the Empire, save slots/autosave/offline, signals
scripts/game/save_store.gd   save-slot files (list, load, write, delete, migrate the old save)
scripts/game/main.gd         builds the world, avatar, HUD, menus
scripts/game/avatar.gd       first-person fisherman: look, move, rake, shuck, sell, pets
scripts/game/hands_view.gd   first-person hands (own viewport): rake, knife, held oyster
scripts/game/settings.gd     autoload "Settings": key bindings, mouse/video/volume, tutorial progress
scripts/world/               coast builder, oyster beds, stations, crew yard, figures, FX
scripts/ui/                  HUD, tabbed menu, title screen, pause menu (rebinding, settings), tutorial
docs/legacy/                 the original shift/boss-based SPEC and DECISIONS, kept for reference
```

Balance lives entirely in `scripts/sim/catalog.gd`.
