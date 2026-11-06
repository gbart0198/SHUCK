extends RefCounted
class_name MeshFactory
## Every mesh is a Godot primitive assembled in code. No downloaded assets.

static func material(color: Color, rough := 0.85, metallic := 0.0, emission := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if emission.a > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 2.0
	return m

static func box(size: Vector3, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = material(color)
	mi.position = pos
	mi.rotation = rot
	return mi

static func sphere(radius: float, color: Color, pos := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = material(color)
	mi.position = pos
	mi.scale = scale
	return mi

static func cylinder(radius: float, height: float, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = material(color)
	mi.position = pos
	mi.rotation = rot
	return mi

static func quad(size: Vector2, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = material(color)
	mi.position = pos
	return mi

## An oyster in its closed or open state, built from two shell halves.
static func oyster(species: SpeciesData, open := false, with_pearl := false) -> Node3D:
	var root := Node3D.new()
	root.name = "OysterModel"
	var sc := species.mesh_scale
	var bottom := sphere(0.5, species.ridge_color, Vector3(0, 0.06, 0), sc)
	root.add_child(bottom)
	var top_pivot := Node3D.new()
	top_pivot.position = Vector3(0, 0.09, -0.45 * sc.z)
	top_pivot.rotation.x = deg_to_rad(-62.0 if open else 0.0)
	root.add_child(top_pivot)
	var top := sphere(0.5, species.shell_color, Vector3(0, 0, 0.45 * sc.z), sc)
	top_pivot.add_child(top)
	var hinge := cylinder(0.055, 0.16, species.ridge_color.darkened(0.2),
		Vector3(0, 0.10, -0.52 * sc.z), Vector3(0, 0, PI * 0.5))
	root.add_child(hinge)
	if open:
		var meat := sphere(0.30, species.meat_color, Vector3(0, 0.10, 0.05), Vector3(1.0, 0.42, 1.25))
		root.add_child(meat)
		for i in 3:
			var ridge := box(Vector3(0.03, 0.02, 0.5 * sc.z), species.ridge_color.darkened(0.12),
				Vector3(-0.28 + i * 0.28, 0.14, 0.06), Vector3(0, 0, 0.12 * (i - 1)))
			root.add_child(ridge)
		if with_pearl:
			var p := sphere(0.07, Color(0.97, 0.95, 0.88), Vector3(0.05, 0.16, 0.15))
			root.add_child(p)
	return root

static func meat(species: SpeciesData) -> MeshInstance3D:
	var m := sphere(0.26, species.meat_color, Vector3.ZERO, Vector3(1.0, 0.45, 1.2))
	return m

static func pearl(color: Color, radius := 0.09) -> MeshInstance3D:
	var m := material(color, 0.15, 0.3)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	var p := sphere(radius, color)
	p.material_override = m
	return p

static func plate(color := Color(0.95, 0.94, 0.90)) -> Node3D:
	var root := Node3D.new()
	root.add_child(cylinder(0.38, 0.035, color, Vector3.ZERO))
	root.add_child(cylinder(0.30, 0.04, Color(0.86, 0.88, 0.86), Vector3(0, 0.01, 0)))
	return root

static func knife(blade_color: Color, handle_color := Color(0.35, 0.22, 0.14)) -> Node3D:
	var root := Node3D.new()
	var blade := box(Vector3(0.034, 0.010, 0.30), blade_color, Vector3(0, 0, -0.17))
	blade.material_override = material(blade_color, 0.25, 0.85)
	root.add_child(blade)
	root.add_child(box(Vector3(0.03, 0.032, 0.15), handle_color, Vector3(0, -0.008, 0.05)))
	root.add_child(cylinder(0.012, 0.05, blade_color, Vector3(0, 0, -0.33), Vector3(PI * 0.5, 0, 0)))
	return root

static func hand(skin: Color, glove: Color) -> Node3D:
	var root := Node3D.new()
	var palm_color := glove if glove.a > 0.0 else skin
	root.add_child(box(Vector3(0.14, 0.07, 0.18), palm_color, Vector3.ZERO))
	for i in 4:
		var f := box(Vector3(0.028, 0.045, 0.13), palm_color.lerp(skin, 0.25),
			Vector3(-0.048 + i * 0.032, 0.0, -0.14), Vector3(-0.18, 0, 0))
		root.add_child(f)
	root.add_child(box(Vector3(0.05, 0.045, 0.09), palm_color.lerp(skin, 0.2),
		Vector3(0.085, 0.0, -0.05), Vector3(0, 0.6, 0.4)))
	root.add_child(box(Vector3(0.09, 0.11, 0.12), palm_color.darkened(0.15), Vector3(0, -0.02, 0.12)))
	return root

static func gull() -> Node3D:
	var root := Node3D.new()
	root.add_child(sphere(0.16, Color(0.96, 0.96, 0.94), Vector3.ZERO, Vector3(1.0, 0.85, 1.7)))
	root.add_child(sphere(0.10, Color(0.98, 0.98, 0.96), Vector3(0, 0.08, -0.24)))
	root.add_child(box(Vector3(0.06, 0.03, 0.10), Color(0.95, 0.65, 0.2), Vector3(0, 0.06, -0.36), Vector3(0.25, 0, 0)))
	root.add_child(box(Vector3(0.55, 0.02, 0.16), Color(0.88, 0.89, 0.88), Vector3(-0.28, 0.04, 0.0), Vector3(0, 0.2, 0.1)))
	root.add_child(box(Vector3(0.55, 0.02, 0.16), Color(0.88, 0.89, 0.88), Vector3(0.28, 0.04, 0.0), Vector3(0, -0.2, -0.1)))
	root.add_child(box(Vector3(0.10, 0.02, 0.10), Color(0.9, 0.55, 0.2), Vector3(0, 0.0, 0.22), Vector3(0.3, 0, 0)))
	return root

static func crab() -> Node3D:
	var root := Node3D.new()
	root.add_child(sphere(0.14, Color(0.72, 0.25, 0.18), Vector3.ZERO, Vector3(1.3, 0.6, 1.0)))
	for i in 3:
		root.add_child(box(Vector3(0.03, 0.02, 0.22), Color(0.65, 0.2, 0.15),
			Vector3(-0.16 - i * 0.04, 0.0, 0.0), Vector3(0, 0.4 - i * 0.4, 0)))
		root.add_child(box(Vector3(0.03, 0.02, 0.22), Color(0.65, 0.2, 0.15),
			Vector3(0.16 + i * 0.04, 0.0, 0.0), Vector3(0, -0.4 + i * 0.4, 0)))
	return root

static func crate(size := Vector3(0.55, 0.5, 0.55), color := Color(0.34, 0.24, 0.16)) -> Node3D:
	var root := Node3D.new()
	root.add_child(box(size, color))
	for x in [-1.0, 1.0]:
		root.add_child(box(Vector3(0.04, size.y * 1.02, 0.04), color.lightened(0.2), Vector3(x * size.x * 0.42, 0, size.z * 0.5)))
		root.add_child(box(Vector3(0.04, size.y * 1.02, 0.04), color.lightened(0.2), Vector3(x * size.x * 0.42, 0, -size.z * 0.5)))
	return root
