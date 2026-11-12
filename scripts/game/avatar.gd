extends CharacterBody3D
class_name Avatar
## First-person fisherman. Mouse to look, WASD to walk, Shift to sprint, Space to jump.
## Aim the crosshair at an oyster and click to rake it; at a bench click to stab; walk onto
## the sell dock to sell. All keys come from Settings and can be rebound in the pause menu.

signal hover_changed(text: String)
signal station_changed(station: Station)
signal menu_requested(tab: String)
signal shucked(result: Dictionary)
signal jumped

const REACH := 6.0
const AUTO_REACH := 3.0
const CLICK_RATE := 7.0          # hold-to-click repeats per second
const PERFECT_WINDOW := 0.09
const GRAVITY := 24.0
const JUMP := 7.5
const EYE := 1.62

var world: Node3D
var head: Node3D
var cam: Camera3D
var hands: HandsView

var yaw := 0.0
var pitch := 0.0
var holding := false
var hold_t := 0.0
var magnet_t := 0.0
var sell_t := 0.0
var bin_t := 0.0
## Shucking feedback the HUD reads: PERFECT streak, gold flash, miss flash, camera shake.
var perfect_streak := 0
var perfect_flash := 0.0
var miss_flash := 0.0
var shake := 0.0
var fov_kick := 0.0
var full_t := 0.0
var meter_t := 0.0
var bob_t := 0.0
var station: Station
var hovered: Object
var hover_text := ""
var pets: Array[Node3D] = []
var pet_key := ""
var input_enabled := true
## The window lost focus (alt-tab): mouse released, world still running. Cleared by clicking back in.
var focus_lost := false
var look_total := 0.0
var walked := 0.0
var last_rot := Vector2.ZERO

func _ready() -> void:
	add_to_group("avatar")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	head = Node3D.new()
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Settings.fov
	cam.near = 0.05
	cam.far = 260.0
	cam.current = true
	head.add_child(cam)
	hands = HandsView.new()
	hands.name = "Hands"
	add_child(hands)
	hands.setup(cam)
	Settings.changed.connect(func() -> void: cam.fov = Settings.fov)
	Game.changed.connect(_refresh_pets)
	_refresh_pets()
	capture_mouse(true)

func capture_mouse(on: bool) -> void:
	if "--shot=" in " ".join(OS.get_cmdline_user_args()):
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

## Alt-tab: stop any held click (otherwise it keeps raking while you're away) and free the mouse.
func release_focus_state() -> void:
	holding = false
	if input_enabled:
		focus_lost = true
		capture_mouse(false)

func set_input(on: bool) -> void:
	input_enabled = on
	holding = false
	focus_lost = false
	capture_mouse(on)

func teleport(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	Fx.ring(world, p, Color(0.9, 0.8, 0.6), 2.0)
	Sfx.play("splash", -6.0)

func look_at_dir(y: float, p := 0.0) -> void:
	yaw = y
	pitch = p
	rotation.y = yaw
	head.rotation.x = pitch

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel := (event as InputEventMouseMotion).relative
		look_total += rel.length()
		yaw -= rel.x * 0.0022 * Settings.sensitivity
		pitch += (rel.y if Settings.invert_y else -rel.y) * 0.0022 * Settings.sensitivity
		pitch = clampf(pitch, -1.45, 1.45)
		rotation.y = yaw
		head.rotation.x = pitch
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse(true)
		focus_lost = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		holding = true
		hold_t = 1.0 / CLICK_RATE
		act()
	elif event.is_action_released("interact"):
		holding = false
	elif event.is_action_pressed("use"):
		use()
	else:
		for t in ["shop", "crew", "pets", "reshell", "map"]:
			if event.is_action_pressed("menu_" + t):
				menu_requested.emit(t)
				get_viewport().set_input_as_handled()
				return

## Use key: open the booth you're standing at, buy a gate you're next to, otherwise act.
func use() -> void:
	if station != null and station.kind in ["shop", "crew", "pets", "reshell"]:
		menu_requested.emit(station.kind)
		return
	if station != null and station.kind == "gate" and not Game.empire.can_enter(station.zone_i):
		Game.unlock_zone(station.zone_i)
		return
	act(true)

## One "click": rake, shuck or buy a gate, whichever the crosshair / position calls for.
func act(keyboard := false) -> void:
	var e := Game.empire
	var target: Object = null if keyboard else hovered
	if target is Station and (target as Station).kind == "gate":
		var g := target as Station
		if not e.can_enter(g.zone_i):
			Game.unlock_zone(g.zone_i)
			return
	if station != null and station.kind == "bench" and (e.has_oysters() or e.shuck_zone >= 0):
		_shuck()
		return
	var at_bin := station != null and station.kind == "bin"
	if (target is Station and (target as Station).kind == "bin") or (at_bin and not (target is OysterPickup)):
		_deposit()
		return
	if target is OysterPickup:
		_rake(target as OysterPickup)
		return
	var near := nearest_oyster(AUTO_REACH if not keyboard else REACH)
	if near != null:
		_rake(near)
		return
	hands.do_swing()
	Sfx.play("swing", -16.0, randf_range(0.9, 1.1))

## Tip the bucket into the crew Dock Bin.
func _deposit() -> void:
	if bin_t > 0.0:
		return
	bin_t = 0.6
	hands.do_swing()
	var bin_st: Station = station if station != null and station.kind == "bin" else (hovered as Station if hovered is Station else null)
	if bin_st == null:
		return
	var n := Game.deposit_bin(bin_st.zone_i)
	if n <= 0:
		return
	var bin_pos: Vector3 = bin_st.global_position + Vector3(0, 1.3, 0)
	var zd := Catalog.zone(Game.empire.best_zone())
	for i in mini(n, 6):
		var o := MeshFactory.oyster(zd.shell, zd.meat, false)
		o.scale = Vector3.ONE * 0.4
		world.add_child(o)
		o.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.3, 0) - global_transform.basis.z * 0.6
		var tw := o.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(o, "global_position", bin_pos + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.4, 0.4)), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(o.queue_free)
	Fx.float_text(world, bin_pos + Vector3(0, 1.0, 0), "+%d in the bin" % n, Color(0.55, 0.85, 0.95), 48)
	Fx.burst(world, bin_pos, Color(0.6, 0.75, 0.8), 8, 1.4, 0.06)

func nearest_oyster(max_d: float) -> OysterPickup:
	var best: OysterPickup = null
	var bd := max_d
	for o in get_tree().get_nodes_in_group("oysters"):
		var op := o as OysterPickup
		if op == null or op.dead or not Game.empire.can_enter(op.zone_i):
			continue
		var d := op.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = op
	return best

func _rake(o: OysterPickup) -> void:
	var e := Game.empire
	if not e.can_enter(o.zone_i):
		Game.toast.emit("Locked: buy the %s gate first" % Catalog.zone(o.zone_i).name, UiKit.MUTED)
		return
	if e.bag_full():
		_bucket_full()
		return
	hands.set_tool(HandsView.Tool.RAKE)
	hands.do_swing()
	Sfx.play("swing", -12.0, randf_range(0.9, 1.2))
	var dmg := e.rake_damage()
	Fx.float_text(world, o.global_position + Vector3(0, 0.6, 0), "-" + Num.short(dmg), UiKit.CREAM, 36, 0.8, 0.6)
	if o.hit(dmg):
		_collect(o)
	else:
		Sfx.play("tick", -14.0, randf_range(0.9, 1.3))

func _collect(o: OysterPickup) -> void:
	var e := Game.empire
	if not e.catch_oyster(o.zone_i):
		_bucket_full()
		return
	var zd := Catalog.zone(o.zone_i)
	Sfx.play("pop", -4.0, randf_range(0.95, 1.15))
	Fx.float_text(world, o.global_position + Vector3(0, 0.8, 0), "+1 %s" % zd.oyster, UiKit.GOLD, 44)
	var flying := MeshFactory.oyster(zd.shell, zd.meat, false)
	flying.scale = Vector3.ONE * 0.4
	Fx.fly_to(world, o.global_position, self, flying)
	o.queue_free()
	Game.changed.emit()
	if e.bag_full():
		_bucket_full()

func _bucket_full() -> void:
	if full_t > 0.0:
		return
	full_t = 2.5
	Sfx.play("beep", -8.0)
	Game.toast.emit("Bucket full. Shuck it at a bench%s." % (" or dump it in the DOCK BIN" if Game.empire.owned("shucker") + Game.empire.owned("shuckbot") > 0 else ""), UiKit.RED)

func meter_value() -> float:
	return pingpong(meter_t * 1.35, 1.0)

func meter_perfect() -> bool:
	return absf(meter_value() - 0.5) <= PERFECT_WINDOW

func _shuck() -> void:
	var perfect := meter_perfect()
	var prev_streak := Game.empire.perfect_streak
	var r := Game.empire.shuck_hit(perfect)
	if not r.ok:
		return
	perfect_streak = int(r.streak)
	hands.set_tool(HandsView.Tool.KNIFE)
	hands.do_stab(perfect)
	var top := station.global_position + Vector3(0, 1.3, 0.4)
	var zc := Catalog.zone(maxi(0, int(r.zone)))
	if perfect:
		perfect_flash = 1.0
		shake = maxf(shake, 0.6)
		fov_kick = 1.0
		var pitch := 1.0 + 0.06 * float(mini(perfect_streak - 1, 8))
		Sfx.play("perfect", -5.0, pitch)
		Sfx.play("plink", -14.0, pitch * 1.5)
		var label := "PERFECT" if perfect_streak < 2 else "PERFECT x%d" % perfect_streak
		Fx.float_text(world, top + Vector3(0, 0.5, 0), label, UiKit.GOLD, 56 + mini(perfect_streak, 6) * 4)
		Fx.sparks(world, top, UiKit.GOLD, 12 + mini(perfect_streak, 8) * 2, 3.5 + float(mini(perfect_streak, 6)) * 0.3)
		Fx.ring(world, top + Vector3(0, -0.25, 0), UiKit.GOLD, 0.45 + float(mini(perfect_streak, 6)) * 0.06)
	else:
		if prev_streak >= 3:
			Game.toast.emit("Streak broken at %d" % prev_streak, UiKit.MUTED)
		miss_flash = 1.0
		shake = maxf(shake, 0.2)
		Sfx.play("stab", -6.0, randf_range(0.9, 1.2))
		Fx.chips(world, top, (zc.shell as Color).lightened(0.2), 3)
	if r.opened:
		var zd := Catalog.zone(int(r.zone))
		Sfx.play("crack", -4.0)
		hands.show_oyster(int(r.zone), true)
		Fx.float_text(world, top + Vector3(0, 0.9, 0), "+%s" % Num.cash(float(r.value)), UiKit.GREEN, 56)
		Fx.burst(world, top, zd.meat, 6, 1.4, 0.08)
		if int(r.count) > 1:
			Fx.float_text(world, top + Vector3(0, 1.3, 0), "%d SHUCKED AT ONCE" % int(r.count), UiKit.GOLD, 48 + mini(int(r.count), 32), 1.8, 1.4)
			Fx.burst(world, top, zd.meat, mini(4 + int(r.count), 30), 1.8, 0.08)
			Sfx.play("crack", -6.0, 0.8)
		if r.pearl:
			Sfx.play("plink", -2.0)
			Fx.float_text(world, top + Vector3(0, 1.5, 0), "PEARL +%d" % int(r.get("pearls_found", 1)), Color(0.97, 0.95, 0.9), 64, 2.2, 1.6)
			Fx.burst(world, top, Color(0.97, 0.95, 0.9), 10, 1.6, 0.06)
		Game.changed.emit()
	if r.tier_up:
		Sfx.play("fanfare", -4.0, 1.1)
		Game.banner.emit("PERFECT STREAK x%d" % int(r.streak), "Now shucking %d oysters per crack" % int(r.batch), UiKit.GOLD)
	shucked.emit(r)

# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	var e := Game.empire
	full_t = maxf(0.0, full_t - dt)
	bin_t = maxf(0.0, bin_t - dt)
	meter_t += dt
	if holding and input_enabled:
		hold_t -= dt
		if hold_t <= 0.0:
			hold_t += 1.0 / CLICK_RATE
			act()
	perfect_flash = maxf(0.0, perfect_flash - dt * 2.2)
	miss_flash = maxf(0.0, miss_flash - dt * 4.0)
	shake = maxf(0.0, shake - dt * 5.0)
	fov_kick = maxf(0.0, fov_kick - dt * 4.0)
	cam.fov = Settings.fov - 3.5 * sin(fov_kick * PI * 0.5)
	var delta_rot := Vector2(rotation.y - last_rot.x, head.rotation.x - last_rot.y)
	last_rot = Vector2(rotation.y, head.rotation.x)
	var speed_k := clampf(Vector2(velocity.x, velocity.z).length() / maxf(1.0, e.walk_speed()), 0.0, 1.5)
	hands.sync(delta_rot, velocity, dt, speed_k if is_on_floor() and Settings.head_bob else 0.0)
	# what's in your hands
	var at_bench := station != null and station.kind == "bench"
	var shucking := at_bench and (e.has_oysters() or e.shuck_zone >= 0)
	hands.aim(meter_value(), meter_perfect(), shucking)
	hands.set_shuck_progress(e.shuck_progress())
	if at_bench and (e.has_oysters() or e.shuck_zone >= 0):
		hands.set_tool(HandsView.Tool.KNIFE)
		var z := e.shuck_zone if e.shuck_zone >= 0 else e._top_zone_in_bag()
		if hands.stab <= 0.0:
			hands.show_oyster(z, false)
	elif not at_bench:
		hands.set_tool(HandsView.Tool.RAKE)
		hands.show_oyster(-1, false)
	_update_hover()
	_update_station()
	var mr := e.magnet_radius()
	if mr > 0.0:
		magnet_t -= dt
		if magnet_t <= 0.0:
			magnet_t = 0.45
			for o in get_tree().get_nodes_in_group("oysters"):
				var op := o as OysterPickup
				if op != null and not op.dead and op.global_position.distance_to(global_position) <= mr and e.can_enter(op.zone_i):
					if e.bag_full():
						break
					if op.hit(e.rake_damage() * 0.5):
						_collect(op)
	if station != null and station.kind == "sell":
		sell_t -= dt
		if sell_t <= 0.0:
			sell_t = 1.0
			_sell()
	for i in pets.size():
		var p := pets[i]
		# trail behind and to the sides, so they show up when you turn around
		var a: float = yaw + float([-1.0, 1.0, 0.0][i % 3])
		var target := global_position + Vector3(sin(a) * 2.4, 1.1 + sin(meter_t * 2.4 + i) * 0.15, cos(a) * 1.8)
		p.global_position = p.global_position.lerp(target, clampf(dt * 4.0, 0.0, 1.0))
		p.rotation.y = lerp_angle(p.rotation.y, yaw, dt * 3.0)

func _physics_process(dt: float) -> void:
	var input := Vector2.ZERO
	var sprint := false
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint = Input.is_action_pressed("sprint")
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var speed := Game.empire.walk_speed() * (1.45 if sprint else 1.0) * 0.62
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
			jumped.emit()
			Sfx.play("swing", -16.0, 0.7)
	else:
		velocity.y -= GRAVITY * dt
	var before := global_position
	move_and_slide()
	walked += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if global_position.y < -5.0:
		global_position = WorldBuilder.zone_spawn(WorldBuilder.zone_at(global_position.x))
	var moving := Vector2(velocity.x, velocity.z).length()
	if Settings.head_bob and moving > 0.2 and is_on_floor():
		bob_t += dt * (7.0 + moving * 0.8)
		head.position.y = EYE + sin(bob_t) * 0.03
	else:
		head.position.y = lerpf(head.position.y, EYE, dt * 8.0)
	# stab shake (tiny, decays fast)
	if shake > 0.0 and Settings.head_bob:
		head.position.x = randf_range(-1.0, 1.0) * 0.012 * shake
		head.position.y += randf_range(-1.0, 1.0) * 0.01 * shake
	else:
		head.position.x = 0.0

func _update_hover() -> void:
	if cam == null or not is_inside_tree():
		return
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var obj: Object = hit.get("collider", null) if not hit.is_empty() else null
	hovered = obj
	var txt := ""
	if obj is OysterPickup:
		txt = (obj as OysterPickup).tooltip()
	elif obj is Station:
		txt = (obj as Station).tooltip()
	if txt != hover_text:
		hover_text = txt
		hover_changed.emit(txt)

func _update_station() -> void:
	var best: Station = null
	for s in get_tree().get_nodes_in_group("stations"):
		var st := s as Station
		if st.near(global_position):
			best = st
			break
	if best == station:
		return
	station = best
	station_changed.emit(station)
	if station == null:
		return
	match station.kind:
		"sell":
			sell_t = 1.0
			_sell()
		"shop", "crew", "pets", "reshell":
			menu_requested.emit(station.kind)

func _sell() -> void:
	var v := Game.do_sell()
	if v > 0.0:
		Fx.float_text(world, global_position + Vector3(0, 2.2, 0) - global_transform.basis.z * 1.5, "+" + Num.cash(v), UiKit.GREEN, 80, 1.6, 1.6)
		Fx.burst(world, global_position + Vector3(0, 0.6, 0) - global_transform.basis.z * 1.2, UiKit.GOLD, 12, 2.0, 0.08)

func _refresh_pets() -> void:
	var e := Game.empire
	if e == null:
		return
	var key := ",".join(e.equipped.map(func(i: Variant) -> String: return str(e.pets[int(i)]) if int(i) < e.pets.size() else ""))
	if key == pet_key:
		return
	pet_key = key
	for p in pets:
		p.queue_free()
	pets.clear()
	for i in e.equipped:
		if int(i) >= e.pets.size():
			continue
		var pd := Catalog.pet(str(e.pets[int(i)]))
		var node := Figures.pet(str(pd.id), pd.color)
		node.top_level = true
		node.scale = Vector3.ONE * 1.2
		add_child(node)
		node.global_position = global_position + Vector3(0, 1.2, 1.5)
		pets.append(node)
