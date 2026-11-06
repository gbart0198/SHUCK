extends Node
## Main → Lobby | Shift (SPEC §20).

var lobby: LobbyUI
var shift: Shift
var shop: ShopUI
var log_ui: PearlLogUI
var last_pier := 1
var last_tides: Array = []
var last_result: Dictionary = {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shot_path := ""
	for a in args:
		if a.begins_with("--shot="):
			shot_path = a.split("=", true, 1)[1]
	if "--autostart" in args:
		var pier := 1
		for a in args:
			if a.begins_with("--pier="):
				pier = int(a.split("=")[1])
		_on_start(pier, [], false, false)
	else:
		show_lobby()
	if "--integration" in args:
		await get_tree().process_frame
		var runner: Node = load("res://tests/integration_runner.gd").new()
		add_child(runner)
		var code: int = await runner.run(self)
		get_tree().quit(code)
		return
	var demo_phase := ""
	for a in args:
		if a.begins_with("--gesture-demo="):
			demo_phase = a.split("=", true, 1)[1]
	if demo_phase != "":
		await get_tree().create_timer(2.0).timeout
		_setup_gesture_demo(demo_phase)
	if shot_path != "":
		await get_tree().process_frame
		await get_tree().create_timer(4.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("SHUCK screenshot: ", shot_path)
		get_tree().quit()

func _setup_gesture_demo(phase: String) -> void:
	if shift == null:
		return
	shift._spawn_ticket()
	if shift.cards.is_empty():
		return
	shift._on_ticket_clicked(shift.cards[0])
	shift._spawn_from_active()
	if shift.oysters.is_empty():
		return
	var p: Player = shift.player
	var o: OysterNode = shift.oysters[0]
	p.pick_up(o)
	p.suppress_until_release = false
	var sim: OysterSim = o.sim
	if phase == "wedge":
		sim.wedge_begin()
		sim.wedge_tick(0.36)
		p.gesture_phase = Player.G.WEDGE
		p.wedge_active = true
	elif phase in ["pop", "slide", "reseat"]:
		sim.wedge_begin()
		sim.wedge_tick(0.40)
		sim.wedge_release()
		p.gesture_phase = Player.G.POP
		if phase == "pop":
			sim.pop_begin()
			sim.pop_tick(0.16)
		else:
			sim.pop_begin()
			sim.pop_tick(0.36)
			sim.pop_click()
			p.hands.show_oyster(sim.species, true, true)
			p._start_slide()
			if phase == "slide":
				p.slide_active = true
				p.virtual_mouse = Vector2(1920 * 0.28 + 400, 1080 * 0.52 + 40)
				p.slide_progress = 0.55
				sim.slide_sample(4.0, 700.0, 0.016, sim.tolerance_px(1))
			else:
				p.gesture_phase = Player.G.RESEAT
				p.reseat_active = true
				p.reseat_pos = p.plate_screen_center()
	p.locked = true
	if shift.hud != null:
		shift.hud.hide_ui = false

func _clear() -> void:
	for n in [lobby, shift, shop, log_ui]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	lobby = null
	shift = null
	shop = null
	log_ui = null

func show_lobby() -> void:
	_clear()
	lobby = LobbyUI.new()
	add_child(lobby)
	lobby.start_requested.connect(_on_start)
	lobby.shop_requested.connect(open_shop)
	lobby.log_requested.connect(open_log)
	lobby.quit_requested.connect(func() -> void: get_tree().quit())

func _on_start(pier_id: int, tides: Array, boss: bool, daily: bool) -> void:
	_clear()
	last_pier = pier_id
	last_tides = tides.duplicate()
	var date := int(Time.get_unix_time_from_system() / 86400.0)
	var seed_value := date if daily else randi()
	Game.begin_session(pier_id, tides, seed_value, daily)
	shift = Shift.new()
	shift.configure(pier_id, tides, seed_value, boss, daily)
	add_child(shift)
	shift.shift_finished.connect(func(r: Dictionary) -> void:
		last_result = r
		last_pier = int(r.pier))
	shift.open_shop_requested.connect(open_shop)
	shift.next_shift_requested.connect(func() -> void:
		start_again())
	shift.lobby_requested.connect(show_lobby)

func start_again() -> void:
	_clear()
	var pier_id := Game.pier()
	var date := int(Time.get_unix_time_from_system() / 86400.0)
	var seed_value := date if Game.session.get("daily", false) else randi()
	var tides: Array = Game.session.get("tides", [])
	Game.begin_session(pier_id, tides, seed_value, bool(Game.session.get("daily", false)))
	shift = Shift.new()
	shift.configure(pier_id, tides, seed_value, false, bool(Game.session.get("daily", false)))
	add_child(shift)
	shift.shift_finished.connect(func(r: Dictionary) -> void:
		last_result = r
		last_pier = int(r.pier))
	shift.open_shop_requested.connect(open_shop)
	shift.next_shift_requested.connect(start_again)
	shift.lobby_requested.connect(show_lobby)

func _pause_shift_for_ui() -> void:
	if shift != null and is_instance_valid(shift) and shift.player != null:
		shift.player.set_locked(true)
		shift.paused = true

func _resume_shift_after_ui() -> void:
	if shift != null and is_instance_valid(shift) and not shift.ended and shift.player != null:
		shift.player.set_locked(false)
		shift.paused = false

func open_shop() -> void:
	if shop != null:
		return
	_pause_shift_for_ui()
	shop = ShopUI.new()
	add_child(shop)
	shop.closed.connect(func() -> void:
		Game.write_save()
		shop.queue_free()
		shop = null
		_resume_shift_after_ui()
		if lobby != null and is_instance_valid(lobby):
			lobby._refresh_stats())

func open_log() -> void:
	if log_ui != null:
		return
	_pause_shift_for_ui()
	log_ui = PearlLogUI.new()
	add_child(log_ui)
	log_ui.closed.connect(func() -> void:
		log_ui.queue_free()
		log_ui = null
		_resume_shift_after_ui())
