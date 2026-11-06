# SHUCK

*A friendslop oyster bar. Four hands, one knife, no refunds.*

Godot 4.7.2 project. Built from `SPEC.md`; every balance number is a `.tres` resource under `res://data/`.

## Status

| Milestone | State |
| --- | --- |
| **M0** Grey-box shuck | **Done.** Four gestures with the §5 timings, grade stamp, sounds, hand spring, hands in a separate viewport. |
| **M1** One full shift | **Done.** Ticket rail, patience/walk-outs, 5 species in play, grading, payout/tips, ledger, upgrade shop, pearl log, versioned save. |
| **M2** Piers 1–2 + polish | **Mostly done.** Ghost hand, gulls, shop dog, cosmetics, 12 badges, pearl case and log, localisation. Missing: full voice/emote/throw layer, all status effects. |
| **M3** Piers 3–6, bosses, relics, Tides | **Done at the systems level.** Six pier palettes, six species + King Oyster, boss shifts on 3–6, six relics, eight Tides, Daily Tide, credits flag. New levels reuse one room kit. |
| **M4** Co-op netcode | **Stub.** Host/join, shift-seed sync and static crew avatars. Live co-op verbs, transform sync and grade validation are not implemented. Single-player never touches it. |
| **M5** Ship polish | **Partial.** Photo mode, debug balance panel, shift CSV analytics, accessibility settings, localisation. Steam achievement integration, Deck verification and a store page are not done. |

The honest list of divergences and stubbed pieces is in `DECISIONS.md`.

## Run

```sh
GODOT=/Users/gbart/Downloads/Godot.app/Contents/MacOS/Godot
"$GODOT" --path /Users/gbart/dev/projects/shuck
```

The game starts in the lobby. Pick a pier (Pier 1 is unlocked), optionally tick Tides, then **Start shift**.

### Controls

| Action | Key |
| --- | --- |
| Move / sprint | WASD / Shift |
| Look | Mouse |
| Interact, hold gestures | LMB |
| Drop / secondary | RMB (reserved) |
| Take a ticket / pick up an oyster / serve the plate | LMB on the object |
| Foot pedal (release the wedge) | Space (after Bench T4) |
| Flashlight | F |
| Pause, FOV, ghost hand, subtitles | Esc |
| Photo mode | P |
| Debug balance panel | F3 |
| Pry Bar / Pager | 1 / 2 |

### The loop

1. Look at a ticket on the rail and click it. Oysters appear on the bench.
2. Click an oyster. Hold LMB, release in the green band (**wedge**).
3. Click when the closing ring reaches the dot (**pop**).
4. Hold LMB and drag along the seam (**slide**).
5. Hold LMB, drag to the plate, release (**reseat**).
6. Click the plate to serve. The ticket pays when every portion is served.
7. When the shift ends, the ledger opens: spend in the shop, then next shift.

## Tests

```sh
GODOT=/Users/gbart/Downloads/Godot.app/Contents/MacOS/Godot
cd /Users/gbart/dev/projects/shuck

# 1. import must be clean
"$GODOT" --headless --import --path .

# 2. required smoke test: FSM, grades, tickets, upgrades, 100k pearls, save
"$GODOT" --headless --path . --script tests/smoke.gd

# 3. wiring test: real input loop, raycast interactables, boss, Tides, save reload
"$GODOT" --headless --path . -- --integration
```

`tests/smoke.gd` is the contract check: 129 assertions, exits non-zero on failure. It covers the oyster state machine (including crack and fight-back), S/A/B/C/F grading, ticket payout and tip maths, upgrade cost application and tier gates, the §8.2 trait distribution over 100,000 rolls, pearl chance over 100,000 spawns, and the versioned save round-trip.

`tests/integration_runner.gd` runs inside the real game (autoloads present) and drives the actual `Player` input flags through all four gestures, raycast ticket/oyster/plate interactions, the ledger, a purchase + reload, a boss shift, all six piers, Tides, Daily Tide, relics and gadgets.

## Layout

```text
project.godot           Godot 4.7 project, input map, autoloads
data/*.tres             species, upgrades, piers, Tides, chaos, modifiers,
                        badges, cosmetics, gadgets, pearls, interaction steps
scripts/core/           pure logic (no scene tree): OysterSim, TicketSim,
                        GradeLogic, PearlRoller, Economy, SaveGame, Registry
scripts/game/           Player, HandsView, Shift, Interactable, OysterNode,
                        PlateStation, TicketCard, autoloads (Data/Game/Sfx/Net), Main
scripts/ui/             HUD, gesture overlay, lobby, shop, ledger, pearl log
scripts/world/          procedural mesh factory, pier builder, gull, relic
tests/                  smoke.gd (required), integration_runner.gd
tools/                  gen_data.gd (regenerates data/*.tres), gen_i18n.py
i18n/en.csv             359 localised keys
```

## Data

`tools/gen_data.gd` is the authoring source for the initial `data/*.tres`. After generation, the `.tres` files are the source of truth; a designer can retune them in the Godot inspector without touching code. `tools/gen_i18n.py` regenerates `i18n/en.csv`.

The five biggest live knobs (wedge band, meter duration, pop window, slide tolerance, patience, pearl base value) are exposed in the F3 debug panel. Every shift appends a row to `user://shift_log.csv` for retuning.

## Save

`user://save.json`, schema version 1 (SPEC §20), written on shift end and when the post-shift shop closes. Mid-shift there are no writes.
