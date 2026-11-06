extends RefCounted
class_name PierBuilder
## Procedural pier room. Six palettes, one kit (SPEC §13, §19).

static func build(parent: Node3D, pier: PierData) -> Dictionary:
	var refs := {}
	var root := Node3D.new()
	root.name = "PierEnvironment"
	parent.add_child(root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pier.sky_top
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pier.sky_bottom
	env.ambient_light_energy = pier.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = pier.fog_color
	env.fog_density = 0.012 + (0.02 if pier.low_gravity else 0.0)
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	refs["env"] = env

	var sun := DirectionalLight3D.new()
	sun.light_color = pier.light_color
	sun.light_energy = pier.light_energy
	sun.rotation_degrees = Vector3(-38, -62, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	refs["sun"] = sun

	# room shell
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	root.add_child(floor_body)
	var floor_cs := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8.0, 0.2, 8.0)
	floor_cs.shape = floor_shape
	floor_cs.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_cs)
	root.add_child(MeshFactory.box(Vector3(8, 0.2, 8), pier.wood_color.darkened(0.35), Vector3(0, -0.1, 0)))
	for i in 10:
		var plank := MeshFactory.box(Vector3(0.76, 0.02, 8), pier.wood_color.lightened(0.03 * (i % 3)),
			Vector3(-3.6 + i * 0.8, 0.01, 0))
		root.add_child(plank)

	_wall(root, Vector3(0, 1.6, -3.6), Vector3(8.2, 3.4, 0.2), pier.wall_color)
	_wall(root, Vector3(-4.0, 1.6, 0), Vector3(0.2, 3.4, 8.2), pier.wall_color.darkened(0.1))
	_wall(root, Vector3(4.0, 1.6, 0), Vector3(0.2, 3.4, 8.2), pier.wall_color.darkened(0.1))
	root.add_child(MeshFactory.box(Vector3(8.2, 0.18, 8.2), pier.wall_color.darkened(0.45), Vector3(0, 3.3, 0)))

	# window frame + water beyond
	var win := Vector3(-2.6, 1.9, -3.48)
	root.add_child(MeshFactory.box(Vector3(2.4, 1.5, 0.04), pier.sky_bottom.darkened(0.15), win))
	root.add_child(MeshFactory.box(Vector3(0.08, 1.6, 0.10), pier.wood_color, win + Vector3(-1.22, 0, 0)))
	root.add_child(MeshFactory.box(Vector3(0.08, 1.6, 0.10), pier.wood_color, win + Vector3(1.22, 0, 0)))
	root.add_child(MeshFactory.box(Vector3(2.52, 0.08, 0.10), pier.wood_color, win + Vector3(0, 0.78, 0)))
	root.add_child(MeshFactory.box(Vector3(2.52, 0.08, 0.10), pier.wood_color, win + Vector3(0, -0.78, 0)))
	root.add_child(MeshFactory.box(Vector3(0.06, 1.55, 0.06), pier.wood_color, win))
	var water := MeshFactory.box(Vector3(40, 0.04, 30), pier.water_color, Vector3(-2.6, -0.6, -14.0))
	root.add_child(water)
	refs["water"] = water
	for i in 5:
		var wave := MeshFactory.box(Vector3(3.0 + i, 0.02, 0.12), pier.water_color.lightened(0.2),
			Vector3(-8.0 + i * 3.4, -0.56, -8.0 - i * 1.4))
		root.add_child(wave)

	# counter (static, blocks walking through)
	var counter_body := StaticBody3D.new()
	counter_body.collision_layer = 1
	root.add_child(counter_body)
	var counter_cs := CollisionShape3D.new()
	var counter_shape := BoxShape3D.new()
	counter_shape.size = Vector3(4.8, 1.05, 0.95)
	counter_cs.shape = counter_shape
	counter_cs.position = Vector3(0, 0.52, -1.05)
	counter_body.add_child(counter_cs)
	root.add_child(MeshFactory.box(Vector3(4.8, 1.0, 0.9), pier.wood_color.darkened(0.2), Vector3(0, 0.5, -1.05)))
	root.add_child(MeshFactory.box(Vector3(4.9, 0.09, 1.0), pier.wood_color.lightened(0.12), Vector3(0, 1.04, -1.02)))

	# chalkboard and neon sign
	var board := MeshFactory.box(Vector3(1.6, 0.9, 0.06), Color(0.08, 0.10, 0.09), Vector3(1.6, 2.05, -3.45))
	root.add_child(board)
	root.add_child(MeshFactory.box(Vector3(1.7, 0.06, 0.09), pier.wood_color, Vector3(1.6, 2.53, -3.44)))
	root.add_child(MeshFactory.box(Vector3(1.7, 0.06, 0.09), pier.wood_color, Vector3(1.6, 1.57, -3.44)))
	refs["board_pos"] = Vector3(1.6, 2.05, -3.35)

	var sign_mesh := MeshFactory.box(Vector3(2.6, 0.55, 0.10), pier.accent_color, Vector3(-1.4, 2.75, -3.42))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = pier.accent_color
	sm.emission_enabled = true
	sm.emission = pier.accent_color
	sm.emission_energy_multiplier = 0.8
	sign_mesh.material_override = sm
	root.add_child(sign_mesh)
	var sign_label := Label3D.new()
	sign_label.text = Data.t(pier.name_key, "THE PIER").to_upper()
	sign_label.font_size = 48
	sign_label.pixel_size = 0.0034
	sign_label.modulate = Color(1, 0.97, 0.9)
	sign_label.outline_size = 12
	sign_label.outline_modulate = Color(0.2, 0.05, 0.02)
	sign_label.position = Vector3(-1.4, 2.74, -3.34)
	root.add_child(sign_label)
	refs["sign_label"] = sign_label

	# hanging lamp over the counter
	var lamp := Node3D.new()
	lamp.position = Vector3(0, 2.95, -1.5)
	root.add_child(lamp)
	lamp.add_child(MeshFactory.cylinder(0.02, 0.55, Color(0.15, 0.14, 0.13), Vector3(0, 0.28, 0)))
	lamp.add_child(MeshFactory.cylinder(0.26, 0.16, pier.accent_color.darkened(0.2), Vector3(0, -0.02, 0)))
	var bulb := MeshFactory.sphere(0.09, Color(1, 0.88, 0.6), Vector3(0, -0.12, 0))
	bulb.material_override = MeshFactory.material(Color(1, 0.9, 0.65), 0.2, 0.0, Color(1, 0.8, 0.45))
	lamp.add_child(bulb)
	var omni := OmniLight3D.new()
	omni.light_color = pier.light_color
	omni.light_energy = 3.2 - pier.darkness * 2.0
	omni.omni_range = 6.5
	omni.position = Vector3(0, -0.15, 0)
	omni.shadow_enabled = true
	lamp.add_child(omni)
	refs["lamp"] = omni

	var fill_light := OmniLight3D.new()
	fill_light.light_color = pier.sky_bottom
	fill_light.light_energy = 0.9
	fill_light.omni_range = 11.0
	fill_light.position = Vector3(1.8, 2.9, 0.8)
	root.add_child(fill_light)
	refs["fill"] = fill_light

	# props
	var crate_spots := [Vector3(-3.3, 0.28, 1.2), Vector3(-3.2, 0.28, 2.0), Vector3(3.3, 0.28, 1.5)]
	for p in crate_spots:
		var c := MeshFactory.crate(Vector3(0.55, 0.5 + randf() * 0.2, 0.55), pier.wood_color.lightened(0.05))
		c.position = p
		c.rotation.y = randf() * 0.8
		root.add_child(c)
	for i in 3:
		var stool := Node3D.new()
		stool.position = Vector3(-2.2 + i * 2.2, 0.0, 1.5)
		stool.add_child(MeshFactory.cylinder(0.22, 0.06, pier.wood_color.lightened(0.15), Vector3(0, 0.55, 0)))
		for k in 3:
			var a := k * TAU / 3.0
			stool.add_child(MeshFactory.box(Vector3(0.04, 0.55, 0.04), pier.wood_color.darkened(0.2),
				Vector3(cos(a) * 0.15, 0.27, sin(a) * 0.15)))
		root.add_child(stool)
	for i in 5:
		var bottle := MeshFactory.cylinder(0.035, 0.16, Color(0.2, 0.45, 0.35).lightened(i * 0.06),
			Vector3(-3.6 + i * 0.28, 1.62, -1.8))
		root.add_child(bottle)
	for i in 2:
		var bucket := MeshFactory.cylinder(0.16, 0.26, Color(0.55, 0.57, 0.58), Vector3(3.3, 0.14, -1.6 + i * 0.4))
		root.add_child(bucket)
	var net := MeshFactory.cylinder(0.18, 0.7, Color(0.28, 0.33, 0.28), Vector3(-3.2, 1.3, -2.4), Vector3(0.3, 0, 0.2))
	root.add_child(net)
	# rope rail at the front
	for x in [-3.4, 3.4]:
		root.add_child(MeshFactory.box(Vector3(0.12, 1.0, 0.12), pier.wood_color, Vector3(x, 0.5, 3.5)))
	root.add_child(MeshFactory.box(Vector3(7.0, 0.06, 0.06), Color(0.55, 0.48, 0.36), Vector3(0, 0.95, 3.5)))

	# gulls perched outside
	for i in pier.gull_count:
		var g := MeshFactory.gull()
		g.position = Vector3(-3.0 + i * 1.4, 2.1 + (i % 2) * 0.4, -3.2)
		g.scale = Vector3(0.8, 0.8, 0.8)
		g.rotation.y = PI
		root.add_child(g)

	# relic, hidden behind the crates on pier 1 etc.
	if pier.relic_id != "":
		refs["relic_pos"] = Vector3(-3.15, 0.18, 2.55)
	refs["counter_top"] = 1.09
	refs["counter_z"] = -1.0
	return refs

static func _wall(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	parent.add_child(MeshFactory.box(size, color, pos))
