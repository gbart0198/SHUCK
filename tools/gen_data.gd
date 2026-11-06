extends SceneTree
## Generates every res://data/*.tres file. Run once:
##   Godot --headless --path . --script tools/gen_data.gd
## The .tres files are the source of truth after that; a designer can retune them.

func _initialize() -> void:
	_gen_balance()
	_gen_grades()
	_gen_pearls()
	_gen_species()
	_gen_upgrades()
	_gen_piers()
	_gen_tides()
	_gen_chaos()
	_gen_modifiers()
	_gen_badges()
	_gen_cosmetics()
	_gen_gadgets()
	_gen_steps()
	print("SHUCK data generated.")
	quit(0)

func _dir(p: String) -> void:
	DirAccess.make_dir_recursive_absolute(p)

func _save(res: Resource, path: String) -> void:
	_dir(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("could not save %s: %s" % [path, err])

func _gen_balance() -> void:
	_save(BalanceData.new(), "res://data/balance.tres")

func _gen_grades() -> void:
	var g := GradeData.new()
	g.grades = [
		{"id": "S", "min_score": 40, "price_mult": 1.6, "tip_pct": 0.30, "color": Color(1.0, 0.84, 0.35)},
		{"id": "A", "min_score": 25, "price_mult": 1.25, "tip_pct": 0.15, "color": Color(0.55, 0.9, 0.55)},
		{"id": "B", "min_score": 12, "price_mult": 1.0, "tip_pct": 0.05, "color": Color(0.9, 0.92, 0.95)},
		{"id": "C", "min_score": -9999, "price_mult": 0.55, "tip_pct": 0.0, "color": Color(0.95, 0.62, 0.3)},
		{"id": "F", "min_score": -99999, "price_mult": 0.0, "tip_pct": 0.0, "color": Color(0.85, 0.28, 0.28)},
	]
	_save(g, "res://data/grades.tres")

func _gen_pearls() -> void:
	var c := PearlConfig.new()
	c.colour_values = PackedColorArray([
		Color(0.97, 0.96, 0.93), Color(0.96, 0.91, 0.80), Color(0.97, 0.80, 0.82),
		Color(0.83, 0.78, 0.95), Color(0.96, 0.84, 0.48), Color(0.35, 0.72, 0.72),
		Color(0.22, 0.23, 0.28), Color(0.72, 0.62, 0.95),
	])
	c.colour_mults = PackedFloat32Array([1.0, 1.1, 1.3, 1.5, 2.0, 2.4, 3.0, 3.5])
	c.named_pearls = [
		{"id": "jetty_tear", "name": "The Jetty Tear", "pier": 1, "flavour": "Found in a shell that had no business opening."},
		{"id": "harbor_eye", "name": "The Harbor Eye", "pier": 2, "flavour": "It watches the cranes. The cranes watch back."},
		{"id": "raft_heart", "name": "Raft City Heart", "pier": 3, "flavour": "Still warm. Nobody asks why."},
		{"id": "reef_lung", "name": "The Reef Lung", "pier": 4, "flavour": "Breathes once when you look away."},
		{"id": "lamp_tear", "name": "The Lamp's Tear", "pier": 5, "flavour": "Shed for a ship that never came home."},
		{"id": "trench_die", "name": "The Trench Die", "pier": 6, "flavour": "Always rolls seven."},
		{"id": "kings_thumb", "name": "The King's Thumb", "pier": 6, "flavour": "He wants it back."},
		{"id": "tidewrought", "name": "The Tidewrought", "pier": 6, "flavour": "The tide made it. The tide wants it."},
	]
	_save(c, "res://data/pearl_config.tres")
	var t := PearlTraitTable.new()
	t.ids = PackedStringArray(["common", "lustrous", "flawed", "twin", "cultured", "mother_of_pearl", "tidewrought"])
	t.weights = PackedFloat32Array([79.90, 12.00, 5.00, 2.00, 0.90, 0.09, 0.01])
	t.value_mults = PackedFloat32Array([1.0, 1.0, 0.4, 1.0, 1.0, 1.0, 1.0])
	_save(t, "res://data/pearl_traits.tres")

func _gen_species() -> void:
	var list := [
		{"id": "dock_blue", "pier": 1, "value": 8, "pearl": 0.04, "tol": 8.0, "window": 1.0, "note": "SPECIES_DOCK_BLUE_NOTE",
			"shell": Color(0.55, 0.60, 0.63), "ridge": Color(0.38, 0.43, 0.46)},
		{"id": "kumamoto", "pier": 2, "value": 14, "pearl": 0.08, "tol": 0.0, "window": 0.75, "note": "SPECIES_KUMAMOTO_NOTE",
			"shell": Color(0.62, 0.57, 0.49), "ridge": Color(0.44, 0.40, 0.34)},
		{"id": "pacific_gigas", "pier": 2, "value": 22, "pearl": 0.03, "tol": 0.0, "window": 1.0, "extra": 0.3, "meat": 2, "note": "SPECIES_GIGAS_NOTE",
			"shell": Color(0.70, 0.68, 0.60), "ridge": Color(0.50, 0.48, 0.42), "scale": Vector3(1.25, 0.5, 1.5)},
		{"id": "razor_clam", "pier": 3, "value": 18, "pearl": 0.06, "tol": 14.0, "window": 1.0, "maxspeed": 0.7, "note": "SPECIES_RAZOR_NOTE",
			"shell": Color(0.76, 0.72, 0.58), "ridge": Color(0.52, 0.49, 0.38), "scale": Vector3(0.55, 0.35, 1.7)},
		{"id": "moon_snail", "pier": 4, "value": 30, "pearl": 0.09, "tol": 0.0, "window": 1.0, "drill": 4.0, "note": "SPECIES_MOON_NOTE",
			"shell": Color(0.78, 0.76, 0.70), "ridge": Color(0.55, 0.50, 0.48), "scale": Vector3(1.0, 1.0, 1.0)},
		{"id": "devils_claw", "pier": 5, "value": 55, "pearl": 0.12, "tol": 0.0, "window": 1.0, "gloves": 4, "note": "SPECIES_DEVIL_NOTE",
			"shell": Color(0.42, 0.28, 0.30), "ridge": Color(0.24, 0.16, 0.18), "scale": Vector3(1.15, 0.55, 1.35)},
		{"id": "cursed_oyster", "pier": 6, "value": 90, "pearl": 0.25, "tol": 0.0, "window": 1.0, "escape": 8.0, "note": "SPECIES_CURSED_NOTE",
			"shell": Color(0.30, 0.34, 0.30), "ridge": Color(0.16, 0.20, 0.16), "scale": Vector3(1.05, 0.5, 1.25)},
		{"id": "king_oyster", "pier": 6, "value": 200, "pearl": 0.40, "tol": 0.0, "window": 1.0, "boss": true, "note": "SPECIES_KING_NOTE",
			"shell": Color(0.45, 0.36, 0.24), "ridge": Color(0.26, 0.20, 0.12), "scale": Vector3(2.4, 1.0, 2.8)},
	]
	for d in list:
		var s := SpeciesData.new()
		s.id = d.id
		s.name_key = "SPECIES_" + str(d.id).to_upper()
		s.pier = d.pier
		s.value_cents = d.value
		s.pearl_chance = d.pearl
		s.slide_tolerance = d.tol
		s.meter_window_scale = d.window
		s.gesture_time_add = d.get("extra", 0.0)
		s.meat_yield = d.get("meat", 1)
		s.max_slide_speed_scale = d.get("maxspeed", 0.0)
		s.drill_seconds = d.get("drill", 0.0)
		s.requires_gloves_tier = d.get("gloves", 0)
		s.escape_seconds = d.get("escape", 0.0)
		s.is_boss = d.get("boss", false)
		s.notes_key = d.note
		s.shell_color = d.shell
		s.ridge_color = d.ridge
		s.mesh_scale = d.get("scale", Vector3(1.0, 0.42, 1.25))
		_save(s, "res://data/species/%s.tres" % d.id)

func _gen_upgrades() -> void:
	var lines := [
		{"line": "knife", "names": ["UP_KNIFE_1", "UP_KNIFE_2", "UP_KNIFE_3", "UP_KNIFE_4", "UP_KNIFE_5", "UP_KNIFE_6"],
		 "costs": [0, 120, 400, 1100, 2600, 5500], "unlock": [1, 1, 5, 6, 0, 0],
		 "descs": ["UP_KNIFE_1_D", "UP_KNIFE_2_D", "UP_KNIFE_3_D", "UP_KNIFE_4_D", "UP_KNIFE_5_D", "UP_KNIFE_6_D"]},
		{"line": "gloves", "names": ["UP_GLOVES_1", "UP_GLOVES_2", "UP_GLOVES_3", "UP_GLOVES_4", "UP_GLOVES_5", "UP_GLOVES_6"],
		 "costs": [0, 120, 400, 1100, 2600, 5500], "unlock": [1, 1, 5, 6, 0, 0],
		 "descs": ["UP_GLOVES_1_D", "UP_GLOVES_2_D", "UP_GLOVES_3_D", "UP_GLOVES_4_D", "UP_GLOVES_5_D", "UP_GLOVES_6_D"]},
		{"line": "bench", "names": ["UP_BENCH_1", "UP_BENCH_2", "UP_BENCH_3", "UP_BENCH_4", "UP_BENCH_5", "UP_BENCH_6"],
		 "costs": [0, 120, 400, 1100, 2600, 5500], "unlock": [1, 2, 5, 6, 0, 0],
		 "descs": ["UP_BENCH_1_D", "UP_BENCH_2_D", "UP_BENCH_3_D", "UP_BENCH_4_D", "UP_BENCH_5_D", "UP_BENCH_6_D"]},
		{"line": "auto", "names": ["UP_AUTO_1", "UP_AUTO_2", "UP_AUTO_3", "UP_AUTO_4", "UP_AUTO_5", "UP_AUTO_6"],
		 "costs": [0, 900, 2200, 4500, 7000, 12000], "unlock": [1, 3, 5, 6, 0, 0],
		 "descs": ["UP_AUTO_1_D", "UP_AUTO_2_D", "UP_AUTO_3_D", "UP_AUTO_4_D", "UP_AUTO_5_D", "UP_AUTO_6_D"]},
		{"line": "floor", "names": ["UP_FLOOR_1", "UP_FLOOR_2", "UP_FLOOR_3", "UP_FLOOR_4", "UP_FLOOR_5", "UP_FLOOR_6"],
		 "costs": [0, 150, 500, 1300, 3000, 6500], "unlock": [1, 4, 5, 6, 0, 0],
		 "descs": ["UP_FLOOR_1_D", "UP_FLOOR_2_D", "UP_FLOOR_3_D", "UP_FLOOR_4_D", "UP_FLOOR_5_D", "UP_FLOOR_6_D"]},
	]
	for l in lines:
		for i in 6:
			var u := UpgradeData.new()
			u.line = l.line
			u.tier = i + 1
			u.name_key = l.names[i]
			u.desc_key = l.descs[i]
			u.cost = l.costs[i]
			u.unlock_pier = l.unlock[i]
			_save(u, "res://data/upgrades/%s_%d.tres" % [l.line, i + 1])

func _gen_piers() -> void:
	var list := [
		{"id": 1, "tickets": 8, "quota": 120, "scale": 1.0, "spawn": 70.0,
		 "species": ["dock_blue"], "hazard": "PIER1_HAZARD", "boss": false,
		 "relic": "jetty_wheel", "named": "",
		 "sky": Color(0.10, 0.16, 0.26), "horizon": Color(0.72, 0.46, 0.30), "fog": Color(0.40, 0.36, 0.34),
		 "light": Color(1.0, 0.78, 0.55), "energy": 1.5, "water": Color(0.07, 0.18, 0.24),
		 "wood": Color(0.36, 0.25, 0.16), "wall": Color(0.20, 0.24, 0.26), "accent": Color(0.86, 0.47, 0.24),
		 "ambient": 0.55, "gulls": 3, "tilt": 0.0, "lowg": false, "dark": 0.0},
		{"id": 2, "tickets": 10, "quota": 300, "scale": 1.3, "spawn": 60.0,
		 "species": ["dock_blue", "kumamoto", "pacific_gigas"], "hazard": "PIER2_HAZARD", "boss": false,
		 "relic": "harbor_clam", "named": "",
		 "sky": Color(0.14, 0.20, 0.27), "horizon": Color(0.55, 0.55, 0.52), "fog": Color(0.42, 0.45, 0.46),
		 "light": Color(0.95, 0.92, 0.82), "energy": 1.1, "water": Color(0.10, 0.20, 0.24),
		 "wood": Color(0.30, 0.29, 0.27), "wall": Color(0.30, 0.33, 0.34), "accent": Color(0.35, 0.55, 0.62),
		 "ambient": 0.6, "gulls": 4, "tilt": 0.0, "lowg": false, "dark": 0.0},
		{"id": 3, "tickets": 11, "quota": 600, "scale": 1.7, "spawn": 60.0,
		 "species": ["kumamoto", "pacific_gigas", "razor_clam"], "hazard": "PIER3_HAZARD", "boss": true,
		 "relic": "raft_comb", "named": "raft_heart",
		 "sky": Color(0.16, 0.10, 0.22), "horizon": Color(0.45, 0.32, 0.48), "fog": Color(0.30, 0.26, 0.36),
		 "light": Color(0.85, 0.65, 0.95), "energy": 0.9, "water": Color(0.10, 0.14, 0.24),
		 "wood": Color(0.30, 0.22, 0.20), "wall": Color(0.28, 0.24, 0.32), "accent": Color(0.9, 0.35, 0.6),
		 "ambient": 0.5, "gulls": 5, "tilt": 0.02, "lowg": false, "dark": 0.0},
		{"id": 4, "tickets": 12, "quota": 1000, "scale": 2.2, "spawn": 58.0,
		 "species": ["razor_clam", "moon_snail", "pacific_gigas"], "hazard": "PIER4_HAZARD", "boss": true,
		 "relic": "reef_lens", "named": "reef_lung",
		 "sky": Color(0.02, 0.18, 0.24), "horizon": Color(0.05, 0.35, 0.38), "fog": Color(0.06, 0.30, 0.34),
		 "light": Color(0.4, 0.9, 0.9), "energy": 0.8, "water": Color(0.02, 0.22, 0.26),
		 "wood": Color(0.22, 0.26, 0.24), "wall": Color(0.10, 0.28, 0.30), "accent": Color(0.3, 0.9, 0.8),
		 "ambient": 0.7, "gulls": 0, "tilt": 0.0, "lowg": true, "dark": 0.0},
		{"id": 5, "tickets": 14, "quota": 1600, "scale": 2.8, "spawn": 56.0,
		 "species": ["moon_snail", "devils_claw", "razor_clam"], "hazard": "PIER5_HAZARD", "boss": true,
		 "relic": "lighthouse_lens", "named": "lamp_tear",
		 "sky": Color(0.02, 0.03, 0.05), "horizon": Color(0.06, 0.07, 0.10), "fog": Color(0.04, 0.05, 0.07),
		 "light": Color(0.9, 0.85, 0.7), "energy": 0.55, "water": Color(0.02, 0.04, 0.06),
		 "wood": Color(0.20, 0.16, 0.14), "wall": Color(0.14, 0.14, 0.15), "accent": Color(1.0, 0.9, 0.5),
		 "ambient": 0.18, "gulls": 2, "tilt": 0.0, "lowg": false, "dark": 0.75},
		{"id": 6, "tickets": 16, "quota": 2600, "scale": 3.5, "spawn": 52.0,
		 "species": ["devils_claw", "cursed_oyster", "moon_snail"], "hazard": "PIER6_HAZARD", "boss": true,
		 "relic": "casino_dice", "named": "kings_thumb",
		 "sky": Color(0.10, 0.03, 0.06), "horizon": Color(0.30, 0.08, 0.10), "fog": Color(0.18, 0.06, 0.08),
		 "light": Color(1.0, 0.55, 0.45), "energy": 1.0, "water": Color(0.08, 0.02, 0.04),
		 "wood": Color(0.26, 0.14, 0.12), "wall": Color(0.16, 0.10, 0.12), "accent": Color(1.0, 0.35, 0.3),
		 "ambient": 0.4, "gulls": 2, "tilt": 0.0, "lowg": false, "dark": 0.35},
	]
	for d in list:
		var p := PierData.new()
		p.id = d.id
		p.name_key = "PIER_%d" % d.id
		p.tagline_key = "PIER_%d_TAG" % d.id
		p.ticket_count = d.tickets
		p.quota = d.quota
		p.price_scale = d.scale
		p.spawn_interval = d.spawn
		p.shift_seconds = d.tickets * d.spawn
		p.species = PackedStringArray(d.species)
		p.hazard_key = d.hazard
		p.has_boss = d.boss
		p.boss_species = "king_oyster" if d.boss else ""
		p.boss_seconds = 180.0
		p.relic_id = d.relic
		p.named_pearl = d.named
		p.chaos_weights = PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 1, 1])
		p.sky_top = d.sky
		p.sky_bottom = d.horizon
		p.fog_color = d.fog
		p.light_color = d.light
		p.light_energy = d.energy
		p.water_color = d.water
		p.wood_color = d.wood
		p.wall_color = d.wall
		p.accent_color = d.accent
		p.ambient_energy = d.ambient
		p.gull_count = d.gulls
		p.tilt = d.tilt
		p.low_gravity = d.lowg
		p.darkness = d.dark
		_save(p, "res://data/piers/pier_%d.tres" % d.id)

func _gen_tides() -> void:
	var list := [
		{"id": "neap", "payout": 0.9, "patience": 1.2, "desc": "TIDE_NEAP_D"},
		{"id": "spring", "payout": 1.2, "patience": 0.8, "desc": "TIDE_SPRING_D"},
		{"id": "murky", "payout": 1.2, "light": 0.5, "desc": "TIDE_MURKY_D"},
		{"id": "slippery", "payout": 1.3, "tolerance": 0.7, "desc": "TIDE_SLIPPERY_D"},
		{"id": "crowded", "payout": 1.5, "ticket": 1.5, "desc": "TIDE_CROWDED_D"},
		{"id": "hungry", "payout": 1.5, "quota": 1.5, "desc": "TIDE_HUNGRY_D"},
		{"id": "gulls", "payout": 1.3, "gulls": 4, "desc": "TIDE_GULLS_D"},
		{"id": "low_water", "payout": 1.2, "slots": 1, "desc": "TIDE_LOW_WATER_D"},
	]
	for d in list:
		var t := TideData.new()
		t.id = d.id
		t.name_key = "TIDE_" + str(d.id).to_upper()
		t.desc_key = d.desc
		t.payout_mult = d.payout
		t.patience_mult = d.get("patience", 1.0)
		t.ticket_mult = d.get("ticket", 1.0)
		t.quota_mult = d.get("quota", 1.0)
		t.tolerance_mult = d.get("tolerance", 1.0)
		t.light_mult = d.get("light", 1.0)
		t.gull_extra = d.get("gulls", 0)
		t.gadget_slots = d.get("slots", 2)
		_save(t, "res://data/tides/%s.tres" % d.id)

func _gen_chaos() -> void:
	var list := [
		{"id": "gull_raid", "effect": "gull", "dur": 8.0},
		{"id": "crab_convoy", "effect": "crab", "dur": 8.0},
		{"id": "rogue_wave", "effect": "wave", "dur": 6.0},
		{"id": "power_cut", "effect": "dark", "dur": 6.0},
		{"id": "health_inspector", "effect": "inspector", "dur": 30.0},
		{"id": "drunk_customer", "effect": "drunk", "dur": 12.0},
		{"id": "rival_van", "effect": "rival", "dur": 4.0},
		{"id": "brine_spill", "effect": "slick", "dur": 15.0},
		{"id": "screaming_oyster", "effect": "scream", "dur": 12.0},
	]
	for d in list:
		var c := ChaosData.new()
		c.id = d.id
		c.name_key = "CHAOS_" + str(d.id).to_upper()
		c.subtitle_key = c.name_key + "_SUB"
		c.effect = d.effect
		c.duration = d.dur
		c.weight = 1.0
		_save(c, "res://data/chaos/%s.tres" % d.id)

func _gen_modifiers() -> void:
	var list := [
		{"id": "no_pearl", "pay": 0.4, "tip": 0.0, "no_pearl": true},
		{"id": "extra_brine", "pay": 0.2, "delta": 1.0, "plate": 1.0},
		{"id": "regulars", "tip": 0.5, "mult": 0.75},
		{"id": "to_go", "pay": 0.1, "delta": -2.0, "two_handed": true},
		{"id": "still_alive", "pay": 0.6, "delta": -3.0, "no_pop": true},
	]
	for d in list:
		var m := TicketModifierData.new()
		m.id = d.id
		m.name_key = "MOD_" + str(d.id).to_upper()
		m.pay_bonus = d.get("pay", 0.0)
		m.tip_bonus = d.get("tip", 0.0)
		m.patience_delta = d.get("delta", 0.0)
		m.patience_mult = d.get("mult", 1.0)
		m.no_pearl = d.get("no_pearl", false)
		m.plate_delay = d.get("plate", 0.0)
		m.no_pop = d.get("no_pop", false)
		m.two_handed = d.get("two_handed", false)
		_save(m, "res://data/tickets/%s.tres" % d.id)

func _gen_badges() -> void:
	var list := [
		{"id": "first_shift", "reward": "hat_deckhand"},
		{"id": "clean_hands", "reward": "glove_white"},
		{"id": "pearl_diver", "reward": "hat_pin"},
		{"id": "gulled", "reward": "hat_gull"},
		{"id": "nine_fingers", "reward": "glove_bandage"},
		{"id": "last_call", "reward": "hat_stopwatch"},
		{"id": "whole_pier", "reward": "apron_flag"},
		{"id": "full_case", "reward": "apron_velvet"},
		{"id": "mothers_day", "reward": "knife_mother"},
		{"id": "tidebreaker", "reward": "knife_inherited_skin"},
		{"id": "crew_of_four", "reward": "hat_crew"},
		{"id": "the_log", "reward": "hat_baron"},
	]
	for d in list:
		var b := BadgeData.new()
		b.id = d.id
		b.name_key = "BADGE_" + d.id.to_upper()
		b.desc_key = b.name_key + "_D"
		b.reward_cosmetic = d.reward
		_save(b, "res://data/badges/%s.tres" % d.id)

func _gen_cosmetics() -> void:
	var list := [
		{"id": "hat_deckhand", "slot": "hat", "price": 0, "badge": true, "color": Color(0.35, 0.45, 0.7)},
		{"id": "hat_pin", "slot": "hat", "price": 0, "badge": true, "color": Color(0.9, 0.85, 0.7)},
		{"id": "hat_gull", "slot": "hat", "price": 0, "badge": true, "color": Color(0.95, 0.95, 0.95)},
		{"id": "hat_stopwatch", "slot": "hat", "price": 0, "badge": true, "color": Color(0.75, 0.7, 0.4)},
		{"id": "hat_crew", "slot": "hat", "price": 0, "badge": true, "color": Color(0.2, 0.4, 0.35)},
		{"id": "hat_baron", "slot": "hat", "price": 0, "badge": true, "color": Color(0.95, 0.8, 0.3)},
		{"id": "hat_wool", "slot": "hat", "price": 120, "color": Color(0.55, 0.3, 0.25)},
		{"id": "hat_sou_west", "slot": "hat", "price": 200, "color": Color(0.85, 0.8, 0.55)},
		{"id": "hat_diver", "slot": "hat", "price": 340, "color": Color(0.3, 0.5, 0.45)},
		{"id": "hat_crown", "slot": "hat", "price": 800, "color": Color(0.95, 0.78, 0.2)},
		{"id": "apron_flag", "slot": "apron", "price": 0, "badge": true, "color": Color(0.7, 0.2, 0.2)},
		{"id": "apron_velvet", "slot": "apron", "price": 0, "badge": true, "color": Color(0.35, 0.1, 0.3)},
		{"id": "apron_canvas", "slot": "apron", "price": 90, "color": Color(0.6, 0.55, 0.42)},
		{"id": "apron_leather", "slot": "apron", "price": 260, "color": Color(0.28, 0.18, 0.12)},
		{"id": "glove_white", "slot": "glove", "price": 0, "badge": true, "color": Color(0.95, 0.95, 0.92)},
		{"id": "glove_bandage", "slot": "glove", "price": 0, "badge": true, "color": Color(0.85, 0.82, 0.75)},
		{"id": "glove_yellow", "slot": "glove", "price": 140, "color": Color(0.9, 0.75, 0.2)},
		{"id": "knife_rust", "slot": "knife", "price": 0, "color": Color(0.45, 0.32, 0.22)},
		{"id": "knife_sea_glass", "slot": "knife", "price": 0, "badge": true, "color": Color(0.35, 0.8, 0.75)},
		{"id": "knife_mother", "slot": "knife", "price": 0, "badge": true, "color": Color(0.95, 0.9, 0.95)},
		{"id": "knife_inherited_skin", "slot": "knife", "price": 0, "badge": true, "color": Color(0.65, 0.55, 0.35)},
		{"id": "knife_bone", "slot": "knife", "price": 320, "color": Color(0.88, 0.85, 0.75)},
		{"id": "bucket_galv", "slot": "bucket", "price": 80, "color": Color(0.6, 0.62, 0.65)},
		{"id": "bucket_red", "slot": "bucket", "price": 160, "color": Color(0.7, 0.2, 0.18)},
		{"id": "radio_fm", "slot": "radio", "price": 100, "color": Color(0.3, 0.35, 0.4)},
		{"id": "radio_am", "slot": "radio", "price": 220, "color": Color(0.45, 0.35, 0.25)},
		{"id": "hook_brass", "slot": "hook", "price": 180, "color": Color(0.75, 0.6, 0.25)},
		{"id": "sign_open", "slot": "sign", "price": 240, "color": Color(0.2, 0.8, 0.5)},
		{"id": "sign_closed", "slot": "sign", "price": 240, "color": Color(0.8, 0.25, 0.25)},
	]
	for d in list:
		var c := CosmeticData.new()
		c.id = d.id
		c.name_key = "COS_" + d.id.to_upper()
		c.slot = d.slot
		c.price = d.price
		c.color = d.color
		c.badge_only = d.get("badge", false)
		_save(c, "res://data/cosmetics/%s.tres" % d.id)

func _gen_gadgets() -> void:
	var list := [
		{"id": "chiller", "cost": 90, "uses": 1},
		{"id": "prybar", "cost": 120, "uses": 1},
		{"id": "pager", "cost": 60, "uses": 1},
		{"id": "shout", "cost": 40, "uses": 1},
		{"id": "pinhole", "cost": 250, "uses": 1},
		{"id": "ice_bucket", "cost": 80, "uses": 1},
		{"id": "shell_glue", "cost": 70, "uses": 1},
		{"id": "shop_dog", "cost": 400, "uses": 0, "permanent": true},
		{"id": "fog_horn", "cost": 150, "uses": 1},
		{"id": "rubber_oyster", "cost": 30, "uses": 1},
	]
	for d in list:
		var g := GadgetData.new()
		g.id = d.id
		g.name_key = "GADGET_" + d.id.to_upper()
		g.desc_key = g.name_key + "_D"
		g.cost = d.cost
		g.uses = d.uses
		g.permanent = d.get("permanent", false)
		_save(g, "res://data/gadgets/%s.tres" % d.id)

func _gen_steps() -> void:
	var wedge := InteractionStep.new()
	wedge.id = "wedge"
	wedge.duration = 0.6
	wedge.skill = "hold_release"
	wedge.params = {"meter": "bite", "band": [0.55, 0.75], "next": "pop"}
	_save(wedge, "res://data/steps/wedge.tres")

	var pop := InteractionStep.new()
	pop.id = "pop"
	pop.duration = 0.5
	pop.skill = "ring"
	pop.params = {"perfect": 0.30, "normal": 0.60, "next": "slide"}
	_save(pop, "res://data/steps/pop.tres")

	var slide := InteractionStep.new()
	slide.id = "slide"
	slide.duration = 0.0
	slide.skill = "drag"
	slide.params = {"offline_limit": 40.0, "next": "reseat"}
	_save(slide, "res://data/steps/slide.tres")

	var reseat := InteractionStep.new()
	reseat.id = "reseat"
	reseat.duration = 0.0
	reseat.skill = "place"
	reseat.params = {"target": "plate"}
	_save(reseat, "res://data/steps/reseat.tres")
