extends RefCounted
class_name Catalog
## Every number in the simulator lives here: zones, upgrades, crew, robots, pets, ranks.
## Pure data + formulas so headless tests and the game read the same tables.

# ------------------------------------------------------------------ zones
## Each zone is a stretch of coast. Unlocking one opens its gate for good (until a Re-Shell).
## Palettes follow the original pier look: dusky, foggy, low saturation, warm lamps.
const ZONES: Array[Dictionary] = [
	{"id": "shallows", "name": "Muddy Shallows", "oyster": "Dock Blue", "value": 2.0, "hp": 4, "gate": 0.0,
		"sand": Color(0.50, 0.42, 0.32), "water": Color(0.07, 0.18, 0.24), "shell": Color(0.55, 0.6, 0.63), "meat": Color(0.93, 0.88, 0.76), "accent": Color(0.86, 0.47, 0.24),
		"sky_top": Color(0.1, 0.16, 0.26), "sky_bottom": Color(0.72, 0.46, 0.3), "fog": Color(0.4, 0.36, 0.34), "light": Color(1, 0.78, 0.55), "light_energy": 1.5, "ambient": 0.55, "wood": Color(0.36, 0.25, 0.16)},
	{"id": "rocky", "name": "Rocky Point", "oyster": "Kumamoto", "value": 8.0, "hp": 8, "gate": 250.0,
		"sand": Color(0.38, 0.38, 0.36), "water": Color(0.1, 0.2, 0.24), "shell": Color(0.5, 0.46, 0.42), "meat": Color(0.95, 0.86, 0.74), "accent": Color(0.35, 0.55, 0.62),
		"sky_top": Color(0.14, 0.2, 0.27), "sky_bottom": Color(0.55, 0.55, 0.52), "fog": Color(0.42, 0.45, 0.46), "light": Color(0.95, 0.92, 0.82), "light_energy": 1.1, "ambient": 0.6, "wood": Color(0.3, 0.29, 0.27)},
	{"id": "kelp", "name": "Kelp Forest", "oyster": "Pacific Gigas", "value": 30.0, "hp": 14, "gate": 3000.0,
		"sand": Color(0.32, 0.36, 0.27), "water": Color(0.05, 0.18, 0.15), "shell": Color(0.42, 0.48, 0.38), "meat": Color(0.9, 0.9, 0.72), "accent": Color(0.55, 0.75, 0.4),
		"sky_top": Color(0.08, 0.15, 0.14), "sky_bottom": Color(0.42, 0.5, 0.38), "fog": Color(0.3, 0.38, 0.32), "light": Color(0.9, 0.95, 0.75), "light_energy": 1.0, "ambient": 0.55, "wood": Color(0.28, 0.26, 0.2)},
	{"id": "reef", "name": "Coral Reef", "oyster": "Rainbow Oyster", "value": 110.0, "hp": 24, "gate": 75000.0,
		"sand": Color(0.46, 0.38, 0.40), "water": Color(0.1, 0.14, 0.24), "shell": Color(0.7, 0.42, 0.5), "meat": Color(0.98, 0.8, 0.82), "accent": Color(0.9, 0.35, 0.6),
		"sky_top": Color(0.16, 0.1, 0.22), "sky_bottom": Color(0.45, 0.32, 0.48), "fog": Color(0.3, 0.26, 0.36), "light": Color(0.85, 0.65, 0.95), "light_energy": 0.9, "ambient": 0.5, "wood": Color(0.3, 0.22, 0.2)},
	{"id": "lagoon", "name": "Neon Lagoon", "oyster": "Neon Oyster", "value": 420.0, "hp": 40, "gate": 2000000.0,
		"sand": Color(0.2, 0.28, 0.28), "water": Color(0.02, 0.22, 0.26), "shell": Color(0.25, 0.7, 0.62), "meat": Color(0.8, 0.95, 0.9), "accent": Color(0.3, 0.9, 0.8),
		"sky_top": Color(0.02, 0.18, 0.24), "sky_bottom": Color(0.05, 0.35, 0.38), "fog": Color(0.06, 0.3, 0.34), "light": Color(0.4, 0.9, 0.9), "light_energy": 0.8, "ambient": 0.7, "wood": Color(0.22, 0.26, 0.24)},
	{"id": "volcano", "name": "Volcano Vent", "oyster": "Devil's Claw", "value": 1600.0, "hp": 65, "gate": 60000000.0,
		"sand": Color(0.18, 0.13, 0.12), "water": Color(0.08, 0.02, 0.04), "shell": Color(0.32, 0.16, 0.13), "meat": Color(1.0, 0.6, 0.4), "accent": Color(1, 0.35, 0.3),
		"sky_top": Color(0.1, 0.03, 0.06), "sky_bottom": Color(0.3, 0.08, 0.1), "fog": Color(0.18, 0.06, 0.08), "light": Color(1, 0.55, 0.45), "light_energy": 1.0, "ambient": 0.4, "wood": Color(0.26, 0.14, 0.12)},
	{"id": "trench", "name": "Abyssal Trench", "oyster": "Cursed Oyster", "value": 6500.0, "hp": 105, "gate": 2000000000.0,
		"sand": Color(0.1, 0.11, 0.13), "water": Color(0.02, 0.04, 0.06), "shell": Color(0.18, 0.16, 0.22), "meat": Color(0.6, 0.9, 0.6), "accent": Color(1, 0.9, 0.5),
		"sky_top": Color(0.02, 0.03, 0.05), "sky_bottom": Color(0.06, 0.07, 0.1), "fog": Color(0.04, 0.05, 0.07), "light": Color(0.9, 0.85, 0.7), "light_energy": 0.55, "ambient": 0.25, "wood": Color(0.2, 0.16, 0.14)},
	{"id": "atoll", "name": "Golden Atoll", "oyster": "King Oyster", "value": 28000.0, "hp": 170, "gate": 80000000000.0,
		"sand": Color(0.58, 0.48, 0.32), "water": Color(0.12, 0.2, 0.26), "shell": Color(0.75, 0.6, 0.3), "meat": Color(1.0, 0.94, 0.75), "accent": Color(1.0, 0.8, 0.35),
		"sky_top": Color(0.2, 0.18, 0.28), "sky_bottom": Color(0.95, 0.68, 0.36), "fog": Color(0.6, 0.48, 0.34), "light": Color(1, 0.85, 0.6), "light_energy": 1.4, "ambient": 0.6, "wood": Color(0.42, 0.3, 0.18)},
]

const ZONE_WIDTH := 44.0

# ------------------------------------------------------------------ player upgrades
## cost(level) = base * growth^level, level starts at 0.
const UPGRADES: Array[Dictionary] = [
	{"id": "rake", "name": "Rake Power", "desc": "Harder hits on oyster beds", "base": 25, "growth": 1.75, "max": 80, "icon": "⛏"},
	{"id": "bucket", "name": "Bigger Bucket", "desc": "Carry more oysters", "base": 25, "growth": 1.6, "max": 80, "icon": "🪣"},
	{"id": "knife", "name": "Sharper Knife", "desc": "Shuck in fewer stabs", "base": 25, "growth": 1.75, "max": 80, "icon": "🔪"},
	{"id": "quality", "name": "Meat Quality", "desc": "+15% sell price per level", "base": 500, "growth": 2, "max": 100, "icon": "⭐"},
	{"id": "speed", "name": "Sneakers", "desc": "Run faster", "base": 120, "growth": 2.4, "max": 12, "icon": "👟"},
	{"id": "luck", "name": "Pearl Luck", "desc": "More pearls when shucking", "base": 1000, "growth": 2.4, "max": 25, "icon": "🍀"},
	{"id": "magnet", "name": "Tide Magnet", "desc": "Auto-rakes oysters near you", "base": 5000, "growth": 3, "max": 10, "icon": "🧲"},
	{"id": "warehouse", "name": "Warehouse", "desc": "Crew storage: Dock Bin + Meat Crate", "base": 300.0, "growth": 1.9, "max": 60, "icon": "🏭"},
]

# ------------------------------------------------------------------ crew and robots
## Each hire is cheaper than the next: cost = base * 1.15^owned (robots 1.18).
## Rates are per unit per second; they feed the empire pipeline: catch → Dock Bin → shuck → Meat Crate → sell.
## Coordinators are the big upgrade: one per beach, each new one 3.5x the price of the last, each gives
## ALL crew +50% speed, and one
## sells 6 meat/s, more than a full beach of untrained Shuckers makes (1.4/s on the Shallows, 6.3/s at the Atoll).
## A Shucker shucks exactly as fast as a Deckhand rakes (a ShuckBot as fast as a RakeBot), so with
## equal training one of each keeps a beach's Dock Bin level instead of piling up.
const CREW: Array[Dictionary] = [
	{"id": "deckhand", "name": "Deckhand", "desc": "Rakes oysters into the Dock Bin", "role": "catch", "rate": 0.35, "base": 120.0, "growth": 1.19, "robot": false, "icon": "🧑‍🌾"},
	{"id": "shucker", "name": "Shucker", "desc": "Shucks oysters from the Dock Bin", "role": "shuck", "rate": 0.35, "base": 180.0, "growth": 1.19, "robot": false, "icon": "🔪"},
	{"id": "coordinator", "name": "Coordinator", "desc": "Runs a beach: sells its whole Meat Crate + ALL crew +50% speed. One per beach", "role": "sell", "rate": 6.0, "base": 6000.0, "growth": 3.5, "slots": 1, "slots_step": 0, "robot": false, "icon": "📋"},
	{"id": "rakebot", "name": "RakeBot", "desc": "Robot. Rakes like twenty deckhands", "role": "catch", "rate": 8.0, "base": 1000000.0, "growth": 1.22, "robot": true, "icon": "🤖"},
	{"id": "shuckbot", "name": "ShuckBot 3000", "desc": "Robot. Never nicks a thumb", "role": "shuck", "rate": 8.0, "base": 1300000.0, "growth": 1.22, "robot": true, "icon": "🦾"},
	{"id": "selldrone", "name": "Sell Drone", "desc": "Robot. Flies meat to market", "role": "sell", "rate": 15.0, "base": 4000000.0, "growth": 1.22, "robot": true, "icon": "🛸"},
]

const ROBOTICS_LAB_COST := 4000000.0
## Mega-Factory: each level doubles robot output.
const FACTORY_BASE := 200000000.0
const FACTORY_GROWTH := 12.0
const COORDINATOR_BOOST := 0.5   # each Coordinator: +50% speed for ALL crew

## Every beach has room for a limited crew. Hires fill the Muddy Shallows first, then the next
## beach up the coast. No free slot anywhere = no hire; open more gates for more room.
const CREW_SLOTS_BASE := 4      # people per crew type on the Muddy Shallows
const CREW_SLOTS_STEP := 2      # +2 per beach further along the coast
const ROBOT_SLOTS_BASE := 2
const ROBOT_SLOTS_STEP := 1

## Crew training (humans) / firmware (robots): a second upgrade path per crew type that makes
## every unit of that type work faster. cost = hire base * TRAIN_COST_MULT * TRAIN_GROWTH^level.
const TRAIN_COST_MULT := 30.0
const TRAIN_GROWTH := 3.0
const TRAIN_MAX := 40
const TRAIN_STEP := 0.25   # +25% speed per level

# ------------------------------------------------------------------ ranks (lifetime cash)
const RANKS: Array[Dictionary] = [
	{"at": 0.0, "name": "Lowly Fisherman"},
	{"at": 250.0, "name": "Mudlark"},
	{"at": 3000.0, "name": "Deckhand"},
	{"at": 40000.0, "name": "Head Shucker"},
	{"at": 600000.0, "name": "Foreman"},
	{"at": 15000000.0, "name": "Harbourmaster"},
	{"at": 500000000.0, "name": "Oyster Baron"},
	{"at": 25000000000.0, "name": "Shellionaire"},
	{"at": 2000000000000.0, "name": "Oyster Emperor"},
	{"at": 500000000000000.0, "name": "Poseidon's Accountant"},
]

# ------------------------------------------------------------------ pets
const RARITIES: Array[Dictionary] = [
	{"name": "Common", "color": Color(0.85, 0.88, 0.9)},
	{"name": "Uncommon", "color": Color(0.4, 0.95, 0.45)},
	{"name": "Rare", "color": Color(0.3, 0.6, 1.0)},
	{"name": "Epic", "color": Color(0.75, 0.35, 1.0)},
	{"name": "Legendary", "color": Color(1.0, 0.75, 0.15)},
	{"name": "Mythic", "color": Color(1.0, 0.25, 0.45)},
	{"name": "SECRET", "color": Color(0.1, 1.0, 0.95)},
]

## mult is applied to cash earned (all sources). Pets stack multiplicatively-additive: 1 + sum(mult-1).
const PETS: Array[Dictionary] = [
	{"id": "hermit", "name": "Hermit Crab", "rarity": 0, "mult": 1.10, "color": Color(0.85, 0.35, 0.25)},
	{"id": "gull", "name": "Greedy Gull", "rarity": 0, "mult": 1.12, "color": Color(0.96, 0.96, 0.94)},
	{"id": "starfish", "name": "Starfish", "rarity": 1, "mult": 1.25, "color": Color(1.0, 0.55, 0.3)},
	{"id": "otter", "name": "Sea Otter", "rarity": 1, "mult": 1.30, "color": Color(0.5, 0.36, 0.25)},
	{"id": "puffer", "name": "Pufferfish", "rarity": 2, "mult": 1.60, "color": Color(1.0, 0.85, 0.35)},
	{"id": "seal", "name": "Seal", "rarity": 2, "mult": 1.75, "color": Color(0.55, 0.6, 0.65)},
	{"id": "octopus", "name": "Octopus", "rarity": 3, "mult": 2.50, "color": Color(0.85, 0.3, 0.6)},
	{"id": "narwhal", "name": "Narwhal", "rarity": 4, "mult": 4.0, "color": Color(0.6, 0.8, 1.0)},
	{"id": "lobster", "name": "Golden Lobster", "rarity": 5, "mult": 8.0, "color": Color(1.0, 0.8, 0.15)},
	{"id": "kraken", "name": "Kraken Jr.", "rarity": 6, "mult": 20.0, "color": Color(0.2, 0.95, 0.85)},
]

## Mystery Clams cost pearls. weights are per PETS index.
const CLAMS: Array[Dictionary] = [
	{"id": "common", "name": "Beach Clam", "cost": 5, "weights": [40, 35, 12, 8, 3, 1.5, 0.45, 0.05, 0, 0]},
	{"id": "rare", "name": "Reef Clam", "cost": 40, "weights": [0, 0, 30, 25, 20, 14, 8, 2.5, 0.45, 0.05]},
	{"id": "mythic", "name": "Abyssal Clam", "cost": 300, "weights": [0, 0, 0, 0, 12, 13, 40, 25, 9, 1]},
]

const PET_SLOTS := 3

# ------------------------------------------------------------------ PERFECT streaks
## Consecutive PERFECT stabs at the bench. At each streak, this many oysters crack at once.
const STREAK_TIERS := [[1000, 128], [500, 64], [200, 32], [100, 16], [50, 8], [10, 4], [5, 2]]

# ------------------------------------------------------------------ re-shell (prestige)
const RESHELL_BASE := 150000000.0
const RESHELL_GROWTH := 6.0
const RESHELL_BONUS := 0.5   # +50% cash per Golden Shell

# ------------------------------------------------------------------ events
const EVENTS: Array[Dictionary] = [
	{"id": "golden_tide", "name": "GOLDEN TIDE", "desc": "x2 cash", "seconds": 60.0, "color": Color(1.0, 0.82, 0.2)},
	{"id": "pearl_storm", "name": "PEARL STORM", "desc": "x5 pearl chance", "seconds": 45.0, "color": Color(0.9, 0.9, 1.0)},
	{"id": "frenzy", "name": "OYSTER FRENZY", "desc": "beds refill instantly", "seconds": 40.0, "color": Color(0.3, 1.0, 0.6)},
	{"id": "crew_coffee", "name": "CREW COFFEE BREAK", "desc": "crew x3 speed", "seconds": 60.0, "color": Color(0.75, 0.5, 0.3)},
]
const EVENT_INTERVAL := 150.0

# ------------------------------------------------------------------ formulas
static func zone(i: int) -> Dictionary:
	return ZONES[clampi(i, 0, ZONES.size() - 1)]

static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

static func crew(id: String) -> Dictionary:
	for c in CREW:
		if c.id == id:
			return c
	return {}

static func pet(id: String) -> Dictionary:
	for p in PETS:
		if p.id == id:
			return p
	return {}

static func clam(id: String) -> Dictionary:
	for c in CLAMS:
		if c.id == id:
			return c
	return {}

static func upgrade_cost(id: String, level: int) -> float:
	var u := upgrade(id)
	if u.is_empty():
		return INF
	return floor(float(u.base) * pow(float(u.growth), float(level)))

static func crew_cost(id: String, owned: int) -> float:
	var c := crew(id)
	if c.is_empty():
		return INF
	return floor(float(c.base) * pow(float(c.growth), float(owned)))

static func streak_batch(streak: int) -> int:
	for t in STREAK_TIERS:
		if streak >= int(t[0]):
			return int(t[1])
	return 1

## The next tier above this streak as [streak needed, batch], or [] at the top.
static func next_streak_tier(streak: int) -> Array:
	var nxt: Array = []
	for t in STREAK_TIERS:
		if streak < int(t[0]):
			nxt = t
	return nxt

static func train_cost(id: String, lv: int) -> float:
	var c := crew(id)
	if c.is_empty():
		return INF
	return floor(float(c.base) * TRAIN_COST_MULT * pow(TRAIN_GROWTH, float(lv)))

static func crew_slots(zone_i: int, id: String) -> int:
	var c := crew(id)
	if c.has("slots"):   # e.g. Coordinators: exactly one per beach
		return int(c.slots) + int(c.get("slots_step", 0)) * zone_i
	if bool(c.get("robot", false)):
		return ROBOT_SLOTS_BASE + ROBOT_SLOTS_STEP * zone_i
	return CREW_SLOTS_BASE + CREW_SLOTS_STEP * zone_i

static func train_mult(lv: int) -> float:
	return 1.0 + float(lv) * TRAIN_STEP

static func factory_cost(level: int) -> float:
	return FACTORY_BASE * pow(FACTORY_GROWTH, float(level))

static func reshell_cost(rebirths: int) -> float:
	return RESHELL_BASE * pow(RESHELL_GROWTH, float(rebirths))

static func bucket_capacity(level: int) -> int:
	# grows steadily, not exponentially: a big bucket is earned, not an afterthought
	return 6 + level * 3 + int(pow(float(level), 1.5) * 0.5)

static func storage_capacity(level: int) -> float:
	return floor(60.0 * pow(1.55, float(level)))

static func rake_damage(level: int) -> float:
	# +0.5 per level, ramping gently (Lv 10: 8.5, Lv 20: 21, Lv 40: 61)
	return 1.0 + float(level) * 0.5 * (1.0 + float(level) / 20.0)

static func knife_damage(level: int) -> float:
	return 1.0 + float(level) * 0.5 * (1.0 + float(level) / 20.0)

static func walk_speed(level: int) -> float:
	return 7.0 + float(level) * 0.8

static func pearl_chance(level: int) -> float:
	return 0.03 + float(level) * 0.01

static func magnet_radius(level: int) -> float:
	return 0.0 if level <= 0 else 3.0 + float(level) * 0.6

static func quality_mult(level: int) -> float:
	return 1.0 + float(level) * 0.15

static func rank_index(lifetime: float) -> int:
	var r := 0
	for i in RANKS.size():
		if lifetime >= float(RANKS[i].at):
			r = i
	return r
