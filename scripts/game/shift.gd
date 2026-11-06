extends Node3D
class_name Shift
## One shift: pier, tickets, bench, plate, rail, chaos, automation, ledger.

signal shift_finished(result: Dictionary)
signal open_shop_requested
signal open_log_requested
signal lobby_requested
signal next_shift_requested

const SLOT_X := [-1.65, -0.95, 0.95, 1.65]
const SLOT_Z := -1.0

var pier: PierData
var tide_ids: Array = []
var boss_mode := false
var daily := false
var seed_value := 0

var rng := RandomNumberGenerator.new()
var player: Player
var plate: PlateStation
var bench_root: Node3D
var rail_root: Node3D
var cards: Array[TicketCard] = []
var active_ticket: TicketSim
var active_card: TicketCard
var bench_positions: Array[Vector3] = []
var oysters: Array[OysterNode] = []

var ticket_id := 1
var tickets_spawned := 0
var tickets_total := 0
var spawn_interval := 70.0
var shift_length := 600.0
var elapsed := 0.0
var time_left := 600.0
var next_spawn := 2.0
var last_call_done := false
var earnings := 0
var tips := 0
var walked_out := 0
var pearls_found: Array[Pearl] = []
var pearls_value := 0
var quota := 120
var stars := 0
var ended := false
var chaos_done := false
var chaos_at := 360.0
var boss_oyster: OysterNode
var boss_time := 0.0
var boss_done := false
var boss_finished := false

var hud: Hud
var overlay: GestureOverlay
var pause_ui: Control
var ledger: LedgerUI
var refs: Dictionary = {}
var lights: Array[Light3D] = []
var subtitle := ""
var subtitle_timer := 0.0
var ghost := false
var paused := false
var photo := false
var photo_freeze := false
var auto_timer := 0.0
var otto_timer := 0.0
var slick_timer := 0.0
var late_serve := false

func configure(p_pier: int, p_tides: Array, p_seed: int, p_boss := false, p_daily := false) -> void:
	pier = Registry.get_pier(p_pier)
	tide_ids = p_tides.duplicate()
	seed_value = p_seed
	boss_mode = p_boss
	daily = p_daily

func _ready() -> void:
	Registry.ensure_loaded()
	if pier == null:
		pier = Registry.get_pier(1)
	rng.seed = seed_value
	var bal := Registry.balance
	quota = roundi(float(pier.quota) * _tide_product("quota_mult"))
	tickets_total = roundi(float(pier.ticket_count) * _tide_product("ticket_mult"))
	shift_length = maxf(120.0, float(pier.ticket_count) * pier.spawn_interval)
	spawn_interval = shift_length / maxf(1.0, float(tickets_total))
	time_left = shift_length
	chaos_at = shift_length * bal.chaos_at_fraction
	ghost = Game.state.get("settings", {}).get("ghost_hand", true) and Game.state.get("shifts", 0) < 1

	_build_world()
	_build_station()
	_build_player()
	_build_ui()
	if boss_mode:
		_start_boss()
	else:
		next_spawn = 2.0
	_subtitle(Data.t(pier.tagline_key, ""))

func _tide_product(prop: String) -> float:
	var v := 1.0
	for tid in tide_ids:
		var t := Registry.get_tide(str(tid))
		if t != null:
			v *= float(t.get(prop))
	return v

func _build_world() -> void:
	refs = PierBuilder.build(self, pier)
	for child in get_children():
		pass
	if refs.has("sun") and refs.sun is Light3D:
		lights.append(refs.sun)
	if refs.has("lamp") and refs.lamp is Light3D:
		lights.append(refs.lamp)
	if pier.relic_id != "" and not Game.state.get("relics", []).has(pier.relic_id) and refs.has("relic_pos"):
		var relic := Relic.new()
		relic.setup(pier.relic_id, pier.relic_id)
		relic.position = refs.relic_pos
		relic.collected.connect(_on_relic)
		add_child(relic)

func _on_relic(id: String) -> void:
	if Game.add_relic(id):
		_toast("Relic found: %s  (+1% tips, kept for good)" % id.replace("_", " "))
		Sfx.play("coin")

func _build_station() -> void:
	bench_root = Node3D.new()
	bench_root.name = "Bench"
	add_child(bench_root)
	for i in 4:
		bench_positions.append(Vector3(SLOT_X[i], 1.12, SLOT_Z))

	plate = PlateStation.new()
	plate.position = Vector3(0, 1.06, -0.62)
	plate.rotation.y = 0.0
	add_child(plate)
	plate.add_child(MeshFactory.plate(Color(0.92, 0.91, 0.87)))
	plate.serve_requested.connect(_serve_from_plate)

	rail_root = Node3D.new()
	rail_root.name = "TicketRail"
	add_child(rail_root)
	rail_root.add_child(MeshFactory.box(Vector3(3.4, 0.03, 0.03), Color(0.6, 0.62, 0.64), Vector3(0, 1.62, -1.62)))
	for x in [-1.55, 1.55]:
		rail_root.add_child(MeshFactory.box(Vector3(0.04, 0.04, 0.04), Color(0.5, 0.52, 0.54), Vector3(x, 1.62, -1.62)))
	rail_root.add_child(MeshFactory.box(Vector3(3.4, 0.02, 0.20), Color(0.30, 0.22, 0.16), Vector3(0, 1.70, -1.55)))

	# towel + sink (status cures, physical props)
	for spot in [Vector3(-3.2, 1.12, -0.45), Vector3(3.2, 1.12, -0.45)]:
		var b := MeshFactory.box(Vector3(0.55, 0.06, 0.4), Color(0.55, 0.58, 0.58), spot)
		add_child(b)

func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 0, 1.35)
	player.rotation.y = 0.0
	add_child(player)
	player.plate_ref = plate
	player.oyster_resolved.connect(_on_oyster_resolved)
	player.focus_changed.connect(_on_focus)
	player.toast.connect(_toast)
	if pier.darkness > 0.3:
		var fl := SpotLight3D.new()
		fl.light_color = Color(1.0, 0.95, 0.8)
		fl.light_energy = 3.0
		fl.spot_range = 14.0
		fl.spot_angle = 32.0
		fl.position = Vector3(0.1, -0.1, 0.0)
		player.main_camera.add_child(fl)
	# knife skin from cosmetics
	var skin := Game.equipped("knife")
	if skin != "":
		var c := Registry.get_cosmetic(skin)
		if c != null:
			player.hands.refresh_knife(c.color)

func _build_ui() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud.shift = self
	hud_layer.add_child(hud)

	overlay = GestureOverlay.new()
	overlay.player = player
	hud_layer.add_child(overlay)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ended:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo") and not ended:
		_toggle_photo()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ tickets
func _process(dt: float) -> void:
	if ended or paused or photo_freeze:
		return
	elapsed += dt
	time_left = maxf(0.0, shift_length - elapsed)
	if subtitle_timer > 0.0:
		subtitle_timer -= dt
	_refresh_hud_prompt()

	if boss_mode:
		_process_boss(dt)
	else:
		_process_tickets(dt)
	_process_automation(dt)
	_process_chaos(dt)

	if not ended and _should_end():
		_end_shift()

func _process_tickets(dt: float) -> void:
	# scheduled arrivals
	var guard := 0
	while tickets_spawned < tickets_total and elapsed >= next_spawn and guard < 4:
		_spawn_ticket()
		next_spawn += spawn_interval
		guard += 1
	if not last_call_done and time_left <= Registry.balance.last_call_seconds:
		last_call_done = true
		while tickets_spawned < tickets_total:
			_spawn_ticket()
	# patience / rail timeouts
	for card in cards.duplicate():
		card.ticket.tick(dt)
		if card.ticket.walked_out:
			_on_walked_out(card)
	# keep the bench stocked for the active ticket
	_spawn_from_active()
	# leaving the rail alone expires too
	if active_ticket != null and active_ticket.completed:
		_finish_active()

func _spawn_ticket() -> void:
	if tickets_spawned >= tickets_total:
		return
	var t := TicketSim.create(ticket_id, pier, Registry.species, rng, Registry.balance,
		_tide_product("patience_mult"), _floor_patience())
	ticket_id += 1
	tickets_spawned += 1
	var card := TicketCard.new()
	card.setup(t, cards.size())
	var idx := cards.size()
	var x := -1.05 + 1.05 * idx
	card.position = Vector3(x, 1.48, -1.52)
	card.clicked.connect(_on_ticket_clicked)
	rail_root.add_child(card)
	cards.append(card)
	Sfx.play("click", -12.0, 0.7)

func _floor_patience() -> float:
	return 0.05 if Game.tier("floor") >= 3 else 0.0

func _on_ticket_clicked(card: TicketCard) -> void:
	if card.ticket == active_ticket:
		_serve_from_plate()
		return
	if active_ticket != null and not active_ticket.completed:
		_toast("Finish the ticket on the pass first.")
		return
	if card.ticket.walked_out or card.ticket.completed:
		return
	active_ticket = card.ticket
	active_card = card
	active_ticket.accept()
	card.set_active(true)
	for c in cards:
		if c != card:
			c.set_active(false)
	_spawn_from_active()
	Sfx.play("click", -4.0)

func _spawn_from_active() -> void:
	if active_ticket == null or active_ticket.completed or active_ticket.walked_out:
		return
	if active_ticket.spawn_index >= active_ticket.species_ids.size():
		return
	var capacity := Registry.balance.bench_slots[clampi(Game.tier("bench") - 1, 0, 5)]
	var free := -1
	for i in capacity:
		var used := false
		for o in oysters:
			if is_instance_valid(o) and o.slot == i:
				used = true
				break
		if not used:
			free = i
			break
	if free < 0:
		return
	var sid := str(active_ticket.species_ids[active_ticket.spawn_index])
	var sp := Registry.get_species(sid)
	if sp == null:
		active_ticket.spawn_index += 1
		return
	active_ticket.spawn_index += 1
	var sim := OysterSim.new(sp, Registry.balance, Registry.grade_data, rng)
	sim.knife_tier_bonus = Registry.balance.knife_t4_score_bonus if Game.tier("knife") >= 4 else 0
	var luck := 1.0
	if Game.tier("floor") >= 5:
		luck += Registry.balance.lamp_pearl_bonus
	var chance := clampf(sp.pearl_chance * luck, 0.0, 1.0)
	# pearls are rolled HERE, at spawn, and never when the shell opens.
	sim.setup_pearls(PearlRoller.roll(rng, chance, pier.id))
	var node := OysterNode.new()
	node.setup(sp, sim, free)
	node.position = bench_positions[free]
	if sp.is_boss:
		node.scale = Vector3(1.7, 1.7, 1.7)
	node.expired.connect(_on_oyster_binned)
	bench_root.add_child(node)
	oysters.append(node)

func _on_oyster_resolved(oyster: OysterNode, sim: OysterSim) -> void:
	Game.session["oysters"] = int(Game.session.get("oysters", 0)) + 1
	oysters.erase(oyster)
	if sim.perfect_pops > 0:
		Game.session["perfect"] = int(Game.session.get("perfect", 0)) + 1
	if sim.state == OysterSim.State.PLATED:
		plate.add_plated(sim)
		_collect_pearls(sim)
		if sim.grade == "S":
			_toast("S — perfect. It pays 1.6x.")
		if active_ticket == null:
			_toast("On the pass. Take a ticket off the rail.")
		else:
			_spawn_from_active()
	else:
		Game.session["ruined"] = int(Game.session.get("ruined", 0)) + 1
		if sim.ruin_reason == "escaped":
			_toast("The Cursed Oyster escaped and bit someone.")
		if active_ticket != null:
			_spawn_from_active()
	if is_instance_valid(oyster):
		oyster.queue_free()

func _on_oyster_binned(oyster: OysterNode) -> void:
	oysters.erase(oyster)
	Game.session["ruined"] = int(Game.session.get("ruined", 0)) + 1

func _collect_pearls(sim: OysterSim) -> void:
	if sim.pearls.is_empty():
		return
	var no_pearl := active_ticket != null and active_ticket.modifier != null and active_ticket.modifier.no_pearl
	if no_pearl:
		sim.pearls_forfeited = true
		_toast("No pearl on this order. The house keeps it.")
		return
	for p in sim.pearls:
		pearls_found.append(p)
		pearls_value += p.value
	Game.add_pearls(sim.pearls)
	Sfx.play("plink")
	var p0: Pearl = sim.pearls[0]
	var colour_name: String = Registry.pearl_config.colours[p0.colour]
	var shape_name: String = Registry.pearl_config.shapes[p0.shape]
	_subtitle("PEARL — %s %s, %.1f mm, %s" % [colour_name, shape_name.to_lower(), p0.size,
		p0.trait_id.replace("_", " ")], 4.0)
	Game.bump_stat("pearls")

func _serve_from_plate() -> void:
	if plate == null or plate.portions.is_empty():
		_toast("Nothing plated yet.")
		return
	if active_ticket == null or active_ticket.completed or active_ticket.walked_out:
		_toast("Take a ticket off the rail first.")
		return
	var portion := plate.take_one()
	if portion.is_empty():
		return
	var sim: OysterSim = portion.sim
	var grade: String = portion.grade
	var species: SpeciesData = portion.species
	active_ticket.serve(grade, 1, species.id)
	Game.session["served"] = int(Game.session.get("served", 0)) + 1
	Game.session["grades"][grade] = int(Game.session["grades"].get(grade, 0)) + 1
	if active_ticket.patience_left < Registry.balance.last_call_badge_window:
		late_serve = true
	Sfx.play("coin", -4.0)
	if active_ticket.completed:
		_finish_active()

func _finish_active() -> void:
	if active_ticket == null:
		return
	var t := active_ticket
	var card := active_card
	var p := t.payout(Registry.species, pier, Registry.grade_data, Game.tip_bonus())
	var mult := _tide_product("payout_mult")
	p.base = roundi(float(p.base) * mult)
	p.tip = roundi(float(p.tip) * mult)
	p.total = int(p.base) + int(p.tip)
	earnings += int(p.base)
	tips += int(p.tip)
	Game.session["earnings"] = int(Game.session.get("earnings", 0)) + int(p.base)
	Game.session["tips"] = int(Game.session.get("tips", 0)) + int(p.tip)
	_toast("Ticket #%d paid ¢%d  (¢%d + ¢%d tip)" % [t.id, p.total, p.base, p.tip])
	if card != null:
		cards.erase(card)
		card.queue_free()
	active_ticket = null
	active_card = null
	for c in cards:
		c.set_active(false)
	Sfx.play("money")

func _on_walked_out(card: TicketCard) -> void:
	if card.ticket == active_ticket:
		active_ticket = null
		active_card = null
		_clear_bench()
	if card in cards:
		cards.erase(card)
	card.queue_free()
	walked_out += 1
	Game.session["walked_out"] = int(Game.session.get("walked_out", 0)) + 1
	_toast("Walked out. One star gone.")
	Sfx.play("fail")

func _clear_bench() -> void:
	for o in oysters.duplicate():
		if is_instance_valid(o) and not o.held:
			o.sim.abandon()
			o.queue_free()
	oysters.clear()

# ------------------------------------------------------------------ boss
func _start_boss() -> void:
	boss_time = pier.boss_seconds
	var sp := Registry.get_species(pier.boss_species)
	if sp == null:
		sp = Registry.get_species("king_oyster")
	var sim := OysterSim.new(sp, Registry.balance, Registry.grade_data, rng)
	sim.knife_tier_bonus = Registry.balance.knife_t4_score_bonus if Game.tier("knife") >= 4 else 0
	var luck := 1.0 + (Registry.balance.lamp_pearl_bonus if Game.tier("floor") >= 5 else 0.0)
	sim.setup_pearls(PearlRoller.roll(rng, minf(1.0, sp.pearl_chance * luck), pier.id))
	boss_oyster = OysterNode.new()
	boss_oyster.setup(sp, sim, 0)
	boss_oyster.position = Vector3(0, 1.12, -0.95)
	boss_oyster.scale = Vector3(1.8, 1.8, 1.8)
	boss_oyster.expired.connect(_on_boss_binned)
	bench_root.add_child(boss_oyster)
	oysters.append(boss_oyster)
	_subtitle(Data.t("BOSS_INTRO", "The King Oyster. Three minutes."), 4.0)
	Sfx.play("beep")

func _process_boss(dt: float) -> void:
	if boss_finished:
		return
	boss_time -= dt
	if boss_time <= 0.0:
		_finish_boss(false)

func _on_boss_binned(_o: OysterNode) -> void:
	_finish_boss(false)

func _finish_boss(won: bool) -> void:
	if boss_finished:
		return
	boss_finished = true
	boss_done = won
	if won:
		Sfx.play("money")
		_subtitle(Data.t("BOSS_WIN", "The King comes apart. Something is inside."), 5.0)
		var named_id: String = pier.named_pearl
		var np := Pearl.new()
		np.shape = 0
		np.colour = 4
		np.lustre = 5
		np.size = 12.8
		np.trait_id = "common"
		np.pier = pier.id
		np.named = named_id
		np.value = 1500
		for d in Registry.pearl_config.named_pearls:
			if str(d.get("id", "")) == named_id:
				np.value = 2500
		pearls_found.append(np)
		pearls_value += np.value
		Game.add_pearls([np])
		var bosses: Array = Game.state.get("bosses", [])
		if not bosses.has(pier.id):
			bosses.append(pier.id)
		Game.state["bosses"] = bosses
		earnings += roundi(200.0 * pier.price_scale * _tide_product("payout_mult"))
	else:
		_subtitle(Data.t("BOSS_LOSE", "It got away. The ledger will remember."), 4.0)
		Sfx.play("fail")
	ended = false
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void:
		if not ended:
			_end_shift())

# ------------------------------------------------------------------ chaos
func _process_chaos(dt: float) -> void:
	if chaos_done or boss_mode:
		return
	if elapsed >= chaos_at:
		_trigger_chaos()

func _pick_chaos() -> ChaosData:
	var total := 0.0
	for i in Registry.chaos.size():
		var w := 1.0
		if i < pier.chaos_weights.size():
			w = pier.chaos_weights[i]
		total += maxf(0.0, w)
	var r := rng.randf() * total
	var acc := 0.0
	for i in Registry.chaos.size():
		var w := 1.0
		if i < pier.chaos_weights.size():
			w = pier.chaos_weights[i]
		acc += maxf(0.0, w)
		if r <= acc:
			return Registry.chaos[i]
	return Registry.chaos[0]

func _trigger_chaos() -> void:
	chaos_done = true
	var c := _pick_chaos()
	_subtitle(Data.t(c.subtitle_key, Data.t(c.name_key, c.id)), 4.0)
	Sfx.play("beep")
	var timer := get_tree().create_timer(c.telegraph_seconds)
	timer.timeout.connect(func() -> void: _apply_chaos(c))

func _apply_chaos(c: ChaosData) -> void:
	if ended:
		return
	Sfx.play("gull" if c.effect in ["gull", "crab"] else "splash")
	match c.effect:
		"gull":
			_spawn_thief(true)
		"crab":
			_spawn_thief(false)
		"dark":
			_set_lights(0.0)
			_subtitle(Data.t("CHAOS_POWER_CUT_SUB", "The lamp dies. Shuck by feel."), 4.0)
			var t := get_tree().create_timer(c.duration)
			t.timeout.connect(func() -> void: _set_lights(1.0))
		"wave":
			for o in oysters.duplicate():
				if is_instance_valid(o) and not o.held:
					o.sim.abandon()
					o.queue_free()
			oysters.clear()
			_subtitle(Data.t("CHAOS_WAVE_SUB", "A rogue wave takes the bench."), 3.0)
			_shake(16.0)
		"rival":
			for card in cards.duplicate():
				if card.ticket != active_ticket:
					cards.erase(card)
					card.queue_free()
					_toast("A rival van stole a ticket off the rail.")
					break
		"scream":
			var sid := "cursed_oyster"
			var sp := Registry.get_species(sid)
			if sp != null and oysters.size() < 4:
				var sim := OysterSim.new(sp, Registry.balance, Registry.grade_data, rng)
				sim.setup_pearls(PearlRoller.roll(rng, sp.pearl_chance, pier.id))
				var node := OysterNode.new()
				node.setup(sp, sim, oysters.size())
				node.position = bench_positions[mini(3, oysters.size())]
				bench_root.add_child(node)
				oysters.append(node)
		_:
			_subtitle(Data.t(c.subtitle_key, Data.t(c.name_key, c.id)), 3.0)
	if c.effect == "brine_spill" or c.effect == "slick":
		slick_timer = c.duration
		_subtitle(Data.t("CHAOS_BRINE_SPILL_SUB", "The floor is slick."), 3.0)

func _spawn_thief(winged: bool) -> void:
	var victim: OysterNode
	for o in oysters:
		if is_instance_valid(o) and not o.held:
			victim = o
			break
	if victim == null:
		_subtitle(Data.t("CHAOS_NOTHING_TO_TAKE", "Nothing on the bench to take."), 2.0)
		return
	var pos := victim.global_position
	var mesh := MeshFactory.oyster(victim.species, false, false)
	victim.sim.abandon()
	oysters.erase(victim)
	victim.queue_free()
	Game.session["gulled"] = int(Game.session.get("gulled", 0)) + 1
	if winged:
		var gull: Gull = Gull.new()
		add_child(gull)
		gull.setup(Vector3(9, 5, -6), pos, func() -> Node3D:
			return mesh)
	else:
		var crab := MeshFactory.crab()
		crab.position = pos
		add_child(crab)
		var tw := create_tween()
		tw.tween_property(crab, "position", pos + Vector3(4.0, 0.0, 2.0), 2.2)
		tw.tween_callback(crab.queue_free)
	_subtitle(Data.t("CHAOS_TAKEN_SUB", "Something took an oyster."), 2.5)
	Sfx.play("gull")

func _set_lights(factor: float) -> void:
	for l in lights:
		if is_instance_valid(l):
			if not l.has_meta("base_energy"):
				l.set_meta("base_energy", l.light_energy)
			l.light_energy = float(l.get_meta("base_energy")) * factor
	if refs.has("env"):
		if not refs.env.has_meta("base_ambient"):
			refs.env.set_meta("base_ambient", refs.env.ambient_light_energy)
		refs.env.ambient_light_energy = float(refs.env.get_meta("base_ambient")) * (factor if factor > 0.0 else 0.35)

func _shake(amount: float) -> void:
	if player:
		var base := player.position
		var tw := create_tween()
		for i in 5:
			tw.tween_property(player, "position", base + Vector3(randf_range(-0.04, 0.04) * amount * 0.1, 0, randf_range(-0.04, 0.04) * amount * 0.1), 0.04)
		tw.tween_property(player, "position", base, 0.05)

# ------------------------------------------------------------------ automation
func _process_automation(dt: float) -> void:
	var auto := Game.tier("auto")
	if auto < 2 or active_ticket == null or active_ticket.completed:
		return
	auto_timer += dt
	otto_timer += dt
	if auto >= 2 and auto_timer >= Registry.balance.auto_belt_interval:
		auto_timer = 0.0
		_spawn_from_active()
	if auto >= 4 and otto_timer >= Registry.balance.auto_otto_interval:
		otto_timer = 0.0
		_auto_shuck()

func _auto_shuck() -> void:
	if active_ticket == null or active_ticket.completed or active_ticket.walked_out:
		return
	if active_ticket.spawn_index >= active_ticket.species_ids.size() and active_ticket.served_portions >= active_ticket.portions_total:
		return
	var sid := str(active_ticket.species_ids[mini(active_ticket.spawn_index, active_ticket.species_ids.size() - 1)])
	var sp := Registry.get_species(sid)
	if sp == null:
		return
	var grade := Registry.balance.auto_max_grade
	# automation caps at B and halves pearl chance
	if rng.randf() < sp.pearl_chance * Registry.balance.automation_pearl_penalty:
		var p := PearlRoller.roll(rng, 1.0, pier.id)
		for pearl in p:
			pearls_found.append(pearl)
			pearls_value += pearl.value
			Game.add_pearls([pearl])
	active_ticket.serve(grade, 1, sp.id)
	Game.session["served"] = int(Game.session.get("served", 0)) + 1
	Game.session["grades"][grade] = int(Game.session["grades"].get(grade, 0)) + 1
	_toast("Otto shucks one. %s, half pearl odds." % grade)
	if active_ticket.completed:
		_finish_active()

# ------------------------------------------------------------------ endings
func _should_end() -> bool:
	if boss_mode:
		return boss_finished
	if time_left <= 0.0:
		return true
	if tickets_spawned >= tickets_total and cards.is_empty() and active_ticket == null:
		return true
	return false

func _end_shift() -> void:
	if ended:
		return
	ended = true
	if player != null:
		player.release_gesture()
	if active_ticket != null and not active_ticket.completed:
		active_ticket.walked_out = true
		active_ticket = null
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()
	_clear_bench()
	var total := earnings + tips
	var quota_met := boss_mode and boss_done
	if not boss_mode:
		quota_met = total >= quota
	stars = 0
	if quota_met:
		stars = clampi(3 - mini(2, walked_out), 1, 3)
		if boss_mode:
			stars = 3
	var xp := int(Registry.balance.xp_per_shift)
	for g in Game.session.get("grades", {}).keys():
		xp += int(Game.session["grades"][g]) * int(Registry.balance.xp_per_grade.get(g, 0))
	Game.add_xp(xp)
	var rank := int(Game.state.get("rank", 0))
	# pier progression
	var unlocked_next := false
	if quota_met:
		if pier.id < 6 and int(Game.state.get("pier", 1)) <= pier.id:
			Game.state["pier"] = pier.id + 1
			unlocked_next = true
		if pier.id == 6:
			Game.state["credits"] = true
	var badges := _award_badges(quota_met)
	var result := {
		"pier": pier.id,
		"pier_name": Data.t(pier.name_key, "Pier"),
		"base": earnings,
		"tips": tips,
		"total": total,
		"walked_out": walked_out,
		"pearls": pearls_found.size(),
		"pearl_value": pearls_value,
		"oysters": int(Game.session.get("oysters", 0)),
		"perfect": int(Game.session.get("perfect", 0)),
		"quota": quota,
		"quota_met": quota_met,
		"stars": stars,
		"xp": xp,
		"rank": rank,
		"grades": Game.session.get("grades", {}),
		"tides": tide_ids,
		"tide_key": _tide_key(),
		"boss": boss_mode,
		"boss_win": boss_done,
		"credits": bool(Game.state.get("credits", false)) and pier.id == 6,
		"unlocked_next": unlocked_next,
		"badges": badges,
		"daily": daily,
	}
	Game.record_shift(result)
	_show_ledger(result)

func _tide_key() -> String:
	var parts: Array[String] = []
	for t in tide_ids:
		parts.append(str(t))
	parts.sort()
	return "pier%d|%s|%s" % [pier.id, ",".join(parts), "daily" if daily else "free"]

func _award_badges(quota_met: bool) -> Array:
	var out: Array = []
	if Game.state.get("shifts", 0) == 0:
		if Game.award_badge("first_shift"):
			out.append("first_shift")
	if int(Game.session.get("perfect", 0)) >= Registry.balance.perfect_pops_badge_count:
		if Game.award_badge("clean_hands"):
			out.append("clean_hands")
	if not pearls_found.is_empty() and Game.award_badge("pearl_diver"):
		out.append("pearl_diver")
	if int(Game.session.get("gulled", 0)) > 0 and Game.award_badge("gulled"):
		out.append("gulled")
	if late_serve and Game.award_badge("last_call"):
		out.append("last_call")
	var showed := Game.displayed_pearls()
	if showed >= 12 and Game.award_badge("full_case"):
		out.append("full_case")
	for p in pearls_found:
		if p.trait_id == "mother_of_pearl" and Game.award_badge("mothers_day"):
			out.append("mothers_day")
	if Game.log_entries() >= 48 and Game.award_badge("the_log"):
		out.append("the_log")
	if Net.player_count() >= 4 and Game.award_badge("crew_of_four"):
		out.append("crew_of_four")
	if pier.id == 6 and quota_met and Game.award_badge("tidebreaker"):
		out.append("tidebreaker")
	if stars == 3 and quota_met:
		var ps: Dictionary = Game.state.get("pierStars", {})
		var key := str(pier.id)
		ps[key] = int(ps.get(key, 0)) + 1
		Game.state["pierStars"] = ps
		if int(ps[key]) >= 3 and Game.award_badge("whole_pier"):
			out.append("whole_pier")
	return out

func _show_ledger(result: Dictionary) -> void:
	player.set_locked(true)
	ledger = LedgerUI.new()
	add_child(ledger)
	ledger.setup(result)
	ledger.shop_pressed.connect(func() -> void: open_shop_requested.emit())
	ledger.next_pressed.connect(func() -> void: next_shift_requested.emit())
	ledger.lobby_pressed.connect(func() -> void: lobby_requested.emit())
	shift_finished.emit(result)

# ------------------------------------------------------------------ pause/photo
func _toggle_pause() -> void:
	if paused:
		_close_pause()
		return
	paused = true
	player.set_locked(true)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	pause_ui = Control.new()
	pause_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_ui)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(center)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := UiKit.vbox(10)
	panel.add_child(v)
	var title := UiKit.title(Data.t("PAUSE_TITLE", "PAUSED"), 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UiKit.button(Data.t("PAUSE_RESUME", "Resume"), _close_pause, 20, true))
	v.add_child(UiKit.label(Data.t("PAUSE_FOV", "Field of view"), 16, UiKit.MUTED))
	var settings: Dictionary = Game.state.get("settings", {})
	var fov_slider := HSlider.new()
	fov_slider.min_value = 60
	fov_slider.max_value = 100
	fov_slider.step = 1
	fov_slider.value = float(settings.get("fov", 75.0))
	fov_slider.value_changed.connect(func(v2: float) -> void:
		settings["fov"] = v2
		Game.state["settings"] = settings
		player.apply_settings())
	v.add_child(fov_slider)
	var bob := CheckBox.new()
	bob.text = Data.t("PAUSE_BOB", "Head bob")
	bob.button_pressed = bool(settings.get("head_bob", true))
	bob.toggled.connect(func(on: bool) -> void:
		settings["head_bob"] = on
		Game.state["settings"] = settings
		player.apply_settings())
	v.add_child(bob)
	var ghost_cb := CheckBox.new()
	ghost_cb.text = Data.t("PAUSE_GHOST", "Ghost hand hints")
	ghost_cb.button_pressed = bool(settings.get("ghost_hand", true))
	ghost_cb.toggled.connect(func(on: bool) -> void:
		settings["ghost_hand"] = on
		Game.state["settings"] = settings
		ghost = on and Game.state.get("shifts", 0) < 1)
	v.add_child(ghost_cb)
	var subs := CheckBox.new()
	subs.text = Data.t("PAUSE_SUBS", "Subtitles")
	subs.button_pressed = bool(settings.get("subtitles", true))
	subs.toggled.connect(func(on: bool) -> void:
		settings["subtitles"] = on
		Game.state["settings"] = settings)
	v.add_child(subs)
	v.add_child(UiKit.label(Data.t("PAUSE_PHOTO_HINT", "P — photo mode (freeze, hide UI)"), 14, UiKit.MUTED))
	v.add_child(UiKit.button(Data.t("PAUSE_QUIT", "Quit to lobby"), func() -> void:
		_close_pause()
		lobby_requested.emit(), 18))

func _close_pause() -> void:
	paused = false
	if pause_ui != null:
		pause_ui.get_parent().queue_free()
		pause_ui = null
	if not ended:
		player.set_locked(false)

func _toggle_photo() -> void:
	if not photo and player != null and player.is_gesturing():
		_toast("Finish the oyster first.")
		return
	photo = not photo
	photo_freeze = photo
	hud.hide_ui = photo
	overlay.visible = not photo
	player.set_locked(photo)
	if photo:
		_subtitle(Data.t("PHOTO_ON", "PHOTO MODE — P to return"), 30.0)
	else:
		subtitle_timer = 0.0

# ------------------------------------------------------------------ helpers
func _refresh_hud_prompt() -> void:
	if hud == null or player == null:
		return
	if player.is_gesturing():
		hud.prompt_text = ""
		return
	if player.focus != null and player.focus.can_interact(player):
		hud.prompt_text = player.focus.prompt_text()
		hud.prompt_key = "LMB"
	else:
		hud.prompt_text = ""

func _toast(text: String) -> void:
	if player != null:
		player.msg = text
		player.msg_timer = 2.6

func _subtitle(text: String, dur := 3.0) -> void:
	if not Game.state.get("settings", {}).get("subtitles", true):
		return
	subtitle = text
	subtitle_timer = dur

func _on_focus(target: Interactable) -> void:
	if hud == null:
		return
	hud.prompt_text = target.prompt_text() if target != null else ""

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
