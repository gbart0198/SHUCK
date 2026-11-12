# DECISIONS

Every place where `SPEC.md` was ambiguous, internally inconsistent, or deliberately narrowed.
One line of reasoning per decision. Nothing here changes the spec file itself.

## Numbers and scoring

1. **Grade score buckets.** §7.1 gives the buckets and multipliers but no raw score. I use
   `wedge (clean +10 / imperfect +5 / slip −10) + pop (perfect +20 / normal +10 / cracked 0)
   + surgical +10 − damage (nick 15, juice 25, stab 25)`, bucketed at `S ≥ 40, A ≥ 25, B ≥ 12,
   C < 12`, with a perfect pop flooring the result at A and crack/juice/stab capping it at C.
   *Reason: the scoring falls out of the S/A/B/C descriptions and makes each documented
   combination land in its documented bucket.*
2. **Trait weights total 99.90, not 100.** The §8.2 table sums to 79.90 + 12 + 5 + 2 + 0.90 +
   0.09 + 0.01 = 99.90. The roller divides by the actual total weight, so the shares stay
   proportional to the table. *Reason: keep the printed weights rather than invent a missing
   0.1%.*
3. **Species tolerance shifts the knife ladder.** Dock Blue is 8 px and Razor Clam 14 px, while
   the knife is 6 → 18 px. Effective tolerance = species base + (knife tier tolerance − 6), so
   Dock Blue goes 8 px at T1 and 20 px at T6. *Reason: both numbers in the spec stay true, and
   knife upgrades still help every species.*
4. **The upgrade ladder costs 67,210¢, not 103,600¢.** Summing the five §10 tables gives
   9,720 × 3 + 26,600 + 11,450 = 67,210. The per-tier costs are the actionable numbers, so the
   tables win; `Economy.total_ladder_cost()` returns 67,210 and the smoke test asserts it.
   *Reason: the 103,600 figure cannot be reconciled with any reading of the tables.*
5. **Tips are rounded once, half away from zero** (`roundi`), after modifiers and bonuses.
   *Reason: cents are integers and the order of multipliers otherwise changes the result.*
6. **The Surgical bonus is a score bonus (+10), not a 10% price multiplier.** §5.3 says
   "+10% grade"; grade is a bucket, not a number, so it maps to score. *Reason: it makes the
   documented "clean pop + surgical + no damage = S" true without a fourth price multiplier.*
7. **The knife T3 band is 0.52–0.78 and T6 perfect pops always succeed**, replacing the §5.1
   base band and the pop roll. *Reason: §10 explicitly redefines those two bands.*

## Tickets and shift structure

8. **Patience starts when the ticket is accepted, not when it arrives.** Untaken tickets sit on
   the rail for 60 s and then walk out. *Reason: a 22 s clock that starts while the player is
   mid-gesture on another ticket is unplayable in solo, and the spec only defines "patience
   per ticket" without a start point.*
9. **Shift length = ticket count × spawn interval**, so pier 1 is 8 × 70 s = 9:20 and pier 6 is
   16 × 52 s = 13:52. *Reason: lands inside §4's 10–16 minute band and derives from the pier
   data instead of a second hard-coded number.*
10. **Crowded adds tickets without lengthening the shift** (the spawn interval shrinks) and
    Hungry raises only the quota. *Reason: both Tides read as pressure, not as a longer shift.*
11. **Stars:** quota met → `3 − min(2, walked_out)`, otherwise 0. *Reason: the spec says stars
    gate unlocks and walk-outs cost a star, so one formula covers both statements.*
12. **The modifier table's patience effects** are: No Pearl 0 s, Extra Brine +1 s, Regular −25%,
    To Go −2 s, Still Alive −3 s. *Reason: §7.2 only names the Regular's −25% and Extra Brine's
    +1 s; the others needed a value.*
13. **To Go pays +10%.** *Reason: §7.2 lists no number for it; it costs an extra two-handed step.*
14. **Ticket payout uses the species actually served**, recorded per slot, not the species the
    ticket originally listed. *Reason: a Gigas yields two plates and leftovers can be served to
    the next ticket; the player is paid for the oyster they handed over.*

## Economy and unlocks

15. **Tier gates follow §9.1:** tier 2 at pier 1 for knife and gloves, pier 2 for bench, pier 3
    for automation, pier 4 for shop floor; tier 3 at pier 5; tier 4 at pier 6; tiers 5–6 only
    after the credits (Franchise). *Reason: that is the only table that maps tiers to piers.*
16. **Pier unlocks on a completed quota (≥ 1 star)**, and "Next shift" starts the highest
    unlocked pier. *Reason: the ledger's "Tomorrow: the Harbor" beat requires forward motion.*
17. **Credits** are set when pier 6's quota is met (or its boss is won); the ledger shows a
    credits block and Franchise (tiers 5–6) opens. *Reason: §4 and §9.2 both treat credits as
    the end of the six-pier run, not a separate scene.*
18. **Upgrade purchases are not saved until a shift ends or the ledger's shop closes.**
    *Reason: §20 forbids mid-shift saves; closing the post-shift shop is part of that end-of-shift
    transaction, and without it a bought upgrade would be lost on restart.*
19. **Extra save keys** (`settings`, `bosses`, `pierStars`, `credits`) were added additively,
    keeping `"version": 1`; `SaveGame.migrate` fills them for old saves. *Reason: they carry
    state the §20 schema has no field for, and additive keys do not break v1 readers.*

## Pearls

20. **Pearls are rolled at spawn and stored on the oyster.** The reveal only animates the
    pre-rolled result. *Reason: hard rule in §5.5 and §16.*
21. **Cultured adds +1% pearl chance for the rest of the shift**, applied to oysters spawned
    after the reveal; Lamp Rig adds +8% to the species chance. *Reason: §8.2 says "+1 permanent
    Luck for the rest of the shift" and §10 calls the Lamp the Luck stat.*
22. **Named pearls** use the eight entries in `pearl_config.tres`. Boss shifts award the pier's
    Named Pearl; Cursed Oysters have a 3% chance to cough one up; the Tidewrought trait names
    itself. *Reason: only six boss shifts exist but eight named pearls are required.*
23. **Pearl value** = `40¢ × (size/6)^2.2 × colour multiplier × lustre multiplier`, with
    Mother-of-Pearl fixed at 2,500¢ and The Tidewrought at 5,000¢. *Reason: §8.1 gives the size
    curve and lustre range but no base value or colour table; both live in `pearl_config.tres`.*
24. **Displayed pearls** are capped at 12 (the case size); each adds 2% tips up to +20%, doubled
    by the Aquarium Wall. *Reason: §8.4 and §10's Aquarium entry.*

## Simulation and content scope

25. **Automation is a floor, not a person.** Belt Feed (T2) stocks the bench every 4 s; Otto (T4)
    auto-serves one B-grade portion every 12 s at half pearl odds; Brine Recycler's +15% and the
    T3 auto-grader are not separately simulated. *Reason: the anti-degenerate rule matters more
    than a full idle simulation.*
26. **Only two gadgets have in-shift effects:** Pry Bar (key 1) skips a wedge and Pager (key 2)
    deletes a ticket for free. The rest are purchasable and tracked but inert. *Reason: time
    went to the core verb; this is stated in-game and here rather than faked.*
27. **Status effects implemented:** Nicked (bleeding, −1 grade), Barnacle Rash (−20% slide
    tolerance), Wet Hands (meter 15% faster; set by the rogue-wave event). Cramp, Salt Burn,
    Drowsy and Fainted-by-teammates are not. *Reason: they need splash/sink/sleep systems that
    the current shift does not have.*
28. **Fainting is implemented as a 6 s camera drop with a dropped oyster**, triggered by two
    nicks within 60 s (three with Gloves T6). Ragdoll, dragging and co-op revive are not.
    *Reason: solo failure had to be visible; ragdoll physics is co-op only in practice.*
29. **Throw, the emote radial, voice and the free-form 5 m photo camera are not implemented.**
    Photo mode freezes the shift and hides the UI but keeps the player camera. *Reason: they are
    co-op verbs and polish; a working single-player loop came first.*
30. **Six piers share one procedural room kit** with different palettes, fog, lights, props and
    species. Raft City adds a camera sway and the Lighthouse adds darkness + flashlight; the
    crab/gull/rogue-wave/power-cut hazards are chaos events. *Reason: a full unique level kit per
    pier is weeks of art, and §3 says placeholder art is expected.*
31. **Boss shifts reuse the King Oyster** on piers 3–6 with a three-minute timer and the pier's
    Named Pearl. *Reason: §13 allows "a single enormous oyster" and one boss species covers all
    four boss shifts without four bespoke encounters.*
32. **Devil's Claw requires Gloves tier 4** (spec §6) and the rash penalty is a −20% slide
    tolerance; §14's "gloves tier 5" is read as the cure for the rash. *Reason: §6 is the
    species table and §14 the status table; tier 4 to hold, tier 5 to be immune.*
33. **Dock Blue's 8 px tolerance becomes 20 px at knife T6** (see decision 3). *Reason: keeps the
    knife line meaningful on the tutorial species.*
34. **Tide of Gulls adds four decorative/troublesome gulls**; the gull raid chaos event is the
    functional thief. *Reason: no separate gull AI budget.*
35. **Daily Tide uses the UTC date as its seed** and picks two Tides from that seed; there is no
    leaderboard service in this build, only `tideHighScores` locally. *Reason: no Steam SDK is
    available offline.*
36. **Shift end is early if every ticket is resolved**, otherwise at the timer. *Reason: waiting
    out an empty rail is dead time.*
37. **The ghost hand shows on the first shift only** and can be toggled in the pause menu.
    *Reason: §18's onboarding is per-player, not per-pier.*
38. **The held oyster is shown in the hands viewport** at a fixed, art-directed size; the world
    oyster is hidden while held. *Reason: this is what "hands in a separate view layer" is for
    and it removes clipping entirely.*
39. **Audio is synthesised at runtime** (sine/square/noise buffers in `sfx.gd`). *Reason: the
    no-download rule; 180 Foley one-shots are not achievable procedurally in the time, so there
    are 15 cues.*
40. **Achievements are the 12 badges**, not 32 Steam achievements; badges are data-driven and
    unlock cosmetics. *Reason: the badge list is the only concrete achievement table in the spec.*
41. **Cosmetics: 29 items across 8 slots**, not the 20 hats / 12 aprons / etc. full budget. Only
    the knife skin is visible in first person; hats and aprons are co-op-visible. *Reason: content
    budget, not systems work.*
42. **The shop dog is cosmetic-plus-one-effect:** if owned, it intercepts 50% of gull/crab
    thefts. *Reason: §11 says it chases gulls; a coin flip is enough to feel it.*

## Netcode

43. **M4 is a skeleton, not playable co-op.** Host/join on ENet port 24777, host broadcasts the
    shift seed, clients start the same seeded shift, and static crew avatars appear. Oyster
    transitions have a declared RPC endpoint but no replicated oyster registry, so live verbs,
    transform sync, grade validation and revive are absent. *Reason: a finished single-player
    beat a broken co-op build, as the brief allows; single-player never enters this code path.*

## Performance and platforms

44. **60 fps at 1080p on this Apple M4 is the only target actually measured**; Steam Deck 40 fps
    and a GTX 1060 were not available to test. *Reason: no hardware to verify against.*
45. **Draw calls stay low** by building the pier from a few primitive meshes and one material per
    colour; the hand viewport adds a second small world. *Reason: §20's budget, measured only
    indirectly by the scene's node count.*
