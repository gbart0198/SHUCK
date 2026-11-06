extends RefCounted
class_name TicketSim
## One ticket: composition, patience, payout (SPEC §7.2).

var id := 0
var species_ids: PackedStringArray = PackedStringArray()
var modifier: TicketModifierData
var patience_max := 22.0
var patience_left := 22.0
var rail_left := 60.0
var accepted := false
var walked_out := false
var completed := false
var grades: PackedStringArray = PackedStringArray()
var served_portions := 0
var portions_total := 0
var spawn_index := 0
var served_species: PackedStringArray = PackedStringArray()
var regular := false
var spawn_time := 0.0

static func create(p_id: int, pier: PierData, all_species: Dictionary, rng: RandomNumberGenerator, bal: BalanceData, tide_patience := 1.0, floor_patience := 0.0, force_species := "") -> TicketSim:
	var t := TicketSim.new()
	t.id = p_id
	var pool: Array[String] = []
	if force_species != "":
		pool.append(force_species)
	else:
		for sid in pier.species:
			if all_species.has(sid):
				pool.append(sid)
	if pool.is_empty():
		for sid in all_species.keys():
			pool.append(str(sid))
	var count := rng.randi_range(1, bal.ticket_max_oysters)
	var first: String = pool[rng.randi_range(0, pool.size() - 1)]
	var use_two := pool.size() > 1 and rng.randf() < 0.4
	var second := first
	if use_two:
		second = pool[rng.randi_range(0, pool.size() - 1)]
		if second == first:
			second = pool[(pool.find(first) + 1) % pool.size()]
	for i in count:
		t.species_ids.append(second if use_two and i % 2 == 1 else first)
	t.portions_total = count
	if rng.randf() < bal.modifier_chance and not Registry.modifiers.is_empty():
		t.modifier = Registry.modifiers[rng.randi_range(0, Registry.modifiers.size() - 1)]
	t.patience_max = t.calc_patience(bal, tide_patience, floor_patience)
	t.patience_left = t.patience_max
	t.rail_left = bal.rail_timeout
	t.regular = t.modifier != null and t.modifier.id == "regulars"
	return t

func calc_patience(bal: BalanceData, tide_patience := 1.0, floor_patience := 0.0) -> float:
	var p := bal.patience_base - bal.patience_per_extra_oyster * maxi(0, species_ids.size() - 1)
	if modifier != null:
		p += modifier.patience_delta
		p *= modifier.patience_mult
	p *= tide_patience
	p *= (1.0 + floor_patience)
	return maxf(8.0, snappedf(p, 0.1))

func accept() -> void:
	accepted = true

## Patience only runs once the ticket is taken off the rail.
func tick(dt: float) -> void:
	if completed or walked_out:
		return
	if not accepted:
		rail_left -= dt
		if rail_left <= 0.0:
			walked_out = true
		return
	patience_left -= dt
	if patience_left <= 0.0:
		patience_left = 0.0
		walked_out = true

func serve(grade_id: String, portions := 1, species_id := "") -> void:
	if walked_out:
		return
	for i in portions:
		grades.append(grade_id)
		served_species.append(species_id)
	served_portions += portions
	if served_portions >= portions_total:
		completed = true

func species_value(species_map: Dictionary, pier: PierData) -> float:
	var total := 0.0
	for sid in species_ids:
		var s: SpeciesData = species_map.get(sid, null)
		if s != null:
			total += float(s.value_cents) * pier.price_scale
	return total

## Gross and tip. Tip bonuses are additive fractions (neon, pearls, rank).
func payout(species_map: Dictionary, pier: PierData, gdata: GradeData, tip_bonus := 0.0) -> Dictionary:
	if walked_out:
		return {"base": 0, "tip": 0, "total": 0, "walked_out": true}
	var base := 0.0
	var tip := 0.0
	for i in grades.size():
		var sid := species_ids[mini(i, species_ids.size() - 1)] if species_ids.size() > 0 else ""
		if i < served_species.size() and served_species[i] != "":
			sid = served_species[i]
		var s: SpeciesData = species_map.get(sid, null)
		var v := float(s.value_cents) * pier.price_scale if s != null else 0.0
		var g := grades[i]
		base += v * GradeLogic.price_mult(g, gdata)
		tip += v * GradeLogic.tip_pct(g, gdata)
	var pay_mult := 1.0
	var tip_mult := 1.0
	if modifier != null:
		pay_mult += modifier.pay_bonus
		tip_mult += modifier.tip_bonus
	base *= pay_mult
	tip *= tip_mult * (1.0 + tip_bonus)
	var base_i := roundi(base)
	var tip_i := roundi(tip)
	return {"base": base_i, "tip": tip_i, "total": base_i + tip_i, "walked_out": false}

func display_species() -> String:
	var counts := {}
	for s in species_ids:
		counts[s] = counts.get(s, 0) + 1
	var parts: Array[String] = []
	for k in counts.keys():
		parts.append("%s x%d" % [str(k), counts[k]])
	return ", ".join(parts)
