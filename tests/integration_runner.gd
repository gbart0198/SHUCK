extends Node
## Runs inside the normal game (autoloads present). Triggered by:
##   Godot --headless --path . -- --integration
## Drives the real Player input loop, not just the pure OysterSim.

var fails: Array[String] = []

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails.append(msg)
		print("  FAIL ", msg)

func frame(p: Player, dt := 0.016) -> void:
	p._process(dt)

func run(main: Node) -> int:
	var save_path := "user://save.json"
	var backup := ""
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		backup = f.get_as_text()
		f.close()
	Game.load_game()
	await get_tree().process_frame
	main._on_start(1, [], false, false)
	await get_tree().process_frame
	var shift = main.shift
	ck(shift != null, "shift scene built")
	ck(shift.player != null, "player exists")
	shift._spawn_ticket()
	ck(shift.cards.size() == 1, "ticket card on rail")
	shift._on_ticket_clicked(shift.cards[0])
	ck(shift.active_ticket != null, "ticket accepted")
	shift._spawn_from_active()
	ck(shift.oysters.size() == 1, "oyster spawned on bench")
	var p = shift.player
	var o = shift.oysters[0]
	p.pick_up(o)
	ck(p.sim == o.sim, "player holds the oyster")
	# clear the pickup click
	p.lmb_released = true
	frame(p)
	ck(not p.suppress_until_release, "pickup click consumed")
	# ---- gesture 1: wedge via real input flags
	p.lmb_pressed = true
	frame(p)
	ck(p.gesture_phase == Player.G.WEDGE and p.wedge_active, "wedge meter starts on LMB hold")
	for i in 23:
		p.lmb_pressed = false
		frame(p)
	p.lmb_released = true
	frame(p)
	ck(p.gesture_phase == Player.G.POP, "clean wedge release advances to POP")
	# ---- gesture 2: pop
	var guard := 0
	while p.sim.pop_ring > 0.33 and guard < 60:
		frame(p)
		guard += 1
	p.lmb_pressed = true
	frame(p)
	ck(p.sim.state == OysterSim.State.OPEN, "pop click opens the shell")
	ck(p.gesture_phase == Player.G.SLIDE, "advances to SLIDE")
	# ---- gesture 3: slide
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var seam_y := func(prog: float) -> float:
		return vs.y * 0.52 + sin(prog * PI) * vs.y * 0.05
	p.lmb_pressed = true
	frame(p)
	p.lmb_pressed = false
	p.slide_active = true
	var step := 0
	guard = 0
	while p.gesture_phase == Player.G.SLIDE and guard < 200:
		step += 1
		var prog: float = clampf(float(step * 12) / (vs.x * 0.44), 0.0, 1.0)
		p.virtual_mouse = Vector2(vs.x * 0.28 + step * 12, seam_y.call(prog))
		frame(p)
		guard += 1
	ck(p.sim.surgical, "surgical slide (inside tolerance at speed)")
	ck(p.gesture_phase == Player.G.RESEAT, "slide completes into RESEAT")
	# ---- gesture 4: reseat
	p.lmb_pressed = true
	frame(p)
	p.lmb_pressed = false
	p.virtual_mouse = p.plate_screen_center()
	for i in 12:
		frame(p)
	p.lmb_released = true
	frame(p)
	ck(p.sim == null and shift.plate.portions.size() == 1, "reseat over plate puts it on the pass")
	ck(shift.plate.portions.size() > 0 and shift.plate.portions[0].grade == "S", "grade S from a clean four-gesture run")
	# ---- finish the remaining portions of the 3-oyster ticket
	var safety := 0
	while shift.active_ticket != null and not shift.active_ticket.completed and safety < 8:
		safety += 1
		shift._spawn_from_active()
		if shift.oysters.is_empty():
			break
		var o2 = shift.oysters[0]
		p.pick_up(o2)
		p.suppress_until_release = false
		var s2: OysterSim = o2.sim
		s2.wedge_begin()
		s2.wedge_tick(0.40)
		s2.wedge_release()
		s2.pop_begin()
		s2.pop_tick(0.36)
		s2.pop_click()
		s2.slide_begin()
		for i2 in 12:
			s2.slide_sample(0.0, 900.0, 0.016, s2.tolerance_px(1))
		s2.slide_finish()
		s2.reseat(true)
		p._resolve()
		shift._serve_from_plate()
	while shift.active_ticket != null and not shift.active_ticket.completed and not shift.plate.portions.is_empty():
		shift._serve_from_plate()
	ck(shift.earnings + shift.tips > 0, "ticket paid out: ¢%d" % (shift.earnings + shift.tips))
	ck(shift.stars >= 0, "stars computed")
	ck(shift.active_ticket == null, "ticket left the pass")
	var before := Game.money()
	shift._end_shift()
	await get_tree().process_frame
	ck(shift.ended, "shift ended")
	ck(shift.ledger != null, "ledger shown")
	ck(Game.money() >= before, "money recorded")
	ck(FileAccess.file_exists("user://save.json"), "save written on shift end")
	var r := SaveGame.load_from("user://save.json")
	ck(r.ok, "save readable")
	print("  result total: ", shift.earnings + shift.tips, " quota: ", shift.quota, " walked: ", shift.walked_out,
		" stars: ", shift.stars, " met: ", shift.earnings + shift.tips >= shift.quota)
	if backup != "":
		var f2 := FileAccess.open(save_path, FileAccess.WRITE)
		f2.store_string(backup)
		f2.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("")
	if fails.is_empty():
		print("INTEGRATION PASS")
		return 0
	print("INTEGRATION FAIL: ", fails)
	return 1
