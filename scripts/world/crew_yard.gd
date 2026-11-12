extends Node3D
class_name CrewYard
## Visible crew: the numbers in the CREW menu walk around each beach's crew outpost doing the job.
## Purely visual; production is in Empire.tick. Hires fill the best unlocked beach first
## (Empire.assignment), so when a new gate opens, workers walk along the boardwalk to it.
## Each worker runs a small job loop (walk, do the task, carry the result on) and reacts to
## its beach's real Dock Bin / Meat Crate, so dumping your bucket in puts idle Shuckers to work.

## Shown per beach (the real count can be higher; the HUD and menu show the numbers).
const MAX_SHOWN := {"deckhand": 5, "shucker": 4, "coordinator": 1, "rakebot": 3, "shuckbot": 3, "selldrone": 3}

## Local (per-beach) layout, x relative to the zone's left edge.
const GAP_X := 32.2          # gap in the boardwalk rail down to the flats
const RAIL_Z := 0.35
const WALK_Z := 2.2          # the boardwalk lane between beaches
const YARD_X := 29.0         # where crew step between the boardwalk and the outpost
const YARD_Z := 9.8
## Soft obstacles as local XZ boxes [center, half-size]; walkers are pushed out of them.
const OBSTACLES := [
	[Vector2(33, 8), Vector2(1.1, 0.9)],      # Dock Bin
	[Vector2(39, 8), Vector2(1.1, 0.9)],      # Meat Crate
	[Vector2(36, 12.6), Vector2(2.0, 0.5)],   # crew shuck bench
	[Vector2(41, 14), Vector2(0.75, 0.55)],   # market cart
	[Vector2(24, 6), Vector2(1.9, 1.9)],      # sell dock
	[Vector2(14, 6.8), Vector2(1.7, 0.8)],    # shuck shack
	[Vector2(4, 11.5), Vector2(1.8, 0.2)],    # beach name board
	[Vector2(34.5, 4), Vector2(0.1, 0.1)],    # lamp posts
	[Vector2(19.5, 4), Vector2(0.1, 0.1)],
	[Vector2(4.5, 4), Vector2(0.1, 0.1)],
]

var refs: Dictionary
var npcs: Dictionary = {}     # id -> Array[CrewNpc]
var label_t := 0.0
var synced_once := false

func setup(p_refs: Dictionary) -> void:
	refs = p_refs

func _ready() -> void:
	Game.changed.connect(_sync)
	Game.reshelled.connect(_sync)
	_sync()

func _sync() -> void:
	var e := Game.empire
	var asg := e.assignment()
	var nz := Catalog.ZONES.size()
	for c in Catalog.CREW:
		var id := str(c.id)
		var by_zone: Array = []
		for z in nz:
			by_zone.append([])
		for n in npcs.get(id, []):
			by_zone[(n as CrewNpc).zone_i].append(n)
		# surplus workers leave their beach...
		var pool: Array = []
		for z in nz:
			var want := _want(e, asg, id, z)
			while (by_zone[z] as Array).size() > want:
				pool.append((by_zone[z] as Array).pop_back())
		# ...and fill the gaps, best beach first, before anyone new is hired in
		for z in range(nz - 1, -1, -1):
			var want := _want(e, asg, id, z)
			var list: Array = by_zone[z]
			while list.size() < want:
				if not pool.is_empty():
					var mover: CrewNpc = pool.pop_front()
					mover.idx = list.size()
					mover.move_to_zone(z)
					list.append(mover)
				else:
					var npc := CrewNpc.new()
					npc.setup(id, z, list.size(), refs, synced_once)
					add_child(npc)
					list.append(npc)
		for n in pool:
			(n as Node).queue_free()
		var all: Array = []
		for z in nz:
			for k in (by_zone[z] as Array).size():
				(by_zone[z][k] as CrewNpc).idx = k
				all.append(by_zone[z][k])
		npcs[id] = all
	synced_once = true

static func _want(e: Empire, asg: Dictionary, id: String, z: int) -> int:
	if z >= e.zones_unlocked:
		return 0
	return mini(int(asg[id][z]), int(MAX_SHOWN.get(id, 3)))

## How many visible workers of a type are on a beach (tests use this).
func shown_at(id: String, z: int) -> int:
	var n := 0
	for w in npcs.get(id, []):
		if (w as CrewNpc).zone_i == z:
			n += 1
	return n

func _process(_dt: float) -> void:
	label_t -= _dt
	if label_t > 0.0:
		return
	label_t = 0.3
	var e := Game.empire
	var cap := e.storage_capacity()
	var yards: Array = refs.get("yards", [])
	for z in yards.size():
		var y: Dictionary = yards[z]
		var b := float(e.bins[z])
		var c := float(e.crates[z])
		(y.bin_label as Label3D).text = "DOCK BIN\n%s / %s" % [Num.short(floor(b)), Num.short(cap)]
		(y.bin_label as Label3D).modulate = Color(1, 0.4, 0.4) if b >= cap - 0.5 else Color(0.6, 0.85, 1)
		(y.crate_label as Label3D).text = "MEAT CRATE\n%s / %s" % [Num.short(floor(c)), Num.short(cap)]
		(y.crate_label as Label3D).modulate = Color(1, 0.4, 0.4) if c >= cap - 0.5 else Color(1, 0.7, 0.6)


class CrewNpc extends Node3D:
	const TURN_RATE := 5.5        # rad/s
	const ACCEL := 6.0            # m/s²
	const RADIUS := 0.42          # personal space

	var id := ""
	var idx := 0
	var zone_i := 0
	var refs: Dictionary
	var model: Node3D
	var robot := false
	var flying := false
	var rng := RandomNumberGenerator.new()
	var bin := Vector3(33, 0, 8)
	var crate := Vector3(39, 0, 8)
	var bench := Vector3(36, 0, 12)
	var market := Vector3(41, 0, 14)

	var heading := 0.0
	var cur_speed := 0.0
	var base_speed := 3.0
	var work_k := 1.0
	var mode := "idle"            # walk | turn | act | wait | bot | fly
	var path: Array = []
	var face := INF
	var on_arrive := Callable()
	var act_kind := ""
	var act_t := 0.0
	var act_len := 1.0
	var on_done := Callable()
	var wait_pred := Callable()
	var wait_t := 0.0
	var desync := false
	var phase := 0.0
	var t := 0.0
	var carry: Node3D
	var carry_kind := ""
	# drone flight
	var fly_from := Vector3.ZERO
	var fly_to := Vector3.ZERO
	var fly_p := 0.0
	var fly_len := 1.0
	var outbound := true
	var hover_t := 0.0
	var stuck_t := 0.0

	func setup(p_id: String, p_zone: int, p_idx: int, p_refs: Dictionary, walk_in: bool) -> void:
		id = p_id
		idx = p_idx
		refs = p_refs
		rng.seed = hash(p_id) + p_idx * 31 + p_zone * 977
		zone_i = p_zone
		_load_zone()
		robot = bool(Catalog.crew(id).get("robot", false))
		match id:
			"deckhand":
				model = Figures.person(Color(0.62, 0.36, 0.22), Color(0.22, 0.24, 0.26), Color(0.75, 0.62, 0.25), Figures.SKIN, 0.85)
				model.get_node("ArmR").add_child(Figures.rake())
				base_speed = 3.0
			"rakebot":
				model = Figures.robot(Color(0.55, 0.42, 0.25))
				model.get_node("ArmR").add_child(Figures.rake(Color(0.3, 0.3, 0.32), Color(0.8, 0.62, 0.3)))
				base_speed = 4.2
			"shucker":
				model = Figures.person(Color(0.82, 0.8, 0.74), Color(0.2, 0.2, 0.22), Color(0, 0, 0, 0), Figures.SKIN, 0.85)
				base_speed = 3.0
			"shuckbot":
				model = Figures.robot(Color(0.42, 0.46, 0.48), Color(1, 0.6, 0.35))
				base_speed = 3.4
			"coordinator":
				model = Figures.person(Color(0.15, 0.15, 0.2), Color(0.12, 0.12, 0.15), Color(0, 0, 0, 0), Figures.SKIN, 0.9)
				model.get_node("ArmL").add_child(MeshFactory.box(Vector3(0.3, 0.4, 0.04), Color(0.7, 0.5, 0.3), Vector3(0, -0.7, -0.15)))
				base_speed = 2.4
			"selldrone":
				model = Figures.drone(Color(0.3, 0.35, 0.4))
				base_speed = 7.0
				flying = true
		add_child(model)
		t = rng.randf() * 10.0
		if walk_in and not flying:
			# new hires stroll over from the Hiring Hall, or arrive along the boardwalk further up the coast
			if zone_i <= 1:
				position = Vector3(17.0 + rng.randf_range(-1.0, 1.0), 0, 18.2)
			else:
				position = Vector3(WorldBuilder.zone_x(zone_i) + 1.5, 0, WALK_Z + rng.randf_range(-0.5, 0.5))
			heading = -PI * 0.5
			_start(false)
		else:
			desync = true
			_start(true)

	func _load_zone() -> void:
		var yards: Array = refs.get("yards", [])
		if zone_i < yards.size():
			var y: Dictionary = yards[zone_i]
			bin = y.bin_pos
			crate = y.crate_pos
			bench = y.crew_bench
			market = y.market
		else:
			var x0 := WorldBuilder.zone_x(zone_i)
			bin = Vector3(x0 + 33, 0, 8)
			crate = Vector3(x0 + 39, 0, 8)
			bench = Vector3(x0 + 36, 0, 12)
			market = Vector3(x0 + 41, 0, 14)

	## Reassigned to another beach: drop what you are doing and head there.
	func move_to_zone(z: int) -> void:
		if z == zone_i:
			return
		zone_i = z
		_load_zone()
		_set_carry("")
		desync = false
		if flying:
			outbound = false
			fly_from = position
			hover_t = 0.0
			_new_flight()
		else:
			_start(false)

	func _bin_amount() -> float:
		return float(Game.empire.bins[zone_i])

	func _crate_amount() -> float:
		return float(Game.empire.crates[zone_i])

	# ------------------------------------------------------------------ job loops
	func _start(snap: bool) -> void:
		match id:
			"deckhand", "rakebot": _go_rake(snap)
			"shucker": _go_fetch(snap)
			"coordinator": _go_crate(snap)
			"shuckbot":
				var slot := Vector3(bench.x - 1.2 + float(idx) * 1.2, 0, bench.z + 1.75)
				_route_to(slot, 0.0, _bot_ready, snap)
			"selldrone":
				outbound = true
				fly_from = crate + Vector3((float(idx) - 1.5) * 0.9, 3.0, 0)
				position = fly_from
				_new_flight()
				fly_p = rng.randf()

	func _bot_ready() -> void:
		mode = "bot"

	# deckhands / RakeBots: rake a spot on the flats → carry to the Dock Bin → dump
	func _go_rake(snap: bool) -> void:
		var spot := Vector3(WorldBuilder.zone_x(zone_i) + rng.randf_range(24.0, 41.0), 0, rng.randf_range(-8.0, -3.0))
		_route_to(spot, rng.randf_range(-0.5, 0.5), _do_rake, snap)

	func _do_rake() -> void:
		_act("rake", rng.randf_range(2.6, 3.8), _go_bin)

	func _go_bin() -> void:
		_set_carry("oyster")
		var slot := bin + Vector3((float(idx % 4) - 1.5) * 0.6 + (0.3 if robot else 0.0), 0, -1.6 - (0.25 if robot else 0.0))
		_route_to(slot, PI, _at_bin)

	func _at_bin() -> void:
		_wait(func() -> bool: return _bin_amount() < Game.empire.storage_capacity() - 0.5, _act.bind("dump", 0.8, _after_dump))

	func _after_dump() -> void:
		_set_carry("")
		_go_rake(false)

	# shuckers: fetch from the Dock Bin → shuck at the bench → drop meat in the crate
	func _bench_slot() -> Vector3:
		return Vector3(bench.x - 1.4 + float(idx) * 0.95, 0, bench.z - 0.6)

	func _go_fetch(snap := false) -> void:
		if _bin_amount() < 1.0:
			_route_to(_bench_slot(), PI, _idle_at_bench, snap)
			return
		_route_to(bin + Vector3((float(idx % 3) - 1.0) * 0.7, 0, 1.6), 0.0, _act.bind("grab", 0.7, _after_grab), snap)

	func _idle_at_bench() -> void:
		_wait(func() -> bool: return _bin_amount() >= 1.0, _go_fetch.bind(false))

	func _after_grab() -> void:
		_set_carry("oyster")
		_route_to(_bench_slot(), PI, _do_shuck)

	func _do_shuck() -> void:
		_act("shuck", rng.randf_range(2.6, 3.8), _after_shuck)   # same beat as a deckhand raking

	func _after_shuck() -> void:
		_set_carry("meat")
		_route_to(crate + Vector3((float(idx % 3) - 1.0) * 0.7, 0, 1.6), 0.0, _act.bind("dump", 0.7, _after_drop))

	func _after_drop() -> void:
		_set_carry("")
		_go_fetch(false)

	# coordinators: check the crate → haul a box to the market cart → come back
	func _go_crate(snap := false) -> void:
		_route_to(crate + Vector3(1.75, 0, 0), PI * 0.5, _at_crate, snap)

	func _at_crate() -> void:
		_act("inspect", rng.randf_range(1.2, 2.4), _check_crate)

	func _check_crate() -> void:
		if _crate_amount() >= 1.0:
			_act("grab", 0.7, _haul)
		else:
			_at_crate()

	func _haul() -> void:
		_set_carry("crate")
		_route_to(market + Vector3(-1.25, 0, rng.randf_range(-0.45, 0.45)), -PI * 0.5, _act.bind("dump", 0.8, _after_sale))

	func _after_sale() -> void:
		_set_carry("")
		_go_crate(false)

	# ------------------------------------------------------------------ task plumbing
	static func _region(z: float) -> int:
		if z < RAIL_Z:
			return 0            # the flats
		if z < 3.9:
			return 1            # the boardwalk
		return 2                # the outpost yard

	## Walk to dest, then turn to face face_h and call cb. Routes through the rail gap to reach the
	## flats and along the boardwalk to reach another beach, so nobody cuts through rails or shacks.
	func _route_to(dest: Vector3, face_h: float, cb: Callable, snap := false) -> void:
		if snap:
			position = dest
			heading = face_h if face_h != INF else heading
			model.rotation.y = heading
			path = []
			cb.call()
			return
		var pts: Array = []
		var hz := WorldBuilder.zone_at(position.x)
		var dz := WorldBuilder.zone_at(dest.x)
		var hx := WorldBuilder.zone_x(hz)
		var dx := WorldBuilder.zone_x(dz)
		var region := _region(position.z)
		var dregion := _region(dest.z)
		var gx := GAP_X + rng.randf_range(-0.45, 0.45)
		var lane := WALK_Z + rng.randf_range(-0.5, 0.5)
		if region == 0 and (dregion != 0 or hz != dz):
			pts.append(Vector3(hx + gx, 0, -1.2))
			pts.append(Vector3(hx + gx, 0, lane))
			region = 1
		if hz != dz:
			if region == 2:
				pts.append(Vector3(hx + YARD_X, 0, YARD_Z))
				pts.append(Vector3(hx + YARD_X, 0, lane))
			pts.append(Vector3(dx + (YARD_X if dregion == 2 else gx), 0, lane))
			if dregion == 2:
				pts.append(Vector3(dx + YARD_X, 0, YARD_Z))
			region = maxi(dregion, 1)
		if dregion == 0 and region != 0:
			pts.append(Vector3(dx + gx, 0, lane))
			pts.append(Vector3(dx + gx, 0, -1.2))
		pts.append(dest)
		path = pts
		stuck_t = 0.0
		face = face_h
		on_arrive = cb
		mode = "walk"

	func _act(kind: String, dur: float, cb: Callable) -> void:
		mode = "act"
		act_kind = kind
		act_len = maxf(0.2, dur / work_k)
		act_t = act_len * (rng.randf() if desync else 1.0)
		desync = false
		on_done = cb

	func _wait(pred: Callable, cb: Callable) -> void:
		if pred.call():
			cb.call()
			return
		mode = "wait"
		wait_pred = pred
		wait_t = 0.0
		on_done = cb

	func _set_carry(kind: String) -> void:
		if carry != null:
			carry.queue_free()
			carry = null
		carry_kind = kind
		var z := Catalog.zone(Game.empire.best_zone())
		var y := 0.9 if robot else 1.32
		match kind:
			"oyster":
				carry = MeshFactory.oyster(z.shell, z.meat, false)
				carry.scale = Vector3.ONE * 0.8
			"meat":
				carry = MeshFactory.oyster(z.shell, z.meat, true)
				carry.scale = Vector3.ONE * 0.8
			"crate":
				carry = MeshFactory.crate(Vector3(0.55, 0.4, 0.5), Color(0.6, 0.35, 0.3))
		if carry != null:
			carry.position = Vector3(0, y, -0.62)
			model.add_child(carry)

	# ------------------------------------------------------------------ frame
	func _process(dt: float) -> void:
		t += dt
		var e := Game.empire
		work_k = clampf(sqrt(e.train_mult(id) * e.crew_mult()), 0.8, 2.4)
		match mode:
			"walk": _walk(dt)
			"turn": _turn(dt)
			"act":
				act_t -= dt
				_anim_act(dt, 1.0 - clampf(act_t / act_len, 0.0, 1.0))
				if act_t <= 0.0:
					mode = "idle"
					on_done.call()
			"wait":
				_anim_idle(dt)
				wait_t -= dt
				if wait_t <= 0.0:
					wait_t = 0.25
					if wait_pred.call():
						mode = "idle"
						on_done.call()
			"bot": _anim_bot(dt)
			"fly": _fly(dt)
			_: _anim_idle(dt)

	func _walk(dt: float) -> void:
		if path.is_empty():
			_arrived()
			return
		var target: Vector3 = path[0]
		var to := Vector3(target.x - position.x, 0, target.z - position.z)
		var dist := to.length()
		var last := path.size() == 1
		# someone else is standing on our spot: close enough is fine
		if last and dist < 0.7:
			stuck_t += dt
			if stuck_t > 1.2:
				path.clear()
				_arrived()
				return
		if (last and dist < 0.05) or (not last and dist < 0.8):
			path.pop_front()
			if path.is_empty():
				_arrived()
			return
		var want := atan2(-to.x, -to.z)
		heading = rotate_toward(heading, want, TURN_RATE * dt)
		var err := absf(angle_difference(heading, want))
		var vmax := base_speed * work_k
		var v := vmax * clampf(1.0 - err / 1.3, 0.0, 1.0)
		if last:
			v = minf(v, dist * 2.0 + 0.2)
		cur_speed = move_toward(cur_speed, v, ACCEL * work_k * dt)
		if last and dist < 0.35:
			position = position.move_toward(Vector3(target.x, position.y, target.z), maxf(cur_speed, 0.5) * dt)
		else:
			position += Vector3(-sin(heading), 0, -cos(heading)) * cur_speed * dt
		_separate(dt)
		_push_out()
		model.rotation.y = heading
		_anim_walk(dt)

	func _arrived() -> void:
		if face != INF and absf(angle_difference(heading, face)) > 0.05:
			mode = "turn"
			return
		mode = "idle"
		cur_speed = 0.0
		on_arrive.call()

	func _turn(dt: float) -> void:
		cur_speed = move_toward(cur_speed, 0.0, ACCEL * 2.0 * dt)
		heading = rotate_toward(heading, face, TURN_RATE * 0.8 * dt)
		model.rotation.y = heading
		phase += dt * 7.0
		_limb("LegL", sin(phase) * 0.18, dt, 18.0)
		_limb("LegR", -sin(phase) * 0.18, dt, 18.0)
		_settle(dt)
		if absf(angle_difference(heading, face)) <= 0.05:
			heading = face
			model.rotation.y = heading
			_arrived()

	## Keep a little personal space from other walkers nearby.
	func _separate(dt: float) -> void:
		for o in get_parent().get_children():
			if o == self or not (o is CrewNpc) or (o as CrewNpc).flying:
				continue
			if absf(o.position.x - position.x) > 1.0:
				continue
			var d := Vector2(position.x - o.position.x, position.z - o.position.z)
			var l := d.length()
			if l < RADIUS * 2.0 and l > 0.001:
				var push := d / l * (RADIUS * 2.0 - l) * clampf(dt * 6.0, 0.0, 1.0)
				position.x += push.x
				position.z += push.y

	func _push_out() -> void:
		var x0 := WorldBuilder.zone_x(WorldBuilder.zone_at(position.x))
		for ob in OBSTACLES:
			var c: Vector2 = ob[0] + Vector2(x0, 0)
			var h: Vector2 = ob[1] + Vector2(0.3, 0.3)
			var dx := position.x - c.x
			var dz := position.z - c.y
			if absf(dx) < h.x and absf(dz) < h.y:
				if h.x - absf(dx) < h.y - absf(dz):
					position.x = c.x + signf(dx if dx != 0.0 else 1.0) * h.x
				else:
					position.z = c.y + signf(dz if dz != 0.0 else 1.0) * h.y

	# ------------------------------------------------------------------ animation
	func _limb(n: String, x: float, dt: float, rate := 10.0) -> void:
		var l: Node3D = model.get_node_or_null(n)
		if l:
			l.rotation.x = lerpf(l.rotation.x, x, 1.0 - exp(-rate * dt))

	func _head(x: float, y: float, dt: float) -> void:
		var h: Node3D = model.get_node_or_null("Head")
		if h:
			var k := 1.0 - exp(-5.0 * dt)
			h.rotation.x = lerpf(h.rotation.x, x, k)
			h.rotation.y = lerpf(h.rotation.y, y, k)

	func _settle(dt: float) -> void:
		var k := 1.0 - exp(-8.0 * dt)
		model.position.y = lerpf(model.position.y, 0.0, k)
		model.rotation.x = lerpf(model.rotation.x, 0.0, k)

	func _carry_arms(dt: float, swing: float) -> void:
		if carry != null:
			_limb("ArmL", 1.25, dt)
			_limb("ArmR", 1.25, dt)
		elif id in ["deckhand", "rakebot"]:
			_limb("ArmL", -swing * 0.5, dt)
			_limb("ArmR", 0.35, dt)        # rake held at the ready
		else:
			_limb("ArmL", -swing * 0.5, dt, 14.0)
			_limb("ArmR", swing * 0.5, dt, 14.0)

	func _anim_walk(dt: float) -> void:
		_rake_tilt(-0.35, dt)
		var amp := clampf(cur_speed / maxf(0.1, base_speed), 0.0, 1.3)
		phase += cur_speed * dt * (3.2 if not robot else 2.0)
		var s := sin(phase)
		if robot:
			model.position.y = absf(sin(phase * 2.0)) * 0.025 * amp
			model.rotation.x = lerpf(model.rotation.x, -0.08 * amp, 1.0 - exp(-6.0 * dt))
		else:
			_limb("LegL", s * 0.62 * amp, dt, 22.0)
			_limb("LegR", -s * 0.62 * amp, dt, 22.0)
			model.position.y = absf(cos(phase)) * 0.05 * amp
			model.rotation.x = lerpf(model.rotation.x, -0.05 * amp, 1.0 - exp(-6.0 * dt))
		_carry_arms(dt, s * amp)
		_head(0.0, 0.0, dt)

	func _anim_idle(dt: float) -> void:
		cur_speed = 0.0
		_limb("LegL", 0.0, dt)
		_limb("LegR", 0.0, dt)
		if carry != null:
			_carry_arms(dt, 0.0)
		elif id == "shucker":
			_limb("ArmL", 0.45, dt, 4.0)      # leaning on the bench, waiting for oysters
			_limb("ArmR", 0.45, dt, 4.0)
		else:
			_limb("ArmL", 0.0, dt, 4.0)
			_limb("ArmR", 0.35 if id in ["deckhand", "rakebot"] else 0.0, dt, 4.0)
		_settle(dt)
		model.position.y = sin(t * 1.8 + float(idx)) * 0.008
		# glance around now and then
		_head(0.0, sin(t * 0.45 + float(idx) * 1.7) * 0.7 * clampf(sin(t * 0.21 + float(idx)) * 2.0, 0.0, 1.0), dt)

	## Rake angle relative to the arm: tines down on the mud while raking, level otherwise.
	func _rake_tilt(x: float, dt: float) -> void:
		var arm: Node3D = model.get_node_or_null("ArmR")
		var r: Node3D = arm.get_node_or_null("Rake") if arm else null
		if r:
			r.rotation.x = lerpf(r.rotation.x, x, 1.0 - exp(-8.0 * dt))

	func _anim_act(dt: float, p: float) -> void:
		if act_kind != "rake":
			_rake_tilt(-0.35, dt)
		_limb("LegL", 0.0, dt)
		_limb("LegR", 0.0, dt)
		match act_kind:
			"rake":
				var c := fmod(t * 1.25 * work_k, 1.0)
				var pull := sin(c * TAU)
				_limb("ArmR", 0.4 + pull * 0.25, dt, 14.0)
				_limb("ArmL", 0.5 + pull * 0.25, dt, 14.0)
				_rake_tilt(-1.15, dt)
				_limb("LegL", 0.28, dt)
				_limb("LegR", -0.18, dt)
				model.rotation.x = lerpf(model.rotation.x, -0.2 - pull * 0.08, 1.0 - exp(-10.0 * dt))
				model.position.y = lerpf(model.position.y, 0.0, 1.0 - exp(-8.0 * dt))
				_head(-0.3, 0.0, dt)
			"dump":
				var up := sin(p * PI)
				_limb("ArmL", 1.25 + up * 1.0, dt, 16.0)
				_limb("ArmR", 1.25 + up * 1.0, dt, 16.0)
				if carry != null:
					carry.position.y = (0.9 if robot else 1.32) + up * 0.35
					carry.rotation.x = -p * 1.4
				model.rotation.x = lerpf(model.rotation.x, -0.1 * up, 1.0 - exp(-10.0 * dt))
				_head(-0.2, 0.0, dt)
			"grab":
				var bend := sin(p * PI)
				_limb("ArmL", 0.4 + bend * 0.9, dt, 14.0)
				_limb("ArmR", 0.4 + bend * 0.9, dt, 14.0)
				model.rotation.x = lerpf(model.rotation.x, -0.38 * bend, 1.0 - exp(-12.0 * dt))
				_head(-0.4, 0.0, dt)
			"shuck":
				_limb("ArmL", 1.15, dt)
				_limb("ArmR", 1.0 + absf(sin(t * 6.5 * work_k)) * 0.7, dt, 24.0)
				model.rotation.x = lerpf(model.rotation.x, -0.08, 1.0 - exp(-6.0 * dt))
				if carry != null:
					carry.position.y = 1.1
				_head(-0.4, 0.0, dt)
			"inspect":
				_limb("ArmL", 1.0, dt)
				_limb("ArmR", 0.75 + sin(t * 7.0) * 0.08, dt, 16.0)
				_settle(dt)
				_head(-0.3 + sin(t * 0.8) * 0.15, sin(t * 0.6 + float(idx)) * 0.3, dt)

	func _anim_bot(dt: float) -> void:
		var busy := _bin_amount() >= 1.0
		if busy:
			_limb("ArmL", 1.2, dt, 14.0)
			_limb("ArmR", 1.2 + absf(sin(t * 10.0 * work_k)) * 0.8, dt, 30.0)
			_head(-0.3, sin(t * 3.0) * 0.08, dt)
		else:
			_limb("ArmL", 0.2, dt, 4.0)
			_limb("ArmR", 0.2, dt, 4.0)
			_head(0.0, sin(t * 0.7 + float(idx)) * 0.6, dt)
		model.position.y = sin(t * 2.2 + float(idx)) * 0.01

	# ------------------------------------------------------------------ drones
	func _new_flight() -> void:
		if outbound:
			fly_to = Vector3(crate.x + rng.randf_range(-12.0, 12.0), 9.0, -34.0)
		else:
			fly_to = crate + Vector3((float(idx) - 1.5) * 0.9, 3.0, 0)
		fly_len = maxf(1.0, fly_from.distance_to(fly_to) / base_speed)
		fly_p = 0.0
		mode = "fly"

	func _fly(dt: float) -> void:
		for p in model.get_children():
			if p.name.begins_with("Prop"):
				p.rotation.y += dt * 30.0
		if hover_t > 0.0:
			hover_t -= dt
			position.y += sin(t * 3.0) * 0.004
			model.rotation.x = lerpf(model.rotation.x, 0.0, 1.0 - exp(-4.0 * dt))
			return
		# home and the crate is empty: hover and wait
		if not outbound and fly_p >= 1.0:
			if _crate_amount() < 1.0:
				position.y = fly_to.y + sin(t * 2.0) * 0.08
				return
			outbound = true
			fly_from = position
			_new_flight()
		fly_p = minf(1.0, fly_p + dt * work_k / fly_len)
		var k := smoothstep(0.0, 1.0, fly_p)
		var prev := position
		position = fly_from.lerp(fly_to, k) + Vector3(0, sin(fly_p * PI) * 2.5, 0)
		var mv := Vector2(position.x - prev.x, position.z - prev.z)
		if mv.length() > 0.001:
			heading = rotate_toward(heading, atan2(-mv.x, -mv.y), 3.0 * dt)
		model.rotation.y = heading
		model.rotation.x = lerpf(model.rotation.x, -0.3 * sin(fly_p * PI), 1.0 - exp(-4.0 * dt))
		if fly_p >= 1.0:
			hover_t = 0.6
			if outbound:
				outbound = false
				fly_from = position
				_new_flight()
				hover_t = 0.6
			# back home: the next loop checks the crate
