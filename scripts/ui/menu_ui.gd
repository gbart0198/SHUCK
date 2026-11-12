extends Control
class_name MenuUI
## One big tabbed window: SHOP · CREW · PETS · RE-SHELL · MAP.
## Rows keep a refresh callable so prices/affordability update live without rebuilding.

signal closed
signal teleport(zone_i: int)

const TABS := [["shop", "SHOP", UiKit.BLUE], ["crew", "CREW", UiKit.ORANGE], ["pets", "PETS", UiKit.PINK],
	["reshell", "RE-SHELL", Color(0.85, 0.65, 0.1)], ["map", "MAP", UiKit.GREEN]]

var tab := "shop"
var list: VBoxContainer
var header: Label
var sub: Label
var cash_chip: PanelContainer
var pearl_chip: PanelContainer
var tab_buttons: Dictionary = {}
var refreshers: Array[Callable] = []
var refresh_t := 0.0
var pet_count := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.04, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	var win := UiKit.panel(UiKit.PANEL)
	win.custom_minimum_size = Vector2(1000, 760)
	UiKit.anchor(win, Control.PRESET_CENTER, Vector2(-500, -380))
	add_child(win)
	var v := UiKit.vbox(8)
	win.add_child(v)
	var top := UiKit.hbox(8)
	v.add_child(top)
	for t in TABS:
		var id: String = t[0]
		var b := UiKit.button(t[1], func() -> void: show_tab(id), 20, t[2])
		b.custom_minimum_size = Vector2(146, 50)
		top.add_child(b)
		tab_buttons[id] = [b, t[2]]
	top.add_child(UiKit.spacer())
	var x := UiKit.button("X", close, 24, UiKit.RED)
	x.custom_minimum_size = Vector2(54, 50)
	top.add_child(x)
	var head := UiKit.hbox(12)
	v.add_child(head)
	var hv := UiKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	header = UiKit.title("", 38)
	hv.add_child(header)
	sub = UiKit.label("", 16, UiKit.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(sub)
	var chips := UiKit.vbox(6)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(chips)
	cash_chip = UiKit.chip("", UiKit.GOLD, 22)
	cash_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	chips.add_child(cash_chip)
	pearl_chip = UiKit.chip("", UiKit.CREAM, 16)
	pearl_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	chips.add_child(pearl_chip)
	v.add_child(UiKit.wave(UiKit.BORDER, 12))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = UiKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	Game.changed.connect(_on_changed)
	show_tab(tab)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use"):
		close()
		get_viewport().set_input_as_handled()
		return
	for t in ["shop", "crew", "pets", "reshell", "map"]:
		if InputMap.has_action("menu_" + t) and event.is_action_pressed("menu_" + t):
			if tab == t:
				close()
			else:
				show_tab(t)
			get_viewport().set_input_as_handled()
			return

func close() -> void:
	closed.emit()

func _on_changed() -> void:
	if tab == "pets" and Game.empire.pets.size() != pet_count:
		show_tab(tab)
		return
	_refresh()

func _process(dt: float) -> void:
	refresh_t -= dt
	if refresh_t <= 0.0:
		refresh_t = 0.25
		_refresh()

func _refresh() -> void:
	if cash_chip:
		UiKit.set_chip(cash_chip, Num.cash(Game.empire.cash))
		UiKit.set_chip(pearl_chip, "%s pearls" % Num.short(float(Game.empire.pearls)))
	for r in refreshers:
		r.call()

func show_tab(id: String) -> void:
	tab = id
	for k in tab_buttons.keys():
		var tb: Button = tab_buttons[k][0]
		if k == id:
			UiKit.paint(tb, UiKit.GOLD)
			tb.add_theme_color_override("font_color", UiKit.GOLD)
		else:
			UiKit.paint(tb, tab_buttons[k][1])
	sub.text = ""
	refreshers.clear()
	for c in list.get_children():
		c.queue_free()
	match id:
		"shop": _shop()
		"crew": _crew()
		"pets": _pets()
		"reshell": _reshell()
		"map": _map()
	_refresh()

# ------------------------------------------------------------------ row helper
func _row(title: String, color: Color) -> Dictionary:
	var p := PanelContainer.new()
	var ps := UiKit.style(UiKit.PANEL_LIGHT, UiKit.BORDER.darkened(0.25), 10, 1)
	ps.border_width_left = 6
	ps.border_color = UiKit.BORDER.darkened(0.25)
	p.add_theme_stylebox_override("panel", ps)
	list.add_child(p)
	var h := UiKit.hbox(14)
	p.add_child(h)
	var swatch := Panel.new()
	var ss := UiKit.style(color.darkened(0.15), color.lightened(0.15), 5, 1)
	swatch.add_theme_stylebox_override("panel", ss)
	swatch.custom_minimum_size = Vector2(10, 0)
	h.add_child(swatch)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var t := UiKit.title(title, 24, UiKit.CREAM)
	v.add_child(t)
	var d := UiKit.label("", 16, UiKit.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return {"panel": p, "h": h, "v": v, "title": t, "desc": d}

func _buy_button(row: Dictionary, cb: Callable) -> Button:
	var b := UiKit.button("", cb, 22, UiKit.GREEN)
	b.custom_minimum_size = Vector2(220, 60)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(row.h as HBoxContainer).add_child(b)
	return b

func _section(text: String) -> void:
	var l := UiKit.tag(text, UiKit.SAND, 15)
	list.add_child(UiKit.spacer(0, 4))
	list.add_child(l)

# ------------------------------------------------------------------ tabs
func _shop() -> void:
	header.text = "TACKLE & TOOLS"
	sub.text = "Gear for your own two hands. The Warehouse also sets how much the crew Dock Bin and Meat Crate hold."
	for u in Catalog.UPGRADES:
		var id := str(u.id)
		var row := _row(str(u.name), UiKit.BLUE)
		var b := _buy_button(row, func() -> void: Game.buy_upgrade(id))
		refreshers.append(func() -> void:
			var e := Game.empire
			row.title.text = "%s  Lv %d" % [u.name, e.level(id)]
			row.desc.text = "%s  ·  %s" % [u.desc, _upgrade_effect(id)]
			if e.upgrade_maxed(id):
				b.text = "MAXED"
				b.disabled = true
			else:
				var c := e.upgrade_cost(id)
				b.text = Num.cash(c)
				b.disabled = e.cash < c)

func _upgrade_effect(id: String) -> String:
	var e := Game.empire
	var lv := e.level(id)
	match id:
		"rake": return "hit %s → %s" % [Num.short(Catalog.rake_damage(lv)), Num.short(Catalog.rake_damage(lv + 1))]
		"bucket": return "holds %d → %d" % [Catalog.bucket_capacity(lv), Catalog.bucket_capacity(lv + 1)]
		"knife": return "stab %s → %s" % [Num.short(Catalog.knife_damage(lv)), Num.short(Catalog.knife_damage(lv + 1))]
		"quality": return "price x%s → x%s" % [Num.short(Catalog.quality_mult(lv)), Num.short(Catalog.quality_mult(lv + 1))]
		"speed": return "speed %s → %s" % [Num.short(Catalog.walk_speed(lv)), Num.short(Catalog.walk_speed(lv + 1))]
		"luck": return "pearl %d%% → %d%%" % [int(Catalog.pearl_chance(lv) * 100.0), int(Catalog.pearl_chance(lv + 1) * 100.0)]
		"magnet": return "radius %s → %s" % [Num.short(Catalog.magnet_radius(lv)), Num.short(Catalog.magnet_radius(lv + 1))]
		"warehouse": return "storage %s → %s" % [Num.short(Catalog.storage_capacity(lv)), Num.short(Catalog.storage_capacity(lv + 1))]
	return ""

func _crew() -> void:
	header.text = "CREW & ROBOTS"
	sub.text = "Every beach has its own crew outpost with room for a few of each worker and one Coordinator to run it. Hires fill the Muddy Shallows first, then the next beach up the coast; when every slot is taken, open another gate. HIRE adds workers, TRAIN makes every one of them faster."
	_section("THE CREW")
	for c in Catalog.CREW:
		if bool(c.robot):
			continue
		_crew_row(c)
	_section("THE ROBOTICS LAB")
	var lab_row := _row("Robotics Lab", Color(0.3, 0.8, 0.8))
	var lab_b := _buy_button(lab_row, func() -> void: Game.buy_lab())
	refreshers.append(func() -> void:
		var e := Game.empire
		lab_row.desc.text = "Unlocks RakeBots, ShuckBots and Sell Drones"
		lab_b.text = "BUILT" if e.lab else Num.cash(Catalog.ROBOTICS_LAB_COST)
		lab_b.disabled = e.lab or e.cash < Catalog.ROBOTICS_LAB_COST)
	for c in Catalog.CREW:
		if bool(c.robot):
			_crew_row(c)
	var fac_row := _row("Mega-Factory", Color(0.3, 0.8, 0.8))
	var fac_b := _buy_button(fac_row, func() -> void: Game.buy_factory())
	refreshers.append(func() -> void:
		var e := Game.empire
		fac_row.title.text = "Mega-Factory  Lv %d" % e.factory
		fac_row.desc.text = "Doubles every robot's output (now x%s)" % Num.short(e.robot_mult())
		fac_b.text = "NEEDS LAB" if not e.lab else Num.cash(e.factory_cost())
		fac_b.disabled = not e.lab or e.cash < e.factory_cost())

const ROLE_VERB := {"catch": "oysters/s", "shuck": "shucked/s", "sell": "sold/s"}

## One crew type: HIRE (more of them) and TRAIN / FIRMWARE (each one works faster).
func _crew_row(c: Dictionary) -> void:
	var id := str(c.id)
	var robot := bool(c.robot)
	var row := _row(str(c.name), Color(0.3, 0.8, 0.8) if robot else UiKit.ORANGE)
	var speed := UiKit.bar(UiKit.GREEN if not robot else Color(0.3, 0.8, 0.8), 6)
	speed.custom_minimum_size = Vector2(0, 6)
	(row.v as VBoxContainer).add_child(speed)
	var col := UiKit.vbox(6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(row.h as HBoxContainer).add_child(col)
	var hire_b := UiKit.button("", func() -> void: Game.hire(id), 18, UiKit.GREEN)
	hire_b.custom_minimum_size = Vector2(250, 44)
	col.add_child(hire_b)
	var train_b := UiKit.button("", func() -> void: Game.train(id), 18, UiKit.ORANGE)
	train_b.custom_minimum_size = Vector2(250, 44)
	col.add_child(train_b)
	var word := "Firmware" if robot else "Training"
	refreshers.append(func() -> void:
		var e := Game.empire
		var lv := e.train_level(id)
		row.title.text = "%s  x%d  of %d slots" % [c.name, e.owned(id), e.total_slots(id)]
		var unit := e.unit_rate(id) * e.crew_mult()
		row.desc.text = "%s\n%s %s each  ·  %s Lv %d (x%s speed)  ·  team %s\n%s" % [c.desc, Num.short(unit), ROLE_VERB.get(str(c.role), "/s"), word, lv, Num.short(e.train_mult(id)), Num.rate(unit * float(e.owned(id))), _where(e, id)]
		speed.set_value(float(lv) / float(Catalog.TRAIN_MAX))
		if robot and not e.lab:
			hire_b.text = "NEEDS LAB"
			hire_b.disabled = true
		elif e.free_slots(id) <= 0:
			hire_b.text = "BEACHES FULL"
			hire_b.disabled = true
		else:
			var cost := e.hire_cost(id)
			hire_b.text = "HIRE  %s" % Num.cash(cost)
			hire_b.disabled = e.cash < cost
		if e.train_maxed(id):
			train_b.text = "%s MAXED" % word.to_upper()
			train_b.disabled = true
		elif e.owned(id) <= 0:
			train_b.text = "%s  (hire one first)" % ("UPGRADE" if robot else "TRAIN")
			train_b.disabled = true
		else:
			var tc := e.train_cost(id)
			train_b.text = "%s +25%%  %s" % ["UPGRADE" if robot else "TRAIN", Num.cash(tc)]
			train_b.disabled = e.cash < tc)

func _pets() -> void:
	var e := Game.empire
	pet_count = e.pets.size()
	header.text = "PET CLAMS"
	sub.text = "Spend pearls (found while shucking) to crack Mystery Clams. Pets multiply ALL cash. Up to %d follow you; fuse 3 of the same pet into the next rarity." % Catalog.PET_SLOTS
	var pl := UiKit.title("", 24, UiKit.CREAM)
	list.add_child(pl)
	refreshers.append(func() -> void:
		pl.text = "Pearls: %s     Pet bonus: x%s" % [Num.short(float(Game.empire.pearls)), Num.short(Game.empire.pet_mult())])
	var clams := UiKit.hbox(10)
	list.add_child(clams)
	for c in Catalog.CLAMS:
		var cid := str(c.id)
		var b := UiKit.button("", func() -> void: Game.hatch(cid), 20, UiKit.PINK if cid == "common" else (UiKit.PURPLE if cid == "rare" else Color(0.9, 0.2, 0.35)))
		b.custom_minimum_size = Vector2(300, 80)
		clams.add_child(b)
		refreshers.append(func() -> void:
			b.text = "%s\n%d pearls" % [c.name, int(c.cost)]
			b.disabled = Game.empire.pearls < int(c.cost))
	var tools := UiKit.hbox(10)
	list.add_child(tools)
	tools.add_child(UiKit.button("EQUIP BEST", func() -> void: Game.equip_best(), 20, UiKit.GREEN))
	# odds
	var odds := UiKit.label(_odds_text(), 16, UiKit.MUTED)
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(odds)
	if e.pets.is_empty():
		list.add_child(UiKit.label("No pets yet. Shuck oysters to find pearls!", 22))
		return
	# owned: grouped counts with fuse
	var counts := {}
	for p in e.pets:
		counts[p] = int(counts.get(p, 0)) + 1
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for i in e.pets.size():
		var pid := str(e.pets[i])
		var pd := Catalog.pet(pid)
		var idx := i
		var rar: Dictionary = Catalog.RARITIES[int(pd.rarity)]
		var b := UiKit.button("", func() -> void: Game.toggle_pet(idx), 20, UiKit.BORDER)
		b.custom_minimum_size = Vector2(470, 64)
		b.add_theme_color_override("font_color", rar.color)
		b.add_theme_color_override("font_hover_color", rar.color)
		grid.add_child(b)
		refreshers.append(func() -> void:
			if idx >= Game.empire.pets.size():
				return
			var on := Game.empire.equipped.has(idx)
			b.text = "%s%s  [%s]  x%s" % ["[ON] " if on else "", pd.name, rar.name, Num.short(float(pd.mult))]
			UiKit.paint(b, UiKit.GREEN if on else UiKit.BORDER))
	var fuse_row := UiKit.hbox(8)
	list.add_child(fuse_row)
	for pid in counts.keys():
		if int(counts[pid]) >= 3 and int(Catalog.pet(str(pid)).rarity) < Catalog.RARITIES.size() - 1:
			var fid := str(pid)
			fuse_row.add_child(UiKit.button("FUSE 3x %s" % Catalog.pet(fid).name, func() -> void: Game.fuse(fid), 18, UiKit.PURPLE))

func _odds_text() -> String:
	var lines: Array[String] = []
	for c in Catalog.CLAMS:
		var total := 0.0
		for w in c.weights:
			total += float(w)
		var parts: Array[String] = []
		for i in Catalog.PETS.size():
			var w := float(c.weights[i])
			if w > 0.0:
				parts.append("%s %s%%" % [Catalog.PETS[i].name, String.num(w / total * 100.0, 2)])
		lines.append("%s: %s" % [c.name, ", ".join(parts)])
	return "\n".join(lines)

func _reshell() -> void:
	header.text = "THE PEARL MERCHANT"
	sub.text = "Sell the whole operation for a Golden Shell. The cost grows x6 each time."
	var lose := UiKit.label("You LOSE:  cash, upgrades, crew + training, robots, zones.", 19, UiKit.CREAM)
	list.add_child(lose)
	var keep := UiKit.label("You KEEP:  pets, pearls, Golden Shells, your rank.   Each Golden Shell: +50% cash forever.", 19, UiKit.GREEN)
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(keep)
	var row := _row("Golden Shells", UiKit.GOLD)
	var prog := UiKit.bar(UiKit.GOLD, 8)
	(row.v as VBoxContainer).add_child(prog)
	var b := _buy_button(row, func() -> void:
		if Game.reshell():
			close())
	b.custom_minimum_size = Vector2(300, 80)
	refreshers.append(func() -> void:
		var e := Game.empire
		row.title.text = "Golden Shells: %d  (x%s cash)" % [e.shells, Num.short(e.shell_mult())]
		row.desc.text = "Earned this run: %s / %s" % [Num.cash(e.lifetime), Num.cash(e.reshell_cost())]
		prog.set_value(e.lifetime / maxf(1.0, e.reshell_cost()))
		b.text = "RE-SHELL!" if e.can_reshell() else "NOT YET"
		UiKit.paint(b, UiKit.GOLD if e.can_reshell() else UiKit.MUTED)
		b.disabled = not e.can_reshell())

func _map() -> void:
	header.text = "THE COAST"
	sub.text = "Eight stretches of shoreline, each behind a rope gate. Your crew always work the best one you own."
	for i in Catalog.ZONES.size():
		var z := Catalog.zone(i)
		var zi := i
		var row := _row(str(z.name), z.accent)
		var b := _buy_button(row, func() -> void:
			var e := Game.empire
			if e.can_enter(zi):
				teleport.emit(zi)
				close()
			else:
				Game.unlock_zone(zi))
		refreshers.append(func() -> void:
			var e := Game.empire
			row.desc.text = "%s  ·  %s per meat  ·  %s hp" % [z.oyster, Num.cash(float(z.value)), Num.short(float(z.hp))]
			if e.can_enter(zi):
				b.text = "GO"
				b.disabled = false
				UiKit.paint(b, UiKit.GREEN)
			elif zi == e.zones_unlocked:
				b.text = "UNLOCK %s" % Num.cash(e.zone_cost(zi))
				b.disabled = e.cash < e.zone_cost(zi)
				UiKit.paint(b, UiKit.ORANGE)
			else:
				b.text = "LOCKED"
				b.disabled = true)

## "Working: Kelp Forest 8/8 · Rocky Point 3/6" (best beach first), or where the next hire goes.
func _where(e: Empire, id: String) -> String:
	var asg: Array = e.assignment()[id]
	var parts: Array[String] = []
	for z in range(e.zones_unlocked - 1, -1, -1):
		if int(asg[z]) > 0:
			parts.append("%s %d/%d" % [Catalog.zone(z).name, int(asg[z]), e.slots(z, id)])
	if parts.is_empty():
		return "Next hire works %s" % Catalog.zone(e.best_zone()).name
	var s := "Working: " + "  ·  ".join(parts)
	if e.free_slots(id) <= 0 and e.zones_unlocked < Catalog.ZONES.size():
		s += "   (open %s for more slots)" % Catalog.zone(e.zones_unlocked).name
	return s
