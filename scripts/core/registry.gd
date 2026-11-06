extends RefCounted
class_name Registry
## Static loader so the same data is available to the game and to headless tests.

static var loaded := false
static var balance: BalanceData
static var grade_data: GradeData
static var pearl_config: PearlConfig
static var pearl_traits: PearlTraitTable
static var species: Dictionary = {}
static var upgrades: Array[UpgradeData] = []
static var piers: Dictionary = {}
static var tides: Array[TideData] = []
static var chaos: Array[ChaosData] = []
static var modifiers: Array[TicketModifierData] = []
static var badges: Array[BadgeData] = []
static var cosmetics: Array[CosmeticData] = []
static var gadgets: Array[GadgetData] = []
static var steps: Dictionary = {}

static func ensure_loaded() -> bool:
	if loaded:
		return true
	balance = _res("res://data/balance.tres")
	grade_data = _res("res://data/grades.tres")
	pearl_config = _res("res://data/pearl_config.tres")
	pearl_traits = _res("res://data/pearl_traits.tres")
	if balance == null or grade_data == null or pearl_config == null or pearl_traits == null:
		push_error("SHUCK data missing: run tools/gen_data.gd")
		return false
	species.clear()
	for d in _typed("res://data/species", SpeciesData):
		species[d.id] = d
	upgrades.clear()
	for d in _typed("res://data/upgrades", UpgradeData):
		upgrades.append(d)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		if a.line == b.line:
			return a.tier < b.tier
		return a.line < b.line)
	piers.clear()
	for d in _typed("res://data/piers", PierData):
		piers[d.id] = d
	tides.clear()
	for d in _typed("res://data/tides", TideData):
		tides.append(d)
	chaos.clear()
	for d in _typed("res://data/chaos", ChaosData):
		chaos.append(d)
	modifiers.clear()
	for d in _typed("res://data/tickets", TicketModifierData):
		modifiers.append(d)
	badges.clear()
	for d in _typed("res://data/badges", BadgeData):
		badges.append(d)
	cosmetics.clear()
	for d in _typed("res://data/cosmetics", CosmeticData):
		cosmetics.append(d)
	gadgets.clear()
	for d in _typed("res://data/gadgets", GadgetData):
		gadgets.append(d)
	steps.clear()
	for d in _typed("res://data/steps", InteractionStep):
		steps[d.id] = d
	loaded = true
	return true

static func _res(path: String) -> Variant:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func _typed(dir_path: String, klass: Variant) -> Array:
	var out := []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".tres") and not f.ends_with(".res"):
			continue
		var r: Resource = load(dir_path.path_join(f))
		if r != null and is_instance_of(r, klass):
			out.append(r)
	return out

static func get_species(id: String) -> SpeciesData:
	ensure_loaded()
	return species.get(id, null)

static func get_pier(id: int) -> PierData:
	ensure_loaded()
	return piers.get(id, null)

static func get_tide(id: String) -> TideData:
	ensure_loaded()
	for t in tides:
		if t.id == id:
			return t
	return null

static func get_modifier(id: String) -> TicketModifierData:
	ensure_loaded()
	for m in modifiers:
		if m.id == id:
			return m
	return null

static func get_cosmetic(id: String) -> CosmeticData:
	ensure_loaded()
	for c in cosmetics:
		if c.id == id:
			return c
	return null

static func get_gadget(id: String) -> GadgetData:
	ensure_loaded()
	for g in gadgets:
		if g.id == id:
			return g
	return null

static func upgrade(line: String, tier: int) -> UpgradeData:
	ensure_loaded()
	for u in upgrades:
		if u.line == line and u.tier == tier:
			return u
	return null

static func line_tiers(line: String) -> Array[UpgradeData]:
	ensure_loaded()
	var out: Array[UpgradeData] = []
	for u in upgrades:
		if u.line == line:
			out.append(u)
	return out

static func species_for_pier(pier: int) -> Array[SpeciesData]:
	ensure_loaded()
	var out: Array[SpeciesData] = []
	for s in species.values():
		if s.pier <= pier and not s.is_boss:
			out.append(s)
	return out
