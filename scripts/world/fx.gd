extends RefCounted
class_name Fx
## Juice: floating numbers, coin bursts, sparkles. All tween-driven, all self-freeing.

static func float_text(parent: Node, pos: Vector3, text: String, color := Color(1, 0.9, 0.3), size := 64, rise := 2.2, life := 1.1) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = int(size * 0.22)
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.05, 0.08)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.006
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * 0.3
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", l.position + Vector3(0, rise, 0), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tw.tween_property(l, "outline_modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tw.chain().tween_callback(l.queue_free)

static func burst(parent: Node, pos: Vector3, color: Color, count := 10, spread := 2.5, size := 0.12) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	for i in count:
		var m := MeshFactory.cylinder(size, size * 0.3, color)
		m.material_override = MeshFactory.material(color, 0.2, 0.6, color * 0.4)
		m.position = pos
		m.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		parent.add_child(m)
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.4, 1.0) * spread
		var peak := pos + dir * 0.5 + Vector3(0, randf_range(1.0, 2.2), 0)
		var end := pos + dir + Vector3(0, -0.2, 0)
		var tw := m.create_tween()
		tw.tween_property(m, "position", peak, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(m, "position", end, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(m, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(m.queue_free)

## A thing flies from `from` to a moving target node (e.g. an oyster into your bucket).
static func fly_to(parent: Node, from: Vector3, target: Node3D, mesh: Node3D, time := 0.35) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	parent.add_child(mesh)
	mesh.position = from
	var tw := mesh.create_tween()
	var start := from
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(target) or not is_instance_valid(mesh):
			return
		var to := target.global_position + Vector3(0, 1.4, 0)
		var p := start.lerp(to, k)
		p.y += sin(k * PI) * 1.5
		mesh.global_position = p
		mesh.scale = Vector3.ONE * lerpf(1.0, 0.3, k), 0.0, 1.0, time)
	tw.tween_callback(mesh.queue_free)

static func ring(parent: Node, pos: Vector3, color: Color, radius := 2.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var mat := MeshFactory.material(color, 0.3, 0.0, color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)

## Hot streaks that shoot out and fall with gravity, like a blade striking a spark.
static func sparks(parent: Node, pos: Vector3, color: Color, count := 14, speed := 4.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mat := MeshFactory.material(color, 0.3, 0.0, color * 2.2)
	for i in count:
		var m := MeshFactory.box(Vector3(0.018, 0.018, randf_range(0.1, 0.22)), color)
		m.material_override = mat
		parent.add_child(m)
		m.global_position = pos
		var v := Vector3(randf_range(-1, 1), randf_range(0.3, 1.4), randf_range(-1, 1)).normalized() * speed * randf_range(0.5, 1.0)
		var life := randf_range(0.3, 0.55)
		var tw := m.create_tween()
		tw.tween_method(func(k: float) -> void:
			if not is_instance_valid(m):
				return
			var tt := k * life
			var vel := v + Vector3(0, -9.8 * tt, 0)
			m.global_position = pos + v * tt + Vector3(0, -4.9 * tt * tt, 0)
			if vel.length() > 0.01:
				m.look_at(m.global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)
			m.scale = Vector3.ONE * (1.0 - k * 0.8), 0.0, 1.0, life)
		tw.tween_callback(m.queue_free)

## Little shell chips knocked off by a stab.
static func chips(parent: Node, pos: Vector3, color: Color, count := 4) -> void:
	burst(parent, pos, color, count, 0.6, 0.035)
