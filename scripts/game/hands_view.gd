extends Node
class_name HandsView
## First-person hands in their own SubViewport world with their own camera, so they never
## clip into the world. Right hand holds the rake (on the beach) or the knife (at a bench);
## the left hand holds the oyster you're working on. Spring sway + swing/stab animations.

enum Tool { RAKE, KNIFE }

var main_camera: Camera3D
var viewport: SubViewport
var cam: Camera3D
var sway_root: Node3D
var display: TextureRect
var layer: CanvasLayer
var held_slot: Node3D
var left_hand: Node3D
var right_hand: Node3D
var right_rest_pos := Vector3(0.30, -0.29, -0.54)
var right_rest_rot := Vector3(0.22, -0.35, 0.16)
var left_rest_pos := Vector3(-0.30, -0.28, -0.52)
var tool_node: Node3D
var tool := -1
var held_model: Node3D
var held_zone := -2
var held_open := false

var sway := Vector3.ZERO
var sway_vel := Vector3.ZERO
var omega := 18.0
var zeta := 0.52
var swing := 0.0
var stab := 0.0
var bob_t := 0.0
# shucking: each stab picks a style (jab, twist-and-pry, wiggle); the held oyster jolts and its
# lid creeps open with progress; a gold glint light flashes on a PERFECT.
var stab_style := 0
var stab_power := 1.0
var jolt := 0.0
var glint := 0.0
var glint_light: OmniLight3D
var aim_v := 0.5
var aim_hot := false
var aim_on := false
var shuck_k := 0.0
var lid_open := 0.0
var t := 0.0

func setup(main_cam: Camera3D) -> void:
	main_camera = main_cam
	layer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	display = TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(display)

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	display.texture = viewport.get_texture()

	cam = Camera3D.new()
	cam.fov = main_camera.fov
	cam.near = 0.01
	cam.far = 12.0
	viewport.add_child(cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.75)
	key.light_energy = 0.9
	key.rotation_degrees = Vector3(-35, -30, 0)
	viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.75, 1.0)
	fill.light_energy = 0.35
	fill.position = Vector3(-0.4, 0.2, -0.6)
	fill.omni_range = 3.0
	viewport.add_child(fill)

	sway_root = Node3D.new()
	cam.add_child(sway_root)

	left_hand = MeshFactory.hand(Color(0.62, 0.45, 0.35), Color(0.75, 0.7, 0.58))
	left_hand.position = left_rest_pos
	left_hand.rotation = Vector3(0.35, 0.30, -0.14)
	left_hand.scale = Vector3(0.68, 0.68, 0.68)
	sway_root.add_child(left_hand)

	right_hand = MeshFactory.hand(Color(0.62, 0.45, 0.35), Color(0.75, 0.7, 0.58))
	right_hand.position = right_rest_pos
	right_hand.rotation = right_rest_rot
	right_hand.scale = Vector3(0.68, 0.68, 0.68)
	sway_root.add_child(right_hand)

	held_slot = Node3D.new()
	held_slot.position = Vector3(-0.32, -0.22, -0.50)
	held_slot.rotation = Vector3(0.55, 0.22, -0.12)
	sway_root.add_child(held_slot)

	glint_light = OmniLight3D.new()
	glint_light.light_color = Color(1.0, 0.82, 0.4)
	glint_light.light_energy = 0.0
	glint_light.omni_range = 1.2
	glint_light.position = Vector3(-0.2, -0.12, -0.55)
	sway_root.add_child(glint_light)

	set_tool(Tool.RAKE)
	resize()
	get_window().size_changed.connect(resize)

func resize() -> void:
	var s: Vector2i = get_window().size
	if s.x < 2:
		s = Vector2i(1920, 1080)
	viewport.size = s

func set_tool(t: int) -> void:
	if t == tool:
		return
	tool = t
	if tool_node != null:
		tool_node.queue_free()
	if t == Tool.KNIFE:
		tool_node = MeshFactory.knife(Color(0.78, 0.8, 0.82))
		tool_node.position = Vector3(0.02, -0.06, -0.10)
		tool_node.rotation = Vector3(0.32, -0.55, 0.12)
	else:
		tool_node = Node3D.new()
		var shaft := MeshFactory.cylinder(0.022, 1.1, Color(0.42, 0.3, 0.2), Vector3(0, 0.0, -0.35), Vector3(PI * 0.5, 0, 0))
		tool_node.add_child(shaft)
		tool_node.add_child(MeshFactory.box(Vector3(0.34, 0.035, 0.04), Color(0.5, 0.52, 0.52), Vector3(0, 0, -0.9)))
		for i in 5:
			var tine := MeshFactory.box(Vector3(0.02, 0.1, 0.02), Color(0.5, 0.52, 0.52), Vector3(-0.14 + i * 0.07, -0.06, -0.9))
			tool_node.add_child(tine)
		tool_node.position = Vector3(0.0, -0.02, 0.0)
		tool_node.rotation = Vector3(-0.35, 0.25, 0.0)
	right_hand.add_child(tool_node)

## zone -1 = empty hand.
func show_oyster(zone_i: int, open: bool) -> void:
	if zone_i == held_zone and open == held_open:
		return
	held_zone = zone_i
	held_open = open
	lid_open = 0.0
	if held_model != null:
		held_model.queue_free()
		held_model = null
	if zone_i < 0:
		return
	var z := Catalog.zone(zone_i)
	held_model = MeshFactory.oyster(z.shell, z.meat, open)
	held_model.scale = Vector3(0.085, 0.085, 0.085)
	held_slot.add_child(held_model)

func do_swing() -> void:
	swing = 1.0

## perfect = bigger, faster, gold-glinting stab. Styles rotate so a long shuck doesn't look canned.
func do_stab(perfect := false) -> void:
	stab = 1.0
	stab_style = (stab_style + 1 + (1 if perfect else 0)) % 3
	stab_power = 1.35 if perfect else 1.0
	jolt = 1.0 if perfect else 0.6
	if perfect:
		glint = 1.0

## The knife tip drifts with the timing meter while you hold it at the bench (hot = in the gold band).
func aim(v: float, hot: bool, on: bool) -> void:
	aim_v = v
	aim_hot = hot
	aim_on = on

## 0..1 shuck progress: the held oyster's lid creeps open as you work the hinge.
func set_shuck_progress(k: float) -> void:
	shuck_k = k

func sync(delta_rot: Vector2, move: Vector3, dt: float, bob_amount: float) -> void:
	if main_camera == null or cam == null:
		return
	cam.global_transform = main_camera.global_transform
	cam.fov = main_camera.fov
	var target := Vector3(
		clampf(delta_rot.y * 2.2, -0.06, 0.06) + clampf(-move.x * 0.012, -0.03, 0.03),
		clampf(-delta_rot.x * 2.2, -0.06, 0.06) + clampf(move.y * 0.004, -0.02, 0.02),
		0.0)
	var acc := (target - sway) * omega * omega - sway_vel * (2.0 * zeta * omega)
	sway_vel += acc * dt
	sway += sway_vel * dt
	sway = sway.limit_length(0.09)
	bob_t += dt * 9.0 * bob_amount
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.014, 0) * bob_amount
	sway_root.position = sway + bob
	sway_root.rotation = Vector3(sway.y * 2.5, sway.x * 2.5, sway.x * 1.5)
	held_slot.position = Vector3(-0.32 - sway.x * 0.5, -0.22 - sway.y * 0.4, -0.50)
	held_slot.rotation = Vector3(0.55 + sway.y, 0.22 + sway.x, -0.12 + sway.x * 2.0)
	# rake: lift then chop down and forward
	if swing > 0.0:
		swing = maxf(0.0, swing - dt * 5.5)
		var k := sin(swing * PI)
		right_hand.position = right_rest_pos + Vector3(-0.05 * k, 0.12 * k, -0.08 * k)
		right_hand.rotation = right_rest_rot + Vector3(0.9 * k - 0.5 * (1.0 - swing) * k, 0, 0)
	# knife: three stab styles toward the oyster's hinge
	elif stab > 0.0:
		stab = maxf(0.0, stab - dt * (7.0 if stab_power <= 1.0 else 6.0))
		var p := 1.0 - stab                       # 0 → 1 over the stab
		var s := sin(stab * PI) * stab_power
		var jab := Vector3(-0.22 * s, 0.06 * s, -0.06 * s)
		var rot := Vector3(-0.2 * s, 0.5 * s, 0)
		match stab_style:
			1:  # twist and pry: drive in, then lever the hinge
				var lever := smoothstep(0.35, 0.8, p) * (1.0 - smoothstep(0.85, 1.0, p))
				jab += Vector3(0.02, 0.05 * lever, 0)
				rot += Vector3(0.55 * lever, 0, -0.9 * lever)
			2:  # wiggle the blade in the gap
				var w := sin(p * PI * 5.0) * sin(stab * PI)
				jab += Vector3(0.012 * w, 0, 0)
				rot += Vector3(0, 0.28 * w, 0.2 * w)
		right_hand.position = right_rest_pos + jab
		right_hand.rotation = right_rest_rot + rot
		left_hand.position = left_rest_pos + Vector3(0.01 * s, -0.012 * s, 0)
	else:
		var rest_pos := right_rest_pos
		var rest_rot := right_rest_rot
		if aim_on:
			# hover the knife over the hinge, drifting with the meter; steady and raised in the gold band
			var off := (aim_v - 0.5) * 2.0
			rest_pos += Vector3(-0.06 + off * 0.035, 0.03 + (0.015 if aim_hot else 0.0), -0.02)
			rest_rot += Vector3(-0.08, 0.2 + off * 0.12, off * 0.1 + sin(t * 9.0) * (0.0 if aim_hot else 0.02))
		right_hand.position = right_hand.position.lerp(rest_pos, clampf(dt * 12.0, 0.0, 1.0))
		right_hand.rotation = right_hand.rotation.lerp(rest_rot, clampf(dt * 12.0, 0.0, 1.0))
		left_hand.position = left_hand.position.lerp(left_rest_pos, clampf(dt * 12.0, 0.0, 1.0))
	_shuck_fx(dt)

func _shuck_fx(dt: float) -> void:
	t += dt
	# the held oyster jolts on each stab
	jolt = maxf(0.0, jolt - dt * 6.0)
	if jolt > 0.0:
		var j := jolt * jolt
		held_slot.position += Vector3(sin(t * 61.0) * 0.012, cos(t * 47.0) * 0.008, 0) * j
		held_slot.rotation += Vector3(0, 0, sin(t * 53.0) * 0.12 * j)
	# lid creeps open with progress, then pops when the oyster opens (show_oyster(open=true))
	if held_model != null and not held_open:
		var lid: Node3D = held_model.get_node_or_null("Lid")
		lid_open = lerpf(lid_open, shuck_k, clampf(dt * 10.0, 0.0, 1.0))
		if lid:
			lid.rotation.x = deg_to_rad(-26.0 * lid_open) + sin(t * 40.0) * 0.04 * jolt
	elif held_model == null:
		lid_open = 0.0
	# gold glint on a PERFECT
	glint = maxf(0.0, glint - dt * 3.0)
	glint_light.light_energy = glint * 1.6 + (0.25 if aim_on and aim_hot else 0.0)
