extends RefCounted
class_name PearlRoller
## Spawn-time pearl rolls. Clients never roll in co-op (SPEC §16).

static func roll(rng: RandomNumberGenerator, chance: float, pier: int) -> Array[Pearl]:
	var out: Array[Pearl] = []
	if rng.randf() >= chance:
		return out
	var p := _one(rng, pier)
	out.append(p)
	if p.trait_id == "twin":
		var twin := _one(rng, pier, p.shape, p.colour, p.lustre, p.size, p.trait_id)
		out.append(twin)
	# keep order stable so the twin is the same shape/colour as the first
	return out

static func _one(rng: RandomNumberGenerator, pier: int, shape := -1, colour := -1, lustre := -1, size := -1.0, trait_id := "") -> Pearl:
	var cfg := Registry.pearl_config
	var table := Registry.pearl_traits
	var p := Pearl.new()
	p.pier = pier
	p.shape = rng.randi_range(0, cfg.shapes.size() - 1) if shape < 0 else shape
	p.colour = rng.randi_range(0, cfg.colours.size() - 1) if colour < 0 else colour
	p.lustre = rng.randi_range(1, 5) if lustre < 0 else lustre
	p.size = rng.randf_range(cfg.size_min, cfg.size_max) if size < 0.0 else size
	if trait_id == "":
		trait_id = roll_trait(rng)
	p.trait_id = trait_id
	if trait_id == "lustrous":
		p.lustre = 5
	p.value = value_of(p, cfg)
	return p

static func roll_trait(rng: RandomNumberGenerator) -> String:
	var table := Registry.pearl_traits
	var total := 0.0
	for w in table.weights:
		total += w
	var r := rng.randf() * total
	var acc := 0.0
	for i in table.weights.size():
		acc += table.weights[i]
		if r < acc:
			return table.ids[i]
	return table.ids[table.ids.size() - 1]

static func value_of(p: Pearl, cfg: PearlConfig) -> int:
	if p.trait_id == "mother_of_pearl":
		return cfg.mother_of_pearl_value
	if p.trait_id == "tidewrought":
		return cfg.tidewrought_value
	var colour_mult := 1.0
	if p.colour < cfg.colour_mults.size():
		colour_mult = cfg.colour_mults[p.colour]
	var lustre_mult := 1.0
	if p.lustre >= 1 and p.lustre <= cfg.lustre_mults.size():
		lustre_mult = cfg.lustre_mults[p.lustre - 1]
	var v := cfg.base_value * pow(p.size / 6.0, cfg.size_curve) * colour_mult * lustre_mult
	if p.trait_id == "flawed":
		v *= cfg.flawed_mult
	return roundi(v)

static func trait_index(trait_id: String) -> int:
	var table := Registry.pearl_traits
	return table.ids.find(trait_id)
