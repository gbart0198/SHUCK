extends SceneTree
## SHUCK headless smoke test.
## Run: Godot --headless --path . --script tests/smoke.gd

var failures: Array[String] = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures.append(msg)
		print("  FAIL ", msg)

func near(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol

func _initialize() -> void:
	print("SHUCK smoke test")
	Registry.ensure_loaded()
	var bal := Registry.balance
	var gd := Registry.grade_data

	test_data()
	test_state_machine()
	test_grades()
	test_tickets()
	test_upgrades()
	test_pearls()
	test_save()

	print("")
	if failures.is_empty():
		print("PASS — %d checks" % checks)
		quit(0)
	else:
		print("FAIL — %d/%d checks failed" % [failures.size(), checks])
		for f in failures:
			print("   * ", f)
		quit(1)

# ---------------------------------------------------------------- data
func test_data() -> void:
	print("[data]")
	var bal := Registry.balance
	var gd := Registry.grade_data
	check(Registry.species.size() == 8, "8 species loaded")
	check(Registry.upgrades.size() == 30, "30 upgrade tiers loaded (5 lines x 6)")
	check(Registry.piers.size() == 6, "6 piers loaded")
	check(Registry.tides.size() == 8, "8 Tides loaded")
	check(Registry.modifiers.size() == 5, "5 ticket modifiers loaded")
	check(Registry.badges.size() == 12, "12 badges loaded")
	check(near(Registry.pearl_traits.total_weight(), 99.9), "pearl trait weights total 99.9 (as printed in §8.2)")
	check(Registry.steps.size() == 4, "4 interaction steps loaded")
	check(Registry.steps["wedge"].params.get("next", "") == "pop", "wedge chains to pop")
	check(Registry.steps["pop"].params.get("next", "") == "slide", "pop chains to slide")
	check(Registry.steps["slide"].params.get("next", "") == "reseat", "slide chains to reseat")

	var db := Registry.get_species("dock_blue")
	check(db != null and db.value_cents == 8 and near(db.pearl_chance, 0.04) and near(db.slide_tolerance, 8.0),
		"Dock Blue: 8c, 4% pearl, 8px tolerance")
	var kum := Registry.get_species("kumamoto")
	check(near(kum.meter_window_scale, 0.75), "Kumamoto meter window -25%")
	var gig := Registry.get_species("pacific_gigas")
	check(gig.meat_yield == 2 and near(gig.gesture_time_add, 0.3), "Gigas: 2 meat, +0.3s per gesture")
	var razor := Registry.get_species("razor_clam")
	check(near(razor.slide_tolerance, 14.0) and near(razor.max_slide_speed_scale, 0.7), "Razor: 14px, breaks above 70% speed")
	var moon := Registry.get_species("moon_snail")
	check(near(moon.drill_seconds, 4.0), "Moon Snail drill is 4s")
	var devil := Registry.get_species("devils_claw")
	check(devil.requires_gloves_tier == 4, "Devil's Claw needs Gloves T4")
	var cursed := Registry.get_species("cursed_oyster")
	check(near(cursed.escape_seconds, 8.0), "Cursed Oyster escapes after 8s")

	var scales := []
	for i in range(1, 7):
		scales.append(Registry.get_pier(i).price_scale)
	check(scales == [1.0, 1.3, 1.7, 2.2, 2.8, 3.5], "pier price scales 1.0/1.3/1.7/2.2/2.8/3.5")
	var quotas := []
	for i in range(1, 7):
		quotas.append(Registry.get_pier(i).quota)
	check(quotas == [120, 300, 600, 1000, 1600, 2600], "pier quotas match §9.1")

	check(near(GradeLogic.price_mult("S", gd), 1.6), "S pays x1.6")
	check(near(GradeLogic.tip_pct("S", gd), 0.30), "S tip 30%")
	check(near(GradeLogic.price_mult("A", gd), 1.25), "A pays x1.25")
	check(near(GradeLogic.price_mult("C", gd), 0.55), "C pays x0.55")
	check(near(GradeLogic.price_mult("F", gd), 0.0), "F pays x0")

	var neap := Registry.get_tide("neap")
	check(near(neap.payout_mult, 0.9) and near(neap.patience_mult, 1.2), "Neap: +20% patience, x0.9")
	var spring := Registry.get_tide("spring")
	check(near(spring.patience_mult, 0.8) and near(spring.payout_mult, 1.2), "Spring: -20% patience, x1.2")
	check(near(Registry.get_tide("slippery").tolerance_mult, 0.7), "Slippery: tolerance -30%")
	check(Registry.get_tide("gulls").gull_extra == 4, "Gulls: 4 extra gulls")
	check(Registry.get_tide("low_water").gadget_slots == 1, "Low Water: 1 gadget slot")
	check(near(bal.wedge_duration, 0.6) and near(bal.pop_duration, 0.5), "wedge 0.6s, pop 0.5s")
	check(near(bal.patience_base, 22.0) and near(bal.patience_per_extra_oyster, 3.0), "patience 22s, -3s per extra oyster")

# ---------------------------------------------------------------- oyster FSM
func fresh(species_id := "dock_blue", seed_value := 7) -> OysterSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var o := OysterSim.new(Registry.get_species(species_id), Registry.balance, Registry.grade_data, rng)
	return o

func wedge(o: OysterSim, seconds: float) -> void:
	o.wedge_begin()
	o.wedge_tick(seconds)
	o.wedge_release()

func pop(o: OysterSim, at_seconds: float) -> void:
	o.pop_begin()
	if at_seconds > 0.0:
		o.pop_tick(at_seconds)
	o.pop_click()

func test_state_machine() -> void:
	print("[oyster state machine]")
	var o := fresh()
	check(o.state == OysterSim.State.SPAWNED and o.stage == OysterSim.Stage.WEDGE, "spawns SPAWNED/WEDGE")

	# < 0.40 does nothing, gesture restarts
	o.wedge_begin()
	o.wedge_tick(0.20)
	o.wedge_release()
	check(o.state == OysterSim.State.SPAWNED and o.wedge_result == OysterSim.Wedge.NONE, "wedge <0.40 restarts, still SPAWNED")

	# clean wedge -> SEATED
	o.wedge_begin()
	o.wedge_tick(0.40)
	o.wedge_release()
	check(o.state == OysterSim.State.SEATED, "clean wedge -> SEATED")
	check(o.wedge_result == OysterSim.Wedge.CLEAN, "wedge 0.55-0.75 is CLEAN")
	check(o.steady, "clean wedge grants Steady")

	# perfect pop -> OPEN
	pop(o, 0.36)
	check(o.pop_result == OysterSim.Pop.PERFECT, "ring in inner 30% is PERFECT")
	check(o.state == OysterSim.State.OPEN and o.stage == OysterSim.Stage.SLIDE, "pop -> OPEN/SLIDE")

	# slide + reseat -> PLATED
	o.slide_begin()
	var tol := o.tolerance_px(1)
	for i in 12:
		o.slide_sample(0.0, 800.0, 0.016, tol)
	o.slide_finish()
	check(o.surgical, "inside tolerance at speed grants Surgical")
	o.reseat(true)
	check(o.state == OysterSim.State.PLATED, "reseat over plate -> PLATED")
	check(o.grade == "S", "clean wedge + perfect pop + surgical + no damage = S")
	check(o.serve(), "PLATED can be served")
	check(o.state == OysterSim.State.SERVED, "serve -> SERVED")
	check(not o.serve(), "SERVED cannot be served twice")

	# fight-back path
	var f := fresh()
	wedge(f, 0.40)
	f.pop_begin()
	for i in 40:
		f.pop_tick(0.016)
	check(f.state == OysterSim.State.SPAWNED and f.pop_result == OysterSim.Pop.FIGHTBACK, "no click -> fight back, back to SPAWNED")
	check(f.fightbacks == 1 and f.stage == OysterSim.Stage.WEDGE, "fight back requires re-wedge (1.2s wasted)")
	check(near(f.time_penalty, 1.2), "fight back costs 1.2s")
	wedge(f, 0.40)
	pop(f, 0.20)
	check(f.state == OysterSim.State.OPEN, "can complete after fight back")

	# cracked
	var c := fresh()
	wedge(c, 0.40)
	c.pop_begin()
	c.pop_click() # instant click: ring still 1.0, outside dot
	check(c.pop_result == OysterSim.Pop.CRACKED and c.cracked, "early click -> CRACKED")
	check(c.state == OysterSim.State.OPEN, "cracked still opens")
	c.slide_begin()
	for i in 12:
		c.slide_sample(0.0, 800.0, 0.016, c.tolerance_px(1))
	c.slide_finish()
	c.reseat(true)
	check(c.grade == "C", "crack caps grade at C")

	# juice loss / stab
	var s := fresh()
	wedge(s, 0.40)
	pop(s, 0.20)
	s.slide_begin()
	for i in 40:
		s.slide_sample(30.0, 400.0, 0.1, s.tolerance_px(1))
	check(s.stabbed and s.juice_loss, "cumulative off-line > 40px stabs the meat")
	s.slide_finish()
	s.reseat(true)
	check(s.grade == "C", "stab caps grade at C")

	# shattered
	var sh := fresh()
	wedge(sh, 0.40)
	pop(sh, 0.20)
	sh.slide_begin()
	sh.slide_sample(90.0, 200.0, 0.016, sh.tolerance_px(1))
	check(sh.state == OysterSim.State.BINNED and sh.grade == "F" and sh.shattered, "off the shell shatters -> F/BINNED")

	# dropped
	var d := fresh()
	wedge(d, 0.40)
	pop(d, 0.20)
	d.slide_begin()
	d.slide_sample(0.0, 800.0, 0.016, d.tolerance_px(1))
	d.slide_finish()
	d.reseat(false)
	check(d.grade == "F" and d.state == OysterSim.State.BINNED, "dropped -> Ruined F")
	check(not d.serve(), "BINNED cannot be served")

	# abandoned
	var a := fresh()
	wedge(a, 0.40)
	a.abandon()
	check(a.grade == "F" and a.state == OysterSim.State.BINNED, "abandoned -> F")

	# SPAWNED cannot be served / plated directly
	var bad := fresh()
	check(not bad.serve(), "SPAWNED cannot serve (transition guarded)")
	bad.reseat(true)
	check(bad.state == OysterSim.State.SPAWNED, "SPAWNED cannot plate (transition guarded)")

	# slip
	var sl := fresh()
	sl.wedge_begin()
	sl.wedge_tick(0.70)
	sl.wedge_release()
	check(sl.wedge_result == OysterSim.Wedge.SLIP, "meter >1.00 slips")
	check(sl.state == OysterSim.State.SPAWNED, "slip does not seat the oyster")

	# wedge bands
	var snag := fresh()
	wedge(snag, 0.30) # 0.5
	check(snag.wedge_result == OysterSim.Wedge.SNAG and near(snag.time_penalty, 0.15), "0.40-0.55 snags, +0.15s")
	var wob := fresh()
	wedge(wob, 0.48) # 0.8
	check(wob.wedge_result == OysterSim.Wedge.WOBBLE and wob.wobble, "0.75-1.00 wobbles")

	# Steady widens tolerance by 8%
	var t1 := fresh()
	var base_tol := t1.tolerance_px(1)
	wedge(t1, 0.40)
	var steady_tol := t1.tolerance_px(1)
	check(near(steady_tol, base_tol * 1.08), "Steady gives +8% slide tolerance")
	# knife tiers 6 -> 18
	check(near(t1.tolerance_px(6), (8.0 + 12.0) * 1.08), "knife T6 raises Dock Blue 8px to 20px, steady 21.6")
	# Kumamoto narrows the clean band
	var k := fresh("kumamoto")
	k.wedge_begin()
	k.wedge_tick(0.40) # 0.667, outside 0.575-0.725? no, inside
	k.wedge_release()
	check(k.wedge_result == OysterSim.Wedge.CLEAN, "Kumamoto still accepts 0.667")
	var k2 := fresh("kumamoto")
	k2.wedge_begin()
	k2.wedge_tick(0.34) # 0.567 < 0.575 -> snag
	k2.wedge_release()
	check(k2.wedge_result == OysterSim.Wedge.SNAG, "Kumamoto -25% window snags at 0.567")

# ---------------------------------------------------------------- grades
func test_grades() -> void:
	print("[grades]")
	var o := fresh()
	wedge(o, 0.40)
	pop(o, 0.20) # normal pop, clean wedge, no surgical
	o.slide_begin()
	o.slide_sample(0.0, 200.0, 0.016, o.tolerance_px(1))
	o.slide_finish()
	o.reseat(true)
	check(o.grade == "B", "clean wedge + normal pop, slow slide = B")

	var a := fresh()
	wedge(a, 0.40)
	pop(a, 0.36)
	a.slide_begin()
	a.slide_sample(0.0, 200.0, 0.016, a.tolerance_px(1))
	a.slide_finish()
	a.reseat(true)
	check(a.grade == "A", "clean pop floors at A without surgical")

	var f := fresh()
	f.abandon()
	check(f.compute_grade() == "F", "F bucket for ruined oyster")

	# knife T4 adds +1 score (SPEC §10 line A)
	var t4 := fresh()
	t4.knife_tier_bonus = Registry.balance.knife_t4_score_bonus
	wedge(t4, 0.40)
	pop(t4, 0.20)
	t4.slide_begin()
	t4.slide_sample(0.0, 200.0, 0.016, t4.tolerance_px(1))
	t4.slide_finish()
	t4.reseat(true)
	check(t4.grade_score == 21, "Oyster Fork adds +1 grade score (20 -> 21)")

# ---------------------------------------------------------------- tickets
func test_tickets() -> void:
	print("[tickets]")
	var gd := Registry.grade_data
	var pier := Registry.get_pier(1)
	var sp := Registry.species
	var t := TicketSim.new()
	t.species_ids = PackedStringArray(["dock_blue"])
	t.portions_total = 1
	t.grades = PackedStringArray(["B"])
	t.accepted = true
	var p := t.payout(sp, pier, gd, 0.0)
	check(p.base == 8 and p.tip == 0 and p.total == 8, "1x Dock Blue B: 8c base, 0c tip, 8c total")

	t.grades = PackedStringArray(["S"])
	p = t.payout(sp, pier, gd, 0.0)
	check(p.base == 13 and p.tip == 2 and p.total == 15, "S: 12.8 -> 13 base, 2.4 -> 2 tip")

	p = t.payout(sp, pier, gd, 0.10)
	check(p.tip == 3, "tip bonus +10%: 2.4*1.1=2.64 -> 3")

	var t2 := TicketSim.new()
	t2.species_ids = PackedStringArray(["dock_blue", "dock_blue"])
	t2.portions_total = 2
	t2.grades = PackedStringArray(["S", "B"])
	var pier2 := Registry.get_pier(2) # scale 1.3
	p = t2.payout(sp, pier2, gd, 0.0)
	check(p.base == 27, "pier 2 scale 1.3: S+B = 27 base")
	check(p.tip == 4, "pier 2 S+B tip = 4")

	var t3 := TicketSim.new()
	t3.species_ids = PackedStringArray(["dock_blue"])
	t3.portions_total = 1
	t3.grades = PackedStringArray(["S"])
	t3.modifier = Registry.get_modifier("no_pearl")
	p = t3.payout(sp, pier, gd, 0.0)
	check(p.base == 18, "no-pearl modifier +40% pay: 12.8 -> 17.9 -> 18")

	t3.modifier = Registry.get_modifier("regulars")
	p = t3.payout(sp, pier, gd, 0.0)
	check(p.tip == 4, "regular's order: tip +50% (2.4*1.5=3.6 -> 4)")

	t3.walked_out = true
	p = t3.payout(sp, pier, gd, 0.0)
	check(p.total == 0 and p.walked_out, "walked out pays nothing")

	var pt := TicketSim.new()
	pt.species_ids = PackedStringArray(["dock_blue", "dock_blue", "dock_blue", "dock_blue"])
	pt.modifier = Registry.get_modifier("regulars")
	var pat := pt.calc_patience(Registry.balance, 1.0, 0.0)
	check(near(pat, 9.8), "patience: (22-9)*0.75 = 9.8s")
	pt.patience_left = 0.0
	pt.accepted = true
	pt.tick(0.01)
	check(pt.walked_out, "patience expiry walks out")

	# rail timeout before the ticket is taken
	var rail := TicketSim.new()
	rail.patience_left = 5.0
	rail.rail_left = 0.05
	rail.tick(0.06)
	check(rail.walked_out, "untaken ticket walks out after rail timeout")

	# serving all portions completes
	var done := TicketSim.new()
	done.portions_total = 2
	done.species_ids = PackedStringArray(["dock_blue", "dock_blue"])
	done.serve("B", 1)
	check(not done.completed, "1 of 2 portions is not complete")
	done.serve("A", 1)
	check(done.completed and done.grades.size() == 2, "all portions served completes ticket")

# ---------------------------------------------------------------- upgrades
func test_upgrades() -> void:
	print("[upgrades]")
	var state := {"money": 0, "upgrades": {"knife": 1, "gloves": 1, "bench": 1, "auto": 1, "floor": 1}, "pier": 1, "franchise": false}
	var r := Economy.buy(state, "knife")
	check(not r.ok and r.reason == "money", "knife T2 needs 120c")
	state.money = 120
	r = Economy.buy(state, "knife")
	check(r.ok and r.cost == 120, "buy knife T2 for 120c")
	check(state.money == 0 and state.upgrades.knife == 2, "money 120 -> 0, tier 1 -> 2")
	r = Economy.buy(state, "knife")
	check(not r.ok and r.reason == "locked", "knife T3 locked at pier 1")
	state.money = 100000
	state.pier = 5
	r = Economy.buy(state, "knife")
	check(r.ok and r.cost == 400 and state.upgrades.knife == 3, "knife T3 unlocked and costs 400 at pier 5")
	# T4/T5 at pier 6
	state.upgrades.knife = 3
	state.pier = 6
	r = Economy.buy(state, "knife")
	check(r.ok and r.cost == 1100, "knife T4 at pier 6")
	r = Economy.buy(state, "knife")
	check(not r.ok and r.reason == "locked", "knife T5 is franchise-only")
	state.franchise = true
	r = Economy.buy(state, "knife")
	check(r.ok and r.cost == 2600, "knife T5 in franchise")
	r = Economy.buy(state, "knife")
	check(r.ok and r.cost == 5500, "knife T6 in franchise")
	r = Economy.buy(state, "knife")
	check(not r.ok and r.reason == "maxed", "knife line maxed at T6")

	var expected := {"knife": 120 + 400 + 1100 + 2600 + 5500,
		"gloves": 120 + 400 + 1100 + 2600 + 5500,
		"bench": 120 + 400 + 1100 + 2600 + 5500,
		"auto": 900 + 2200 + 4500 + 7000 + 12000,
		"floor": 150 + 500 + 1300 + 3000 + 6500}
	for line in expected.keys():
		var sum := 0
		for u in Registry.line_tiers(line):
			sum += u.cost
		check(sum == expected[line], "%s ladder sums to %dc" % [line, expected[line]])
	check(Economy.total_ladder_cost() == 67210, "full ladder costs 67,210c (see DECISIONS.md)")

# ---------------------------------------------------------------- pearls
func test_pearls() -> void:
	print("[pearls]")
	var bal := Registry.balance
	var cfg := Registry.pearl_config
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# spawn-time roll: pearls exist before the shell opens and never change on open
	var o := fresh()
	var rolled := PearlRoller.roll(rng, 1.0, 1)
	o.setup_pearls(rolled)
	var before := o.value_pearls()
	var before_count := o.pearls.size()
	check(before_count >= 1, "pearls are rolled before any gesture")
	wedge(o, 0.40)
	pop(o, 0.36)
	o.slide_begin()
	o.slide_sample(0.0, 800.0, 0.016, o.tolerance_px(1))
	o.slide_finish()
	o.reseat(true)
	check(o.pearls.size() == before_count and o.value_pearls() == before, "opening does not reroll or change pearls")
	check(o.has_pearl(), "pearl present on open")

	# value curve: value = base * (size/6)^2.2
	var p1 := Pearl.new()
	p1.size = 6.0
	p1.lustre = 1
	p1.trait_id = "common"
	p1.colour = 0
	var p2 := Pearl.new()
	p2.size = 12.0
	p2.lustre = 1
	p2.trait_id = "common"
	p2.colour = 0
	var v1 := PearlRoller.value_of(p1, cfg)
	var v2 := PearlRoller.value_of(p2, cfg)
	check(near(float(v2) / float(v1), pow(2.0, 2.2), 0.05), "size curve (size/6)^2.2")
	var pf := Pearl.new()
	pf.size = 6.0
	pf.lustre = 1
	pf.colour = 0
	pf.trait_id = "flawed"
	check(near(float(PearlRoller.value_of(pf, cfg)) / float(v1), 0.4, 0.02), "Flawed value x0.4")
	var pm := Pearl.new()
	pm.trait_id = "mother_of_pearl"
	check(PearlRoller.value_of(pm, cfg) == 2500, "Mother-of-Pearl worth 2,500c")

	# trait distribution over 100k samples, 5 sigma bounds
	var counts := {}
	for id in Registry.pearl_traits.ids:
		counts[id] = 0
	var n := 100000
	for i in n:
		counts[PearlRoller.roll_trait(rng)] += 1
	var weights := Registry.pearl_traits.weights
	for i in weights.size():
		var id: String = Registry.pearl_traits.ids[i]
		var p := weights[i] / 100.0
		var expected := n * p
		var sigma := sqrt(n * p * (1.0 - p))
		var got: int = counts[id]
		check(absf(float(got) - expected) <= 5.0 * maxf(sigma, 1.0),
			"trait %s: %d / %d (%.2f%%)" % [id, got, n, 100.0 * got / n])
	check(counts["common"] + counts["lustrous"] + counts["flawed"] + counts["twin"]
		+ counts["cultured"] + counts["mother_of_pearl"] + counts["tidewrought"] == n,
		"every pearl rolls exactly one trait")

	# pearl chance over 100k spawns at 4%
	var found := 0
	for i in 100000:
		if not PearlRoller.roll(rng, 0.04, 1).is_empty():
			found += 1
	var exp_found := 4000.0
	var sigma_found := sqrt(100000 * 0.04 * 0.96)
	check(absf(found - exp_found) <= 5.0 * sigma_found, "Dock Blue 4%% pearl chance: %d / 100000" % found)

	# Log entry / save shape
	check(cfg.shapes.size() == 6 and cfg.colours.size() == 8, "6 shapes x 8 colours = 48 log entries")

# ---------------------------------------------------------------- save
func test_save() -> void:
	print("[save]")
	var path := "user://smoke_save.json"
	var s := SaveGame.default_state()
	s.money = 1234
	s.upgrades.knife = 3
	s.pearls.append({"shape": 2, "colour": 5, "lustre": 4, "size": 9.1, "trait": "lustrous", "pier": 3})
	s.log["2-5"] = {"bestLustre": 4, "bestSize": 9.1, "count": 1}
	s.stats.oysters = 77
	s.shifts = 4
	check(SaveGame.save_to(path, s) == OK, "write user://save.json")
	var r := SaveGame.load_from(path)
	check(r.ok, "read save")
	check(r.data.money == 1234 and r.data.upgrades.knife == 3, "money and upgrades round-trip")
	check(r.data.pearls.size() == 1 and r.data.pearls[0].trait == "lustrous", "pearl round-trip")
	check(r.data.log["2-5"].count == 1 and near(float(r.data.log["2-5"].bestSize), 9.1), "pearl log round-trip")
	check(int(r.data.version) == SaveGame.CURRENT_VERSION, "version is %d" % SaveGame.CURRENT_VERSION)

	var newer := s.duplicate(true)
	newer.version = SaveGame.CURRENT_VERSION + 1
	var bad := SaveGame.from_json(JSON.stringify(newer))
	check(not bad.ok and bad.error == "newer_version", "newer save refused, not silently loaded")
	var nover := s.duplicate(true)
	nover.erase("version")
	bad = SaveGame.from_json(JSON.stringify(nover))
	check(not bad.ok and bad.error == "no_version", "save without version refused")
	bad = SaveGame.from_json("not json at all")
	check(not bad.ok and bad.error == "not_json", "corrupt save refused")

	var old := {"version": 1, "money": 55}
	var mig := SaveGame.from_json(JSON.stringify(old))
	check(mig.ok and mig.data.money == 55, "old v1 save migrates")
	check(mig.data.upgrades.has("floor") and mig.data.stats.has("faints"), "migrated save fills missing defaults")

	# the real save path is used by the game
	check(SaveGame.DEFAULT_PATH == "user://save.json", "save path is user://save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
