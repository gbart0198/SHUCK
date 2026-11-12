extends RefCounted
class_name Figures
## Blocky characters, robots and pets. Primitives only; limbs are named pivots so a
## tiny animator can swing them (see Figures.animate_walk).

const SKIN := Color(0.62, 0.45, 0.35)

## A Roblox-ish blocky person. Children: Hip/LegL, Hip/LegR, Torso, ShoulderL/ArmL, ShoulderR/ArmR, Head, Hat.
static func person(shirt: Color, pants: Color, hat := Color(0, 0, 0, 0), skin := SKIN, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Person"
	root.scale = Vector3.ONE * scale
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.name = "LegL" if side < 0 else "LegR"
		hip.position = Vector3(0.17 * side, 0.9, 0)
		hip.add_child(MeshFactory.box(Vector3(0.32, 0.9, 0.34), pants, Vector3(0, -0.45, 0)))
		hip.add_child(MeshFactory.box(Vector3(0.34, 0.12, 0.42), pants.darkened(0.45), Vector3(0, -0.86, -0.04)))
		root.add_child(hip)
	root.add_child(MeshFactory.box(Vector3(0.7, 0.8, 0.38), shirt, Vector3(0, 1.3, 0)))
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.name = "ArmL" if side < 0 else "ArmR"
		sh.position = Vector3(0.5 * side, 1.62, 0)
		sh.add_child(MeshFactory.box(Vector3(0.28, 0.78, 0.32), shirt.lightened(0.08), Vector3(0, -0.36, 0)))
		sh.add_child(MeshFactory.box(Vector3(0.26, 0.2, 0.3), skin, Vector3(0, -0.8, 0)))
		root.add_child(sh)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.98, 0)
	head.add_child(MeshFactory.box(Vector3(0.52, 0.5, 0.5), skin))
	# face
	head.add_child(MeshFactory.box(Vector3(0.07, 0.1, 0.02), Color(0.08, 0.08, 0.1), Vector3(-0.11, 0.05, -0.255)))
	head.add_child(MeshFactory.box(Vector3(0.07, 0.1, 0.02), Color(0.08, 0.08, 0.1), Vector3(0.11, 0.05, -0.255)))
	head.add_child(MeshFactory.box(Vector3(0.22, 0.04, 0.02), Color(0.08, 0.08, 0.1), Vector3(0, -0.1, -0.255)))
	if hat.a > 0.0:
		head.add_child(MeshFactory.cylinder(0.36, 0.05, hat.darkened(0.15), Vector3(0, 0.27, 0)))
		head.add_child(MeshFactory.cylinder(0.24, 0.24, hat, Vector3(0, 0.4, 0)))
	root.add_child(head)
	return root

static func animate_walk(body: Node3D, t: float, amount: float) -> void:
	var s := sin(t) * 0.75 * amount
	for n in ["LegL", "ArmR"]:
		var a: Node3D = body.get_node_or_null(n)
		if a:
			a.rotation.x = s
	for n in ["LegR", "ArmL"]:
		var b: Node3D = body.get_node_or_null(n)
		if b:
			b.rotation.x = -s

static func animate_swing(body: Node3D, k: float) -> void:
	# k 1 → 0 over the swing; arm goes up then chops down
	var arm: Node3D = body.get_node_or_null("ArmR")
	if arm:
		arm.rotation.x = -2.4 * sin(k * PI) if k > 0.0 else arm.rotation.x

## The rake you carry. Attach to ArmR.
static func rake(color := Color(0.55, 0.36, 0.2), head_color := Color(0.75, 0.78, 0.8)) -> Node3D:
	var root := Node3D.new()
	root.name = "Rake"
	root.add_child(MeshFactory.cylinder(0.04, 1.5, color, Vector3(0, -0.5, -0.45), Vector3(PI * 0.5, 0, 0)))
	root.add_child(MeshFactory.box(Vector3(0.6, 0.06, 0.08), head_color, Vector3(0, -0.5, -1.2)))
	for i in 5:
		root.add_child(MeshFactory.box(Vector3(0.04, 0.18, 0.04), head_color, Vector3(-0.24 + i * 0.12, -0.6, -1.2)))
	return root

static func robot(body_color: Color, eye := Color(0.2, 1.0, 1.0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Robot"
	root.add_child(MeshFactory.cylinder(0.32, 0.18, Color(0.15, 0.15, 0.17), Vector3(0, 0.18, 0), Vector3(0, 0, PI * 0.5)))
	root.add_child(MeshFactory.box(Vector3(0.9, 0.9, 0.7), body_color, Vector3(0, 0.82, 0)))
	root.add_child(MeshFactory.box(Vector3(0.7, 0.18, 0.04), Color(0.1, 0.1, 0.12), Vector3(0, 0.95, -0.36)))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.55, 0)
	head.add_child(MeshFactory.box(Vector3(0.6, 0.45, 0.5), body_color.lightened(0.15)))
	var visor := MeshFactory.box(Vector3(0.5, 0.14, 0.04), eye, Vector3(0, 0.03, -0.26))
	visor.material_override = MeshFactory.material(eye, 0.3, 0.0, eye)
	head.add_child(visor)
	head.add_child(MeshFactory.cylinder(0.02, 0.35, Color(0.6, 0.6, 0.6), Vector3(0, 0.38, 0)))
	var bulb := MeshFactory.sphere(0.06, Color(1, 0.3, 0.3), Vector3(0, 0.58, 0))
	bulb.material_override = MeshFactory.material(Color(1, 0.3, 0.3), 0.3, 0.0, Color(1, 0.2, 0.2))
	head.add_child(bulb)
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(0.55 * side, 1.1, 0)
		arm.add_child(MeshFactory.box(Vector3(0.16, 0.7, 0.16), Color(0.6, 0.62, 0.66), Vector3(0, -0.3, 0)))
		arm.add_child(MeshFactory.box(Vector3(0.26, 0.12, 0.26), Color(0.3, 0.3, 0.32), Vector3(0, -0.7, 0)))
		root.add_child(arm)
	return root

static func drone(color: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(MeshFactory.box(Vector3(0.7, 0.22, 0.7), color))
	var eye := MeshFactory.sphere(0.1, Color(0.2, 1, 0.6), Vector3(0, -0.08, -0.36))
	eye.material_override = MeshFactory.material(Color(0.2, 1, 0.6), 0.2, 0.0, Color(0.2, 1, 0.6))
	root.add_child(eye)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			root.add_child(MeshFactory.cylinder(0.04, 0.12, Color(0.3, 0.3, 0.3), Vector3(x * 0.42, 0.12, z * 0.42)))
			var prop := MeshFactory.cylinder(0.24, 0.02, Color(0.85, 0.85, 0.9, 1.0), Vector3(x * 0.42, 0.19, z * 0.42))
			prop.name = "Prop"
			root.add_child(prop)
	root.add_child(MeshFactory.crate(Vector3(0.36, 0.3, 0.36), Color(0.55, 0.38, 0.22)))
	root.get_child(root.get_child_count() - 1).position = Vector3(0, -0.36, 0)
	return root

## Small floaty pet models. Each gets googly eyes so they read as characters.
static func pet(id: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Pet"
	match id:
		"hermit":
			var c := MeshFactory.crab()
			c.scale = Vector3.ONE * 1.8
			root.add_child(c)
			root.add_child(MeshFactory.shell(0.22, 0.26, 0.24, Color(0.95, 0.85, 0.7)))
			root.get_child(1).position = Vector3(0, 0.08, 0.05)
			_eyes(root, Vector3(0, 0.2, -0.22), 0.05)
		"gull":
			var g := MeshFactory.gull()
			g.scale = Vector3.ONE * 1.4
			root.add_child(g)
		"starfish":
			for i in 5:
				var a := TAU * float(i) / 5.0
				root.add_child(MeshFactory.box(Vector3(0.12, 0.08, 0.34), color, Vector3(sin(a) * 0.16, 0, cos(a) * 0.16), Vector3(0, a, 0)))
			_eyes(root, Vector3(0, 0.07, -0.02), 0.04)
		"narwhal":
			root.add_child(MeshFactory.sphere(0.24, color, Vector3.ZERO, Vector3(1.0, 0.85, 1.6)))
			root.add_child(MeshFactory.cylinder(0.03, 0.6, Color(1, 0.97, 0.85), Vector3(0, 0.08, -0.6), Vector3(PI * 0.5, 0, 0)))
			_eyes(root, Vector3(0, 0.1, -0.3), 0.05)
		"octopus", "kraken":
			var r := 0.24 if id == "octopus" else 0.34
			root.add_child(MeshFactory.sphere(r, color, Vector3(0, r * 0.6, 0), Vector3(1, 1.2, 1)))
			for i in 8:
				var a := TAU * float(i) / 8.0
				root.add_child(MeshFactory.box(Vector3(0.06, 0.06, r * 1.4), color.darkened(0.15),
					Vector3(sin(a) * r * 0.9, -r * 0.2, cos(a) * r * 0.9), Vector3(0.6, a, 0)))
			_eyes(root, Vector3(0, r * 0.8, -r * 0.85), 0.06 if id == "octopus" else 0.09)
			if id == "kraken":
				var crown := MeshFactory.cylinder(0.16, 0.1, Color(1, 0.85, 0.2), Vector3(0, r * 1.75, 0))
				crown.material_override = MeshFactory.material(Color(1, 0.85, 0.2), 0.2, 0.8, Color(0.6, 0.45, 0.1))
				root.add_child(crown)
		"lobster":
			root.add_child(MeshFactory.sphere(0.2, color, Vector3.ZERO, Vector3(1.0, 0.8, 1.8)))
			for side in [-1.0, 1.0]:
				root.add_child(MeshFactory.sphere(0.12, color.lightened(0.1), Vector3(0.26 * side, 0.02, -0.34), Vector3(1.0, 0.6, 1.4)))
			for m in root.get_children():
				(m as MeshInstance3D).material_override = MeshFactory.material(color, 0.15, 0.9, color * 0.35)
			_eyes(root, Vector3(0, 0.14, -0.3), 0.05)
		_:
			root.add_child(MeshFactory.sphere(0.24, color, Vector3.ZERO, Vector3(1.0, 0.9, 1.15)))
			if id == "puffer":
				for i in 10:
					var a := TAU * float(i) / 10.0
					root.add_child(MeshFactory.box(Vector3(0.04, 0.04, 0.14), color.darkened(0.25), Vector3(sin(a) * 0.25, cos(a * 2.0) * 0.08, cos(a) * 0.25), Vector3(0, a, 0)))
			if id == "otter" or id == "seal":
				root.add_child(MeshFactory.sphere(0.1, color.lightened(0.35), Vector3(0, -0.04, -0.22)))
			_eyes(root, Vector3(0, 0.08, -0.2), 0.05)
	return root

static func _eyes(root: Node3D, at: Vector3, r: float) -> void:
	for side in [-1.0, 1.0]:
		root.add_child(MeshFactory.sphere(r, Color.WHITE, at + Vector3(side * r * 1.4, 0, 0)))
		root.add_child(MeshFactory.sphere(r * 0.5, Color(0.05, 0.05, 0.08), at + Vector3(side * r * 1.4, 0, -r * 0.7)))
