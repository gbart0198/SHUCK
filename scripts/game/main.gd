extends Node
## Builds the coast, drops the fisherman in (first person), wires HUD, menus, pause and tutorial.
## One persistent world, no levels.

var world: Node3D
var refs: Dictionary
var avatar: Avatar
var crew_yard: CrewYard
var ui: CanvasLayer
var hud: Hud
var menu: MenuUI
var pause_layer: CanvasLayer
var pause_menu: PauseMenu
var title: TitleMenu
var title_t := 0.0
var _pause_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.zone_unlocked.connect(_open_gate)
	Game.reshelled.connect(func() -> void:
		# A Re-Shell rebuilds the world from scratch: gates come back, crew go home.
		await get_tree().create_timer(1.2).timeout
		_rebuild())
	var args := OS.get_cmdline_user_args()
	if not Game.in_session:
		_enter_title()
		await _maybe_shot(args)
		return
	if Game.offline_earned > 0.0 and not "--integration" in args:
		hud.show_offline(Game.offline_earned, Game.offline_seconds)
	if "--integration" in args:
		await get_tree().process_frame
		var runner: Node = load("res://tests/integration_runner.gd").new()
		add_child(runner)
		var code: int = await runner.run(self)
		get_tree().quit(code)
		return
	if "--demo" in args:
		_demo_state()
	if "--at-bench" in args:
		avatar.global_position = Vector3(14, 0.5, 4.4)
		avatar.look_at_dir(PI, -0.5)
	for a in args:
		if a.begins_with("--look="):
			var p := a.split("=", true, 1)[1].split(",")
			avatar.global_position = Vector3(float(p[0]), 0.5, float(p[1]))
			avatar.look_at_dir(deg_to_rad(float(p[2])), deg_to_rad(float(p[3])) if p.size() > 3 else 0.0)
		if a.begins_with("--menu="):
			open_menu(a.split("=", true, 1)[1])
	if "--pause" in args:
		open_pause()
		await get_tree().process_frame
		for a in args:
			if a.begins_with("--pause-page="):
				pause_menu.show_page(a.split("=", true, 1)[1])
	await _maybe_shot(args)

## --shot=path: wait (--shot-delay), optionally land PERFECT stabs (--perfect), save a PNG, quit.
func _maybe_shot(args: PackedStringArray) -> void:
	var shot := ""
	for a in args:
		if a.begins_with("--shot="):
			shot = a.split("=", true, 1)[1]
	if shot != "":
		var delay := 3.0
		for a in args:
			if a.begins_with("--shot-delay="):
				delay = float(a.split("=", true, 1)[1])
		await get_tree().create_timer(delay, true).timeout
		if "--perfect" in args and Game.in_session:
			# dev: land a few PERFECT stabs right before the capture to show the feedback
			for k in 6:
				avatar.meter_t = 0.5 / 1.35
				avatar.act()
				await get_tree().create_timer(0.12, true).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		print("SHUCK screenshot: ", shot)
		get_tree().quit()

func _build() -> void:
	world = Node3D.new()
	world.name = "WorldRoot"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	refs = WorldBuilder.build(world)
	for i in refs.gates.keys():
		if Game.empire.can_enter(int(i)):
			_remove_gate(int(i), false)
	crew_yard = CrewYard.new()
	crew_yard.setup(refs)
	world.add_child(crew_yard)
	avatar = Avatar.new()
	avatar.world = world
	world.add_child(avatar)
	avatar.global_position = WorldBuilder.zone_spawn(0)
	avatar.menu_requested.connect(open_menu)
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ui)
	hud = Hud.new()
	hud.avatar = avatar
	ui.add_child(hud)

func _rebuild() -> void:
	close_menu()
	for n in [world, ui]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().process_frame
	_build()

func _process(dt: float) -> void:
	if title != null:
		# title screen: drift the camera slowly along the coast
		title_t += dt
		avatar.look_at_dir(-0.75 + sin(title_t * 0.06) * 0.35, -0.07 + sin(title_t * 0.045) * 0.03)
	if avatar != null and is_instance_valid(avatar) and not get_tree().paused:
		WorldBuilder.blend_atmosphere(refs, avatar.global_position.x, dt)

func _unhandled_input(event: InputEvent) -> void:
	if title != null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if pause_menu != null:
			return
		if menu != null and is_instance_valid(menu):
			close_menu()
		else:
			open_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# Alt-tabbing away does NOT pause: it's an idle game, the crew keep earning while you're gone.
	# We just let go of the mouse and drop any held click; clicking back in retakes control.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and avatar != null and is_instance_valid(avatar):
		avatar.release_focus_state()

func _open_gate(i: int) -> void:
	_remove_gate(i, true)

func _remove_gate(i: int, animate: bool) -> void:
	var g: Node3D = refs.gates.get(i, null)
	if g == null or not is_instance_valid(g):
		return
	refs.gates.erase(i)
	for c in g.get_children():
		if c is StaticBody3D:
			c.queue_free()
	if not animate:
		g.queue_free()
		return
	Fx.burst(world, g.global_position + Vector3(0, 2, -2), Catalog.zone(i).accent, 20, 4.0, 0.15)
	var tw := g.create_tween()
	tw.tween_property(g, "position:y", -6.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)

func open_menu(tab: String) -> void:
	if pause_menu != null:
		return
	hud.tutorial.notify("menu_" + tab)
	if menu != null and is_instance_valid(menu):
		menu.show_tab(tab)
		return
	menu = MenuUI.new()
	menu.tab = tab
	ui.add_child(menu)
	avatar.set_input(false)
	menu.closed.connect(close_menu)
	menu.teleport.connect(func(zi: int) -> void: avatar.teleport(WorldBuilder.zone_spawn(zi)))

func close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	if avatar != null and is_instance_valid(avatar) and pause_menu == null:
		avatar.set_input(true)
	Game.write_save()

## Opens the pause menu on the next idle frame. Building it immediately could happen mid-notification
## (e.g. a window focus change), where add_child() fails: the old code had already paused the world,
## leaving the game frozen with no menu and no input. The world is only paused once the menu exists.
func open_pause() -> void:
	if _pause_pending or (pause_menu != null and is_instance_valid(pause_menu)):
		return
	_pause_pending = true
	_open_pause_now.call_deferred()

func _open_pause_now() -> void:
	_pause_pending = false
	if not is_inside_tree() or (pause_menu != null and is_instance_valid(pause_menu)):
		return
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 40
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_layer.add_child(pause_menu)
	if hud != null:
		hud.tutorial.notify("pause")
		hud._process(0.0)
	get_tree().paused = true
	avatar.set_input(false)
	pause_menu.resumed.connect(close_pause)
	pause_menu.quit_requested.connect(func() -> void:
		Game.write_save()
		Settings.save()
		get_tree().quit())
	pause_menu.main_menu_requested.connect(func() -> void:
		Game.end_session()
		Settings.save()
		get_tree().paused = false
		get_tree().call_deferred("reload_current_scene"))
	pause_menu.tutorial_replay.connect(func() -> void: hud.tutorial.restart())
	pause_menu.tutorial_skip.connect(func() -> void: hud.tutorial.skip())
	Sfx.play("click", -10.0)

func close_pause() -> void:
	if pause_layer != null and is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = null
	pause_menu = null
	get_tree().paused = false
	if menu == null:
		avatar.set_input(true)
	Game.write_save()

## Title screen: the world as a backdrop (no HUD, no hands, no input) under the main menu.
func _enter_title() -> void:
	ui.visible = false
	avatar.set_input(false)
	avatar.capture_mouse(false)
	avatar.hands.layer.visible = false
	avatar.global_position = Vector3(7.0, 0.5, 9.5)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	title = TitleMenu.new()
	layer.add_child(title)
	title.started.connect(func() -> void:
		Sfx.play("fanfare", -8.0)
		get_tree().call_deferred("reload_current_scene"))
	title.quit_requested.connect(func() -> void:
		Settings.save()
		get_tree().quit())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--title-page="):
			title.show_page(a.split("=", true, 1)[1])

## --demo: a mid-game empire for screenshots.
func _demo_state() -> void:
	var e := Game.empire
	e.cash = 185000.0
	e.total_earned = 900000.0
	e.lifetime = 900000.0
	e.pearls = 64
	e.upgrades = {"rake": 9, "bucket": 8, "knife": 9, "quality": 4, "speed": 3, "luck": 2, "magnet": 1, "warehouse": 6}
	e.crew = {"deckhand": 12, "shucker": 9, "coordinator": 3}
	e.zones_unlocked = 4
	e.pets = ["otter", "puffer", "hermit"]
	e.equipped = [0, 1, 2]
	e.bag = {"0": 5, "3": 4}
	e.meat_count = 6
	e.meat_value = 300.0
	for i in [1, 2, 3]:
		_remove_gate(i, false)
	hud.tutorial.skip()
	Game.changed.emit()
