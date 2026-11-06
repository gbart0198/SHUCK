extends CharacterBody3D
class_name Player
## First-person shucker. Owns the four-gesture input loop and the hand view.

signal focus_changed(target: Interactable)
signal toast(text: String)
signal oyster_resolved(oyster: OysterNode, sim: OysterSim)
signal gesture_phase_changed(phase: int)

enum G { NONE, DRILL, WEDGE, POP, SLIDE, RESEAT }

const WALK := 3.1
const SPRINT := 4.6

var head: Node3D
var main_camera: Camera3D
var ray: RayCast3D
var hands: HandsView
var focus: Interactable
var plate_ref: Node3D
var clamp_ref: Node3D

var held_oyster: OysterNode
var sim: OysterSim
var gesture_phase := G.NONE
var force_no_pop := false

var yaw := 0.0
var pitch := 0.0
var sensitivity := 1.0
var fov := 75.0
var head_bob := true
var locked := false

var virtual_mouse := Vector2.ZERO
var lmb_pressed := false
var lmb_released := false
var suppress_until_release := false

var wedge_active := false
var pop_sound_played := false
var slide_active := false
var slide_progress := 0.0
var slide_last_progress := 0.0
var slide_last_pos := Vector2.ZERO
var slide_cursor_started := false
var slide_wander := 0.0
var reseat_active := false
var reseat_pos := Vector2.ZERO
var reseat_vel := Vector2.ZERO
var drill_active := false
var drill_progress := 0.0
var drill_time := 0.0

var last_grade := ""
var last_grade_species := ""
var grade_timer := 0.0
var nicked := false
var nicked_timer := 0.0
var rash := false
var msg_timer := 0.0
var msg := ""
var fainted := false
var faint_timer := 0.0
var nick_times: Array[float] = []
var bob_t := 0.0
var last_camera_rot := Vector2.ZERO
var move_amount := 0.0
var flashlight: SpotLight3D
var pier_tilt := 0.0
var sway_t := 0.0
var prybar_next := false
var photo_mode := false

func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)

	head = Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	add_child(head)
	main_camera = Camera3D.new()
	main_camera.fov = fov
	main_camera.near = 0.03
	main_camera.far = 160.0
	main_camera.current = true
	head.add_child(main_camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.collision_mask = 2
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	main_camera.add_child(ray)

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 30.0
	flashlight.position = Vector3(0.12, -0.12, 0.0)
	flashlight.visible = false
	main_camera.add_child(flashlight)

	hands = HandsView.new()
	hands.name = "Hands"
	add_child(hands)
	hands.setup(main_camera)

	apply_settings()
	if "--shot=" in " ".join(OS.get_cmdline_user_args()):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func apply_settings() -> void:
	if not Game.state.has("settings"):
		return
	var s: Dictionary = Game.state["settings"]
	fov = float(s.get("fov", 75.0))
	sensitivity = float(s.get("sensitivity", 1.0))
	head_bob = bool(s.get("head_bob", true))
	if main_camera:
		main_camera.fov = fov

func set_locked(value: bool) -> void:
	locked = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		release_gesture()

func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion:
		var rel: Vector2 = event.relative / maxf(0.001, get_viewport().get_canvas_transform().get_scale().x)
		if gesture_phase != G.NONE:
			var vs := get_viewport().get_visible_rect().size
			virtual_mouse = (virtual_mouse + rel).clamp(Vector2(4, 4), vs - Vector2(4, 4))
		else:
			yaw -= rel.x * 0.0022 * sensitivity
			pitch -= rel.y * 0.0022 * sensitivity
			if Game.state.get("settings", {}).get("invert_y", false):
				pitch += rel.y * 0.0044 * sensitivity
			pitch = clampf(pitch, -1.45, 1.45)
			rotation.y = yaw
			head.rotation.x = pitch
	elif event.is_action_pressed("flashlight"):
		if flashlight != null:
			flashlight.visible = not flashlight.visible
			Sfx.play("click", -10.0)
	elif event.is_action_pressed("interact"):
		lmb_pressed = true
	elif event.is_action_released("interact"):
		lmb_released = true

func _process(dt: float) -> void:
	if locked:
		lmb_pressed = false
		lmb_released = false
		return
	if fainted:
		_faint_process(dt)
		lmb_pressed = false
		lmb_released = false
		return
	if photo_mode:
		_update_hands(dt)
		lmb_pressed = false
		lmb_released = false
		return
	_update_focus()
	_update_hands(dt)
	if gesture_phase == G.NONE:
		if lmb_pressed and focus != null and focus.can_interact(self):
			focus.begin(self)
	else:
		_gesture_process(dt)
	if grade_timer > 0.0:
		grade_timer -= dt
	if nicked_timer > 0.0:
		nicked_timer -= dt
		if nicked_timer <= 0.0:
			nicked = false
	if msg_timer > 0.0:
		msg_timer -= dt
	lmb_pressed = false
	lmb_released = false

func _physics_process(dt: float) -> void:
	if locked or fainted or photo_mode:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
	input = input.limit_length(1.0)
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	if gesture_phase != G.NONE:
		speed *= 0.35
	var dir := (Basis(Vector3.UP, rotation.y) * Vector3(input.x, 0, input.y)) * speed
	velocity.x = dir.x
	velocity.z = dir.z
	velocity.y -= 9.8 * dt
	move_and_slide()
	move_amount = Vector2(velocity.x, velocity.z).length() / SPRINT
	if head_bob and move_amount > 0.05 and is_on_floor():
		bob_t += dt * (7.0 + move_amount * 6.0)
		head.position.y = 1.62 + sin(bob_t) * 0.012 * move_amount
	else:
		head.position.y = lerpf(head.position.y, 1.62, dt * 8.0)
	sway_t += dt
	if pier_tilt > 0.0 and not fainted:
		head.rotation.z = sin(sway_t * 0.8) * pier_tilt * 3.0

func _update_hands(dt: float) -> void:
	var delta_rot := Vector2(rotation.y - last_camera_rot.x, head.rotation.x - last_camera_rot.y)
	last_camera_rot = Vector2(rotation.y, head.rotation.x)
	hands.sync(delta_rot, velocity, dt)

func _update_focus() -> void:
	if held_oyster != null:
		_set_focus(null)
		return
	ray.force_raycast_update()
	var c: Object = ray.get_collider()
	if c is Interactable and c.can_interact(self):
		_set_focus(c)
	else:
		_set_focus(null)

func _set_focus(t: Interactable) -> void:
	if focus == t:
		return
	focus = t
	focus_changed.emit(t)

# ------------------------------------------------------------------ holding
func pick_up(oyster: OysterNode) -> void:
	if held_oyster != null or oyster == null or oyster.sim == null:
		return
	held_oyster = oyster
	sim = oyster.sim
	oyster.set_held(true)
	suppress_until_release = true
	nicked = sim.nicked
	rash = false
	var gloves := Game.tier("gloves")
	if oyster.species.requires_gloves_tier > 0 and gloves < oyster.species.requires_gloves_tier:
		rash = true
		_toast(Data.t("TOAST_RASH", "Barnacle Rash — the spines bite through these gloves"))
	if gloves >= 2:
		sim.wet_hands_scale = 0.5
	if gloves >= 3 and sim.nicked and randf() < 0.5:
		sim.nicked = false
		nicked = false
	hands.show_oyster(oyster.species, false, false)
	virtual_mouse = get_viewport().get_visible_rect().size * 0.5
	if prybar_next:
		prybar_next = false
		sim.wedge_begin()
		sim.wedge_tick(0.40)
		sim.wedge_release()
		if sim.state == OysterSim.State.SEATED:
			sim.pop_begin()
			_set_phase(G.POP)
			Sfx.play("click", -6.0, 0.8)
			return
	if oyster.species.drill_seconds > 0.0:
		_set_phase(G.DRILL)
		drill_progress = 0.0
		drill_time = 0.0
	else:
		_set_phase(G.WEDGE)
	wedges_used_free_slip()

func wedges_used_free_slip() -> void:
	if Game.tier("knife") >= 6:
		sim.free_slip_available = true

func release_gesture() -> void:
	if held_oyster == null:
		return
	if sim != null and sim.state != OysterSim.State.BINNED and sim.state != OysterSim.State.PLATED:
		sim.abandon()
	_resolve()

func _set_phase(p: int) -> void:
	gesture_phase = p
	gesture_phase_changed.emit(p)
	if p == G.POP:
		pop_sound_played = false

func _toast(text: String) -> void:
	msg = text
	msg_timer = 2.6
	toast.emit(text)

func _gesture_process(dt: float) -> void:
	match gesture_phase:
		G.DRILL:
			_process_drill(dt)
		G.WEDGE:
			_process_wedge(dt)
		G.POP:
			_process_pop(dt)
		G.SLIDE:
			_process_slide(dt)
		G.RESEAT:
			_process_reseat(dt)

func _clear_click() -> void:
	if suppress_until_release:
		if lmb_released:
			suppress_until_release = false
		lmb_pressed = false
		lmb_released = false

# ------------------------------------------------------------------ gestures
func _process_drill(dt: float) -> void:
	_clear_click()
	if suppress_until_release:
		return
	if lmb_pressed:
		drill_active = true
	if lmb_released:
		drill_active = false
	drill_time += dt
	if drill_active:
		var g := _drill_geometry()
		var center: Vector2 = g[0]
		var radius: float = g[1]
		if virtual_mouse.distance_to(center) <= radius:
			drill_progress += dt / maxf(0.5, sim.species.drill_seconds)
		else:
			drill_progress = maxf(0.0, drill_progress - dt * 0.8)
	if drill_progress >= 1.0:
		drill_progress = 0.0
		Sfx.play("drill")
		_set_phase(G.WEDGE)

func _drill_geometry() -> Array:
	var vs := get_viewport().get_visible_rect().size
	var center := vs * 0.5 + Vector2(sin(drill_time * 2.4) * (18.0 + drill_progress * 50.0),
		cos(drill_time * 3.1) * (14.0 + drill_progress * 40.0))
	return [center, lerpf(105.0, 46.0, drill_progress)]

func _process_wedge(dt: float) -> void:
	_clear_click()
	if suppress_until_release:
		return
	if lmb_pressed and not wedge_active:
		sim.wedge_begin()
		wedge_active = true
	var pedal := Input.is_action_just_pressed("pedal")
	if wedge_active:
		sim.wedge_tick(dt)
		if lmb_released or pedal:
			wedge_active = false
			_finish_wedge()
	elif pedal and not wedge_active:
		# foot pedal also starts the meter
		sim.wedge_begin()
		wedge_active = true

func _finish_wedge() -> void:
	var r := sim.wedge_release()
	match r:
		OysterSim.Wedge.NONE:
			_toast(Data.t("TOAST_NOTHING", "Nothing. Hold the knife in the hinge and try again."))
			Sfx.play("click", -12.0)
		OysterSim.Wedge.SLIP:
			Sfx.play("crack")
			if sim.nicked:
				nicked = true
				nicked_timer = 12.0
				_note_nick()
				_toast(Data.t("TOAST_NICKED", "Nicked. The shell is fine. Your hand is not."))
			else:
				_toast(Data.t("TOAST_SLIP", "Slip. No damage this time."))
		_:
			Sfx.play("click", -8.0, 1.2)
			if sim.state == OysterSim.State.SEATED:
				var next := _step_next("wedge")
				if force_no_pop or next == "slide":
					sim.slide_begin()
					_start_slide()
				else:
					sim.pop_begin()
					_set_phase(G.POP)

func _step_next(id: String) -> String:
	var s: InteractionStep = Registry.steps.get(id, null)
	if s == null:
		return ""
	return str(s.params.get("next", ""))

func _process_pop(dt: float) -> void:
	if not sim.pop_active:
		return
	sim.pop_tick(dt)
	if sim.pop_result == OysterSim.Pop.FIGHTBACK:
		_toast(Data.t("TOAST_CLAMP", "It clamped shut. Wedge it again."))
		Sfx.play("thud", -10.0)
		_set_phase(G.WEDGE)
		return
	if lmb_pressed:
		if Game.tier("knife") >= 6 and sim.pop_ring <= 0.6:
			sim.pop_ring = 0.1
		var r := sim.pop_click()
		match r:
			OysterSim.Pop.PERFECT:
				Sfx.play("tock")
			OysterSim.Pop.NORMAL:
				Sfx.play("click")
			OysterSim.Pop.CRACKED:
				Sfx.play("crack")
				_toast(Data.t("TOAST_CRACKED", "Cracked. Shards on the bench."))
		if sim.state == OysterSim.State.OPEN:
			hands.show_oyster(sim.species, true, sim.pearls.size() > 0)
			sim.slide_begin()
			_start_slide()

func _note_nick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	nick_times.append(now)
	while nick_times.size() > 4:
		nick_times.pop_front()
	var recent := 0
	for t in nick_times:
		if now - t <= 60.0:
			recent += 1
	var limit := 3 if Game.tier("gloves") >= 6 else 2
	if recent >= limit:
		_faint()

func _faint() -> void:
	if fainted:
		return
	fainted = true
	faint_timer = Registry.balance.faint_seconds
	nick_times.clear()
	Game.session["faints"] = int(Game.session.get("faints", 0)) + 1
	Game.bump_stat("faints")
	if held_oyster != null:
		_toast(Data.t("TOAST_FAINT", "You faint. Everything hits the floor."))
		release_gesture()
	head.position.y = 0.55
	head.rotation.z = 0.5
	Sfx.play("thud")

func _faint_process(dt: float) -> void:
	faint_timer -= dt
	head.position.y = lerpf(head.position.y, 0.32, dt * 6.0)
	if faint_timer <= 0.0:
		fainted = false
		head.position.y = 1.62
		head.rotation.z = 0.0
		_toast(Data.t("TOAST_WAKE", "You come to. The ticket is still running."))

func _start_slide() -> void:
	var vs := get_viewport().get_visible_rect().size
	slide_progress = 0.0
	slide_last_progress = 0.0
	slide_cursor_started = false
	slide_active = false
	virtual_mouse = Vector2(vs.x * 0.28, vs.y * 0.52)
	_set_phase(G.SLIDE)

func _slide_seam_y(progress: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	return vs.y * 0.52 + sin(progress * PI) * vs.y * 0.05

func seam_points(count := 40) -> PackedVector2Array:
	var vs := get_viewport().get_visible_rect().size
	var x0 := vs.x * 0.28
	var x1 := vs.x * 0.72
	var pts := PackedVector2Array()
	for i in count + 1:
		var p := float(i) / float(count)
		pts.append(Vector2(lerpf(x0, x1, p), _slide_seam_y(p)))
	return pts

func _process_slide(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var x0 := vs.x * 0.28
	var x1 := vs.x * 0.72
	if lmb_released:
		slide_active = false
	if lmb_pressed:
		slide_active = true
		if not slide_cursor_started:
			virtual_mouse = Vector2(x0 + 2.0, _slide_seam_y(0.0))
			slide_last_pos = virtual_mouse
			slide_cursor_started = true
	if not slide_active:
		return
	var p := clampf((virtual_mouse.x - x0) / (x1 - x0), 0.0, 1.0)
	var speed := virtual_mouse.distance_to(slide_last_pos) / maxf(dt, 0.001)
	slide_last_pos = virtual_mouse
	if p <= slide_last_progress - 0.0001 or speed < 18.0:
		if p >= 0.999:
			_finish_slide()
		return
	slide_last_progress = maxf(slide_last_progress, p)
	slide_progress = p
	var knife_tier := Game.tier("knife")
	var tide_mult := 1.0
	for t in Game.session.get("tides", []):
		var td := Registry.get_tide(str(t))
		if td != null:
			tide_mult *= td.tolerance_mult
	var tol := sim.tolerance_px(knife_tier, tide_mult, rash)
	if sim.species.max_slide_speed_scale > 0.0 and speed > Registry.balance.slide_hover_speed_ref * sim.species.max_slide_speed_scale:
		Sfx.play("crack")
		_toast(Data.t("TOAST_BRITTLE", "The razor shell snaps. Too fast."))
		sim.shatter_now("brittle")
		_resolve()
		return
	var offline := virtual_mouse.y - _slide_seam_y(p)
	var wander_mult := 1.0
	if knife_tier >= 1 and knife_tier <= Registry.balance.knife_wander_mult.size():
		wander_mult = Registry.balance.knife_wander_mult[knife_tier - 1]
	var wander: float = (speed / Registry.balance.slide_hover_speed_ref) * Registry.balance.slide_wander_gain * wander_mult
	slide_wander = wander
	sim.slide_sample(offline + wander, speed, dt, tol)
	if sim.shattered:
		Sfx.play("crack")
		_toast(Data.t("TOAST_SHATTER", "Shell shattered. Butchered."))
		_resolve()
		return
	if sim.stabbed:
		Sfx.play("crack", -4.0, 0.8)
		_toast(Data.t("TOAST_STAB", "You stabbed the meat. Juice everywhere."))
		sim.slide_done = true
		_set_phase(G.RESEAT)
		return
	if p >= 0.999:
		_finish_slide()

func _finish_slide() -> void:
	if sim.slide_done:
		_set_phase(G.RESEAT)
		return
	sim.slide_finish()
	if sim.surgical:
		Sfx.play("tock", -8.0, 1.15)
	_set_phase(G.RESEAT)

func _process_reseat(dt: float) -> void:
	_clear_click()
	if suppress_until_release:
		return
	if lmb_pressed and not reseat_active:
		reseat_active = true
		reseat_pos = get_viewport().get_visible_rect().size * 0.5
		reseat_vel = Vector2.ZERO
	if reseat_active:
		var target := virtual_mouse
		var acc := (target - reseat_pos) * 240.0 - reseat_vel * 24.0
		reseat_vel += acc * dt
		reseat_pos += reseat_vel * dt
		if lmb_released:
			reseat_active = false
			var over := plate_screen_rect().has_point(reseat_pos)
			sim.reseat(over)
			if over:
				Sfx.play("click", -4.0, 0.8)
			else:
				Sfx.play("thud")
				_toast(Data.t("TOAST_RUINED", "Ruined. It is on the floor. That sound was the sound."))
			_resolve()

func plate_screen_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var center := Vector2(vs.x * 0.5, vs.y * 0.80)
	if plate_ref != null and is_instance_valid(plate_ref):
		var sp := main_camera.unproject_position(plate_ref.global_position + Vector3(0, 0.08, 0))
		if sp.x > 0 and sp.y > 0 and sp.x < vs.x and sp.y < vs.y:
			center = sp
	return Rect2(center - Vector2(120, 76), Vector2(240, 152))

func plate_screen_center() -> Vector2:
	return plate_screen_rect().get_center()

func _resolve() -> void:
	var o := held_oyster
	var s := sim
	if s != null:
		last_grade = s.grade
		last_grade_species = s.species.id if s.species != null else ""
		grade_timer = 1.6
		Game.bump_stat("oysters")
		if s.perfect_pops > 0:
			Game.bump_stat("perfect")
	handsets_clear()
	held_oyster = null
	sim = null
	wedge_active = false
	slide_active = false
	reseat_active = false
	drill_active = false
	force_no_pop = false
	_set_phase(G.NONE)
	if o != null and s != null:
		oyster_resolved.emit(o, s)
	if o != null and s != null and (s.state == OysterSim.State.BINNED):
		o.queue_free()

func handsets_clear() -> void:
	if hands != null:
		hands.clear_oyster()

func _toast_and_clear(text: String) -> void:
	_toast(text)

# ------------------------------------------------------------------ HUD data
func gesture_info() -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var info := {
		"phase": gesture_phase,
		"virtual_mouse": virtual_mouse,
		"screen": vs,
		"wedge": sim.wedge_value if sim != null else 0.0,
		"band": _wedge_band(),
		"pop_ring": sim.pop_ring if sim != null else 1.0,
		"pop_active": sim.pop_active if sim != null else false,
		"slide_progress": slide_progress,
		"slide_seam": seam_points(),
		"slide_tolerance": sim.tolerance_px(Game.tier("knife"), _tide_tolerance(), rash) if sim != null else 6.0,
		"slide_offline": sim.slide_offline if sim != null else 0.0,
		"slide_wander": slide_wander,
		"reseat": reseat_pos if reseat_active else virtual_mouse,
		"reseat_active": reseat_active,
		"plate_center": plate_screen_center(),
		"drill": drill_progress,
		"drill_time": drill_time,
		"drill_center": _drill_geometry()[0],
		"drill_radius": _drill_geometry()[1],
		"nicked": nicked,
		"fainted": fainted,
		"faint_timer": faint_timer,
		"grade": last_grade,
		"grade_timer": grade_timer,
		"toast": msg,
		"toast_timer": msg_timer,
		"species": sim.species.id if sim != null else "",
	}
	return info

func _wedge_band() -> Vector2:
	if sim == null:
		return Vector2(0.55, 0.75)
	var tier := Game.tier("knife")
	if tier >= 3:
		return Vector2(0.52, 0.78)
	return Vector2(0.55, 0.75)

func _tide_tolerance() -> float:
	var m := 1.0
	for t in Game.session.get("tides", []):
		var td := Registry.get_tide(str(t))
		if td != null:
			m *= td.tolerance_mult
	return m

func is_gesturing() -> bool:
	return gesture_phase != G.NONE

func is_holding() -> bool:
	return held_oyster != null
