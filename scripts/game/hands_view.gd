extends Node
class_name HandsView
## Hands render in their own SubViewport world with their own camera, so they can
## never clip into the pier (SPEC §3). Includes the 60 ms hand spring.

var main_camera: Camera3D
var viewport: SubViewport
var cam: Camera3D
var sway_root: Node3D
var display: TextureRect
var layer: CanvasLayer
var held_slot: Node3D
var left_hand: Node3D
var right_hand: Node3D
var knife: Node3D
var held_model: Node3D

var sway := Vector3.ZERO
var sway_vel := Vector3.ZERO
var omega := 18.0
var zeta := 0.52

func setup(main_cam: Camera3D) -> void:
	main_camera = main_cam
	layer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	display = TextureRect.new()
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	left_hand.position = Vector3(-0.30, -0.28, -0.52)
	left_hand.rotation = Vector3(0.35, 0.30, -0.14)
	left_hand.scale = Vector3(0.68, 0.68, 0.68)
	sway_root.add_child(left_hand)

	right_hand = MeshFactory.hand(Color(0.62, 0.45, 0.35), Color(0.75, 0.7, 0.58))
	right_hand.position = Vector3(0.30, -0.29, -0.54)
	right_hand.rotation = Vector3(0.22, -0.35, 0.16)
	right_hand.scale = Vector3(0.68, 0.68, 0.68)
	sway_root.add_child(right_hand)

	held_slot = Node3D.new()
	held_slot.position = Vector3(-0.32, -0.22, -0.50)
	held_slot.rotation = Vector3(0.55, 0.22, -0.12)
	sway_root.add_child(held_slot)

	refresh_knife(Color(0.55, 0.42, 0.30))
	resize()
	get_window().size_changed.connect(resize)

func resize() -> void:
	var s: Vector2i = get_window().size
	if s.x < 2:
		s = Vector2i(1920, 1080)
	viewport.size = s

func refresh_knife(blade_color: Color) -> void:
	if knife != null:
		knife.queue_free()
	knife = MeshFactory.knife(blade_color)
	knife.position = Vector3(0.02, -0.06, -0.10)
	knife.rotation = Vector3(0.32, -0.55, 0.12)
	right_hand.add_child(knife)

func show_oyster(species: SpeciesData, open: bool, with_pearl: bool) -> void:
	clear_oyster()
	if species == null:
		return
	held_model = MeshFactory.oyster(species, open, with_pearl)
	held_model.scale = Vector3(0.135, 0.135, 0.135)
	held_slot.add_child(held_model)

func clear_oyster() -> void:
	if held_model != null:
		held_model.queue_free()
		held_model = null

func sync(delta_rot: Vector2, move: Vector3, dt: float) -> void:
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
	sway_root.position = sway
	sway_root.rotation = Vector3(sway.y * 2.5, sway.x * 2.5, sway.x * 1.5)
	if held_slot:
		held_slot.position = Vector3(-0.32 - sway.x * 0.5, -0.22 - sway.y * 0.4, -0.50)
		held_slot.rotation = Vector3(0.55 + sway.y, 0.22 + sway.x, -0.12 + sway.x * 2.0)
