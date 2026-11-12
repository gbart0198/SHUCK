# AGENTS.md: SHUCK Simulator

Read this first. It's meant to save you from re-exploring the project. Everything here was true as
of 2026-11-12. If a claim and the code disagree, the code wins: fix this file.

## What the game is

A **first-person, low-poly oyster "simulator"**: the Roblox-simulator incremental loop played in
SHUCK's original foggy, dusk-lit pier art style.

- **Loop:** rake oysters on the mudflat → shuck at a bench (timing meter, gold band = PERFECT) →
  walk onto a sell dock → spend on upgrades / gates / crew / robots / pets → Re-Shell (prestige).
- **Progression:** start as "Lowly Fisherman" and end with an automated empire (deckhands, shuckers,
  coordinators, RakeBots, ShuckBot 3000s, Sell Drones, Mega-Factory).
- **No bosses, no levels, no shifts, no quotas, no tickets.** These were deliberately removed at the
  user's request. Don't reintroduce them. Zones are one continuous walkable coast behind purchasable
  gates; they are not levels.

## User preferences (from conversation; honour these)

- Keep the **simulator gameplay loop**: the user loves it.
- Graphics must stay **"like PEAK"**: first person, low-poly primitives, fog, muted dusk palettes,
  warm hanging lamps, wooden boardwalk/shacks, first-person hands. No bright/bubbly Roblox look,
  no third-person camera, no chunky outlined UI fonts.
- The UI is a muted **beach theme** (2026-11-12 pass): deep dusk-sea panels, sand-rope borders, cream
  text, serif headings, sea-glass green and sunset-coral accents (`UiKit`). Keep it muted, not bubbly.
- Must have: pause menu (Esc), controls tutorial, key rebinding. All exist; keep them working.
- Don't spin on something broken for long: move on and report it at the end.
- Commit only when asked (the user is offered a commit button at the end of each task).

## Environment

- **Godot 4.7.2**, Windows. Use the console exe (prints output; required for headless):
  `C:/Users/gbart/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  (`Godot_v4.7.2-stable_win64.exe` is a **folder** containing the exes.)
- No Python on this machine. Use bash/sed/perl for scripted edits.
- Shell: Git Bash (POSIX) and PowerShell both available.

```sh
G="/c/Users/gbart/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --import --path .                 # must be silent (no errors/warnings)
"$G" --headless --path . --script tests/smoke.gd  # economy + pacing bot: expect "PASS — 94 checks"
"$G" --headless --path . -- --integration > tests/out/integ.log 2>&1   # in-game: expect "PASS — 67 checks"
"$G" --path .                                     # play
```

- After adding or renaming a `class_name`, delete `.godot/global_script_class_cache.cfg` and
  re-import. Otherwise you get "Could not resolve class".
- Headless shutdown prints harmless noise ("BUG: Unreferenced static string", RID leaks). Grep for
  `FAIL|PASS|SCRIPT ERROR` instead.
- Don't pipe a long Godot run into `tail`/`grep` directly under a timeout: the pipe hides a hang.
  Redirect to `tests/out/*.log` (gitignored) and grep afterwards.
- **Screenshots** (real rendering, opens a window briefly): `"$G" --path . --resolution 1600x900 -- --fresh --demo --shot=C:/Users/gbart/shuck/tests/out/x.png`
  then view the PNG. Useful dev flags (after `--`):
  - Normal launch shows the **title screen** (main menu). Any dev flag below starts an unsaved
    session straight in the game instead; add `--title` (and `--title-page=load|settings`) to
    screenshot the title screen.
  - `--fresh`: no save load/write; settings not persisted.
  - `--demo`: mid-game state, skips tutorial.
  - `--at-bench`: stand at the zone-0 bench.
  - `--look=x,z,yawDeg,pitchDeg`: place the camera.
  - `--shot-delay=N`: seconds before the `--shot` capture (default 3; use ~10 to let crew walk).
  - `--perfect`: land six PERFECT stabs (reaches the x5 streak tier) just before the `--shot` capture (use with `--at-bench`).
  - `--menu=shop|crew|pets|reshell|map`
  - `--pause --pause-page=main|howto|controls|settings`
  - `--integration`: also implies a fresh, non-persisting run.

## Architecture (all code, no scenes besides `scenes/Main.tscn` → `scripts/game/main.gd`)

Autoloads (order matters; defined in `project.godot`): **Settings → Sfx → Game**.
`project.godot` has **no `[input]` section**: `Settings` creates every action at runtime.

| File | Role |
| --- | --- |
| `scripts/sim/catalog.gd` (`Catalog`) | **All balance numbers**: `ZONES` (8, each with value/hp/gate + art palette: sand, water, shell, meat, accent, sky_top, sky_bottom, fog, light, light_energy, ambient, wood), `UPGRADES`, `CREW` (incl. robots), crew `TRAIN_*` (training/firmware speed path), `RANKS`, `PETS`, `RARITIES`, `CLAMS`, `EVENTS`, costs/formulas. `ZONE_WIDTH = 44`. |
| `scripts/sim/empire.gd` (`Empire`) | Whole economy as a plain RefCounted (no nodes, testable headless). Bag, shucking (`shuck_hit(perfect)`), `sell()`, purchases, crew `train(id)` + `unit_rate(id)`, per-beach outposts (`bins/bin_values/crates/crate_values` arrays by zone, `bin_total/crate_total`), crew `assignment()` (fills the lowest beach first up to `slots(zone, id)`, then the next one up), `free_slots(id)` (hiring needs one), `deposit_bin(zone)`, crew pipeline in `tick(dt)`, events, `offline(sec)`, pets (`hatch/toggle_equip/equip_best/fuse`), `reshell()`, `next_goal()`, `to_dict/from_dict` (`SAVE_VERSION = 2`). |
| `scripts/sim/num.gd` (`Num`) | `short/cash/rate/duration` big-number formatting (K, M, B, T, Qa…). |
| `scripts/game/game_state.gd` (autoload **Game**) | Owns `Game.empire`; **save slots** via `SaveStore` (`user://saves/slot_N.json` = {meta, empire}; the pre-slot `user://shuck_sim.json` is migrated to slot 1 once, kept as `.bak`). `in_session` (false = title screen), `active_slot`, `continue_latest() / load_slot(n) / new_game() / delete_slot(n) / end_session()`, autosave 20 s, play time in meta, offline earnings on load. Dev flags (`DEV_FLAGS`, `--look=`, `--menu=`, `--shot=`) = unsaved session. Signals `changed, toast, banner, sold, pet_hatched, reshelled, zone_unlocked`. **UI/world call Game.* wrappers** (`buy_upgrade, hire, train, deposit_bin, buy_lab, buy_factory, unlock_zone, reshell, hatch, toggle_pet, equip_best, fuse, do_sell`) so sounds and toasts fire. Doesn't tick while the tree is paused. |
| `scripts/game/settings.gd` (autoload **Settings**) | Key bindings (`ACTIONS`, `DEFAULTS`, encoded `"k:<physical keycode>"` / `"m:<mouse button>"`), `rebind()` (steals the key from its previous owner), `reset_bindings()`, `key(action)` / `keys(action)` labels, options (sensitivity, fov, invert_y, head_bob, volume, fullscreen, vsync), tutorial progress. File `user://settings.json`. Esc is fixed (cannot be bound). |
| `scripts/game/sfx.gd` (autoload **Sfx**) | Procedural sounds: `Sfx.play(id, db, pitch)`. ids: tick tock click crack plink thud stamp gull beep coin money fail splash drill door pop stab perfect fanfare swing. |
| `scripts/game/main.gd` | Builds the world, avatar, CrewYard, HUD. With no session it shows `TitleMenu` over a slow camera pan (`_enter_title`); picking a save reloads the scene into play. Pause "return to main menu" = `Game.end_session()` + reload. Menus (`open_menu/close_menu`), pause (`open_pause/close_pause`, sets `get_tree().paused`), Esc handling, focus loss (does NOT pause: idle game; `avatar.release_focus_state()` frees the mouse and drops a held click, HUD says "Click to take control"), gate removal, `_rebuild()` after Re-Shell, per-frame `WorldBuilder.blend_atmosphere`, dev flags, `_demo_state`. |
| `scripts/game/avatar.gd` (`Avatar`) | First-person CharacterBody3D. Mouse look, `get_vector` movement, sprint, jump. Crosshair ray (layer 2, areas) → `hovered`. `act()`: gate buy / shuck at a bench / dump the bucket at the Dock Bin / rake. `use()` (E). Nearest `Station` → `station` (auto-sells on sell docks, auto-opens booth menus). Tide Magnet. Pets trail behind. Shucking feedback state the HUD reads: `perfect_streak`, `perfect_flash`, `miss_flash`, `shake`, `fov_kick` (PERFECT = sparks + ring + glint + FOV kick + edge glow + streak counter). `set_input(on)` toggles input + mouse capture. Fields the tutorial reads: `look_total`, `walked`, signal `jumped`. |
| `scripts/game/hands_view.gd` (`HandsView`) | First-person hands in their own SubViewport: rake or knife (`set_tool`), held oyster (`show_oyster(zone, open)`), `do_swing/do_stab` (`do_stab(perfect)` rotates jab / twist-pry / wiggle styles), `aim(meter, hot, on)` (knife drifts with the meter), `set_shuck_progress` (lid creeps open), gold glint light, spring sway + bob. |
| `scripts/world/world_builder.gd` (`WorldBuilder`) | Static builder: environment (ProceduralSky + fog), 8 zones along +X (ground, mudflat, tideline posts, `OysterBed`, shuck shack + `Station "bench"`, sell dock + `Station "sell"`, name board, decor, street lamps, rope gate + toll board + `Station "gate"`), boardwalk (rail gap at local x 30.6–33.8 on every beach), HQ booths in zone 0 (`shop` "TACKLE & TOOLS", `crew` "HIRING HALL", `pets` "CLAM HATCHERY", `reshell` "PEARL MERCHANT"), HQ booths. Every beach gets a crew outpost (`_crew_yard`: Dock Bin + `Station "bin"`, Meat Crate, crew bench, market cart; listed in `refs.yards`) and a rail gap. Returns `refs` (env, sky, sun, beds, stations, gates{i:node}, bin/crate labels and positions). Helpers: `zone_x/zone_spawn/zone_at`, `sign_text`, `board`, `lamp`, `blend_atmosphere`. |
| `scripts/world/oyster_bed.gd` / `oyster_pickup.gd` | Beds respawn oysters (3.5 s; Frenzy event ×8). `OysterPickup` is an Area3D on layer 2, group `"oysters"`, with hp, `hit(dmg)` → `raked` signal, and `tooltip()`. |
| `scripts/world/station.gd` (`Station`) | Group `"stations"`. `kind` (bench/sell/bin/shop/crew/pets/reshell/gate), `zone_i`, `radius`, `near(pos)` (gates check only \|dx\|), `tooltip()`. |
| `scripts/world/crew_yard.gd` | Visual-only crew NPCs (inner class `CrewNpc`) per beach, following `Empire.assignment()` (capped by `MAX_SHOWN` per beach), plus live per-beach bin/crate labels. When the assignment changes, surplus workers walk along the boardwalk to the beach that needs them (`move_to_zone`); new hires walk in from the Hiring Hall or along the boardwalk. Each NPC runs a job loop (deckhand: rake flats → carry → dump in bin; shucker: fetch from bin → shuck at bench → drop in crate, idles when the bin is empty; coordinator: crate → market cart) with steering (turn rate, accel, arrive slowdown), separation, soft obstacles (`OBSTACLES`) the rail gap (`GAP_X`) and the boardwalk lane (`WALK_Z`) between beaches. Animation speed follows training. Production lives in `Empire.tick`. |
| `scripts/world/figures.gd` | Blocky person/robot/drone/pet models (`Figures.person/robot/drone/pet`, `animate_walk/swing`). |
| `scripts/world/mesh_factory.gd` | Primitives: box/sphere/cylinder/shell/oyster(shell_color, meat_color, open, scale)/knife/hand/gull/crab/crate/pearl. The `shell_mesh` dome was rewritten (the old one was degenerate and back-lit). Keep the outward-normal logic. |
| `scripts/world/fx.gd` | `float_text`, `burst`, `fly_to`, `ring` (tween-based, self-freeing). |
| `scripts/ui/ui_kit.gd` (`UiKit`) | Beach palette and helpers: `panel, label, title (serif), tag, button(text, cb, size, accentColor), paint, keycap, chip/set_chip, wave, bar (UiKit.Bar), draw_bar, icon (UiKit.Icon: coin/oyster/meat/pearl/shell/crew/spark, drawn, no emoji fonts), anchor(control, preset, offset), theme()`. **Use `UiKit.anchor` for anchored controls**: setting `.position` after `set_anchors_preset` puts things off-screen. |
| `scripts/ui/hud.gd` (`Hud`) | Crosshair + context prompt (uses `Settings.key`), top-left purse (cash, $/min, crew $/min, rank + progress, pearls, shells), key legend bottom-left (rebuilds on `bindings_changed`), top-right column: NEXT goal (hidden during the tutorial) + "THE OPERATION" (a row per owned crew type: count/slots, rate; bins/crates bars; crew $/min), bottom belt (bucket bar, meat + value, PERFECT streak track to the next tier), shuck meter, toasts, banners, zone title. Owns `tutorial`. |
| `scripts/ui/menu_ui.gd` (`MenuUI`) | Tabbed SHOP/CREW/PETS/RE-SHELL/MAP window. Rows hold refresh lambdas (no rebuild per tick). The menu keys toggle or switch tabs; E closes; main handles Esc. |
| `scripts/ui/pause_menu.gd` (`PauseMenu`) | `PROCESS_MODE_ALWAYS`. Pages main / howto / controls (rebind capture in `_input`, Esc cancels) / settings (sliders, checkboxes). Signals `resumed, quit_requested, main_menu_requested, tutorial_replay, tutorial_skip`. |
| `scripts/ui/title_menu.gd` (`TitleMenu`) | Main menu: Continue (latest slot) · Load Save (slot list, two-click delete) · New Game (next free slot, restarts the tutorial) · Settings · Quit. Signals `started, quit_requested`. |
| `scripts/ui/settings_page.gd` (`SettingsPage`) | Shared settings rows (Audio: volume · Video: fullscreen, vsync, FOV, head bob · Mouse: sensitivity, invert) with On/Off pills, used by the title and pause menus. Deeper audio/video options are planned. |
| `scripts/game/save_store.gd` (`SaveStore`) | Pure file logic for save slots (list sorted by last played, latest, next_free, read/write/delete, legacy migration). The smoke test drives it in `user://smoke_saves`. |
| `scripts/ui/tutorial.gd` (`Tutorial`) | 10 steps (look, walk, sprint, jump, rake, fill, shuck, sell, open Shop/buy, pause hint), auto-advancing on real actions, text built from current bindings. Progress lives in Settings. `restart()/skip()/notify(flag)`. |
| `tests/smoke.gd` | SceneTree script: Num, catch/shuck/sell, upgrades/zones, crew pipeline, pets, Re-Shell, save round-trip, plus a **pacing bot** that prints milestone times. |
| `tests/integration_runner.gd` | Run via `-- --integration` (main loads it). Drives the real avatar/menus/pause/rebinding/tutorial/Re-Shell. |
| `docs/legacy/` | The old shift/boss SPEC and DECISIONS, kept for reference only. Not current. |

**Physics layers:** 1 = world, 2 = clickable (oysters, stations), 3 (bit value 4) = player.
**Process modes:** main = ALWAYS; WorldRoot and the HUD CanvasLayer = PAUSABLE; pause layer = ALWAYS.
**Coordinates:** zone *i* spans x ∈ [44i, 44i+44]. The mudflat is z ≈ −11..−2 (sea is −Z), the
boardwalk is z ≈ 0.4..3.6, bench at (x0+14, 6), sell dock at (x0+24, 6), HQ booths at z ≈ 19–20 in
zone 0, spawn at (x0+9.5, 2.5) facing −Z. Signs face −Z (rot PI) so they read from the boardwalk.

## Economy notes

- **Player pipeline:** catch → bag (`bucket_capacity`) → `shuck_hit` → meat (`meat_value` is the base
  value; multipliers apply on sell) → `sell()`, which also empties the crew's Meat Crate.
- **Crew pipeline** (`tick`), per beach: catch → that beach's Dock Bin → shuck → its Meat Crate → sell,
  at that beach's oyster value. Caps come from `storage_capacity(warehouse)` (per beach).
- **Beach slots** (user request): each beach holds `Catalog.crew_slots(zone, id)` of each crew type
  (people 4 + 2·zone, robots 2 + zone). Hires fill the **lowest** beach first (all 4 Shallows slots,
  then Rocky Point, ...); leftovers from old saves go to the best beach. No free slot anywhere = can't
  hire ("BEACHES FULL"); opening a gate adds slots for the next hires (existing crew stay put).
- **Coordinators** (user request): exactly ONE per beach (`"slots": 1` on the CREW entry overrides
  `crew_slots`), expensive (base $6,000, ×3.5 each), each sells 6 meat/s (enough for a full beach of
  untrained Shuckers) and gives ALL crew +50% speed (`COORDINATOR_BOOST`). The +10%-each-with-dozens
  version is gone; with only one per beach the boost had to be bigger to keep the late game paced.
- **Shucker = Deckhand speed** (user request): rates are equal (0.35/s; ShuckBot = RakeBot = 8/s), so
  with equal training one shucker keeps up with one deckhand. Each Coordinator adds +50% crew speed.
  Robots need the lab; the Mega-Factory multiplies robots ×2 per level. The player can also dump
  their bucket into the Dock Bin (`deposit_bin`); the bin tracks `bin_value` so better oysters keep their value.
- **Two crew upgrade paths** (user request): HIRE (count, `crew_cost`) and TRAIN/FIRMWARE (`training[id]`,
  +25% speed per level, cost = hire base × 30 × 3^lv, max 40). Re-Shell resets training.
- **PERFECT streaks** (user request): `Empire.perfect_streak` counts consecutive PERFECT stabs (a miss
  resets it; not saved). When the oyster on the bench cracks, `Catalog.streak_batch(streak)` oysters of
  that kind crack together (x5 → 2, x10 → 4, x50 → 8, x100 → 16, x200 → 32, x500 → 64, x1000 → 128),
  capped by what you carry. Pearl rolls are capped at 8 per crack. `r.tier_up` fires a banner.
- **Tool balance** (user: "way too easy to become super powerful"): rake/knife damage
  `1 + 0.5·L·(1 + L/20)`, bucket `6 + 3L + 0.5·L^1.5` (it used to grow 1.32^L), tool costs ×1.6–3.0 per
  level, quality +15%/level, and zone hp 4/8/14/24/40/65/105/170 so tools keep mattering. Smoke
  checks lock this in (e.g. one-clicking Kelp Forest costs more than the Coral Reef gate).
- **`cash_mult`** = quality × (1 + 0.5·shells) × pet_mult × (2 during Golden Tide).
- **Re-Shell** keeps pets, pearls, shells and `total_earned` (rank). It resets everything else.
  `Game.reshell` → main `_rebuild()`.
- **Pacing** (user wants a slow, grindy start that snowballs): bot at 5 clicks/s gets the first Deckhand
  ~9 min, Rocky Point ~10 min, Lab ~1h15, first Re-Shell ~1h45 (bot timings vary run to run). Humans are roughly 2× slower. Early knobs:
  Shallows hp 4, Rocky gate $250, bucket base 6, shuck hp ×1.5, crew bases 120/180/1200.
  Smoke-test bounds: zone 2 and first crew both 6–20 min,
  lab < 2.5 h, Re-Shell < 4 h. Retune in `catalog.gd` and rerun the smoke test.
- Old v1 shift-era saves (`user://save.json`) are ignored; the new save starts fresh.

## Gotchas learned the hard way

- `queue_free()` inside a `while child_count > n` loop never terminates. Call `remove_child` first.
- Sed chains on numbers can corrupt other numbers (`"gate": 100.0000.0`). Grep the results after
  bulk edits.
- `:=` on Dictionary/Array element access fails type inference. Use `var x: float = ...` or `str()/float()`.
- Label3D defaults to double-sided; `billboard` is not used for world signs (painted boards).
- Headless walking covers less distance per frame. Keep movement-test thresholds loose.
- Don't pause on focus loss. Focus notifications are propagated down the whole tree, and
  `add_child()` fails during that ("Parent node is busy setting up children"): the old code paused
  the world, then failed to add the pause menu, so the game froze with no menu and no input. Never
  add nodes from `_notification`; `open_pause()` now builds the menu deferred and only pauses once it
  exists. Test with `get_tree().root.propagate_notification(...)`, not `node.notification(...)`.
  Real-window repro: launch the non-console exe with `--log-file` and minimize/restore it via
  user32 `ShowWindow` (the console exe is a wrapper, so its window handle is not the game's).
- Never commit without the user asking. Attribution lines come from the session's system reminder.

## Status / open items

- Not hand-playtested with real mouse look yet (verified by tests + screenshots only).
- Co-op/netcode, badges, cosmetics, relics, tides, chaos, tickets, bosses: all removed.
- Possible follow-ups: proper sounds and music, more pet models/animations, gamepad bindings
  (Settings only encodes key and mouse), a Steam build.
