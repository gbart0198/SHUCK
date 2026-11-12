# SHUCK — Game Design Spec

**Working title:** SHUCK
**Tagline:** *A friendslop oyster bar. Four hands, one knife, no refunds.*
**Version:** 1.0 (design lock, implementation not started)
**Owner:** whoever picks this up. Everything here is a decision, not a suggestion, except where marked `TUNE`.

---

## 0. The pitch, in one paragraph

You are the night crew of a condemned oyster bar at the end of a rotting pier. Tickets come
down the rail, you shuck, you grade, you serve, the gull steals your oyster, Dave sets his
hand on fire, you lose the lease. It is `PEAK` played at a counter instead of on a mountain:
first person, physics in your hands, one verb repeated until it is muscle memory, and three
friends making every repetition louder. Solo works, four players is the point.

---

## 1. Positioning

| | |
|---|---|
| Price | **$7.99 list**, $5.99 launch week (-25%). Do not go free. Free kills the friendslop gift-buy. |
| Platform | Steam, Windows + Linux + Steam Deck Verified |
| Players | 1, or 2–4 online co-op (host-authoritative, later) |
| Target playtime | **6–8 h to credits**, 15–20 h to completionist, infinite daily shifts after |
| Genre tags | Simulation, Indie, Co-op, Physics, Funny, First-Person, Cooking, Relaxing (ironic) |
| Comps | PEAK ($7.99, 94%, 311k reviews), PowerWash Simulator, Overcooked, Trash Goblin ($19.99) |
| Shelf gap | Verified Nov 2026: **zero** oyster-shucking games on Steam. `shuck` = 0 results. `oyster shucking` = 1 result, a horror fishing game. `mussel`, `oyster farm`, `cannery` = nothing relevant. |

Why it sells: the shelf is empty, the verb is instantly legible in a trailer (hand, knife,
shell, pearl), and the 4-player chaos clip is the ad. PEAK proved the $8 co-op-physics slot
is a 300k-review market.

**What it is not:** a management sim, a restaurant tycoon, a fishing game, a horror game.
No building, no crafting grid, no combat, no open world.

---

## 2. Pillars

1. **One verb, endlessly tuned.** The shuck is the whole game. Every upgrade changes how the
   same four gestures feel. If a system does not make the shuck faster, cleaner or funnier,
   it is out.
2. **Physics in your hands.** The oyster is a real object. You can drop it, throw it, stab
   the wrong thing, knock a friend's tray. Nothing is a menu.
3. **Numbers go up, visibly.** Money on the wall, grade on the plate, pearls in the case.
   The player should see progress without opening a UI.
4. **Friends make it worse, then better.** Co-op adds chaos first (someone bumps your elbow)
   and competence second (four-station line). Never a griefing tool.
5. **Soft failure only.** Nobody dies. You faint, you lose the shift, you keep your pearls.
   PEAK's lesson: losing is a story, not a penalty.

---

## 3. The PEAK feel — a checklist the build must pass

Copy these behaviours, not the mountain.

| Element | Requirement |
|---|---|
| Camera | First person, 1.62 m eye height, 75° FOV, hands rendered in a separate view layer so they never clip. |
| Hands | A hand *spring*: hands lag 60 ms behind camera, overshoot 15%, always settle. Held item sways with movement. |
| Read | Every interactable is a chunky silhouette with 3–5 flat shades, no outlines, strong warm/cool light contrast, baked-ish AO. |
| Ragdoll | Fainting ragdolls the player for 6 s. Teammates can drag you. |
| Throw | Everything held can be thrown with a charged arc preview. Throwing is the co-op verb. |
| Comedy | Timing, not text. No joke dialogue, no memes, no fourth wall. The gull is the joke. |
| Voice | Proximity voice on by default in lobby. Push-to-talk alt. |
| Emotes | 4: wave, shrug, point, "one sec". Bound to a radial. |
| Chaos events | One per shift, telegraphed 3 s ahead with audio only. |
| Fail state | Shift failure screen is a fisherman's ledger with your losses hand-written on it. Never a "YOU DIED". |

---

## 4. Loop at three timescales

**Second:** wedge → pop → slide → scoop. Pick up, place, serve.
**Shift (10–16 min):** tickets arrive, quota rises, one chaos event, shift ends, ledger screen
with payout, spend or save.
**Pier (~60–90 min):** new species, new hazards, one tier of every upgrade, boss shift, credits
roll, next pier.

**Franchise (post-credits, open-ended):** replay any pier at raised Tide (difficulty), payouts
×2.5, finish the upgrade ladder, chase the pearl log and daily leaderboard.

---

## 5. THE SHUCK — the verb (this section is the game)

A single oyster is held in the left hand. A knife in the right. Four gestures, each with a
timing or tracking skill check. Total time per oyster: **3.2 s skilled, 8 s novice**.

### 5.1 Gesture 1 — Wedge (hold LMB)
A `bite meter` fills 0 → 1.0 over **0.6 s**. The hinge sweet spot is the band **0.55–0.75**.

| Release at | Result |
|---|---|
| < 0.40 | Nothing happens. Restart the gesture. |
| 0.40–0.55 | Seated, `+0.15 s` penalty (the knife snags). |
| **0.55–0.75** | **Seated clean.** Grants `Steady` for the next gesture (+8% slide tolerance). |
| 0.75–1.00 | Seated, wobble +20% on the slide. |
| > 1.00 | **Slip.** 40% chance of `Nicked` (bleeding, see §14). Shell is fine, oyster is fine, hand is not. |

### 5.2 Gesture 2 — Pop (release, then click on the ring)
A ring closes toward a centre dot over **0.5 s**. Click when the ring is inside the dot.

| Timing | Result |
|---|---|
| Dead centre (inner 30%) | **Clean pop.** Grade floor raised to A. Audio: a single perfect ceramic *tock*. |
| 30–60% | Normal. |
| Outside the dot | **Cracked.** Meat damage +1 tier, shell shards on the bench, grade capped at C. |
| No click (ring collapses) | The oyster *fights back*: it clamps, and you must re-wedge. Wastes 1.2 s. |

### 5.3 Gesture 3 — Slide (drag along the seam)
A seam spline appears on the shell. The knife follows your mouse with **wander**: the faster
you drag, the more the knife drifts off the line. Off-line distance is sampled every frame.

- Tolerance: **6 px** at knife tier 1 → **18 px** at tier 6.
- Staying inside tolerance at ≥ 80% hover speed grants `Surgical` (+10% grade).
- Cumulative off-line > 40 px: you stab the meat. `Juice loss`, grade −1 tier, one drip on the bench.
- Off the shell entirely: shell breaks. Full `Butchered` grade, no pearl reel.

### 5.4 Gesture 4 — Reseat (grab, lift, release over the plate)
Hold LMB to pinch the meat with the knife tip, then move over the plate and release. The meat
follows a real physics arc. Dropped = **Ruined** (grade F), the oyster is gone, the ticket
timer keeps running, and you get the worst sound in the game.

### 5.5 Pearls
Pearls are **decided at spawn**, never on open. This is a hard rule: it keeps RNG honest and
makes netcode trivial later. The reveal is cosmetic — a `plink`, a small dust puff, and the
pearl rolls into the shell cup.

Pearl chance is per-species (see §6), modified by the `Luck` stat from the Lamp line (§10).

### 5.6 Skill expression
Three layers, all visible in the trailer:

- **Speed:** APM. A tier-6 player shucks in under 2 s.
- **Precision:** clean pop + surgical slide = grade S, which pays 1.6×.
- **Luck:** pearl table. Cannot be bought, only hunted.

### 5.7 Input map (rebindable, all of it)

| Action | MnK | Pad |
|---|---|---|
| Interact / hold gestures | LMB | RT |
| Secondary (drop, place, throw charge) | RMB | LT |
| Rotate held item | Mouse X/Y | Right stick |
| Emote radial | E hold | D-pad up |
| Sprint | Shift | L3 |
| Voice | V (push-to-talk) | — |
| Flashlight | F | D-pad right |
| Pause / ledger | Esc | Start |

---

## 6. Oysters (species)

7 species. Each is a difficulty curve and a price, not a skin.

| Species | Pier | Difficulty | Value (¢) | Pearl % | Notes |
|---|---|---|---|---|---|
| Dock Blue | 1 | Easy: wide hinge, 8 px slide tolerance | 8 | 4% | Tutorial species. Forgiving valves. |
| Kumamoto | 2 | Small, slippery: −25% meter window | 14 | 8% | High pearl rate, low meat. |
| Pacific Gigas | 2 | Huge, slow, heavy: +0.3 s per gesture | 22 | 3% | Yields **2** meat, so 2 plates from one shell. |
| Razor Clam | 3 | Long seam, 14 px tolerance, brittle | 18 | 6% | Breaks if you slide faster than 70% speed. |
| Moon Snail | 4 | Round: needs a drill minigame first | 30 | 9% | Drill = hold-still test, 4 s, wobble increases. |
| Devil's Claw | 5 | Spiky: requires Gloves tier ≥ 4 or you take `Barnacle Rash` | 55 | 12% | Best pearl source before the finale. |
| Cursed Oyster | 6 / events | Opens itself, screams, moves | 90 | 25% | Must be shucked within 8 s or it escapes and bites. |

`TUNE`: value column is at Pier 1 pricing. Multiply by `pier.priceScale` (1.0, 1.3, 1.7, 2.2, 2.8, 3.5).

---

## 7. Grading and serving

### 7.1 Grades

| Grade | How | Price mult | Tip |
|---|---|---|---|
| **S** Perfect | Clean pop + Surgical + no damage | ×1.6 | +30% |
| **A** Clean | Clean pop, minor imperfection | ×1.25 | +15% |
| **B** Standard | No mistakes, no bonuses | ×1.0 | +5% |
| **C** Rushed | Crack, juice loss, or stab | ×0.55 | 0 |
| **F** Butchered | Dropped, shattered, or abandoned | ×0 | 0 |

Grade is computed as: `gradeScore = timingBonus + surgicalBonus + popBonus − damagePenalties`,
then bucketed. Show the bucket, never the number.

### 7.2 Tickets
Tickets arrive on the rail on a timer. Each ticket = 1–4 oysters of one or two species, plus
an optional modifier.

| Modifier | Effect |
|---|---|
| *"On the half shell, no pearl"* | Pearl is forfeited, +40% pay. |
| *"Extra brine"* | +1 s at the plate station, +20% pay. |
| *"Regular's order"* | Named customer, patience −25%, tip +50%. |
| *"To go"* | Must be boxed (pick up box, place oyster, close). Adds a two-handed step. |
| *"Still alive, please"* | Cannot use the Pop gesture. Serve whole. +60% pay. |

Patience bar per ticket: **22 s** base, minus 3 s per extra oyster, minus modifiers. Expire =
`Walked Out`, lose the ticket pay and one star from the shift.

### 7.3 Shift structure
8–16 tickets, a rising quota, one chaos event at the 60% mark, and a 20 s "last call" with
three rapid tickets. End of shift shows a ledger: earnings, tips, walked-out count, pearls
found, stars (0–3). Stars gate badges and pier unlocks; money does not.

---

## 8. Pearls — the collection meta

The long tail. This is the "one more shift" hook and the reason the game has a wiki.

### 8.1 Anatomy of a pearl
`shape` (6) × `colour` (8) × `lustre` (1–5) × `size` (mm 3.0–14.0) + one `trait`.

Shapes: Round, Button, Drop, Oval, Baroque, Circled.
Colours: White, Cream, Pink, Lavender, Gold, Peacock, Black, Iris.
Lustre 1–5 is a visual shader parameter and a price multiplier (×1.0 → ×4.0).
Size multiplies value on a curve: `value = base × (size/6)^2.2`.

### 8.2 Traits (rolled after shape/colour)

| Trait | Chance | Effect |
|---|---|---|
| Common | 79.90% | None. |
| Lustrous | 12.00% | Lustre set to max. |
| Flawed | 5.00% | Value ×0.4, still logs the entry (completionists need it). |
| Twin | 2.00% | Two pearls, same stats. |
| Cultured | 0.90% | +1 permanent Luck for the rest of the shift. |
| Mother-of-Pearl | 0.09% | Shell is kept as a display item; worth 2,500¢. |
| **The Tidewrought** | 0.01% | Named pearl. Server-wide announcement. |

### 8.3 The log
**48 entries** (6 shapes × 8 colours). Each entry tracks: best lustre, best size, count.
Completing a colour row unlocks a cosmetic; completing the log unlocks `Pearl Baron` rank,
a trophy case, and the Sea Glass knife skin.

Plus **8 Named Pearls** from boss shifts and Cursed Oysters, each with a hand-written flavour
line and a unique display plinth. These are the "I was there" items.

### 8.4 The case
A physical display case in the bar, visible from the counter. Pearls you place are rendered
in-world with a light rig. Placing a pearl gives a passive bonus to that pier's tips
(+2% per displayed pearl, cap +20%) — the collection pays rent.

---

## 9. Economy

Currency: **shells (¢)**. Never abstract points. Show a chalkboard total on the back wall.

### 9.1 Income per shift

| Pier | Tickets | Avg ticket | Avg shift income | Quota | Tier unlocked |
|---|---|---|---|---|---|
| 1 Jetty | 8 | 16¢ | ~300¢ | 120¢ | Knife/Glove T2 |
| 2 Harbor | 10 | 30¢ | ~600¢ | 300¢ | Bench T2 |
| 3 Raft City | 11 | 55¢ | ~1,000¢ | 600¢ | Automation T2 |
| 4 Reef | 12 | 85¢ | ~1,600¢ | 1,000¢ | Floor T2 |
| 5 Lighthouse | 14 | 120¢ | ~2,400¢ | 1,600¢ | All T3 |
| 6 Trench Casino | 16 | 190¢ | ~3,500¢ | 2,600¢ | All T4 |

### 9.2 Spend targets (these are the pacing contract)

| Moment | Time from launch | Must be affordable |
|---|---|---|
| First upgrade | 3 min | 120¢ knife tier 2 |
| First automation | 40 min | 900¢ conveyor |
| First "wow" purchase | 70 min | 2,000¢ shop floor tier 3 |
| First boss shift | 90 min | not money-gated, skill-gated |
| Credits | 6–8 h | ~60% of the ladder bought |

Total ladder cost **103,600¢** across 5 lines. Full maxing is a Franchise-mode goal, not a
first-playthrough one. That is deliberate: it gives post-credits a reason to exist.

---

## 10. Upgrades — five lines, six tiers

Each tier is gated by pier (tier N unlocks at pier N). Costs are per line. Every tier must
change how the shuck *feels*, not just a number.

### Line A — Knives (the shuck itself)

| Tier | Name | Cost | Effect |
|---|---|---|---|
| 1 | Rusty Shucker | start | Baseline. |
| 2 | Dock Knife | 120 | Slide tolerance 6 → 9 px. |
| 3 | Stainless | 400 | Wedge band widens to 0.52–0.78. |
| 4 | Oyster Fork | 1,100 | +1 grade score on every oyster. |
| 5 | Titanium | 2,600 | Slide tolerance 9 → 15 px; wander −30%. |
| 6 | The Inherited Blade | 5,500 | Perfect pops auto-succeed; one free `Slip` per shift. |

### Line B — Gloves (protection and grip)

| Tier | Name | Cost | Effect |
|---|---|---|---|
| 1 | Dish Gloves | start | Baseline. |
| 2 | Rubber Grip | 120 | `Wet Hands` penalty halved. |
| 3 | Chainmail Thumb | 400 | 50% chance to ignore `Nicked`. |
| 4 | Butcher's Cuff | 1,100 | `Cramp` never triggers on the first oyster of a ticket. |
| 5 | Devilhide | 2,600 | Immune to `Barnacle Rash`; can hold Devil's Claw at full speed. |
| 6 | The Old Pair | 5,500 | Fainting takes 2 hits instead of 1. |

### Line C — The Bench (workspace)

| Tier | Name | Cost | Effect |
|---|---|---|---|
| 1 | Driftwood Bench | start | 1 oyster slot, 90 s freshness. |
| 2 | Second Board | 120 | 2 oysters in flight; freshness +30 s. |
| 3 | Ice Trough | 400 | Freshness 120 s → 10 min. |
| 4 | Foot Pedal | 1,100 | Releases the wedge without moving your mouse hand. |
| 5 | Marble Top | 2,600 | Plated oyster holds grade 20 s longer before it dries. |
| 6 | The Long Counter | 5,500 | 4 slots; you can shuck two oysters at once (double gesture, double risk). |

### Line D — Automation (idle-ish, deliberately worse than you)

Automation is a throughput floor, never a replacement. Auto-shucked oysters cap at grade B
and halve pearl chance. This is the anti-degenerate rule.

| Tier | Name | Cost | Effect |
|---|---|---|---|
| 1 | Hand Crank Conveyor | start | None. |
| 2 | Belt Feed | 900 | Feeds 1 oyster to the bench every 4 s. |
| 3 | Auto-Grader | 2,200 | Grades and plates B-max automatically; you serve. |
| 4 | Otto (the robot shucker) | 4,500 | Shucks a ticket every 12 s at B-max, ½ pearl odds. |
| 5 | Brine Recycler | 7,000 | +15% pay on every auto-processed oyster. |
| 6 | The Line | 12,000 | Otto + belt run unattended for 60 s. Automation stops when you stop playing — no offline income. |

### Line E — Shop floor (multipliers and vibe)

| Tier | Name | Cost | Effect |
|---|---|---|---|
| 1 | One Stool | start | 1 customer slot. |
| 2 | Neon Sign | 150 | +10% tips. |
| 3 | Radio | 500 | +5% patience; unlocks the station selector. |
| 4 | Four Stools | 1,300 | 4 customers; parallel tickets. |
| 5 | Lamp Rig | 3,000 | +8% pearl chance (the `Luck` stat). |
| 6 | The Aquarium Wall | 6,500 | Pearls on display pay double (+40% tip cap). |

`TUNE`: the five lines should never compete for the same 3 minutes of cash. If a player can
only afford one thing, it must be obvious which one (the one that fixes their current pain).

---

## 11. Gadgets (consumables and toys)

Bought in the back room, or found in chaos events. Max 2 carried per player. This is where
the PEAK item DNA lives — every gadget is a physical object you hold and throw.

| Gadget | Cost | Use |
|---|---|---|
| Flash Chiller | 90 | Freeze freshness decay for 10 s, whole bench. |
| Pry Bar | 120 | Skip one wedge (no skill check, no `Nicked` risk). 1 use. |
| Pager | 60 | Delete one ticket with no penalty. |
| The Shout | 40 | Stuns all gulls for 6 s. Costs your voice. |
| Pinhole Light | 250 | Reveals a pearl's rarity before you open. 1 use. |
| Bucket of Ice | 80 | Splash a fainted teammate awake, or chill 3 oysters. |
| Shell Glue | 70 | Repair a cracked shell back to grade A. |
| Shop Dog | 400 | Permanent. Chases gulls. Takes one oyster a shift as payment. |
| Fog Horn | 150 | Ends a `Rogue Wave` event early. |
| Rubber Oyster | 30 | Decoy. Thrown. Does nothing. The gull takes it. Beloved. |

---

## 12. Shop, cosmetics, unlockables

### 12.1 Cosmetics (money sink, no gameplay effect)
Hats (20), aprons (12), gloves skins (10), knife skins (8), bucket skins (6), radio stations (5),
hook hands (3), bar signs (6). Every cosmetic is worn in first person where visible (knife,
gloves) or seen by teammates (hat, apron). Prices 60–800¢.

### 12.2 Badges — 12, PEAK-style, each unlocks a cosmetic

| Badge | Condition | Reward |
|---|---|---|
| First Shift | Finish a shift | Deckhand cap |
| Clean Hands | 20 perfect pops in one shift | White gloves |
| Pearl Diver | Log your first pearl | Pearl tie-pin |
| Gulled | Have a gull steal your oyster | Gull hat |
| Nine Fingers | Faint twice in one shift and finish it | Bandaged hand wrap |
| Last Call | Serve the final ticket with < 1 s left | Stopwatch charm |
| The Whole Pier | 3-star every shift in one pier | Pier flag apron |
| Full Case | Display 12 pearls at once | Velvet case |
| Mother's Day | Find a Mother-of-Pearl | Mother-of-Pearl knife |
| Tidebreaker | Beat the Trench Casino | The Inherited Blade (cosmetic variant) |
| Crew of Four | Finish a shift with 4 players | Crew jacket |
| The Log | Complete the pearl log | Pearl Baron crown |

### 12.3 Relics (found, not bought)
One per pier, hidden in the environment, missable. Each is a physical object for the bar:
a ship's wheel, a neon clam, a mermaid's comb, a lighthouse lens, a rigged dice, a captain's
chair. Placing them changes the bar's look permanently and adds a small passive. These are
the "explore the level" pull.

---

## 13. Locations — six piers

Each pier = new species, new hazard, one upgrade tier, one boss shift, one relic.

1. **The Jetty** — tutorial. Calm water, sunset, 3 gulls. Teaches the four gestures, one at a
   time, with a "ghost hand" overlay you can turn off.
2. **Crabpot Harbor** — working docks, cranes, crab swarms. Hazard: crabs steal from the
   bench. Species: Kumamoto, Gigas.
3. **Raft City** — a floating shantytown. Physics chaos: your bar bobs, the floor tilts, the
   bench slides. Hazard: rogue wave.
4. **The Reef** — an underwater bubble bar. Absurd, PEAK-esque. Air pockets, fish swimming
   through, low gravity on thrown items. Hazard: bubble pop (the room floods for 10 s).
5. **The Lighthouse** — storm, darkness, the lamp is your only light. Hazard: power cuts.
   Species: Devil's Claw.
6. **The Trench Casino** — the finale. A casino built on a trench, run by something. Cursed
   Oysters, the King Oyster boss shift, and the credits.

**Boss shifts:** one per pier from 3 onward. A single enormous oyster (or a table of 6 cursed
ones) with a 3-minute timer and its own theme. Beating it awards the pier's Named Pearl.

### 13.1 Tides (difficulty modifiers, PEAK's *Ascents*)
Stackable, chosen before a shift, each worth a payout multiplier:

| Tide | Effect | × |
|---|---|---|
| Neap | +20% patience | 0.9 |
| Spring | −20% patience | 1.2 |
| Murky | Bench lighting halved | 1.2 |
| Slippery | All tolerance −30% | 1.3 |
| Crowded | +50% tickets | 1.5 |
| Hungry | Quota +50% | 1.5 |
| Gulls | 4 extra gulls | 1.3 |
| **Low Water** | One gadget slot | 1.2 |

---

## 14. Hazards, status effects, events

### 14.1 Status effects (visible on the body, not in a HUD list)

| Status | Cause | Effect | Cure |
|---|---|---|---|
| Wet Hands | Any splash, ice melt | Wedge meter 15% faster (harder) | Towel (bench item) |
| Nicked | Slip | Steady blood drip, 12 s, +1 damage to grade | Bandage |
| Cramp | 8 oysters without a break | Random hand shake, 20% gesture failure | Shake it out (emote) |
| Salt Burn | 3 min in salt water events | Patience of your own actions −10% | Rinse at the sink |
| Barnacle Rash | Devil's Claw bare-handed | Screen itch vignette, −20% slide tolerance | Gloves tier 5 |
| Drowsy | Pier 5–6 night shifts | Occasional 0.2 s input delay | Coffee (gadget) |
| Fainted | 2 Nicked in 60 s | Ragdoll 6 s, drop everything | Teammate splash |

### 14.2 Chaos events (one per shift, telegraphed by audio 3 s ahead)

Gull raid · Crab convoy · Rogue wave · Power cut · Health inspector (a 30 s mini-task: hide the
bad oysters, wipe the bench) · Drunk customer (throws an empty shell every 4 s) · Rival van
(parks outside, steals 1 ticket) · Brine spill (floor slick, you can slip) · The Screaming
Oyster (a cursed one gets loose and hides under the bench).

---

## 15. Co-op design (2–4) and solo

### 15.1 Stations
Four stations around one counter. Each player *owns* a station; it is not a shared free-for-all.

| Station | Job |
|---|---|
| **Shucker** | Opens oysters, drops them on the pass. |
| **Grader** | Picks up opened oysters, plates, adds ice/lemon, calls the grade. |
| **Runner** | Takes tickets off the rail, boxes to-go orders, keeps ice stocked, throws gadgets. |
| **Griller** | Hot oyster orders only; also the only one who can reach the back room. |

Solo = all four, in sequence. That is the skill ceiling and the reason solo is not a lesser mode.

### 15.2 Co-op rules
- **Hand-off:** you can throw an opened oyster to a teammate. Catching is a click. Dropping it is a grade F and everyone hears it.
- **Combo:** consecutive S/A grades *across the team* build a `Line` multiplier (up to ×2.0). One F resets it. This is the entire reason to play with people.
- **Revive:** a fainted player is revived by a splash (Bucket of Ice) or by a teammate dragging them to the sink (3 s).
- **No griefing tools.** You can bump, splash and throw, and that is enough.
- **Scale:** ticket count and quota scale ×1, ×2.2, ×3.2, ×4.0 for 1–4 players. Income scales slightly below that, so co-op is a little slower per head but far more fun.
- **Drop-in:** a new player joins mid-shift at an empty station; the shift does not pause.

### 15.3 Lobby
Steam lobby, 4 slots, "Ready" per player, host picks pier and Tides on a wall chart. 3 s
countdown. Mid-run drop-in allowed; no host migration (host leaves = shift ends, everyone
keeps pearls, the ledger is honest about it).

---

## 16. Netcode plan (build later, design for it now)

The design above is already netcode-cheap because every interaction is a **discrete state
transition**, not a continuous physics dependency.

- **Model:** host-authoritative. Host = server (`multiplayer.is_server()`), Godot `ENetMultiplayerPeer`, 4 players, no dedicated servers, no matchmaking service.
- **Oyster state machine:** `SPAWNED → SEATED → OPEN → PLATED → SERVED → BINNED`. Only the
  player who currently *holds* the oyster may send a transition. Server validates holder and
  state, then broadcasts the transition. Everything visual (particles, audio, the reveal
  animation) is client-side and triggered by the transition, never by state polling.
- **Pearls decided at spawn** by a host-seeded `RandomNumberGenerator`. One stream per shift,
  seed sent with the shift start. Clients never roll. This kills rollback, dupes and rerolls
  in one line of design.
- **Scoring:** server computes grade from the transition payload (timings the client reports,
  clamped server-side). Never trust a client's grade. Anti-cheat here is "clamp the numbers",
  nothing more; it is a $8 co-op game.
- **Transforms:** `MultiplayerSynchronizer` at 20 Hz for held items, 10 Hz for props.
- **Physics:** each client simulates locally. Thrown items are client-authoritative on release
  (send position + velocity + owner); the server arbitrates disputes by last-write-wins.
  No rollback, no determinism.
- **Voice:** out of scope for v1. Add Steam voice or a plugin post-launch. Proximity voice is
  a marketing bullet, not a launch blocker — but put it in the store page only if it ships.
- **Later:** SteamWorks lobbies, friend invites, join-in-progress, ping display, host tag.

---

## 17. Progression & metagame

### 17.1 Ranks (XP from grades, never from money)
Deckhand → Shucker → First Shucker → Dock Boss → Pearl Baron → Tidebreaker.
Each rank is a title on the door, a small passive (+2% tips per rank), and a colour on your
nameplate. XP: S = 10, A = 6, B = 3, C = 1, F = 0, +20 per shift completed.

### 17.2 Daily Tide
Seeded shift per day (seed = date), fixed species and Tides, Steam leaderboard on payout.
No extra content, infinite retention, zero authoring cost.

### 17.3 Steam achievements — 32 (representative list)
First Shuck · First Pearl · First S · Shift of 20 perfects · Serve a ticket you shucked blind
(power cut) · 3-star Pier 1 · 3-star all six · Find all six relics · Log 48 pearls · Find The
Tidewrought · Beat a boss shift solo · Beat a boss shift with 4 · Faint and still 3-star ·
Serve 1000 oysters · 1000 perfect pops · Pay the full upgrade ladder · Buy every cosmetic ·
Win a Daily Tide (top 10%) · Gull hat equipped · Serve a ticket with 0.1 s left · Ruin 10
oysters in one shift (hidden, "Cursed Crew") · Complete the tutorial without the ghost hand ·
Throw an oyster to a teammate who catches it · and so on.

### 17.4 Photo mode and shareability
Freeze, hide UI, free camera inside 5 m. Every friendslop game needs one screenshot that
sells the game. A button in the lobby and the shift-end ledger.

---

## 18. Onboarding — the first 10 minutes

| Minute | Beat |
|---|---|
| 0:00 | Black screen, a door, a gull. Push the door. You are behind the counter. |
| 0:30 | One ticket. One oyster. Ghost hand shows the wedge. You do it. It pops. |
| 1:30 | Second ticket, ghost hand shows the pop ring. |
| 2:30 | Third ticket, full four gestures. First grade shown, first 8¢ on the wall. |
| 4:00 | First pearl. The `plink`. The case lights up. |
| 5:00 | First upgrade affordable. Shop opens. The knife is visibly better. |
| 7:00 | First chaos event: a gull. You learn you can throw things. |
| 9:00 | Second player can join here (or the solo path continues). |
| 10:00 | Shift ends. Ledger. "Tomorrow: the Harbor." |

The ghost hand is skippable from the pause menu and the achievement remembers.

---

## 19. Content budget

| Asset | Count | Notes |
|---|---|---|
| Oyster meshes | 7 + 1 boss | Closed, open, meat, shell-shard variants (4 states each) |
| Pearl meshes | 6 shapes, 8 material variants | One mesh per shape, material tint per colour |
| Knives | 8 | Cosmetic + tier silhouettes |
| Hats | 20 | Chunky, low poly |
| Pier environments | 6 | One kit each, ~40 props reused |
| Props | ~120 | Crates, stools, lamps, buckets, nets, bottles |
| Characters | 1 rig, 8 cosmetic slots | First-person hands are the star; bodies are simple |
| Relics | 6 | Unique hero props |
| Audio | ~180 one-shots | Foley is 40% of the feel |
| UI | 6 screens | Pause, ledger, shop, case, log, lobby |

Playtime: 6–8 h to credits (6 piers × ~8 shifts × ~1.2 min average after the first pass),
~12 h to all stars and relics, ~18 h to a full pearl log and the maxed ladder.

---

## 20. Technical spec

- **Engine:** Godot 4.4+ (Forward+). Renderer needs good low-poly lighting; Forward+ is fine,
  Mobile is not.
- **Targets:** 60 fps at 1080p on a GTX 1060 / Steam Deck at 40 fps 800p. Budget: 1.5 ms CPU
  for the interaction system, < 200 draw calls per pier.
- **Scene structure:**
  - `Main` → `Lobby` | `Shift`
  - `Shift` → `PierEnvironment`, `Counter`, `Stations[4]`, `Player[1..4]`, `TicketRail`, `ChaosDirector`
  - `Oyster.tscn` — mesh states, `OysterStateMachine`, interaction surface
  - `Player.tscn` — `Head`, `HandsLayer` (separate `Viewport`? no — separate `Camera` cull mask layer + own `WorldEnvironment`), `HoldSlot`, `EmoteRadial`
- **Data-driven:** all species, pearls, upgrades, tickets, cosmetics, achievements in
  `res://data/*.tres` (custom `Resource` classes) so a designer can retune without code.
- **Interaction system:** one `Interactable` interface (`can_interact`, `begin`, `tick`, `end`).
  The shuck gestures are four `InteractionStep` resources chained by `OysterStateMachine`.
  This is the single most important abstraction in the codebase — every gadget reuses it.
- **Save:** `user://save.json`, versioned, written on shift end only (no mid-shift saves).
  Schema below.
- **Localisation:** key everything from day one. Strings in `res://i18n/en.csv`.
- **Accessibility:** hold-vs-toggle on every hold, FOV 60–100, head-bob off, motion blur off,
  subtitle the chaos events, colourblind-safe pearl tiers (shape + icon, never colour alone),
  full input rebinding, one-hand mode (foot pedal maps to a key).

### Save schema (v1)

```json
{
  "version": 1,
  "money": 0,
  "xp": 0,
  "rank": 0,
  "pier": 1,
  "upgrades": { "knife": 1, "gloves": 1, "bench": 1, "auto": 1, "floor": 1 },
  "gadgets": { "chiller": 0, "prybar": 0 },
  "pearls": [ { "shape": 0, "colour": 3, "lustre": 4, "size": 8.2, "trait": 0, "pier": 2 } ],
  "log": { "0-3": { "bestLustre": 4, "bestSize": 8.2, "count": 1 } },
  "relics": ["jetty_wheel"],
  "badges": ["first_shift"],
  "cosmetics": { "owned": ["hat_deckhand"], "equipped": { "hat": "hat_deckhand", "knife": null } },
  "stats": { "oysters": 0, "perfect": 0, "faints": 0, "walkedOut": 0 },
  "shifts": 0,
  "tideHighScores": {}
}
```

---

## 21. Build milestones (for the implementing agent)

Each milestone has an acceptance check. Do not start the next one before the check passes.

### M0 — Grey-box shuck (3–5 days)
One room, one oyster, four gestures, a grade, a sound.
**Accept:** a human can shuck 10 oysters in a row and tell the difference between an S, a B
and an F by feel before reading the HUD. If the feel is not there, stop and fix it. Everything
else in this document is worthless if M0 is flat.

### M1 — One full shift (1 week)
Ticket rail, 3 species, grading, payout, ledger screen, upgrade shop with 3 lines × 2 tiers,
save/load.
**Accept:** 10 minutes of play, one shift finished, one upgrade bought, save survives a restart.

### M2 — Pier 1 + Pier 2, polish (2 weeks)
Onboarding, ghost hand, gulls, the shop dog, cosmetics, badges, the pearl case and log.
**Accept:** a stranger plays 30 minutes without being told anything and asks to keep playing.

### M3 — Content: piers 3–6, boss shifts, relics, Tides (3 weeks)
**Accept:** 6–8 h playthrough to credits, no progression blockers, no dead ends in the economy.

### M4 — Co-op netcode (3 weeks)
Host-authoritative per §16, Steam lobbies, drop-in, the Line combo, revive.
**Accept:** 4 players, 45 minutes, no desync on pearl reveals, no client-side grade inflation,
host-quits handled gracefully.

### M5 — Ship (2 weeks)
Achievements, photo mode, Steam Deck verification, localisation pass, store page, a trailer
built from one 30-second clip of the gull steal.

Total: **~3 months solo**, which is why the scope rules below matter.

---

## 22. Out of scope (write this on the wall)

No fishing minigame. No boat. No restaurant tycoon. No crafting. No combat. No procedural
levels. No PvP. No battle pass. No cosmetic microtransactions. No offline income. No story
cutscenes. No dialogue trees. No second playable verb (you shuck; everything else is picking
things up).

---

## 23. Balance knobs (expose these as a debug panel)

`TUNE` list — the agent should make every one of these editable at runtime:

- Wedge band start/end, meter duration
- Pop ring speed, perfect window
- Slide tolerance per knife tier, wander curve
- Freshness timers per bench tier
- Ticket patience base, per-oyster penalty
- Grade multipliers and tip percentages
- Pearl chances per species, trait table weights
- Automation interval, grade cap, pearl penalty
- Co-op player scaling factor
- Tide payout multipliers
- Chaos event weights per pier

Log to CSV: shift length, grades histogram, oysters per minute, pearls per shift, money per
shift, abandons, faint count. Retune weekly against the histogram, not against vibes.

---

## 24. Store page draft (so the build has a target)

> **SHUCK**
> *Four hands. One knife. No refunds.*
>
> The oyster bar at the end of the pier is yours now. The lease is not paid. The health
> inspector is coming. The gulls know.
>
> Shuck. Grade. Serve. Upgrade. Repeat until the tide comes in.
>
> - **A real knife.** Four physical gestures per oyster — wedge, pop, slide, scoop. Get them clean and the money is good.
> - **1–4 players.** A four-station line, or one person doing all four badly.
> - **48 pearls.** Six shapes, eight colours, and a 0.01% chance of something the wiki will argue about.
> - **Six piers.** A jetty, a harbor, a raft city, an underwater bar, a lighthouse in a storm, and a casino at the bottom of the trench.
> - **Badges, relics, a shop dog.** The dog takes one oyster a shift. He is worth it.
>
> $7.99 · Single-player and online co-op · Steam Deck Verified
