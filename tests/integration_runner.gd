extends Node
## Drives the real game (autoloads, world, avatar, HUD, menus) through the whole loop.
## Run: Godot --headless --path . -- --integration

var failures: Array[String] = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures.append(msg)
		print("  FAIL ", msg)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func run(main: Node) -> int:
	print("SHUCK Simulator integration")
	var e := Game.empire
	var av: Avatar = main.avatar
	await frames(10)
	var stations := get_tree().get_nodes_in_group("stations")
	var kinds := {}
	for s in stations:
		kinds[s.kind] = int(kinds.get(s.kind, 0)) + 1
	check(int(kinds.get("bench", 0)) == 8 and int(kinds.get("sell", 0)) == 8, "a bench and sell pad in every zone")
	check(int(kinds.get("gate", 0)) == 7, "seven gates")
	check(kinds.has("shop") and kinds.has("crew") and kinds.has("pets") and kinds.has("reshell"), "HQ booths exist")
	check(get_tree().get_nodes_in_group("oysters").size() >= 30, "oyster beds are growing (%d)" % get_tree().get_nodes_in_group("oysters").size())
	check(main.refs.gates.size() == 7, "all gates closed on a fresh save")

	# --- walk
	var start := av.global_position
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	check(av.global_position.distance_to(start) > 0.5, "WASD moves the fisherman")

	# --- rake
	var o := av.nearest_oyster(999.0)
	var guard := 0
	while e.bag_count() < 3 and guard < 200:
		guard += 1
		o = _oyster_in_zone(0, av)
		if o == null:
			await frames(5)
			continue
		av.global_position = o.global_position + Vector3(1.0, 0.2, 1.0)
		await frames(2)
		av.act(true)
		await frames(1)
	check(e.bag_count() >= 3, "raking oysters fills the bucket (%d)" % e.bag_count())
	check(int(e.stats.caught) >= 3, "caught stat counts")
	# --- shuck at the bench
	var bench := _station("bench", 0)
	av.global_position = bench.global_position + Vector3(0, 0.3, -1.2)
	await frames(4)
	check(av.station == bench, "standing at the bench registers")
	guard = 0
	while e.has_oysters() and guard < 400:
		guard += 1
		av.act()
	check(not e.has_oysters() and e.meat_count >= 3, "shucking turns oysters into meat (%d)" % e.meat_count)
	# --- sell
	var cash0 := e.cash
	var sell := _station("sell", 0)
	av.global_position = sell.global_position + Vector3(0, 0.3, 0)
	await frames(4)
	check(e.cash > cash0 and e.meat_count == 0, "stepping on the sell pad sells (%s)" % Num.cash(e.cash))
	# --- buy upgrades through the menu
	e.cash = 1e5
	main.open_menu("shop")
	await frames(3)
	check(main.menu != null and not av.input_enabled, "menu opens and pauses input")
	check(Game.buy_upgrade("rake") and e.level("rake") == 1, "buy Rake Power")
	for tab in ["crew", "pets", "reshell", "map", "shop"]:
		main.open_menu(tab)
		await frames(2)
		check(main.menu.tab == tab and main.menu.list.get_child_count() > 0, "menu tab %s renders" % tab)
	main.close_menu()
	await frames(2)
	check(main.menu == null and av.input_enabled, "menu closes")
	# --- gates
	check(Game.unlock_zone(1), "unlock Rocky Point")
	await frames(3)
	check(not main.refs.gates.has(1), "the gate opens")
	main.menu = null
	# --- crew
	e.cash = 1e7
	for id in ["deckhand", "deckhand", "shucker", "coordinator"]:
		Game.hire(id)
	await frames(3)
	check(main.crew_yard.npcs.get("deckhand", []).size() == 2, "hired deckhands appear")
	check(int(e.assignment()["deckhand"][0]) == 2 and main.crew_yard.shown_at("deckhand", 0) == 2, "crew fill the Muddy Shallows first")
	# --- feed the Dock Bin yourself, train the crew
	var bin_st := _station("bin", 0)
	check(bin_st != null, "the Dock Bin is a station")
	e.bag = {"0": 4}
	e.bins[0] = 0.0
	e.bin_values[0] = 0.0
	av.global_position = bin_st.global_position + Vector3(0, 0.3, -1.8)
	await frames(4)
	check(av.station == bin_st, "standing at the Dock Bin registers")
	av.bin_t = 0.0
	av.use()
	check(e.bag_count() == 0 and float(e.bins[0]) >= 3.9, "use at the Dock Bin dumps the bucket there (%s)" % e.bins[0])
	var lv0 := e.train_level("shucker")
	check(Game.train("shucker") and e.train_level("shucker") == lv0 + 1, "train Shuckers")
	var sh: Node = main.crew_yard.npcs.get("shucker", [])[0]
	var sh_start: Vector3 = sh.position
	for i in 90:
		await get_tree().process_frame
	check(sh.mode != "wait" and sh.position.distance_to(sh_start) > 0.05, "a Shucker goes to work on the bin (%s)" % sh.mode)
	var sold0 := e.lifetime
	for i in 120:
		await get_tree().process_frame
	e.tick(60.0, false)
	check(e.lifetime > sold0, "crew earn on their own")
	# beach slots: fill Rocky Point, spill to the Shallows, then refuse
	while e.free_slots("deckhand") > 0:
		Game.hire("deckhand")
	check(not Game.hire("deckhand") and int(e.assignment()["deckhand"][1]) == Catalog.crew_slots(1, "deckhand"), "full beaches block hiring (Shallows, then Rocky Point)")
	var moved_before: int = main.crew_yard.shown_at("deckhand", 2)
	e.cash = 1e9
	check(Game.unlock_zone(2) and e.free_slots("deckhand") > 0, "a new gate opens crew slots")
	await frames(3)
	check(Game.hire("deckhand"), "hire into the new beach")
	await frames(3)
	check(main.crew_yard.shown_at("deckhand", 2) == moved_before + 1, "the new hire works the new beach")
	check(Game.buy_lab() and Game.hire("rakebot"), "robots: lab + RakeBot")
	await frames(2)
	check(main.crew_yard.npcs.get("rakebot", []).size() == 1, "RakeBot shows up")
	# --- pets
	e.pearls = 100
	var pid := Game.hatch("common")
	await frames(3)
	check(pid != "" and av.pets.size() == 1, "hatched %s follows you" % pid)
	# --- events
	e.start_event("golden_tide")
	check(is_equal_approx(e.cash_mult(), Catalog.quality_mult(e.level("quality")) * e.shell_mult() * e.pet_mult() * 2.0), "Golden Tide doubles cash")
	e.event_id = ""
	# --- teleport
	av.teleport(WorldBuilder.zone_spawn(1))
	await frames(3)
	check(WorldBuilder.zone_at(av.global_position.x) == 1, "teleport to Rocky Point")
	# --- alt-tab: the world keeps running (idle game), the mouse is released, a held click is dropped
	av.holding = true
	var earned0 := e.lifetime
	# delivered down the whole tree, like the engine does on a real alt-tab
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	for i in 30:
		await get_tree().process_frame
	check(not get_tree().paused and main.pause_menu == null, "tabbing out does not pause the game")
	check(not av.holding and av.focus_lost, "tabbing out drops a held click and frees the mouse")
	check(e.lifetime > earned0, "the crew keep earning while the window is unfocused")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await frames(2)
	check(not av.focus_lost, "clicking back in retakes control")
	# regression: pausing from inside that notification used to pause the world but fail to add the
	# menu, leaving the game frozen with no menu and no input
	var probe: Node = load("res://tests/focus_probe.gd").new()
	probe.main = main
	main.add_child(probe)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(3)
	check(main.pause_menu != null and main.pause_menu.is_inside_tree() and get_tree().paused, "a pause opened mid-notification still shows its menu")
	probe.queue_free()
	main.close_pause()
	await frames(2)
	check(not get_tree().paused and main.pause_menu == null, "and resumes cleanly")
	# --- pause menu
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(3)
	check(main.pause_menu != null and get_tree().paused, "Esc opens the pause menu and pauses the world")
	check(not main.avatar.input_enabled, "pause releases the mouse / stops input")
	var cash_paused := e.cash
	for p in ["howto", "controls", "settings", "main"]:
		main.pause_menu.show_page(p)
		await frames(2)
		check(main.pause_menu.body.get_child_count() > 0, "pause page %s renders" % p)
	for i in 30:
		await get_tree().process_frame
	check(e.cash == cash_paused, "nothing earns while paused")
	main.close_pause()
	await frames(2)
	check(main.pause_menu == null and not get_tree().paused and main.avatar.input_enabled, "resume unpauses")
	# --- rebinding
	var j := InputEventKey.new()
	j.physical_keycode = KEY_J
	Settings.rebind("jump", j)
	check(Settings.key("jump") == "J" and InputMap.action_has_event("jump", j), "jump rebound to J")
	var sp := InputEventKey.new()
	sp.physical_keycode = KEY_SPACE
	Settings.rebind("use", sp)
	check(Settings.key("use") == "Space" and Settings.keys("jump") == "J", "rebinding steals the key from its old action (%s / %s)" % [Settings.key("use"), Settings.keys("jump")])
	var m4 := InputEventMouseButton.new()
	m4.button_index = MOUSE_BUTTON_RIGHT
	Settings.rebind("interact", m4)
	check(Settings.key("interact") == "RMB", "mouse buttons can be bound")
	Settings.reset_bindings()
	check(Settings.key("jump") == "Space" and Settings.key("use") == "E" and Settings.key("interact") == "LMB", "reset restores defaults")
	# --- tutorial
	var tut: Tutorial = main.hud.tutorial
	tut.restart()
	await frames(2)
	check(tut.active and tut.step == 0, "tutorial starts at step 1")
	main.avatar.look_total += 1000.0
	await frames(3)
	check(tut.step == 1, "looking around advances the tutorial")
	check(tut.body_lbl.text.contains("W") and tut.body_lbl.text.contains("D"), "tutorial text names the bound keys")
	tut.skip()
	check(not tut.active and Settings.tutorial_done, "tutorial can be skipped")
	# --- re-shell rebuilds the world
	e._earn(e.reshell_cost())
	check(Game.reshell(), "Re-Shell")
	await get_tree().create_timer(1.6).timeout
	await frames(5)
	check(e.shells == 1 and e.zones_unlocked == 1, "run reset with a Golden Shell")
	check(main.refs.gates.size() == 7, "gates are back after the Re-Shell")
	check(is_instance_valid(main.avatar) and main.avatar.pets.size() == 1, "pets survive the Re-Shell")
	# --- title screen (built standalone; the real one sits behind a scene reload)
	var tm := TitleMenu.new()
	main.add_child(tm)
	await frames(2)
	var names := ["Continue", "Load", "New", "Settings", "Quit"]
	check(names.all(func(n: String) -> bool: return tm.holder.get_node_or_null(n) != null), "title menu: Continue, Load Save, New Game, Settings, Quit")
	tm.show_page("settings")
	await frames(2)
	check(tm.page == "settings" and tm.holder.get_child_count() > 0, "title settings page renders")
	tm.show_page("load")
	await frames(2)
	check(tm.page == "load", "title load page renders")
	tm.queue_free()
	print("")
	if failures.is_empty():
		print("PASS — %d checks" % checks)
		return 0
	print("FAIL — %d/%d" % [failures.size(), checks])
	for f in failures:
		print("   * ", f)
	return 1

func _station(kind: String, zone_i: int) -> Station:
	for s in get_tree().get_nodes_in_group("stations"):
		if s.kind == kind and s.zone_i == zone_i:
			return s
	return null

func _oyster_in_zone(z: int, av: Avatar) -> OysterPickup:
	var best: OysterPickup = null
	var bd := INF
	for o in get_tree().get_nodes_in_group("oysters"):
		var op := o as OysterPickup
		if op.zone_i != z or op.dead:
			continue
		var d := op.global_position.distance_to(av.global_position)
		if d < bd:
			bd = d
			best = op
	return best
