extends RefCounted
class_name Empire
## The whole simulator economy as one plain object. No nodes, no rendering:
## the game, the HUD and the headless tests all drive this.
##
## Pipeline:
##   you:   rake beds → bucket (oysters) → shuck bench → meat → sell pad → cash
##   crew:  deckhands/RakeBots → Dock Bin → shuckers/ShuckBots → Meat Crate → coordinators/Sell Drones → cash
## Selling on the pad also empties the Meat Crate, so early crew still pays before you hire a coordinator.

const SAVE_VERSION := 2

var rng := RandomNumberGenerator.new()

var cash := 0.0
var lifetime := 0.0          # earned since the last Re-Shell (gates the Re-Shell)
var total_earned := 0.0      # all-time, drives your rank title
var pearls := 0
var pearl_frac := 0.0        # crew-found pearl fractions
var shells := 0              # Golden Shells from Re-Shells

var upgrades: Dictionary = {}
var zones_unlocked := 1
var crew: Dictionary = {}
var training: Dictionary = {}  # crew id -> training / firmware level (speed)
var lab := false
var factory := 0

var bag: Dictionary = {}     # zone index (String) -> oyster count
var meat_count := 0
var meat_value := 0.0        # base value of carried meat (multipliers apply on sell)
var shuck_hp := 0.0          # remaining hp of the oyster on the bench (0 = none started)
var shuck_zone := -1
var perfect_streak := 0       # consecutive PERFECT stabs (session only, not saved)

## Each beach has its own crew outpost: a Dock Bin and a Meat Crate (arrays indexed by zone).
var bins: Array = []
var bin_values: Array = []   # base value of the oysters in each bin (you can drop better ones in)
var crates: Array = []
var crate_values: Array = []

var pets: Array = []         # owned pet ids, duplicates allowed
var equipped: Array = []     # indices into pets

var event_id := ""
var event_left := 0.0
var event_timer := Catalog.EVENT_INTERVAL * 0.6

var stats: Dictionary = {"caught": 0, "shucked": 0, "perfect": 0, "pearls": 0, "sold": 0, "clams": 0, "reshells": 0}
var last_seen := 0.0

func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_reset_outposts()

func _reset_outposts() -> void:
	for a in [bins, bin_values, crates, crate_values]:
		a.resize(Catalog.ZONES.size())
		a.fill(0.0)

func bin_total() -> float:
	return _sum(bins)

func crate_total() -> float:
	return _sum(crates)

static func _sum(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s

# ================================================================ queries
func level(id: String) -> int:
	return int(upgrades.get(id, 0))

func owned(id: String) -> int:
	return int(crew.get(id, 0))

func best_zone() -> int:
	return zones_unlocked - 1

func bag_count() -> int:
	var n := 0
	for k in bag.keys():
		n += int(bag[k])
	return n

func bag_capacity() -> int:
	return Catalog.bucket_capacity(level("bucket"))

func bag_full() -> bool:
	return bag_count() >= bag_capacity()

func storage_capacity() -> float:
	return Catalog.storage_capacity(level("warehouse"))

func rake_damage() -> float:
	return Catalog.rake_damage(level("rake"))

func knife_damage() -> float:
	return Catalog.knife_damage(level("knife"))

func walk_speed() -> float:
	return Catalog.walk_speed(level("speed"))

func magnet_radius() -> float:
	return Catalog.magnet_radius(level("magnet"))

func pearl_chance() -> float:
	var c := Catalog.pearl_chance(level("luck"))
	if event_id == "pearl_storm":
		c *= 5.0
	return minf(c, 0.9)

func pet_mult() -> float:
	var bonus := 0.0
	for i in equipped:
		if int(i) >= 0 and int(i) < pets.size():
			bonus += float(Catalog.pet(str(pets[int(i)])).get("mult", 1.0)) - 1.0
	return 1.0 + bonus

func shell_mult() -> float:
	return 1.0 + float(shells) * Catalog.RESHELL_BONUS

## Everything that multiplies cash on a sale.
func cash_mult() -> float:
	var m := Catalog.quality_mult(level("quality")) * shell_mult() * pet_mult()
	if event_id == "golden_tide":
		m *= 2.0
	return m

func crew_mult() -> float:
	var m := 1.0 + float(owned("coordinator")) * Catalog.COORDINATOR_BOOST
	if event_id == "crew_coffee":
		m *= 3.0
	return m

func robot_mult() -> float:
	return pow(2.0, float(factory))

## How many of each crew type are working each beach. Fills the Muddy Shallows first, up to its
## slots, then the next beach up the coast, and so on. (Anything left over, e.g. from an old save,
## crowds onto the best unlocked beach.) Returns id -> Array[int] indexed by zone.
func assignment() -> Dictionary:
	var out := {}
	for c in Catalog.CREW:
		var id := str(c.id)
		var per: Array = []
		per.resize(Catalog.ZONES.size())
		per.fill(0)
		var left := owned(id)
		var z := 0
		while z < zones_unlocked and left > 0:
			var n := mini(left, slots(z, id))
			per[z] = n
			left -= n
			z += 1
		var top := best_zone()
		per[top] = int(per[top]) + left
		out[id] = per
	return out

func zone_crew(zone_i: int, id: String) -> int:
	return int(assignment()[id][zone_i])

func slots(zone_i: int, id: String) -> int:
	return Catalog.crew_slots(zone_i, id)

## Beach slots for this crew type across every unlocked beach.
func total_slots(id: String) -> int:
	var n := 0
	for z in zones_unlocked:
		n += slots(z, id)
	return n

func free_slots(id: String) -> int:
	return maxi(0, total_slots(id) - owned(id))

func role_rate(role: String, zone_i := -1, asg: Dictionary = {}) -> float:
	if asg.is_empty():
		asg = assignment()
	var r := 0.0
	for c in Catalog.CREW:
		if c.role != role:
			continue
		var n := owned(c.id) if zone_i < 0 else int(asg[c.id][zone_i])
		if n <= 0:
			continue
		r += unit_rate(str(c.id)) * float(n)
	return r * crew_mult()

func train_level(id: String) -> int:
	return int(training.get(id, 0))

func train_mult(id: String) -> float:
	return Catalog.train_mult(train_level(id))

## One unit of this crew type, before the coordinator / coffee boost.
func unit_rate(id: String) -> float:
	var c := Catalog.crew(id)
	if c.is_empty():
		return 0.0
	return float(c.rate) * (robot_mult() if bool(c.robot) else 1.0) * train_mult(id)

func catch_rate() -> float:
	return role_rate("catch")

func shuck_rate() -> float:
	return role_rate("shuck")

func sell_rate() -> float:
	return role_rate("sell")

## Rough cash per second of the automated pipeline (bottleneck × value × multipliers).
func passive_income() -> float:
	var asg := assignment()
	var total := 0.0
	for z in zones_unlocked:
		var flow := minf(role_rate("catch", z, asg), minf(role_rate("shuck", z, asg), role_rate("sell", z, asg)))
		total += flow * float(Catalog.zone(z).value)
	return total * cash_mult()

func rank() -> int:
	return Catalog.rank_index(total_earned)

func rank_name() -> String:
	return str(Catalog.RANKS[rank()].name)

func zone_hp(zone_i: int) -> float:
	return float(Catalog.zone(zone_i).hp)

func shuck_hp_max(zone_i: int) -> float:
	return float(Catalog.zone(zone_i).hp) * 1.5

func reshell_cost() -> float:
	return Catalog.reshell_cost(shells)

func can_reshell() -> bool:
	return lifetime >= reshell_cost()

func zone_cost(i: int) -> float:
	return float(Catalog.zone(i).gate)

func can_enter(i: int) -> bool:
	return i < zones_unlocked

# ================================================================ your hands
## A raked oyster lands in the bucket. Returns false when the bucket is full.
func catch_oyster(zone_i: int) -> bool:
	if bag_full():
		return false
	var k := str(zone_i)
	bag[k] = int(bag.get(k, 0)) + 1
	stats["caught"] = int(stats.get("caught", 0)) + 1
	return true

func has_oysters() -> bool:
	return bag_count() > 0

func _top_zone_in_bag() -> int:
	var best := -1
	for k in bag.keys():
		if int(bag[k]) > 0:
			best = maxi(best, int(k))
	return best

## One stab at the bench. perfect = the timing ring was in the gold band.
## Consecutive PERFECT stabs build a streak (a miss resets it). The bigger the streak, the more
## oysters open at once when the one on the bench cracks (Catalog.streak_batch: x5 → 2, x10 → 4 ...),
## capped by how many of that oyster you actually carry.
## Returns {ok, opened, zone, hp, hp_max, value, pearl, perfect, streak, batch, count, tier_up}.
func shuck_hit(perfect := false) -> Dictionary:
	var out := {"ok": false, "opened": false, "zone": -1, "hp": 0.0, "hp_max": 1.0, "value": 0.0, "pearl": false, "perfect": perfect,
		"streak": perfect_streak, "batch": streak_batch(), "count": 0, "tier_up": false}
	if shuck_zone < 0:
		var z := _top_zone_in_bag()
		if z < 0:
			return out
		shuck_zone = z
		shuck_hp = shuck_hp_max(z)
	var before := streak_batch()
	perfect_streak = perfect_streak + 1 if perfect else 0
	stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), perfect_streak)
	out.streak = perfect_streak
	out.batch = streak_batch()
	out.tier_up = streak_batch() > before
	out.ok = true
	out.zone = shuck_zone
	out.hp_max = shuck_hp_max(shuck_zone)
	shuck_hp -= knife_damage() * (3.0 if perfect else 1.0)
	if perfect:
		stats["perfect"] = int(stats.get("perfect", 0)) + 1
	if shuck_hp > 0.0:
		out.hp = shuck_hp
		return out
	# opened: the whole stack cracks together
	var k := str(shuck_zone)
	var n := clampi(streak_batch(), 1, maxi(1, int(bag.get(k, 0))))
	bag[k] = maxi(0, int(bag.get(k, 0)) - n)
	if int(bag[k]) == 0:
		bag.erase(k)
	var meat_units := (2 if perfect else 1) * n
	var v := float(Catalog.zone(shuck_zone).value) * float(meat_units)
	meat_count += meat_units
	meat_value += v
	stats["shucked"] = int(stats.get("shucked", 0)) + n
	# pearl rolls: one per oyster, but at most 8 per stack so huge streaks don't flood the pet shop
	var chance := pearl_chance() * (2.0 if perfect else 1.0)
	var found := 0
	for i in mini(n, 8):
		if rng.randf() < chance:
			found += 1 + (shuck_zone / 2)
	if found > 0:
		pearls += found
		stats["pearls"] = int(stats.get("pearls", 0)) + found
		out.pearl = true
		out["pearls_found"] = found
	out.opened = true
	out.count = n
	out.value = v * cash_mult()
	shuck_zone = -1
	shuck_hp = 0.0
	return out

## How many oysters crack at once at the current PERFECT streak.
func streak_batch() -> int:
	return Catalog.streak_batch(perfect_streak)

func shuck_progress() -> float:
	if shuck_zone < 0:
		return 0.0
	return 1.0 - clampf(shuck_hp / shuck_hp_max(shuck_zone), 0.0, 1.0)

## Sell pad: carried meat + everything in every beach's Meat Crate.
func sell() -> float:
	var base := meat_value + _sum(crate_values)
	if base <= 0.0:
		return 0.0
	var earned := base * cash_mult()
	stats["sold"] = int(stats.get("sold", 0)) + meat_count + int(crate_total())
	meat_value = 0.0
	meat_count = 0
	crates.fill(0.0)
	crate_values.fill(0.0)
	_earn(earned)
	return earned

## Dump your bucket into a beach's Dock Bin so the shuckers there work it. Fills up to the
## warehouse cap, best oysters first. Returns how many oysters went in.
func deposit_bin(zone_i := 0) -> int:
	zone_i = clampi(zone_i, 0, Catalog.ZONES.size() - 1)
	var room := int(floor(storage_capacity() - float(bins[zone_i])))
	var moved := 0
	while room > 0:
		var z := _top_zone_in_bag()
		if z < 0:
			break
		var k := str(z)
		var n := mini(room, int(bag[k]))
		bag[k] = int(bag[k]) - n
		if int(bag[k]) <= 0:
			bag.erase(k)
		bins[zone_i] = float(bins[zone_i]) + float(n)
		bin_values[zone_i] = float(bin_values[zone_i]) + float(n) * float(Catalog.zone(z).value)
		room -= n
		moved += n
	if moved > 0:
		stats["deposited"] = int(stats.get("deposited", 0)) + moved
	return moved

func _earn(v: float) -> void:
	cash += v
	lifetime += v
	total_earned += v

# ================================================================ spending
func upgrade_cost(id: String) -> float:
	return Catalog.upgrade_cost(id, level(id))

func upgrade_maxed(id: String) -> bool:
	return level(id) >= int(Catalog.upgrade(id).get("max", 0))

func buy_upgrade(id: String) -> bool:
	if Catalog.upgrade(id).is_empty() or upgrade_maxed(id):
		return false
	var c := upgrade_cost(id)
	if cash < c:
		return false
	cash -= c
	upgrades[id] = level(id) + 1
	return true

func train_cost(id: String) -> float:
	return Catalog.train_cost(id, train_level(id))

func train_maxed(id: String) -> bool:
	return train_level(id) >= Catalog.TRAIN_MAX

## Training needs at least one of that crew (robots: the lab too).
func can_train(id: String) -> bool:
	if Catalog.crew(id).is_empty() or owned(id) <= 0 or train_maxed(id):
		return false
	return cash >= train_cost(id)

func train(id: String) -> bool:
	if not can_train(id):
		return false
	cash -= train_cost(id)
	training[id] = train_level(id) + 1
	return true

func hire_cost(id: String) -> float:
	return Catalog.crew_cost(id, owned(id))

func can_hire(id: String) -> bool:
	var c := Catalog.crew(id)
	if c.is_empty():
		return false
	if bool(c.robot) and not lab:
		return false
	if free_slots(id) <= 0:
		return false
	return cash >= hire_cost(id)

func hire(id: String) -> bool:
	if not can_hire(id):
		return false
	cash -= hire_cost(id)
	crew[id] = owned(id) + 1
	return true

func buy_lab() -> bool:
	if lab or cash < Catalog.ROBOTICS_LAB_COST:
		return false
	cash -= Catalog.ROBOTICS_LAB_COST
	lab = true
	return true

func factory_cost() -> float:
	return Catalog.factory_cost(factory)

func buy_factory() -> bool:
	if not lab or cash < factory_cost():
		return false
	cash -= factory_cost()
	factory += 1
	return true

func unlock_zone(i: int) -> bool:
	if i != zones_unlocked or i >= Catalog.ZONES.size():
		return false
	var c := zone_cost(i)
	if cash < c:
		return false
	cash -= c
	zones_unlocked += 1
	return true

## Re-Shell: trade the whole operation for a Golden Shell (+50% cash forever).
func reshell() -> bool:
	if not can_reshell():
		return false
	shells += 1
	stats["reshells"] = int(stats.get("reshells", 0)) + 1
	cash = 0.0
	lifetime = 0.0
	upgrades = {}
	zones_unlocked = 1
	crew = {}
	training = {}
	lab = false
	factory = 0
	bag = {}
	meat_count = 0
	meat_value = 0.0
	shuck_hp = 0.0
	shuck_zone = -1
	_reset_outposts()
	return true

# ================================================================ pets
func hatch(clam_id: String) -> String:
	var c := Catalog.clam(clam_id)
	if c.is_empty() or pearls < int(c.cost):
		return ""
	pearls -= int(c.cost)
	var weights: Array = c.weights
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := rng.randf() * total
	var pick := 0
	for i in weights.size():
		roll -= float(weights[i])
		if roll <= 0.0 and float(weights[i]) > 0.0:
			pick = i
			break
	var id := str(Catalog.PETS[pick].id)
	pets.append(id)
	stats["clams"] = int(stats.get("clams", 0)) + 1
	if equipped.size() < Catalog.PET_SLOTS:
		equipped.append(pets.size() - 1)
	return id

func toggle_equip(i: int) -> bool:
	if i < 0 or i >= pets.size():
		return false
	if equipped.has(i):
		equipped.erase(i)
		return true
	if equipped.size() >= Catalog.PET_SLOTS:
		return false
	equipped.append(i)
	return true

func equip_best() -> void:
	var idx: Array = []
	for i in pets.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		return float(Catalog.pet(str(pets[a])).mult) > float(Catalog.pet(str(pets[b])).mult))
	equipped = idx.slice(0, Catalog.PET_SLOTS)

## Fuse three of the same pet into the next-rarity pet up (if one exists). Returns new id or "".
func fuse(id: String) -> String:
	var found: Array = []
	for i in pets.size():
		if str(pets[i]) == id:
			found.append(i)
	if found.size() < 3:
		return ""
	var p := Catalog.pet(id)
	var target := ""
	for q in Catalog.PETS:
		if int(q.rarity) == int(p.rarity) + 1:
			target = str(q.id)
			break
	if target == "":
		return ""
	found = found.slice(0, 3)
	found.sort()
	found.reverse()
	for i in found:
		pets.remove_at(int(i))
	equipped = []
	pets.append(target)
	equip_best()
	return target

# ================================================================ time
## Advance the crew pipeline and the event clock. Returns {sold, event_started, event_ended}.
func tick(dt: float, run_events := true) -> Dictionary:
	var out := {"sold": 0.0, "event_started": "", "event_ended": ""}
	var cap := storage_capacity()
	var asg := assignment()
	for z in zones_unlocked:
		var value := float(Catalog.zone(z).value)
		# catch
		var c := role_rate("catch", z, asg) * dt
		if c > 0.0:
			var added := minf(c, maxf(0.0, cap - float(bins[z])))
			bins[z] = float(bins[z]) + added
			bin_values[z] = float(bin_values[z]) + added * value
		# shuck
		var s := minf(role_rate("shuck", z, asg) * dt, float(bins[z]))
		s = minf(s, maxf(0.0, cap - float(crates[z])))
		if s > 0.0:
			var moved_value := float(bin_values[z]) * (s / float(bins[z]))
			bins[z] = float(bins[z]) - s
			bin_values[z] = float(bin_values[z]) - moved_value
			if float(bins[z]) < 1e-6:
				bins[z] = 0.0
				bin_values[z] = 0.0
			crates[z] = float(crates[z]) + s
			crate_values[z] = float(crate_values[z]) + moved_value
			pearl_frac += s * 0.002 * (5.0 if event_id == "pearl_storm" else 1.0)
			if pearl_frac >= 1.0:
				var whole := int(floor(pearl_frac))
				pearls += whole
				pearl_frac -= float(whole)
				stats["pearls"] = int(stats.get("pearls", 0)) + whole
		# sell
		var sl := minf(role_rate("sell", z, asg) * dt, float(crates[z]))
		if sl > 0.0 and float(crates[z]) > 0.0:
			var base := float(crate_values[z]) * (sl / float(crates[z]))
			crates[z] = float(crates[z]) - sl
			crate_values[z] = float(crate_values[z]) - base
			var earned := base * cash_mult()
			_earn(earned)
			out.sold = float(out.sold) + earned
	# events
	if run_events:
		if event_left > 0.0:
			event_left -= dt
			if event_left <= 0.0:
				out.event_ended = event_id
				event_id = ""
				event_left = 0.0
		else:
			event_timer -= dt
			if event_timer <= 0.0:
				var e: Dictionary = Catalog.EVENTS[rng.randi() % Catalog.EVENTS.size()]
				start_event(str(e.id))
				out.event_started = event_id
	return out

func start_event(id: String) -> void:
	for e in Catalog.EVENTS:
		if e.id == id:
			event_id = id
			event_left = float(e.seconds)
			event_timer = Catalog.EVENT_INTERVAL * rng.randf_range(0.8, 1.3)
			return

## Crew keeps working while the game is closed, at half speed, for up to 8 hours.
func offline(seconds: float) -> float:
	seconds = clampf(seconds, 0.0, 8.0 * 3600.0) * 0.5
	var before := cash
	var step := 5.0
	var t := 0.0
	while t < seconds:
		var d := minf(step, seconds - t)
		tick(d, false)
		t += d
	return cash - before

# ================================================================ guidance
## The "next goal" line on the HUD: always one concrete thing to do.
func next_goal() -> String:
	if int(stats.get("caught", 0)) == 0:
		return "Click the oysters on the beach to rake them up!"
	if int(stats.get("shucked", 0)) == 0:
		return "Walk to the SHUCK BENCH and stab oysters open (click!)"
	if int(stats.get("sold", 0)) == 0:
		return "Step on the green SELL PAD to sell your meat"
	if level("rake") == 0 and level("bucket") == 0:
		return "Open SHOP and buy Rake Power or a Bigger Bucket"
	if zones_unlocked < 2:
		return "Save %s to open the gate to Rocky Point" % Num.cash(zone_cost(1))
	if owned("deckhand") == 0:
		return "Open CREW and hire your first Deckhand"
	if owned("shucker") == 0:
		return "Hire a Shucker so the Dock Bin gets shucked"
	if int(stats.get("deposited", 0)) == 0 and bin_total() < 1.0:
		return "Click the DOCK BIN at HQ to dump your bucket in for your Shuckers"
	if owned("coordinator") == 0:
		return "Hire a Coordinator to sell crate meat for you"
	if training.is_empty():
		return "TRAIN a crew type in CREW: +25% work speed per level"
	if free_slots("deckhand") == 0 and free_slots("shucker") == 0 and zones_unlocked < Catalog.ZONES.size() and cash < zone_cost(zones_unlocked):
		return "Every beach is fully crewed. Open %s (%s) for more crew slots, or TRAIN the crew you have" % [Catalog.zone(zones_unlocked).name, Num.cash(zone_cost(zones_unlocked))]
	if not lab and cash < Catalog.ROBOTICS_LAB_COST:
		return "Grow the crew. Robotics Lab costs %s" % Num.cash(Catalog.ROBOTICS_LAB_COST)
	if not lab:
		return "Build the Robotics Lab in the CREW menu!"
	if owned("rakebot") == 0:
		return "Build your first RakeBot"
	if shells == 0 and not can_reshell():
		return "Earn %s this run to Re-Shell for a Golden Shell" % Num.cash(reshell_cost())
	if can_reshell():
		return "You can RE-SHELL! +50% cash forever"
	if zones_unlocked < Catalog.ZONES.size():
		return "Next gate: %s for %s" % [Catalog.zone(zones_unlocked).name, Num.cash(zone_cost(zones_unlocked))]
	return "You own the whole coast. Become Poseidon's Accountant."

# ================================================================ save
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"cash": cash, "lifetime": lifetime, "total_earned": total_earned,
		"pearls": pearls, "pearl_frac": pearl_frac, "shells": shells,
		"upgrades": upgrades.duplicate(), "zones_unlocked": zones_unlocked,
		"crew": crew.duplicate(), "training": training.duplicate(), "lab": lab, "factory": factory,
		"bag": bag.duplicate(), "meat_count": meat_count, "meat_value": meat_value,
		"bins": bins.duplicate(), "bin_values": bin_values.duplicate(), "crates": crates.duplicate(), "crate_values": crate_values.duplicate(),
		"pets": pets.duplicate(), "equipped": equipped.duplicate(),
		"stats": stats.duplicate(), "last_seen": last_seen,
	}

static func from_dict(d: Dictionary) -> Empire:
	var e := Empire.new()
	if int(d.get("version", 0)) != SAVE_VERSION:
		return e
	e.cash = float(d.get("cash", 0.0))
	e.lifetime = float(d.get("lifetime", 0.0))
	e.total_earned = float(d.get("total_earned", 0.0))
	e.pearls = int(d.get("pearls", 0))
	e.pearl_frac = float(d.get("pearl_frac", 0.0))
	e.shells = int(d.get("shells", 0))
	e.upgrades = _int_dict(d.get("upgrades", {}))
	e.zones_unlocked = clampi(int(d.get("zones_unlocked", 1)), 1, Catalog.ZONES.size())
	e.crew = _int_dict(d.get("crew", {}))
	e.training = _int_dict(d.get("training", {}))
	e.lab = bool(d.get("lab", false))
	e.factory = int(d.get("factory", 0))
	e.bag = _int_dict(d.get("bag", {}))
	e.meat_count = int(d.get("meat_count", 0))
	e.meat_value = float(d.get("meat_value", 0.0))
	_load_arr(e.bins, d.get("bins", []))
	_load_arr(e.bin_values, d.get("bin_values", []))
	_load_arr(e.crates, d.get("crates", []))
	_load_arr(e.crate_values, d.get("crate_values", []))
	# older saves had one shared bin + crate
	if d.has("dock_bin"):
		e.bins[0] = float(d.get("dock_bin", 0.0))
		e.bin_values[0] = float(d.get("bin_value", e.bins[0] * float(Catalog.zone(0).value)))
		e.crates[0] = float(d.get("crate", 0.0))
		e.crate_values[0] = float(d.get("crate_value", 0.0))
	e.pets = Array(d.get("pets", [])).map(func(x: Variant) -> String: return str(x))
	e.equipped = Array(d.get("equipped", [])).map(func(x: Variant) -> int: return int(x))
	var st: Dictionary = d.get("stats", {})
	for k in st.keys():
		e.stats[k] = int(st[k])
	e.last_seen = float(d.get("last_seen", 0.0))
	return e

static func _load_arr(into: Array, v: Variant) -> void:
	if typeof(v) != TYPE_ARRAY:
		return
	for i in mini(into.size(), (v as Array).size()):
		into[i] = float(v[i])

static func _int_dict(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			out[str(k)] = int(v[k])
	return out
