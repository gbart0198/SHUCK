# AGENTS.md: SHUCK Simulator

Read this first. It's meant to save you from re-exploring the project. Everything here was true as
of 2026-11-12. If a claim and the code disagree, the code wins: fix this file.

## What the game is

A **first-person, low-poly oyster "simulator"**: the Roblox-simulator incremental loop played in
SHUCK's original foggy, dusk-lit pier art style.

- **Loop:** rake oysters on the mudflat → shuck at a bench (timing meter, gold band = PERFECT) →
  walk onto a sell dock → spend on upgrades / gates / crew / robots / pets → Re-Shell (prestige).
- **Progression:** start as "Lowly Fisherman" on the Muddy Shallows and end with an automated empire
  across 8 beaches (Deckhands, Shuckers, Coordinators, RakeBots, ShuckBot 3000s, Sell Drones,
  Mega-Factory).
- **No bosses, no levels, no shifts, no quotas, no tickets.** Deliberately removed at the user's
  request; don't reintroduce them. Beaches are one continuous walkable coast behind purchasable gates,
  not levels.

## User preferences and decisions (honour these)

Look and feel:
- Graphics stay **"like PEAK"**: first person, low-poly primitives, fog, muted dusk palettes, warm
  hanging lamps, wooden boardwalk/shacks, first-person hands. No bright/bubbly Roblox look, no
  third-person camera, no chunky outlined UI fonts.
- The UI is a muted **beach theme**: deep dusk-sea panels, sand-rope borders, cream text, serif
  headings, sea-glass green and sunset-coral accents (`UiKit`). Keep it muted, not bubbly.
- Must have: title screen (main menu), pause menu (Esc), controls tutorial, key rebinding. All exist;
  keep them working.

Gameplay decisions (each was an explicit request; the numbers are in "Economy" below):
- **Slow, grindy start that snowballs.** The first hire should take real effort (~20 min for a
  person); upgrades should feel strong because the early game is hard.
- **Tools must not outrun the beaches.** The user found tools "way too easy to become super
  powerful"; they were rebalanced and smoke checks now guard it.
- **Workers fill the LOWEST beach first** (all Shallows slots, then Rocky Point, ...). No free slot
  anywhere = you can't hire.
- **Two upgrade paths per worker type:** HIRE (more of them) and TRAIN / FIRMWARE (each one faster).
- **A Shucker works exactly as fast as a Deckhand** (and a ShuckBot as fast as a RakeBot).
- **One Coordinator per beach.** Expensive, a powerful upgrade: sells the whole beach's crate and
  speeds up all crew.
- **The player can dump their bucket into a Dock Bin** for the shuckers on that beach.
- **PERFECT streaks shuck several oysters at once** (x5 → 2 per crack ... x1000 → 128), never more
  than you carry. Shucking has satisfying feedback (sparks, glint, banner, streak track).
- **Tabbing out does NOT pause.** It's an idle game: the crew keep earning; the mouse is released.
- **Save slots:** Continue / Load Save / New Game from the title screen. New Game never overwrites.

Working style:
- Don't spin on something broken for long: move on and report it at the end.
- Commit only when the user asks. **Never add a Co-Authored-By line or any AI attribution** to
  commits or PRs (the user's Claude settings also turn attribution off).
- Git has no identity configured on this machine. Commits use
  `git -c user.name="SHUCK builder" -c user.email="shuck@example.invalid" commit ...`, matching the
  existing history. Remote: `origin` on GitHub, default branch `main`.

## Environment

- **Godot 4.7.2**, Windows. Use the console exe (prints output; required for headless):
  `C:/Users/gbart/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  (`Godot_v4.7.2-stable_win64.exe` is a **folder** containing both exes.)
- No Python on this machine. Use bash/sed/perl for scripted edits. For multi-line perl edits, put
  the script in a file (`perl -0pi script.pl file`); long one-liners with quotes break in Git Bash.
- Shell: Git Bash (POSIX) and PowerShell both available.

```sh
G="/c/Users/gbart/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --import --path .                 # must be silent (no errors/warnings)
"$G" --headless --path . --script tests/smoke.gd > tests/out/smoke.log 2>&1   # expect "PASS — 94 checks"
"$G" --headless --path . -- --integration > tests/out/integ.log 2>&1          # expect "PASS — 67 checks"
"$G" --path .                                     # play (opens on the title screen)
```

- After adding or renaming a `class_name`, delete `.godot/global_script_class_cache.cfg` and
  re-import. Otherwise you get "Could not resolve class".
- Warnings are errors in this project (e.g. a `:=` that infers Variant fails to parse). A parse error
  in one script makes `main.gd` fail to load, and the integration log fills with unrelated
  "Nil" errors: look for the first `Parse Error` line.
- Headless shutdown prints harmless noise ("BUG: Unreferenced static string", RID leaks). Grep for
  `FAIL|PASS|SCRIPT ERROR` instead.
- Don't pipe a long Godot run into `tail`/`grep` directly under a timeout: the pipe hides a hang.
  Redirect to `tests/out/*.log` (gitignored) and grep afterwards.
- The smoke test's pacing bot clicks randomly (unseeded), so milestone times vary by ±15% run to run.
- **Screenshots** (real rendering, opens a window briefly):
  `"$G" --path . --resolution 1600x900 -- --fresh --demo --shot=C:/Users/gbart/shuck/tests/out/x.png`,
  then view the PNG. A normal launch shows the title screen; **any dev flag below starts an unsaved
  session straight in the game.** Flags (after `--`):
  - `--fresh`: no save load/write; settings not persisted.
  - `--demo`: mid-game state (4 beaches, crew, cash), skips the tutorial.
  - `--at-bench`: stand at the zone-0 shuck bench.
  - `--look=x,z,yawDeg,pitchDeg`: place the camera. Yaw 0 faces −Z (the sea), 180 faces the yard.
    Standing within ~2.6 m of an HQ booth auto-opens its menu.
  - `--shot=path.png`, `--shot-delay=N`: capture after N s (default 3; ~10 lets crew walk).
  - `--perfect`: land six PERFECT stabs just before the capture (reaches the x5 tier; use with `--at-bench`).
  - `--menu=shop|crew|pets|reshell|map`, `--pause --pause-page=main|howto|controls|settings`.
  - `--title` (+ `--title-page=load|settings`): screenshot the title screen.
  - `--integration`: run `tests/integration_runner.gd` (implies a fresh, non-persisting run).

## Architecture (all code; the only scene is `scenes/Main.tscn` → `scripts/game/main.gd`)

Autoloads (order matters; defined in `project.godot`): **Settings → Sfx → Game**.
`project.godot` has **no `[input]` section**: `Settings` creates every action at runtime.

| File | Role |
| --- | --- |
| `scripts/sim/catalog.gd` (`Catalog`) | **All balance numbers**: `ZONES` (8: value, hp, gate + art palette), `UPGRADES`, `CREW` (incl. robots; an entry may set `slots`), slot, training and Coordinator constants, `STREAK_TIERS`, `RANKS`, `PETS`, `RARITIES`, `CLAMS`, `EVENTS`, cost/effect formulas. `ZONE_WIDTH = 44`. |
| `scripts/sim/empire.gd` (`Empire`) | The whole economy as a plain RefCounted (no nodes, testable headless): bag, `shuck_hit(perfect)` (streak + multi-crack), `sell()`, purchases, `hire/train`, `unit_rate`, per-beach outposts (`bins/bin_values/crates/crate_values` by zone), `assignment()` / `slots()` / `free_slots()`, `deposit_bin(zone)`, crew pipeline in `tick(dt)`, events, `offline(sec)`, pets, `reshell()`, `next_goal()`, `to_dict/from_dict` (`SAVE_VERSION = 2`, migrates the old single bin/crate). |
| `scripts/sim/num.gd` (`Num`) | `short/cash/rate/duration` big-number formatting (K, M, B, T, Qa…). |
| `scripts/game/game_state.gd` (autoload **Game**) | Owns `Game.empire` and the session: `in_session` (false = title screen), `active_slot`, `continue_latest() / load_slot(n) / new_game() / delete_slot(n) / end_session()`, autosave 20 s, play time, offline earnings on load. Dev flags (`DEV_FLAGS`, `--look=`, `--menu=`, `--shot=`) make an unsaved session. Signals `changed, toast, banner, sold, pet_hatched, reshelled, zone_unlocked`. **UI/world call the `Game.*` wrappers** (`buy_upgrade, hire, train, deposit_bin, buy_lab, buy_factory, unlock_zone, reshell, hatch, toggle_pet, equip_best, fuse, do_sell`) so sounds and toasts fire. Doesn't tick while the tree is paused. |
| `scripts/game/save_store.gd` (`SaveStore`) | Save-slot files: `user://saves/slot_N.json` = `{meta, empire}`. List (most recent first), latest, next_free, read/write/delete. `migrate_legacy()` moves the pre-slot `user://shuck_sim.json` into slot 1 once (kept as `.bak`). Pure file logic; the smoke test drives it in `user://smoke_saves`. |
| `scripts/game/settings.gd` (autoload **Settings**) | Key bindings (`ACTIONS`, `DEFAULTS`, encoded `"k:<physical keycode>"` / `"m:<mouse button>"`), `rebind()` (steals the key from its previous owner), `reset_bindings()`, `key/keys(action)` labels, options (sensitivity, fov, invert_y, head_bob, volume, fullscreen, vsync), tutorial progress. File `user://settings.json` (shared by all save slots). Esc is fixed. |
| `scripts/game/sfx.gd` (autoload **Sfx**) | Procedural sounds: `Sfx.play(id, db, pitch)`. ids: tick tock click crack plink thud stamp gull beep coin money fail splash drill door pop stab perfect fanfare swing. |
| `scripts/game/main.gd` | Builds the world, avatar, CrewYard, HUD. No session → `_enter_title()`: `TitleMenu` over a slow camera pan, HUD and hands hidden; picking a save reloads the scene into play. Menus (`open_menu/close_menu`), pause (`open_pause` builds the menu deferred, then pauses; `close_pause`), Esc handling, focus loss (`avatar.release_focus_state()`, no pause), gate removal, `_rebuild()` after Re-Shell, `WorldBuilder.blend_atmosphere`, dev flags, `_demo_state`. |
| `scripts/game/avatar.gd` (`Avatar`) | First-person CharacterBody3D: mouse look, movement, sprint, jump. Crosshair ray (layer 2) → `hovered`. `act()`: gate buy / shuck at a bench / dump the bucket at a Dock Bin / rake. `use()` (E). Nearest `Station` → `station` (auto-sells on sell docks, auto-opens booth menus). Tide Magnet, pets. Shucking feedback the HUD reads: `perfect_streak`, `perfect_flash`, `miss_flash`, `shake`, `fov_kick`. `focus_lost` after alt-tab. Tutorial reads `look_total`, `walked`, signal `jumped`. |
| `scripts/game/hands_view.gd` (`HandsView`) | First-person hands in their own SubViewport: rake or knife, held oyster, `do_swing`, `do_stab(perfect)` (jab / twist-pry / wiggle), `aim(meter, hot, on)` (knife drifts with the meter), `set_shuck_progress` (lid creeps open), gold glint light, sway + bob. |
| `scripts/world/world_builder.gd` (`WorldBuilder`) | Static builder: sky + fog, 8 zones along +X (ground, mudflat, tideline posts, `OysterBed`, shuck shack + `Station "bench"`, sell dock + `Station "sell"`, name board, decor, lamps, rope gate + `Station "gate"`), boardwalk with a rail gap per beach, HQ booths in zone 0 (`shop` TACKLE & TOOLS, `crew` HIRING HALL, `pets` CLAM HATCHERY, `reshell` PEARL MERCHANT), and a crew outpost on every beach (`_crew_yard`: Dock Bin + `Station "bin"`, Meat Crate, crew bench, market cart → `refs.yards[i]`). Helpers: `zone_x/zone_spawn/zone_at`, `sign_text`, `board`, `lamp`, `blend_atmosphere`. |
| `scripts/world/crew_yard.gd` (`CrewYard`) | Visual-only crew (`CrewNpc`) per beach, following `Empire.assignment()` (capped by `MAX_SHOWN` per beach), plus each outpost's bin/crate labels. Job loops: deckhand rakes the flats → carries → dumps in the bin; shucker fetches → shucks at the bench → drops meat in the crate (idles when the bin is empty); coordinator hauls crates to the market cart; drones fly arcs to sea; bots stand at the bench. Smooth steering (turn rate, accel, arrive), separation, soft `OBSTACLES`, routes through the rail gap (`GAP_X`) and along the boardwalk (`WALK_Z`) between beaches, `move_to_zone` for reassignments, `shown_at(id, zone)` for tests. Production lives in `Empire.tick`. |
| `scripts/world/oyster_bed.gd` / `oyster_pickup.gd` | Beds respawn oysters (3.5 s; Frenzy ×8). `OysterPickup` is an Area3D on layer 2, group `"oysters"`, with hp and `hit(dmg)`. |
| `scripts/world/station.gd` (`Station`) | Group `"stations"`. `kind` (bench/sell/bin/shop/crew/pets/reshell/gate), `zone_i`, `radius`, `near(pos)` (gates check only \|dx\|), `tooltip()`. |
| `scripts/world/figures.gd` | Blocky person/robot/drone/pet models. Limbs are named pivots (`ArmL/ArmR/LegL/LegR/Head`, rake child `Rake`). **Positive arm `rotation.x` swings forward.** |
| `scripts/world/mesh_factory.gd` | Primitives: box/sphere/cylinder/shell/oyster (lid pivot `Lid`)/knife/hand/gull/crab/crate/pearl. Keep the `shell_mesh` outward-normal logic (the old dome was degenerate and back-lit). |
| `scripts/world/fx.gd` | `float_text`, `burst`, `chips`, `sparks`, `fly_to`, `ring` (tween-based, self-freeing). |
| `scripts/ui/ui_kit.gd` (`UiKit`) | Beach palette and helpers: `panel, label, title (serif), tag, button, paint, keycap, chip/set_chip, wave, bar (UiKit.Bar), draw_bar, icon (UiKit.Icon: coin/oyster/meat/pearl/shell/crew/spark, drawn in code, no emoji fonts), anchor, theme`. **Use `UiKit.anchor` for anchored controls**: setting `.position` after `set_anchors_preset` puts things off-screen. |
| `scripts/ui/hud.gd` (`Hud`) | Crosshair + context prompt; top-left purse (cash, $/min, crew $/min, rank + progress, pearls, shells); key legend bottom-left; top-right NEXT UP + THE OPERATION (row per owned crew type: count/slots, rate; bins/crates; crew $/min); bottom belt (bucket, meat + value, PERFECT streak track); shuck meter; PERFECT edge glow; toasts, banners, zone title. Owns `tutorial`. |
| `scripts/ui/menu_ui.gd` (`MenuUI`) | Tabbed SHOP / CREW / PETS / RE-SHELL / MAP window with cash/pearl chips. Crew rows have HIRE + TRAIN and show slots and where each type works. Rows hold refresh lambdas (no rebuild per tick). |
| `scripts/ui/title_menu.gd` (`TitleMenu`) | Main menu: Continue · Load Save (slot list, two-click delete) · New Game (next free slot, restarts the tutorial) · Settings · Quit. Signals `started, quit_requested`. |
| `scripts/ui/pause_menu.gd` (`PauseMenu`) | `PROCESS_MODE_ALWAYS`. Pages main / howto / controls (rebind capture, Esc cancels) / settings. Signals `resumed, quit_requested, main_menu_requested, tutorial_replay, tutorial_skip`. |
| `scripts/ui/settings_page.gd` (`SettingsPage`) | Settings rows shared by the title and pause menus: Audio (master volume), Video (fullscreen, VSync, FOV, head bob), Mouse (sensitivity, invert Y). On/Off pills, because stock CheckBoxes are invisible on dark panels. Deeper audio/video options are planned. |
| `scripts/ui/tutorial.gd` (`Tutorial`) | 10 steps that auto-advance on real actions; text uses the current bindings. Progress lives in Settings. `restart()/skip()/notify(flag)`. |
| `tests/smoke.gd` | Headless economy tests (Num, catch/shuck/sell, streaks, tool balance, crew pipeline, slots, Coordinators, pets, Re-Shell, saves, save slots) plus the **pacing bot** that prints milestone times. |
| `tests/integration_runner.gd` | Run via `-- --integration`. Drives the real game: walking, raking, shucking, selling, menus, gates, crew + Dock Bin + training + slots, pets, alt-tab, pause, rebinding, tutorial, Re-Shell, title menu. `tests/focus_probe.gd` is its helper for the focus-loss regression test. |
| `docs/legacy/` | The old shift/boss SPEC and DECISIONS, kept for reference only. Not current. |

**Physics layers:** 1 = world, 2 = clickable (oysters, stations), 3 (bit value 4) = player.
**Process modes:** main = ALWAYS; WorldRoot and the HUD CanvasLayer = PAUSABLE; pause and title layers = ALWAYS.
**Coordinates:** zone *i* spans x ∈ [44i, 44i+44]. Local layout (x relative to the zone's left edge):
mudflat z ≈ −11..−2 (sea is −Z), boardwalk z ≈ 0.4..3.6 (rail at z 0.35, gap at x 30.6–33.8), shuck
shack (14, 6), sell dock (24, 6), outpost: Dock Bin (33, 8), Meat Crate (39, 8), crew bench (36, 12.6),
market cart (41, 14). HQ booths at z ≈ 19–20 in zone 0. Spawn (x0+9.5, 2.5) facing −Z. Signs face −Z.

## Economy

| Thing | Rule (all in `catalog.gd` unless noted) |
| --- | --- |
| Beaches | value $2 / 8 / 30 / 110 / 420 / 1.6K / 6.5K / 28K per meat; oyster hp 4 / 8 / 14 / 24 / 40 / 65 / 105 / 170; gates $250 / 3K / 75K / 2M / 60M / 2B / 80B. Shucking takes hp × 1.5 (`Empire.shuck_hp_max`). |
| Rake / knife | damage `1 + 0.5·L·(1 + L/20)` (Lv 10: 8.5, Lv 40: 61). Cost base 25, ×1.75 per level. |
| Bucket | `6 + 3L + 0.5·L^1.5` (Lv 30: 178). It used to grow 1.32^L, which broke the game. Cost ×1.6. |
| Other tools | Quality +15%/level (×2.0 cost), Sneakers +0.8 speed (×2.4), Pearl Luck +1% (×2.4), Tide Magnet radius 3 + 0.6L (×3.0), Warehouse storage 60·1.55^L per beach. |
| Crew rates | Deckhand 0.35/s raked, Shucker 0.35/s shucked (equal on purpose), Coordinator 6/s sold, RakeBot = ShuckBot 8/s, Sell Drone 15/s. Hire costs ×1.19 (robots ×1.22). |
| Beach slots | People 4 + 2·zone per type, robots 2 + zone; Coordinators exactly 1 (`"slots": 1`). `assignment()` fills the Shallows first, then up the coast; leftovers from old saves go to the best beach. |
| Coordinators | Base $6,000, ×3.5 each. Each gives ALL crew +50% speed (`COORDINATOR_BOOST`). |
| Training | +25% speed per level, cost = hire base × 30 × 3^level, max 40. Re-Shell resets it. |
| Crew pipeline | Per beach (`Empire.tick`): catch → its Dock Bin → shuck → its Meat Crate → sell, at that beach's value. The bin tracks value, so a bucket dumped from a better beach keeps its worth. Your sell dock empties every crate. Offline: half speed, up to 8 h. |
| PERFECT streak | `Empire.perfect_streak` (session only). x5 → 2 per crack, x10 → 4, x50 → 8, x100 → 16, x200 → 32, x500 → 64, x1000 → 128 (`STREAK_TIERS`), capped by what you carry. Pearl rolls capped at 8 per crack. A miss resets it. |
| `cash_mult` | quality × (1 + 0.5·shells) × pet_mult × (2 during Golden Tide). |
| Re-Shell | Costs 150M × 6^shells earned this run. Keeps pets, pearls, shells and `total_earned` (rank); resets everything else. `Game.reshell` → main `_rebuild()`. |

**Pacing** (the bot clicks 5/s; a person is roughly 2× slower): first Deckhand ~9 min, Rocky Point
~10 min, first Coordinator ~35 min, Lab ~1h15, first Re-Shell ~1h45. Smoke-test bounds: Rocky Point
and first crew both 6–20 min, lab < 2.5 h, Re-Shell < 4 h. When retuning, change `catalog.gd` and rerun
the smoke test a couple of times (the bot is random). Earlier traps: Coordinators at +10% each were
quietly carrying the late game; capping them at one per beach needed the +50% boost and ×3.5 cost
growth to keep pace.

## Gotchas learned the hard way

- **Never add nodes from `_notification`.** Focus notifications are propagated down the whole tree and
  `add_child()` fails during that ("Parent node is busy setting up children"). The old pause-on-alt-tab
  paused the world, then failed to add the menu: the game froze with no menu and no input. Test with
  `get_tree().root.propagate_notification(...)`, not `node.notification(...)`. Real-window repro:
  launch the non-console exe with `--log-file` and minimize/restore it via user32 `ShowWindow` (the
  console exe is a wrapper, so its window handle is not the game's).
- Several workers sent to the *same* final waypoint never arrive (separation pushes them apart). Keep
  shared points pass-through, and keep the stuck-arrival fallback in `CrewNpc._walk`.
- `queue_free()` inside a `while child_count > n` loop never terminates. Call `remove_child` first.
- Sed chains on numbers can corrupt other numbers (`"gate": 100.0000.0`). Grep the results after
  bulk edits. Sed replacements containing `\U` (e.g. a Windows path) uppercase the rest of the line.
- `:=` on Dictionary/Array element access fails type inference. Use `var x: float = ...` or `str()/float()`.
- Label3D defaults to double-sided; `billboard` is not used for world signs (painted boards).
- Headless walking covers less distance per frame. Keep movement-test thresholds loose.
- `--script` runs (the smoke test) still load the autoloads, so `Game._ready` runs there too.

## Status / open items

- Not hand-playtested with a real mouse yet (verified by tests, screenshots and a real-window
  alt-tab repro). Alt-tab is verified windowed only, not fullscreen.
- Late game may now be too fast: with tools pricier, the bot spends on crew/training and reaches all
  8 beaches with ~$1.8B/s income after 6 h. Watch this if the user reports it.
- Each beach shows at most `MAX_SHOWN` workers per type; real counts are in the CREW menu and HUD.
- Settings (keys, volume, video) are global, not per save slot.
- Possible follow-ups: proper sounds and music, more pet models/animations, gamepad bindings
  (Settings only encodes key and mouse), deeper audio/video settings, a Steam build.
- Removed for good: co-op/netcode, badges, cosmetics, relics, tides, chaos, tickets, bosses, shifts.
