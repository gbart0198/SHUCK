extends SceneTree
## SHUCK Simulator headless smoke test: economy rules + a simulated player for pacing.
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

func _initialize() -> void:
	print("SHUCK Simulator smoke test")
	test_numbers()
	test_catch_shuck_sell()
	test_streak()
	test_upgrades_and_zones()
	test_crew_pipeline()
	test_pets()
	test_reshell()
	test_save()
	test_save_slots()
	test_pacing()
	print("")
	if failures.is_empty():
		print("PASS — %d checks" % checks)
		quit(0)
	else:
		print("FAIL — %d/%d checks failed" % [failures.size(), checks])
		for f in failures:
			print("   * ", f)
		quit(1)

func test_numbers() -> void:
	print("numbers")
	check(Num.short(999.0) == "999", "999 stays 999")
	check(Num.short(1500.0) == "1.50K", "1500 → 1.50K (%s)" % Num.short(1500.0))
	check(Num.short(2.5e9) == "2.50B", "2.5e9 → 2.50B")
	check(Num.cash(12345678.0) == "$12.3M", "cash 12.3M (%s)" % Num.cash(12345678.0))
	check(Catalog.ZONES.size() == 8, "eight zones")
	var prev := -1.0
	var ok := true
	for z in Catalog.ZONES:
		ok = ok and float(z.gate) > prev and float(z.value) > 0.0
		prev = float(z.gate)
	check(ok, "zone gates strictly increase")

func test_catch_shuck_sell() -> void:
	print("catch → shuck → sell")
	var e := Empire.new(42)
	check(e.rank_name() == "Lowly Fisherman", "you start as a Lowly Fisherman")
	var cap := e.bag_capacity()
	for i in cap:
		e.catch_oyster(0)
	check(e.bag_full(), "bucket fills at %d" % cap)
	check(not e.catch_oyster(0), "a full bucket refuses more")
	var opened := 0
	var guard := 0
	while e.has_oysters() and guard < 1000:
		var r := e.shuck_hit(false)
		if r.opened:
			opened += 1
		guard += 1
	check(opened == cap, "every oyster shucks open (%d)" % opened)
	check(e.meat_count == cap, "one meat per normal shuck")
	var earned := e.sell()
	check(is_equal_approx(earned, float(cap) * 2.0), "Dock Blue meat sells for $2 each (%s)" % earned)
	check(e.meat_count == 0 and e.cash == earned, "selling empties meat into cash")
	# perfect shucks give double meat
	var e2 := Empire.new(1)
	e2.catch_oyster(0)
	var r2 := {}
	for i in 10:
		r2 = e2.shuck_hit(true)
		if r2.opened:
			break
	check(r2.opened and e2.meat_count == 2, "PERFECT shuck yields x2 meat")
	check(not e2.shuck_hit(false).ok, "no oysters → no shuck")

## PERFECT streaks crack several oysters at once (never more than you carry); a miss resets it.
func test_streak() -> void:
	print("perfect streak")
	check(Catalog.streak_batch(4) == 1 and Catalog.streak_batch(5) == 2 and Catalog.streak_batch(10) == 4 and Catalog.streak_batch(50) == 8, "tiers: x5 → 2, x10 → 4, x50 → 8")
	check(Catalog.streak_batch(100) == 16 and Catalog.streak_batch(200) == 32 and Catalog.streak_batch(500) == 64 and Catalog.streak_batch(1000) == 128, "tiers: x100 → 16 … x1000 → 128")
	var e := Empire.new(61)
	e.upgrades = {"knife": 60, "bucket": 40}
	for i in 12:
		e.catch_oyster(0)
	var opened := 0
	var r := {}
	for i in 4:
		r = e.shuck_hit(true)
		opened += int(r.count)
	check(e.perfect_streak == 4 and opened == 4, "below x5: one oyster per crack (%d)" % opened)
	r = e.shuck_hit(true)
	check(bool(r.tier_up) and int(r.count) == 2 and e.bag_count() == 6, "5th PERFECT in a row cracks 2 at once (bag %d)" % e.bag_count())
	check(e.meat_count == 4 * 2 + 2 * 2, "each oyster in the stack gives PERFECT meat (%d)" % e.meat_count)
	e.perfect_streak = 10
	r = e.shuck_hit(true)
	check(int(r.count) == 4 and e.bag_count() == 2, "x10 cracks 4")
	e.perfect_streak = 999
	r = e.shuck_hit(true)
	check(int(r.count) == 2 and e.bag_count() == 0 and not e.has_oysters(), "a huge streak never takes more oysters than you carry (%d)" % int(r.count))
	check(not e.shuck_hit(true).ok, "an empty bucket shucks nothing")
	e.catch_oyster(0)
	e.shuck_hit(false)
	check(e.perfect_streak == 0, "a miss resets the streak")

func test_upgrades_and_zones() -> void:
	print("upgrades and zones")
	# tool balance: tools should be a grind that keeps pace with the beaches, not outrun them
	var spent := 0.0
	var lv := 0
	while Catalog.rake_damage(lv) < float(Catalog.zone(2).hp):
		spent += Catalog.upgrade_cost("rake", lv)
		lv += 1
	check(spent > float(Catalog.zone(3).gate), "one-clicking Kelp Forest oysters costs more than the Coral Reef gate (%s, Lv %d)" % [Num.cash(spent), lv])
	check(Catalog.bucket_capacity(30) < 250, "the bucket grows steadily, not exponentially (Lv 30 holds %d)" % Catalog.bucket_capacity(30))
	check(Catalog.rake_damage(40) < float(Catalog.zone(7).hp), "even Rake Lv 40 can't one-shot Golden Atoll oysters (%s)" % Num.short(Catalog.rake_damage(40)))
	var e := Empire.new(3)
	check(not e.buy_upgrade("rake"), "can't buy broke")
	e.cash = 1000.0
	var c := e.upgrade_cost("rake")
	check(e.buy_upgrade("rake") and e.level("rake") == 1 and is_equal_approx(e.cash, 1000.0 - c), "rake Lv1 costs %s" % c)
	check(e.upgrade_cost("rake") > c, "next level costs more")
	check(e.rake_damage() > 1.0, "rake hits harder")
	var b0 := Catalog.bucket_capacity(0)
	e.buy_upgrade("bucket")
	check(e.bag_capacity() > b0, "bucket grows %d → %d" % [b0, e.bag_capacity()])
	check(not e.unlock_zone(2), "zones open in order")
	check(e.unlock_zone(1) and e.zones_unlocked == 2, "Rocky Point opens for %s" % Num.cash(Catalog.zone(1).gate))
	check(e.can_enter(1) and not e.can_enter(2), "gate state")

func test_crew_pipeline() -> void:
	print("crew pipeline")
	var e := Empire.new(5)
	e.cash = 1e6
	e.hire("deckhand")
	e.tick(10.0, false)
	check(is_equal_approx(e.bin_total(), Catalog.crew("deckhand").rate * 10.0), "1 deckhand fills the Dock Bin at its rate (%s)" % e.bin_total())
	e.hire("shucker")
	e.tick(10.0, false)
	check(e.crate_total() > 0.0, "shucker fills the Meat Crate (%s)" % e.crate_total())
	var before := e.cash
	var sold := e.sell()
	check(sold > 0.0 and e.crate_total() == 0.0, "the Sell Pad empties the crate too (%s)" % sold)
	e.hire("coordinator")
	before = e.cash
	e.tick(60.0, false)
	check(e.cash > before, "a coordinator sells automatically")
	check(is_equal_approx(e.crew_mult(), 1.0 + Catalog.COORDINATOR_BOOST), "a Coordinator boosts all crew +%d%%" % int(Catalog.COORDINATOR_BOOST * 100.0))
	check(e.free_slots("coordinator") == 0 and not e.hire("coordinator"), "one Coordinator per beach")
	check(is_equal_approx(Catalog.crew_cost("coordinator", 1), Catalog.crew_cost("coordinator", 0) * 3.5), "each Coordinator costs 3.5x the last")
	var ec := Empire.new(51)
	ec.crew = {"deckhand": 4, "shucker": 4, "coordinator": 1}
	ec.tick(120.0, false)
	check(ec.crate_total() < 1.0, "one Coordinator sells a full beach's meat as fast as it's shucked (%s left)" % ec.crate_total())
	e.cash = 1e10
	check(not e.hire("rakebot"), "robots need the lab")
	check(e.buy_lab() and e.hire("rakebot"), "lab unlocks RakeBots")
	var r := e.catch_rate()
	e.buy_factory()
	check(e.catch_rate() > r * 1.9, "Mega-Factory doubles robots")
	# storage cap
	var e2 := Empire.new(6)
	e2.crew = {"deckhand": 100}
	e2.tick(1000.0, false)
	check(float(e2.bins[0]) <= e2.storage_capacity(), "Dock Bin respects warehouse cap")
	var e3 := Empire.new(7)
	e3.crew = {"deckhand": 10, "shucker": 10, "coordinator": 5}
	var off := e3.offline(3600.0)
	check(off > 0.0, "offline earnings (%s for 1h)" % Num.cash(off))
	# training: a second path that speeds every unit up
	var e4 := Empire.new(8)
	e4.cash = 1e6
	check(not e4.train("deckhand"), "can't train a crew type you haven't hired")
	e4.hire("deckhand")
	var r0 := e4.catch_rate()
	check(e4.train("deckhand") and e4.train_level("deckhand") == 1, "train deckhands")
	check(is_equal_approx(e4.catch_rate(), r0 * Catalog.train_mult(1)), "training +25%% speed (%s → %s)" % [r0, e4.catch_rate()])
	check(e4.train_cost("deckhand") > Catalog.train_cost("deckhand", 0), "training gets pricier")
	# you can feed the Dock Bin yourself
	var e5 := Empire.new(9)
	e5.zones_unlocked = 2
	for i in 5:
		e5.catch_oyster(1)
	check(e5.deposit_bin(0) == 5 and e5.bag_count() == 0 and is_equal_approx(float(e5.bins[0]), 5.0), "dump the bucket into the Dock Bin")
	e5.crew = {"shucker": 3}
	e5.tick(60.0, false)
	check(is_equal_approx(e5.crate_total(), 5.0) and is_equal_approx(Empire._sum(e5.crate_values), 5.0 * float(Catalog.zone(1).value)), "shuckers work your oysters at their zone value (%s)" % Empire._sum(e5.crate_values))
	check(e5.bin_total() == 0.0 and Empire._sum(e5.bin_values) == 0.0, "bin empties cleanly")
	var e6 := Empire.new(10)
	for i in 3:
		e6.catch_oyster(0)
	e6.bins[0] = e6.storage_capacity() - 1.0
	check(e6.deposit_bin() == 1 and e6.bag_count() == 2, "deposit respects the warehouse cap")
	var rt := Empire.from_dict(JSON.parse_string(JSON.stringify(e4.to_dict())))
	check(rt.train_level("deckhand") == 1, "training round-trips through the save")
	# beach slots: crew fill the Muddy Shallows first, then the next beach up; no slots = no hire
	var e7 := Empire.new(13)
	e7.cash = 1e12
	e7.zones_unlocked = 3
	var first := Catalog.crew_slots(0, "deckhand")
	for i in first + 2:
		e7.hire("deckhand")
	var asg: Array = e7.assignment()["deckhand"]
	check(int(asg[0]) == first and int(asg[1]) == 2 and int(asg[2]) == 0, "hires fill the lowest beach first, then the next (%s)" % str(asg.slice(0, 3)))
	var total := e7.total_slots("deckhand")
	while e7.owned("deckhand") < total:
		e7.hire("deckhand")
	check(e7.free_slots("deckhand") == 0 and not e7.hire("deckhand"), "can't hire with every beach slot full (%d)" % total)
	e7.zones_unlocked = 4
	check(int(e7.assignment()["deckhand"][3]) == 0 and e7.hire("deckhand") and int(e7.assignment()["deckhand"][3]) == 1, "a new beach opens slots; the next hire works there")
	var e8 := Empire.new(14)
	e8.zones_unlocked = 2
	e8.crew = {"deckhand": 2, "shucker": 2}
	e8.tick(30.0, false)
	e8.crew = {"deckhand": 6, "shucker": 6}
	e8.tick(30.0, false)
	check(float(e8.crates[1]) > 0.0 and float(e8.crates[0]) > 0.0 and is_equal_approx(Empire._sum(e8.crate_values), float(e8.crates[0]) * float(Catalog.zone(0).value) + float(e8.crates[1]) * float(Catalog.zone(1).value)), "crew work and earn at their own beach's value")
	check(is_equal_approx(e8.unit_rate("shucker"), e8.unit_rate("deckhand")) and is_equal_approx(e8.unit_rate("shuckbot"), e8.unit_rate("rakebot")), "a Shucker keeps pace with a Deckhand (robots too)")
	var e9 := Empire.new(15)
	e9.crew = {"deckhand": 3, "shucker": 3}
	e9.upgrades = {"warehouse": 10}
	e9.tick(600.0, false)
	check(float(e9.bins[0]) < 1.0, "matched crews keep the Dock Bin from piling up (%s left)" % e9.bins[0])
	var old := e4.to_dict()
	old.erase("bins")
	old["dock_bin"] = 7.0
	check(is_equal_approx(float(Empire.from_dict(old).bins[0]), 7.0), "old single-bin saves migrate")

func test_pets() -> void:
	print("pets")
	var e := Empire.new(11)
	check(e.hatch("common") == "", "no pearls → no hatch")
	e.pearls = 500
	var got: Dictionary = {}
	for i in 60:
		var id := e.hatch("common")
		got[id] = true
	check(e.pets.size() == 60, "60 pets hatched")
	check(e.equipped.size() == Catalog.PET_SLOTS, "auto-equips up to %d" % Catalog.PET_SLOTS)
	check(got.size() >= 3, "variety from a clam (%d kinds)" % got.size())
	e.equip_best()
	check(e.pet_mult() > 1.2, "equipped pets multiply cash (x%s)" % e.pet_mult())
	var e2 := Empire.new(12)
	e2.pets = ["hermit", "hermit", "hermit"]
	var f := e2.fuse("hermit")
	check(f != "" and int(Catalog.pet(f).rarity) == 1 and e2.pets.size() == 1, "fuse 3 commons → uncommon (%s)" % f)
	# distribution of the mythic clam
	var e3 := Empire.new(13)
	e3.pearls = 300 * 2000
	var leg := 0
	for i in 2000:
		if int(Catalog.pet(e3.hatch("mythic")).rarity) >= 3:
			leg += 1
	check(leg > 1300, "Abyssal Clam is mostly epic+ (%d/2000)" % leg)

func test_reshell() -> void:
	print("re-shell")
	var e := Empire.new(21)
	e.cash = 5e5
	check(not e.reshell(), "not before the target")
	e._earn(Catalog.reshell_cost(0))
	e.upgrades = {"rake": 10}
	e.crew = {"deckhand": 5}
	e.zones_unlocked = 4
	e.pets = ["seal"]
	e.equipped = [0]
	e.pearls = 9
	check(e.reshell(), "re-shell at %s" % Num.cash(Catalog.reshell_cost(0)))
	check(e.shells == 1 and e.cash == 0.0 and e.level("rake") == 0 and e.owned("deckhand") == 0 and e.zones_unlocked == 1, "run resets")
	check(e.pets.size() == 1 and e.pearls == 9, "pets and pearls kept")
	check(is_equal_approx(e.shell_mult(), 1.5), "Golden Shell = +50% cash")
	check(e.reshell_cost() > Catalog.reshell_cost(0), "next re-shell costs more")
	check(e.rank() > 0, "rank survives (based on all-time earnings)")

func test_save() -> void:
	print("save")
	var e := Empire.new(31)
	e.cash = 12345.5
	e.upgrades = {"knife": 3}
	e.crew = {"shucker": 2}
	e.pets = ["otter", "seal"]
	e.equipped = [1]
	e.bag = {"1": 4}
	e.zones_unlocked = 3
	var d := e.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var r := Empire.from_dict(parsed)
	check(is_equal_approx(r.cash, 12345.5), "cash round-trips")
	check(r.level("knife") == 3 and r.owned("shucker") == 2, "upgrades + crew round-trip")
	check(r.pets == ["otter", "seal"] and r.equipped == [1], "pets round-trip")
	check(r.bag_count() == 4 and r.zones_unlocked == 3, "bucket + zones round-trip")
	var old := Empire.from_dict({"version": 1, "money": 999})
	check(old.cash == 0.0, "old shift-based saves start a fresh empire")

## Save slots in a scratch folder: list order, latest, next free slot, delete, legacy migration.
func test_save_slots() -> void:
	print("save slots")
	var dir := "user://smoke_saves"
	var st := SaveStore.new(dir)
	for s in st.list():
		st.delete(int(s.slot))
	check(st.list().is_empty() and st.latest() == -1 and st.next_free() == 1, "empty save folder")
	var a := Empire.new(41)
	a.cash = 111.0
	var b := Empire.new(42)
	b.cash = 222.0
	b.zones_unlocked = 3
	st.write(1, a, {"name": "Save 1", "last_played": 1000.0, "play_time": 60.0})
	st.write(2, b, {"name": "Save 2", "last_played": 2000.0, "play_time": 7200.0})
	var l := st.list()
	check(l.size() == 2 and int(l[0].slot) == 2 and st.latest() == 2, "most recently played first")
	check(str(l[0].zone) == "Kelp Forest" and is_equal_approx(float(l[0].cash), 222.0), "slot summary (zone, cash)")
	check(st.next_free() == 3, "new game takes the next free slot")
	var back := Empire.from_dict(st.read(1).empire)
	check(is_equal_approx(back.cash, 111.0), "slot round-trips the empire")
	st.delete(1)
	check(st.list().size() == 1 and st.next_free() == 1, "delete frees the slot")
	st.delete(2)
	var legacy := "user://smoke_legacy.json"
	var f := FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string(JSON.stringify(b.to_dict()))
	f.close()
	check(st.migrate_legacy(legacy) == 1 and is_equal_approx(float(st.list()[0].cash), 222.0) and not FileAccess.file_exists(legacy), "the old single save moves into slot 1")
	st.delete(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy + ".bak"))

## A bot that plays the loop: rake → shuck → sell → buy the cheapest useful thing.
## Prints the time each milestone takes so balance changes are visible.
func test_pacing() -> void:
	print("pacing (simulated player, 5 clicks/s)")
	var e := Empire.new(99)
	var t := 0.0
	var marks := {}
	var dt := 1.0
	var clicks_per_s := 5.0
	var phase := "catch"
	var walk := 0.0
	var limit := 6.0 * 3600.0
	while t < limit:
		t += dt
		e.tick(dt)
		if walk > 0.0:
			walk -= dt
		elif phase == "catch":
			var z := e.best_zone()
			var per := ceilf(e.zone_hp(z) / e.rake_damage()) / clicks_per_s + 0.4
			var n := int(dt / per) + (1 if randf() < fmod(dt / per, 1.0) else 0)
			for i in n:
				if not e.catch_oyster(z):
					break
			if e.bag_full():
				phase = "shuck"
				walk = 4.0
		elif phase == "shuck":
			for i in int(clicks_per_s * dt):
				e.shuck_hit(randf() < 0.25)
			if not e.has_oysters():
				phase = "sell"
				walk = 3.0
		elif phase == "sell":
			e.sell()
			phase = "catch"
			walk = 4.0
			_bot_spend(e)
		for k in [["zone2", e.zones_unlocked >= 2], ["deckhand", e.owned("deckhand") > 0], ["zone3", e.zones_unlocked >= 3],
				["coordinator", e.owned("coordinator") > 0], ["zone4", e.zones_unlocked >= 4], ["lab", e.lab],
				["zone5", e.zones_unlocked >= 5], ["reshell_ready", e.can_reshell()], ["zone6", e.zones_unlocked >= 6]]:
			if k[1] and not marks.has(k[0]):
				marks[k[0]] = t
		if e.can_reshell() and not marks.has("reshell_ready"):
			marks["reshell_ready"] = t
	for k in marks.keys():
		print("     %-14s %s" % [k, Num.duration(marks[k])])
	print("     after 6h: %s cash, rank %s, income %s/s" % [Num.cash(e.cash), e.rank_name(), Num.short(e.passive_income())])
	check(marks.has("zone2") and float(marks.zone2) > 360.0 and float(marks.zone2) < 1200.0, "Rocky Point takes a real grind (6-20 min)")
	check(marks.has("deckhand") and float(marks.deckhand) > 360.0 and float(marks.deckhand) < 1200.0, "first crew hire is earned, not instant (6-20 min)")
	check(marks.has("lab") and float(marks.lab) < 2.5 * 3600.0, "robots within 2.5 hours")
	check(marks.has("reshell_ready") and float(marks.reshell_ready) < 4.0 * 3600.0, "first Re-Shell within 4 hours")

func _bot_spend(e: Empire) -> void:
	var guard := 0
	while guard < 200:
		guard += 1
		if e.zones_unlocked < Catalog.ZONES.size() and e.cash >= e.zone_cost(e.zones_unlocked):
			e.unlock_zone(e.zones_unlocked)
			continue
		if not e.lab and e.cash >= Catalog.ROBOTICS_LAB_COST and e.owned("coordinator") > 0:
			e.buy_lab()
			continue
		var options: Array = []
		for id in ["rake", "bucket", "knife", "quality", "warehouse"]:
			if not e.upgrade_maxed(id):
				options.append([e.upgrade_cost(id), "u", id])
		for c in Catalog.CREW:
			if (not c.robot or e.lab) and e.free_slots(c.id) > 0:
				options.append([e.hire_cost(c.id), "c", c.id])
		for c in Catalog.CREW:
			if e.owned(c.id) > 0 and not e.train_maxed(c.id):
				options.append([e.train_cost(c.id), "t", c.id])
		if e.lab:
			options.append([e.factory_cost(), "f", ""])
		options.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		if options.is_empty() or e.cash < float(options[0][0]):
			return
		# keep a little saved for the next gate
		var next_gate := e.zone_cost(e.zones_unlocked) if e.zones_unlocked < Catalog.ZONES.size() else INF
		if float(options[0][0]) > e.cash * 0.6 and next_gate < e.cash * 3.0:
			return
		match str(options[0][1]):
			"u": e.buy_upgrade(str(options[0][2]))
			"c": e.hire(str(options[0][2]))
			"t": e.train(str(options[0][2]))
			"f": e.buy_factory()
