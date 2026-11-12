extends RefCounted
class_name WorldBuilder
## The coast: eight zones laid end to end along +X, each with a tidal mudflat, a shucking
## shack and a sell dock, joined by one long boardwalk and separated by gates you buy open.
## Art follows the original pier look: low-poly primitives, fog, dusk palettes, warm lamps.

const DEPTH_MIN := -15.0
const DEPTH_MAX := 31.0

static func zone_x(i: int) -> float:
	return float(i) * Catalog.ZONE_WIDTH

static func zone_spawn(i: int) -> Vector3:
	return Vector3(zone_x(i) + 9.5, 0.5, 2.5)

static func zone_at(x: float) -> int:
	return clampi(int(floor(x / Catalog.ZONE_WIDTH)), 0, Catalog.ZONES.size() - 1)

static func build(parent: Node3D) -> Dictionary:
	var refs := {"beds": [], "stations": [], "gates": {}, "yards": []}
	var root := Node3D.new()
	root.name = "World"
	parent.add_child(root)
	_environment(root, refs)
	var n := Catalog.ZONES.size()
	var total_w := Catalog.ZONE_WIDTH * float(n)
	_wall(root, Vector3(-1.0, 5, 8), Vector3(2, 10, 50))
	_wall(root, Vector3(total_w + 1.0, 5, 8), Vector3(2, 10, 50))
	_wall(root, Vector3(total_w * 0.5, 5, DEPTH_MAX + 1.0), Vector3(total_w + 4, 10, 2))
	_wall(root, Vector3(total_w * 0.5, 5, -13.5), Vector3(total_w + 4, 10, 1))
	# dunes / cliffs at the ends and along the back so the fog has something to swallow
	for side in [-1.0, 1.0]:
		var cx := -30.0 if side < 0.0 else total_w + 30.0
		root.add_child(MeshFactory.box(Vector3(60, 9, 70), Color(0.24, 0.22, 0.2), Vector3(cx, 3.5, 12)))
	for k in int(total_w / 9.0):
		var h := 3.0 + fmod(float(k) * 2.37, 4.0)
		var c := Catalog.zone(zone_at(float(k) * 9.0)).sand as Color
		root.add_child(MeshFactory.box(Vector3(10, h, 8), c.darkened(0.35), Vector3(float(k) * 9.0 + 4.5, h * 0.5 - 0.5, DEPTH_MAX + 4.5), Vector3(0, fmod(float(k), 3.0) * 0.08 - 0.08, 0)))
	for i in n:
		_zone(root, i, refs)
	_boardwalk(root, total_w)
	_hub(root, refs)
	return refs

static func _environment(root: Node3D, refs: Dictionary) -> void:
	var z := Catalog.zone(0)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = z.sky_top
	sky_mat.sky_horizon_color = z.sky_bottom
	sky_mat.ground_horizon_color = z.sky_bottom
	sky_mat.ground_bottom_color = z.water
	sky_mat.sun_angle_max = 8.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = z.sky_bottom
	env.ambient_light_energy = z.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = z.fog
	env.fog_density = 0.022
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	refs["env"] = env
	refs["sky"] = sky_mat
	var sun := DirectionalLight3D.new()
	sun.light_color = z.light
	sun.light_energy = z.light_energy
	sun.rotation_degrees = Vector3(-24, -62, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	root.add_child(sun)
	refs["sun"] = sun
	var sea := MeshFactory.box(Vector3(Catalog.ZONE_WIDTH * 12, 0.1, 300), z.water, Vector3(Catalog.ZONE_WIDTH * 4, -0.4, -164))
	sea.material_override = MeshFactory.material(z.water, 0.15, 0.2)
	root.add_child(sea)
	refs["sea"] = sea

## Blend the sky, fog and light toward the zone the player is standing in.
static func blend_atmosphere(refs: Dictionary, x: float, dt: float) -> void:
	var w := Catalog.ZONE_WIDTH
	var zf := clampf(x / w - 0.5, 0.0, float(Catalog.ZONES.size() - 1))
	var i0 := int(floor(zf))
	var i1 := mini(i0 + 1, Catalog.ZONES.size() - 1)
	# hold each zone's palette through its middle, cross-fade near the gates
	var t := smoothstep(0.35, 0.65, zf - float(i0))
	var a := Catalog.zone(i0)
	var b := Catalog.zone(i1)
	var k := clampf(dt * 2.0, 0.0, 1.0)
	var env: Environment = refs.env
	var sky: ProceduralSkyMaterial = refs.sky
	var sun: DirectionalLight3D = refs.sun
	sky.sky_top_color = sky.sky_top_color.lerp((a.sky_top as Color).lerp(b.sky_top, t), k)
	sky.sky_horizon_color = sky.sky_horizon_color.lerp((a.sky_bottom as Color).lerp(b.sky_bottom, t), k)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = sky.ground_bottom_color.lerp((a.water as Color).lerp(b.water, t), k)
	env.fog_light_color = env.fog_light_color.lerp((a.fog as Color).lerp(b.fog, t), k)
	env.ambient_light_color = env.ambient_light_color.lerp((a.sky_bottom as Color).lerp(b.sky_bottom, t), k)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, lerpf(float(a.ambient), float(b.ambient), t), k)
	sun.light_color = sun.light_color.lerp((a.light as Color).lerp(b.light, t), k)
	sun.light_energy = lerpf(sun.light_energy, lerpf(float(a.light_energy), float(b.light_energy), t), k)

static func _wall(root: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	root.add_child(b)
	return b

static func _solid(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.add_child(MeshFactory.box(size, color))
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	n.add_child(b)
	root.add_child(n)
	return n

## Painted-board lettering: cream text, dark outline, sits on a plank (not a billboard).
static func sign_text(text: String, size := 64, color := Color(0.94, 0.91, 0.83), pos := Vector3.ZERO, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.12, 0.07, 0.04)
	l.pixel_size = 0.0045
	l.position = pos
	l.rotation.y = rot_y
	return l

## A plank sign on two posts, readable from the +Z side (the boardwalk).
static func board(root: Node3D, pos: Vector3, text: String, wood: Color, accent: Color, width := 2.4, rot_y := 0.0, height := 2.4) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	for x in [-width * 0.45, width * 0.45]:
		n.add_child(MeshFactory.box(Vector3(0.1, height, 0.1), wood.darkened(0.25), Vector3(x, height * 0.5, 0)))
	n.add_child(MeshFactory.box(Vector3(width, 0.6, 0.08), wood.lightened(0.08), Vector3(0, height - 0.2, 0)))
	n.add_child(MeshFactory.box(Vector3(width, 0.06, 0.1), accent.darkened(0.2), Vector3(0, height - 0.53, 0.01)))
	n.add_child(sign_text(text, 64, Color(0.94, 0.91, 0.83), Vector3(0, height - 0.2, 0.05)))
	root.add_child(n)
	return n

static func lamp(root: Node3D, pos: Vector3, color: Color, energy := 2.6, rng := 7.0) -> OmniLight3D:
	var l := Node3D.new()
	l.position = pos
	root.add_child(l)
	l.add_child(MeshFactory.cylinder(0.015, 0.5, Color(0.15, 0.14, 0.13), Vector3(0, 0.25, 0)))
	l.add_child(MeshFactory.cylinder(0.2, 0.13, Color(0.3, 0.26, 0.22), Vector3(0, -0.02, 0)))
	var bulb := MeshFactory.sphere(0.07, Color(1, 0.88, 0.6), Vector3(0, -0.1, 0))
	bulb.material_override = MeshFactory.material(Color(1, 0.9, 0.65), 0.2, 0.0, Color(1, 0.8, 0.45))
	l.add_child(bulb)
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = rng
	omni.position = Vector3(0, -0.15, 0)
	l.add_child(omni)
	return omni

static func _zone(root: Node3D, i: int, refs: Dictionary) -> void:
	var z := Catalog.zone(i)
	var x0 := zone_x(i)
	var w := Catalog.ZONE_WIDTH
	var wood: Color = z.wood
	var zr := Node3D.new()
	zr.name = "Zone_%s" % z.id
	root.add_child(zr)
	var depth := DEPTH_MAX - DEPTH_MIN
	_solid(zr, Vector3(x0 + w * 0.5, -0.5, (DEPTH_MAX + DEPTH_MIN) * 0.5), Vector3(w, 1.0, depth), z.sand)
	# mudflat: darker wet ground, a sheet of shallow water, stones
	zr.add_child(MeshFactory.box(Vector3(w, 0.02, 14), (z.sand as Color).darkened(0.3), Vector3(x0 + w * 0.5, 0.005, -7)))
	var water := MeshFactory.box(Vector3(w, 0.04, 40), z.water, Vector3(x0 + w * 0.5, 0.03, -20.5))
	var wm := MeshFactory.material(z.water, 0.08, 0.2)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(z.water.r, z.water.g, z.water.b, 0.6)
	water.material_override = wm
	zr.add_child(water)
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + i
	for k in 10:
		var s := MeshFactory.sphere(rng.randf_range(0.2, 0.6), (z.sand as Color).darkened(0.45), Vector3(x0 + rng.randf_range(2, w - 2), 0.0, rng.randf_range(-12, -1)), Vector3(1.3, 0.5, 1.0))
		zr.add_child(s)
	# wooden posts marking the tideline, like an old pier
	for k in 7:
		var px := x0 + 3.0 + float(k) * (w - 6.0) / 6.0
		zr.add_child(MeshFactory.cylinder(0.14, 2.4, wood.darkened(0.3), Vector3(px, 0.6, -11.5)))
	var bed := OysterBed.new()
	bed.setup(i, Vector2(w - 8.0, 8.0), 14)
	bed.position = Vector3(x0 + w * 0.5, 0, -6.5)
	zr.add_child(bed)
	refs.beds.append(bed)
	var bench_pos := Vector3(x0 + 14, 0, 6)
	_bench(zr, bench_pos, wood, z.accent, z.light)
	var bench := Station.new().setup("bench", i, 2.6, "Shuck Bench", Vector3(3, 2, 2))
	bench.position = bench_pos
	zr.add_child(bench)
	refs.stations.append(bench)
	var sell_pos := Vector3(x0 + 24, 0, 6)
	_sell_dock(zr, sell_pos, wood)
	var sell := Station.new().setup("sell", i, 1.9, "Sell Dock", Vector3(3.6, 0.3, 3.6))
	sell.position = sell_pos
	zr.add_child(sell)
	refs.stations.append(sell)
	board(zr, Vector3(x0 + 4.0, 0, 11.5), str(z.name).to_upper(), wood, z.accent, 3.6, PI)
	_crew_yard(zr, i, refs)
	_decor(zr, i)
	if i > 0:
		var gate := Node3D.new()
		gate.name = "Gate_%d" % i
		gate.position = Vector3(x0, 0, 8)
		for zz in range(-22, 24, 3):
			gate.add_child(MeshFactory.cylinder(0.14, 2.2, wood.darkened(0.2), Vector3(0, 1.1, float(zz))))
		gate.add_child(MeshFactory.box(Vector3(0.08, 0.08, depth), Color(0.6, 0.52, 0.38), Vector3(0, 1.8, 0)))
		gate.add_child(MeshFactory.box(Vector3(0.08, 0.08, depth), Color(0.6, 0.52, 0.38), Vector3(0, 1.1, 0)))
		var haze := MeshFactory.box(Vector3(0.3, 6, depth), z.fog, Vector3(0, 3, 0))
		var hm := MeshFactory.material(z.fog, 1.0)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.albedo_color = Color(z.fog.r, z.fog.g, z.fog.b, 0.45)
		haze.material_override = hm
		gate.add_child(haze)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.6, 9, depth)
		cs.shape = sh
		cs.position = Vector3(0, 4.5, 0)
		body.add_child(cs)
		gate.add_child(body)
		# toll board, facing back toward the zone you're coming from (-X)
		var toll := Node3D.new()
		toll.position = Vector3(-0.4, 0, -2)
		toll.rotation.y = -PI * 0.5
		gate.add_child(toll)
		toll.add_child(MeshFactory.box(Vector3(2.8, 1.2, 0.08), wood.lightened(0.08), Vector3(0, 2.6, 0)))
		toll.add_child(sign_text("%s\n%s" % [str(z.name).to_upper(), Num.cash(float(z.gate))], 60, (z.accent as Color).lightened(0.3), Vector3(0, 2.6, 0.05)))
		lamp(toll, Vector3(0, 3.6, 0.3), z.light, 2.0, 5.0)
		zr.add_child(gate)
		refs.gates[i] = gate
		var st := Station.new().setup("gate", i, 3.5, "Gate", Vector3(1.2, 9, 30))
		st.position = Vector3(x0, 0, 8)
		zr.add_child(st)
		refs.stations.append(st)

static func _boardwalk(root: Node3D, total_w: float) -> void:
	var count := int(total_w / 1.1)
	for k in count:
		var x := 0.6 + float(k) * 1.1
		var wood: Color = Catalog.zone(zone_at(x)).wood
		root.add_child(MeshFactory.box(Vector3(1.0, 0.08, 3.2), wood.lightened(0.05 * float(k % 3)), Vector3(x, 0.04, 2.0)))
	for k in int(total_w / 4.0):
		var x := 2.0 + float(k) * 4.0
		var wood: Color = Catalog.zone(zone_at(x)).wood
		root.add_child(MeshFactory.cylinder(0.08, 0.9, wood.darkened(0.3), Vector3(x, 0.45, 0.35)))
	# the rail has a gap on every beach (local x 30.6..33.8) where the crew go down to the flats (CrewYard.GAP_X)
	var rail := Color(0.55, 0.48, 0.36)
	var from := 0.0
	for i in Catalog.ZONES.size():
		var x0 := zone_x(i)
		var to := x0 + 30.6
		root.add_child(MeshFactory.box(Vector3(to - from, 0.05, 0.05), rail, Vector3((from + to) * 0.5, 0.85, 0.35)))
		for gx in [x0 + 30.6, x0 + 33.8]:
			root.add_child(MeshFactory.cylinder(0.11, 1.1, Color(0.3, 0.22, 0.15), Vector3(gx, 0.55, 0.35)))
		from = x0 + 33.8
	root.add_child(MeshFactory.box(Vector3(total_w - from, 0.05, 0.05), rail, Vector3((from + total_w) * 0.5, 0.85, 0.35)))

static func _bench(root: Node3D, pos: Vector3, wood: Color, accent: Color, light: Color) -> void:
	var n := _solid(root, pos + Vector3(0, 0.5, 0.6), Vector3(3.0, 1.0, 1.0), wood.darkened(0.2))
	n.add_child(MeshFactory.box(Vector3(3.1, 0.09, 1.1), wood.lightened(0.12), Vector3(0, 0.54, 0)))
	var k := MeshFactory.knife(Color(0.8, 0.82, 0.84))
	k.position = Vector3(0.9, 0.6, 0)
	n.add_child(k)
	for j in 6:
		var s := MeshFactory.shell(0.2, 0.26, 0.07, Color(0.58, 0.58, 0.55))
		s.position = Vector3(-1.2 + j * 0.16, 0.6, (j % 3) * 0.12 - 0.12)
		s.rotation.y = j * 0.9
		n.add_child(s)
	n.add_child(MeshFactory.cylinder(0.16, 0.26, Color(0.55, 0.57, 0.58), Vector3(1.25, 0.68, 0.2)))
	for x in [-1.6, 1.6]:
		root.add_child(MeshFactory.box(Vector3(0.14, 2.8, 0.14), wood.darkened(0.25), pos + Vector3(x, 1.4, 1.35)))
	root.add_child(MeshFactory.box(Vector3(3.6, 0.1, 1.8), wood.darkened(0.1), pos + Vector3(0, 2.85, 0.75), Vector3(0.18, 0, 0)))
	root.add_child(MeshFactory.box(Vector3(3.3, 2.2, 0.08), wood.darkened(0.35), pos + Vector3(0, 1.6, 1.4)))
	var sm := MeshFactory.box(Vector3(1.6, 0.36, 0.06), accent, pos + Vector3(0, 2.5, 1.32))
	sm.material_override = MeshFactory.material(accent, 0.5, 0.0, accent * 0.6)
	root.add_child(sm)
	root.add_child(sign_text("SHUCK", 64, Color(1, 0.97, 0.9), pos + Vector3(0, 2.5, 1.28), PI))
	lamp(root, pos + Vector3(0, 2.4, 0.4), light, 2.6, 6.0)

static func _sell_dock(root: Node3D, pos: Vector3, wood: Color) -> void:
	for k in 5:
		root.add_child(MeshFactory.box(Vector3(3.6, 0.12, 0.66), wood.lightened(0.04 * float(k % 2)), pos + Vector3(0, 0.08, -1.4 + k * 0.7)))
	for x in [-1.7, 1.7]:
		for zz in [-1.6, 1.6]:
			root.add_child(MeshFactory.cylinder(0.1, 1.0, wood.darkened(0.3), pos + Vector3(x, 0.5, zz)))
	var crate := MeshFactory.crate(Vector3(0.6, 0.5, 0.6), wood.lightened(0.1))
	crate.position = pos + Vector3(-1.3, 0.4, -1.2)
	root.add_child(crate)
	root.add_child(MeshFactory.box(Vector3(0.1, 1.6, 0.1), Color(0.3, 0.3, 0.32), pos + Vector3(1.3, 0.9, -1.3)))
	root.add_child(MeshFactory.cylinder(0.3, 0.04, Color(0.6, 0.6, 0.6), pos + Vector3(1.3, 1.5, -1.0)))
	board(root, pos + Vector3(0, 0, -1.9), "SELL", wood, Color(0.45, 0.85, 0.55), 1.8)
	lamp(root, pos + Vector3(0, 2.8, -1.5), Color(1, 0.85, 0.6), 2.0, 5.0)

static func _decor(root: Node3D, i: int) -> void:
	var z := Catalog.zone(i)
	var x0 := zone_x(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + i
	for k in 10:
		var p := Vector3(x0 + rng.randf_range(3, Catalog.ZONE_WIDTH - 3), 0, rng.randf_range(14, 29))
		if i == 0 and p.z < 25.0:
			p.z = rng.randf_range(25.0, 29.0)
		elif p.x - x0 > 29.0 and p.z < 17.0:
			p.z = rng.randf_range(17.0, 29.0)   # keep the crew outpost clear
		match i:
			0, 7:
				if k % 2 == 0:
					var c := MeshFactory.crate(Vector3(0.6, 0.55, 0.6), (z.wood as Color).lightened(0.05))
					c.position = p + Vector3(0, 0.28, 0)
					c.rotation.y = rng.randf() * PI
					root.add_child(c)
				else:
					root.add_child(MeshFactory.sphere(1.2, (z.wood as Color).darkened(0.1), p + Vector3(0, 0.1, 0), Vector3(1.0, 0.35, 2.2)))
			1:
				root.add_child(MeshFactory.sphere(rng.randf_range(0.8, 1.8), Color(0.32, 0.31, 0.3), p, Vector3(1.3, 0.7, 1.0)))
			2:
				for s in 4:
					root.add_child(MeshFactory.box(Vector3(0.22, 1.3, 0.1), Color(0.22, 0.36, 0.22).lightened(s * 0.04), p + Vector3(0, 0.65 + s * 1.2, 0), Vector3(0, 0, sin(s) * 0.2)))
			3:
				for s in 3:
					root.add_child(MeshFactory.cylinder(0.12, rng.randf_range(0.8, 2.0), (z.accent as Color).darkened(0.3), p + Vector3(s * 0.3 - 0.3, 0.6, 0), Vector3(0, 0, (s - 1) * 0.35)))
			4:
				root.add_child(MeshFactory.cylinder(0.08, rng.randf_range(1.5, 3), (z.accent as Color).darkened(0.4), p + Vector3(0, 1, 0)))
				var glow := MeshFactory.sphere(0.12, z.accent, p + Vector3(0, 2.2, 0))
				glow.material_override = MeshFactory.material(z.accent, 0.3, 0.0, (z.accent as Color) * 0.8)
				root.add_child(glow)
			5:
				root.add_child(MeshFactory.sphere(rng.randf_range(0.8, 1.6), Color(0.12, 0.08, 0.08), p, Vector3(1.2, 0.8, 1.0)))
				var ember := MeshFactory.sphere(0.25, Color(1, 0.4, 0.15), p + Vector3(0, 0.6, 0))
				ember.material_override = MeshFactory.material(Color(1, 0.4, 0.15), 0.3, 0.0, Color(1, 0.3, 0.05))
				root.add_child(ember)
			6:
				root.add_child(MeshFactory.box(Vector3(0.5, rng.randf_range(3, 7), 0.5), Color(0.08, 0.08, 0.1), p + Vector3(0, 2, 0), Vector3(0, rng.randf() * PI, rng.randf_range(-0.2, 0.2))))
	# street lamps along the boardwalk
	for k in 3:
		var lx := x0 + 4.5 + float(k) * 15.0
		root.add_child(MeshFactory.box(Vector3(0.12, 3.2, 0.12), Color(0.18, 0.17, 0.16), Vector3(lx, 1.6, 4.0)))
		lamp(root, Vector3(lx, 3.3, 4.0), z.light, 1.6 if i < 6 else 2.4, 8.0)

# ------------------------------------------------------------------ HQ
static func _hub(root: Node3D, refs: Dictionary) -> void:
	var hub := Node3D.new()
	hub.name = "HQ"
	root.add_child(hub)
	var z := Catalog.zone(0)
	var wood: Color = z.wood
	_booth(hub, refs, "shop", Vector3(7, 0, 19), "TACKLE & TOOLS", wood, Color(0.35, 0.55, 0.62), "Upgrade Shop")
	_booth(hub, refs, "crew", Vector3(17, 0, 20), "HIRING HALL", wood, z.accent, "Crew HQ: hire workers and robots")
	_booth(hub, refs, "pets", Vector3(27, 0, 20), "CLAM HATCHERY", wood, Color(0.75, 0.45, 0.55), "Pet Clams: hatch pets with pearls")
	_booth(hub, refs, "reshell", Vector3(37, 0, 19), "PEARL MERCHANT", wood, Color(0.95, 0.8, 0.4), "Re-Shell: reset for a Golden Shell")
	var egg := MeshFactory.pearl(Color(0.95, 0.92, 0.88), 0.45)
	egg.position = Vector3(27, 1.6, 21.0)
	hub.add_child(egg)
	var big := MeshFactory.pearl(Color(1.0, 0.86, 0.5), 0.6)
	big.position = Vector3(37, 1.8, 20.0)
	hub.add_child(big)
	refs["shrine"] = big
	_bob(big, 0.25, 2.6)
	_bob(egg, 0.15, 1.9)
	# the Muddy Shallows crew outpost is built by _crew_yard like every other beach

## Every beach has a crew outpost behind the boardwalk: Dock Bin, crew shuck bench, Meat Crate
## and a market cart. Layout is the same on each beach, offset by the zone's x (CrewYard uses it).
static func _crew_yard(root: Node3D, i: int, refs: Dictionary) -> void:
	var z := Catalog.zone(i)
	var wood: Color = z.wood
	var x0 := zone_x(i)
	var bin_pos := Vector3(x0 + 33, 0, 8)
	var bin := MeshFactory.crate(Vector3(2.2, 1.2, 1.8), Color(0.24, 0.3, 0.32))
	bin.position = bin_pos + Vector3(0, 0.6, 0)
	root.add_child(bin)
	var crate_pos := Vector3(x0 + 39, 0, 8)
	var cr := MeshFactory.crate(Vector3(2.2, 1.2, 1.8), wood.lightened(0.1))
	cr.position = crate_pos + Vector3(0, 0.6, 0)
	root.add_child(cr)
	var bin_lbl := sign_text("DOCK BIN", 48, Color(0.75, 0.85, 0.9), bin_pos + Vector3(0, 1.6, -0.92), PI)
	root.add_child(bin_lbl)
	var crate_lbl := sign_text("MEAT CRATE", 48, Color(0.95, 0.8, 0.7), crate_pos + Vector3(0, 1.6, -0.92), PI)
	root.add_child(crate_lbl)
	var bin_st := Station.new().setup("bin", i, 2.5, "Dock Bin", Vector3(2.4, 1.6, 2.0))
	bin_st.position = bin_pos
	root.add_child(bin_st)
	refs.stations.append(bin_st)
	var bench := Vector3(x0 + 36, 0, 12)
	var market := Vector3(x0 + 41, 0, 14)
	_solid(root, Vector3(x0 + 36, 0.5, 12.6), Vector3(4, 1, 1), wood.darkened(0.15))
	root.add_child(MeshFactory.box(Vector3(4.1, 0.08, 1.1), wood.lightened(0.1), Vector3(x0 + 36, 1.04, 12.6)))
	_market_cart(root, market, wood)
	lamp(root, Vector3(x0 + 36, 2.8, 12.4), z.light, 2.2, 7.0)
	refs.yards.append({"bin_pos": bin_pos, "crate_pos": crate_pos, "crew_bench": bench, "market": market,
		"bin_label": bin_lbl, "crate_label": crate_lbl})

## The handcart coordinators load meat crates onto.
static func _market_cart(root: Node3D, pos: Vector3, wood: Color) -> void:
	root.add_child(MeshFactory.box(Vector3(1.4, 0.12, 1.0), wood.lightened(0.05), pos + Vector3(0, 0.55, 0)))
	for x in [-0.66, 0.66]:
		root.add_child(MeshFactory.box(Vector3(0.06, 0.35, 1.0), wood.darkened(0.1), pos + Vector3(x, 0.78, 0)))
	for z in [-0.45, 0.45]:
		root.add_child(MeshFactory.cylinder(0.32, 0.08, Color(0.2, 0.16, 0.12), pos + Vector3(0.1, 0.32, z * 1.2), Vector3(PI * 0.5, 0, 0)))
	root.add_child(MeshFactory.cylinder(0.03, 1.3, wood.darkened(0.2), pos + Vector3(1.15, 0.75, 0), Vector3(0, 0, 1.2)))
	for k in 3:
		var c := MeshFactory.crate(Vector3(0.5, 0.38, 0.45), Color(0.6, 0.35, 0.3))
		c.position = pos + Vector3(-0.3 + float(k % 2) * 0.55, 0.82 + float(k / 2) * 0.4, 0.05)
		root.add_child(c)
	root.add_child(sign_text("MARKET", 40, Color(0.95, 0.86, 0.7), pos + Vector3(0, 1.75, 0.0), PI))

static func _booth(root: Node3D, refs: Dictionary, kind: String, pos: Vector3, title: String, wood: Color, accent: Color, tip: String) -> void:
	# a small shack: counter facing the boardwalk (-Z), back wall, striped awning, name board
	_solid(root, pos + Vector3(0, 0.55, 0.9), Vector3(3.6, 1.1, 1.0), wood.darkened(0.15))
	root.add_child(MeshFactory.box(Vector3(3.7, 0.08, 1.1), wood.lightened(0.12), pos + Vector3(0, 1.12, 0.9)))
	_solid(root, pos + Vector3(0, 1.6, 2.6), Vector3(4.2, 3.2, 0.2), wood.darkened(0.3))
	for x in [-2.0, 2.0]:
		root.add_child(MeshFactory.box(Vector3(0.14, 3.0, 0.14), wood.darkened(0.25), pos + Vector3(x, 1.5, 0.4)))
	for s in 6:
		var c := accent if s % 2 == 0 else Color(0.9, 0.87, 0.8)
		root.add_child(MeshFactory.box(Vector3(0.72, 0.06, 2.4), c.darkened(0.15), pos + Vector3(-1.8 + s * 0.72, 3.05, 1.3), Vector3(-0.22, 0, 0)))
	root.add_child(MeshFactory.box(Vector3(3.4, 0.6, 0.08), wood.lightened(0.1), pos + Vector3(0, 3.55, 0.25)))
	root.add_child(sign_text(title, 60, Color(0.94, 0.91, 0.83), pos + Vector3(0, 3.55, 0.2), PI))
	lamp(root, pos + Vector3(0, 2.7, 1.1), Color(1, 0.82, 0.55), 2.2, 6.0)
	var st := Station.new().setup(kind, 0, 2.6, tip, Vector3(4, 3, 3))
	st.position = pos
	root.add_child(st)
	refs.stations.append(st)
	root.add_child(MeshFactory.cylinder(1.2, 0.03, wood.darkened(0.1), pos + Vector3(0, 0.02, -0.6)))

## Gentle forever-bob + spin so landmarks feel alive. Node must already be in the tree.
static func _bob(n: Node3D, amp: float, period: float) -> void:
	if not n.is_inside_tree():
		return
	var y := n.position.y
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "position:y", y + amp, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "position:y", y, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spin := n.create_tween().set_loops()
	spin.tween_property(n, "rotation:y", TAU, period * 3.0).from(0.0)
