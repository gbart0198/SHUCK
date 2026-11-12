extends Control
class_name Hud
## First-person HUD: crosshair + context prompt, cash, bucket, goal, crew pipeline,
## a live key legend (follows your bindings), event banners, shuck meter, toasts.

var avatar: Avatar
var cash_lbl: Label
var rate_lbl: Label
var pearl_lbl: Label
var shell_lbl: Label
var rank_lbl: Label
var goal_panel: PanelContainer
var goal_lbl: Label
var crew_panel: PanelContainer
var crew_lbl: Label
var crew_mult_lbl: Label
var bin_bar: UiKit.Bar
var crate_bar: UiKit.Bar
var bin_lbl: Label
var crate_lbl: Label
var event_lbl: Label
var zone_lbl: Label
var prompt_lbl: Label
var legend: VBoxContainer
var toasts: VBoxContainer
var banner_box: VBoxContainer
var bag_lbl: Label
var bag_bar: UiKit.Bar
var meat_val_lbl: Label
var crew_rate_lbl: Label
var rank_bar: UiKit.Bar
var rank_next_lbl: Label
var shell_icon: Control
var crew_rows: Dictionary = {}
var streak_panel: PanelContainer
var streak_lbl: Label
var streak_bar: UiKit.Bar
var streak_next_lbl: Label
var meat_lbl: Label
var full_lbl: Label
var tutorial: Tutorial
var shown_cash := 0.0
var cash_pulse := 0.0
var last_zone := -1
var zone_t := 0.0
var font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()
	font = UiKit.font()
	_build_stats()
	_build_legend()
	_build_goal()
	_build_bottom()
	_build_center()
	tutorial = Tutorial.new()
	tutorial.avatar = avatar
	add_child(tutorial)
	Game.toast.connect(push_toast)
	Game.banner.connect(show_banner)
	Game.sold.connect(func(_v: float) -> void: cash_pulse = 1.0)
	Settings.bindings_changed.connect(_fill_legend)
	shown_cash = Game.empire.cash

## Top-left purse: cash, cash per minute, rank + progress to the next, pearls and Golden Shells.
func _build_stats() -> void:
	var p := UiKit.panel(UiKit.HUD_BG)
	p.custom_minimum_size = Vector2(300, 0)
	p.position = Vector2(24, 20)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var v := UiKit.vbox(4)
	p.add_child(v)
	var top := UiKit.hbox(10)
	v.add_child(top)
	top.add_child(UiKit.icon("coin", 30))
	cash_lbl = UiKit.title("$0", 38, UiKit.GOLD)
	top.add_child(cash_lbl)
	var rates := UiKit.hbox(10)
	v.add_child(rates)
	rate_lbl = UiKit.label("", 16, UiKit.GREEN)
	rates.add_child(rate_lbl)
	crew_rate_lbl = UiKit.label("", 14, UiKit.MUTED)
	crew_rate_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	rates.add_child(crew_rate_lbl)
	v.add_child(UiKit.spacer(0, 2))
	var rank_row := UiKit.hbox(8)
	v.add_child(rank_row)
	rank_lbl = UiKit.tag("", UiKit.ORANGE, 17)
	rank_row.add_child(rank_lbl)
	rank_bar = UiKit.bar(UiKit.ORANGE, 6)
	v.add_child(rank_bar)
	rank_next_lbl = UiKit.label("", 13, UiKit.MUTED)
	v.add_child(rank_next_lbl)
	var chips := UiKit.hbox(8)
	v.add_child(chips)
	chips.add_child(UiKit.icon("pearl", 18))
	pearl_lbl = UiKit.label("0", 16, UiKit.CREAM)
	chips.add_child(pearl_lbl)
	chips.add_child(UiKit.spacer(8, 0))
	shell_icon = UiKit.icon("shell", 18)
	chips.add_child(shell_icon)
	shell_lbl = UiKit.label("", 16, UiKit.GOLD)
	chips.add_child(shell_lbl)

func _build_legend() -> void:
	var p := UiKit.panel(Color(UiKit.HUD_BG, 0.6))
	UiKit.anchor(p, Control.PRESET_BOTTOM_LEFT, Vector2(24, -24))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	legend = UiKit.vbox(4)
	p.add_child(legend)
	_fill_legend()

func _fill_legend() -> void:
	for c in legend.get_children():
		c.queue_free()
	var rows := [["menu_shop", "Shop"], ["menu_crew", "Crew"], ["menu_pets", "Pets"], ["menu_reshell", "Re-Shell"], ["menu_map", "Map"], ["", "Pause"]]
	for r in rows:
		var h := UiKit.hbox(8)
		h.add_child(UiKit.keycap("Esc" if r[0] == "" else Settings.key(r[0]), 13))
		h.add_child(UiKit.label(r[1], 14, UiKit.MUTED))
		legend.add_child(h)

## Top-right column: NEXT UP, then THE OPERATION (one row per crew type you own).
func _build_goal() -> void:
	var col := UiKit.vbox(10)
	col.custom_minimum_size = Vector2(400, 0)
	UiKit.anchor(col, Control.PRESET_TOP_RIGHT, Vector2(-424, 20))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	goal_panel = UiKit.panel(UiKit.HUD_BG, UiKit.ORANGE.darkened(0.35))
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(goal_panel)
	var v := UiKit.vbox(2)
	goal_panel.add_child(v)
	v.add_child(UiKit.tag("NEXT UP", UiKit.ORANGE, 14))
	goal_lbl = UiKit.label("", 16)
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_lbl.custom_minimum_size = Vector2(370, 0)
	v.add_child(goal_lbl)
	crew_panel = UiKit.panel(UiKit.HUD_BG)
	crew_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(crew_panel)
	var cv := UiKit.vbox(4)
	crew_panel.add_child(cv)
	var head := UiKit.hbox(8)
	cv.add_child(head)
	head.add_child(UiKit.tag("THE OPERATION", UiKit.GOLD, 14))
	head.add_child(UiKit.spacer())
	crew_mult_lbl = UiKit.label("", 14, UiKit.GOLD)
	head.add_child(crew_mult_lbl)
	for c in Catalog.CREW:
		var row := UiKit.hbox(8)
		cv.add_child(row)
		row.add_child(UiKit.icon("spark" if bool(c.robot) else "crew", 16))
		var name := UiKit.label(str(c.name), 15, UiKit.CREAM)
		name.custom_minimum_size = Vector2(130, 0)
		row.add_child(name)
		var count := UiKit.label("", 15, UiKit.MUTED)
		count.custom_minimum_size = Vector2(80, 0)
		row.add_child(count)
		var rate := UiKit.label("", 15, UiKit.SAND)
		rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rate)
		crew_rows[str(c.id)] = [row, count, rate]
	cv.add_child(UiKit.spacer(0, 2))
	for which in ["bin", "crate"]:
		var row := UiKit.hbox(10)
		cv.add_child(row)
		row.add_child(UiKit.icon("oyster" if which == "bin" else "meat", 16))
		var l := UiKit.label("", 14, UiKit.MUTED)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var b := UiKit.bar(UiKit.BLUE if which == "bin" else UiKit.PINK, 8)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		if which == "bin":
			bin_lbl = l
			bin_bar = b
		else:
			crate_lbl = l
			crate_bar = b
	crew_lbl = UiKit.label("", 14, UiKit.GREEN)
	cv.add_child(crew_lbl)

## Bottom belt: what you're carrying (oysters + meat) and, while it's going, your PERFECT streak.
func _build_bottom() -> void:
	var col := UiKit.vbox(6)
	col.custom_minimum_size = Vector2(600, 0)
	col.alignment = BoxContainer.ALIGNMENT_END
	UiKit.anchor(col, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -20))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	full_lbl = UiKit.tag("BUCKET FULL  ·  SHUCK IT AT A BENCH", UiKit.RED, 18)
	full_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(full_lbl)
	streak_panel = UiKit.panel(Color(UiKit.HUD_BG, 0.85), UiKit.GOLD.darkened(0.45))
	streak_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(streak_panel)
	var sh := UiKit.hbox(10)
	streak_panel.add_child(sh)
	sh.add_child(UiKit.icon("spark", 22))
	streak_lbl = UiKit.title("", 20, UiKit.GOLD)
	sh.add_child(streak_lbl)
	streak_bar = UiKit.bar(UiKit.GOLD, 8)
	streak_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(streak_bar)
	streak_next_lbl = UiKit.label("", 14, UiKit.MUTED)
	sh.add_child(streak_next_lbl)
	var belt := UiKit.panel(UiKit.HUD_BG)
	belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(belt)
	var h := UiKit.hbox(16)
	belt.add_child(h)
	var left := UiKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var lt := UiKit.hbox(8)
	left.add_child(lt)
	lt.add_child(UiKit.icon("oyster", 22))
	lt.add_child(UiKit.tag("BUCKET", UiKit.SAND, 14))
	lt.add_child(UiKit.spacer())
	bag_lbl = UiKit.label("", 17, UiKit.CREAM)
	lt.add_child(bag_lbl)
	bag_bar = UiKit.bar(UiKit.SAND, 10)
	left.add_child(bag_bar)
	var sep := ColorRect.new()
	sep.color = Color(UiKit.BORDER, 0.6)
	sep.custom_minimum_size = Vector2(1, 0)
	h.add_child(sep)
	var right := UiKit.vbox(4)
	right.custom_minimum_size = Vector2(200, 0)
	h.add_child(right)
	var rt := UiKit.hbox(8)
	right.add_child(rt)
	rt.add_child(UiKit.icon("meat", 22))
	rt.add_child(UiKit.tag("MEAT", UiKit.SAND, 14))
	rt.add_child(UiKit.spacer())
	meat_lbl = UiKit.label("", 17, UiKit.CREAM)
	rt.add_child(meat_lbl)
	meat_val_lbl = UiKit.label("", 14, UiKit.GREEN)
	meat_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(meat_val_lbl)

func _build_center() -> void:
	banner_box = UiKit.vbox(0)
	banner_box.custom_minimum_size = Vector2(1000, 0)
	UiKit.anchor(banner_box, Control.PRESET_CENTER_TOP, Vector2(-500, 140))
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.z_index = 100
	add_child(banner_box)
	event_lbl = UiKit.label("", 20, UiKit.GOLD)
	event_lbl.custom_minimum_size = Vector2(800, 0)
	UiKit.anchor(event_lbl, Control.PRESET_CENTER_TOP, Vector2(-400, 24))
	event_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(event_lbl)
	zone_lbl = UiKit.title("", 52, UiKit.CREAM)
	zone_lbl.custom_minimum_size = Vector2(1200, 0)
	UiKit.anchor(zone_lbl, Control.PRESET_CENTER, Vector2(-600, -250))
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(zone_lbl)
	prompt_lbl = UiKit.label("", 17, UiKit.CREAM)
	prompt_lbl.custom_minimum_size = Vector2(800, 0)
	UiKit.anchor(prompt_lbl, Control.PRESET_CENTER, Vector2(-400, 28))
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt_lbl.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt_lbl)
	toasts = UiKit.vbox(4)
	toasts.custom_minimum_size = Vector2(800, 0)
	UiKit.anchor(toasts, Control.PRESET_CENTER, Vector2(-400, 120))
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.z_index = 100
	add_child(toasts)

# ------------------------------------------------------------------ live
func push_toast(text: String, color: Color) -> void:
	var l := UiKit.label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	toasts.add_child(l)
	toasts.move_child(l, 0)
	while toasts.get_child_count() > 4:
		var old := toasts.get_child(toasts.get_child_count() - 1)
		toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func show_banner(title: String, subtitle: String, color: Color) -> void:
	for c in banner_box.get_children():
		c.queue_free()
	var t := UiKit.title(title, 54, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(t)
	var s := UiKit.label(subtitle, 22, UiKit.CREAM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(s)
	banner_box.modulate.a = 0.0
	var tw := banner_box.create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.8)
	tw.tween_property(banner_box, "modulate:a", 0.0, 0.6)

func _prompt() -> String:
	if avatar == null:
		return ""
	var e := Game.empire
	var lmb := Settings.key("interact")
	var use := Settings.key("use")
	if avatar.focus_lost:
		return "Click to take control again  ·  your crew kept working while you were away"
	var st := avatar.station
	if st != null:
		match st.kind:
			"bench":
				if e.has_oysters() or e.shuck_zone >= 0:
					return "[%s] Stab  ·  hit the gold band for a PERFECT" % lmb
				return "Shuck bench: rake some oysters first"
			"bin":
				if e.has_oysters():
					return "[%s] Dump %d oysters into the Dock Bin  ·  %s / %s%s" % [lmb, e.bag_count(), Num.short(floor(float(e.bins[st.zone_i]))), Num.short(e.storage_capacity()), "" if e.role_rate("shuck", st.zone_i) > 0.0 else "  ·  no Shuckers on this beach yet"]
				return "Dock Bin: rake oysters and dump them here for your Shuckers"
			"sell":
				return "Selling..." if e.meat_count > 0 or e.crate_total() > 0.5 else "Sell dock: shuck oysters to have meat to sell"
			"shop", "crew", "pets", "reshell":
				return "[%s] %s" % [use, st.title]
			"gate":
				if not e.can_enter(st.zone_i) and st.zone_i == e.zones_unlocked:
					return "[%s] Open the gate to %s for %s" % [use, Catalog.zone(st.zone_i).name, Num.cash(e.zone_cost(st.zone_i))]
	if avatar.hovered is OysterPickup:
		return "[%s] Rake  ·  %s" % [lmb, avatar.hover_text]
	if avatar.hovered is Station:
		return avatar.hover_text
	return ""

func _process(dt: float) -> void:
	var e := Game.empire
	shown_cash = lerpf(shown_cash, e.cash, clampf(dt * 10.0, 0.0, 1.0))
	if absf(shown_cash - e.cash) < 0.5:
		shown_cash = e.cash
	cash_lbl.text = Num.cash(shown_cash)
	cash_pulse = maxf(0.0, cash_pulse - dt * 3.0)
	cash_lbl.add_theme_color_override("font_color", UiKit.GOLD.lerp(UiKit.GREEN, cash_pulse))
	rate_lbl.text = "+%s / min" % Num.cash(Game.income_per_sec() * 60.0)
	var passive := e.passive_income() * 60.0
	crew_rate_lbl.text = ("crew %s / min" % Num.cash(passive)) if passive > 0.0 else ""
	pearl_lbl.text = Num.short(float(e.pearls))
	shell_icon.visible = e.shells > 0
	shell_lbl.text = ("%d  (x%s cash)" % [e.shells, Num.short(e.shell_mult())]) if e.shells > 0 else ""
	var ri := e.rank()
	rank_lbl.text = e.rank_name()
	if ri + 1 < Catalog.RANKS.size():
		var a := float(Catalog.RANKS[ri].at)
		var b := float(Catalog.RANKS[ri + 1].at)
		rank_bar.set_value(clampf((e.total_earned - a) / maxf(1.0, b - a), 0.0, 1.0))
		rank_next_lbl.text = "Next: %s at %s earned" % [Catalog.RANKS[ri + 1].name, Num.cash(b)]
	else:
		rank_bar.set_value(1.0)
		rank_next_lbl.text = "Top rank"
	goal_lbl.text = e.next_goal()
	goal_panel.visible = not tutorial.active
	var any_crew := e.crew.size() > 0
	crew_panel.visible = any_crew
	if any_crew:
		var cap := e.storage_capacity()
		crew_mult_lbl.text = "crew speed x%s%s" % [Num.short(e.crew_mult()), ("  ·  robots x%s" % Num.short(e.robot_mult())) if e.lab else ""]
		for c in Catalog.CREW:
			var id := str(c.id)
			var row: Array = crew_rows[id]
			var n := e.owned(id)
			(row[0] as Control).visible = n > 0
			if n > 0:
				(row[1] as Label).text = "%d / %d" % [n, e.total_slots(id)]
				var verb: String = {"catch": "raked", "shuck": "shucked", "sell": "sold"}.get(str(c.role), "")
				(row[2] as Label).text = "%s %s" % [Num.rate(e.unit_rate(id) * e.crew_mult() * float(n)), verb]
		var beaches := 0
		for z in e.zones_unlocked:
			if float(e.bins[z]) > 0.0 or float(e.crates[z]) > 0.0 or e.role_rate("catch", z) + e.role_rate("shuck", z) > 0.0:
				beaches += 1
		var tcap := cap * float(maxi(1, beaches))
		bin_lbl.text = "Dock Bins  %s / %s" % [Num.short(floor(e.bin_total())), Num.short(tcap)]
		crate_lbl.text = "Meat Crates  %s / %s" % [Num.short(floor(e.crate_total())), Num.short(tcap)]
		bin_bar.set_value(e.bin_total() / tcap)
		crate_bar.set_value(e.crate_total() / tcap)
		crew_lbl.text = "Your crew earn about %s / min" % Num.cash(passive)
	# belt
	var k := clampf(float(e.bag_count()) / float(maxi(1, e.bag_capacity())), 0.0, 1.0)
	bag_lbl.text = "%d / %d" % [e.bag_count(), e.bag_capacity()]
	var fill := UiKit.SAND if k < 0.8 else (UiKit.ORANGE if k < 1.0 else UiKit.RED)
	if bag_bar.fill != fill:
		bag_bar.fill = fill
		bag_bar.queue_redraw()
	bag_bar.set_value(k)
	meat_lbl.text = str(e.meat_count)
	meat_val_lbl.text = ("worth %s" % Num.cash(e.meat_value * e.cash_mult())) if e.meat_count > 0 else "sell it at a SELL dock"
	full_lbl.visible = e.bag_full()
	full_lbl.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006))
	# PERFECT streak track: current tier, progress to the next
	var st := e.perfect_streak
	streak_panel.visible = st > 0
	if st > 0:
		streak_lbl.text = "PERFECT x%d  ·  %d per crack" % [st, e.streak_batch()]
		var nxt := Catalog.next_streak_tier(st)
		if nxt.is_empty():
			streak_bar.set_value(1.0)
			streak_next_lbl.text = "max tier"
		else:
			var prev_at := 0
			for t in Catalog.STREAK_TIERS:
				if st >= int(t[0]):
					prev_at = maxi(prev_at, int(t[0]))
			streak_bar.set_value(float(st - prev_at) / float(maxi(1, int(nxt[0]) - prev_at)))
			streak_next_lbl.text = "x%d → %d" % [int(nxt[0]), int(nxt[1])]
	if e.event_id != "":
		for ev in Catalog.EVENTS:
			if ev.id == e.event_id:
				event_lbl.text = "%s  ·  %s  ·  %ds" % [str(ev.name).capitalize(), ev.desc, int(ceil(e.event_left))]
	else:
		event_lbl.text = ""
	prompt_lbl.text = _prompt()
	if avatar:
		var zi := WorldBuilder.zone_at(avatar.global_position.x)
		if zi != last_zone:
			last_zone = zi
			zone_t = 2.5
			zone_lbl.text = str(Catalog.zone(zi).name)
		zone_t = maxf(0.0, zone_t - dt)
		zone_lbl.modulate.a = clampf(zone_t, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var e := Game.empire
	var s := get_viewport_rect().size
	# crosshair: a dot, opening into a ring over something you can use
	var c := s * 0.5
	if avatar != null and avatar.input_enabled:
		if avatar.hovered != null:
			draw_arc(c, 10.0, 0.0, TAU, 28, Color(0, 0, 0, 0.35), 4.0, true)
			draw_arc(c, 10.0, 0.0, TAU, 28, UiKit.CREAM, 2.0, true)
		draw_circle(c, 3.0, Color(0, 0, 0, 0.35))
		draw_circle(c, 2.2, Color(UiKit.CREAM, 0.95))
	if avatar != null and avatar.perfect_flash > 0.0:
		_draw_vignette(s, Color(UiKit.GOLD, 0.32 * avatar.perfect_flash), 70.0 + 40.0 * avatar.perfect_flash)
	if avatar != null and avatar.station != null and avatar.station.kind == "bench" and (e.has_oysters() or e.shuck_zone >= 0):
		_draw_meter(s, e)

func _draw_meter(s: Vector2, e: Empire) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.66)
	var w := 440.0
	var r := Rect2(c.x - w * 0.5, c.y, w, 22)
	draw_style_box(UiKit.style(Color(0.03, 0.06, 0.07, 0.88), UiKit.ROPE.darkened(0.2), 11, 2), r)
	var gold_w := w * Avatar.PERFECT_WINDOW * 2.0
	var pf := avatar.perfect_flash
	if pf > 0.0:
		# the gold band blooms outward on a PERFECT
		var gw := gold_w + 60.0 * pf
		draw_style_box(UiKit.style(Color(UiKit.GOLD, 0.35 * pf), Color(UiKit.GOLD, 0.8 * pf), 14, 2), Rect2(c.x - gw * 0.5, c.y - 8.0 * pf, gw, 22 + 16.0 * pf))
	draw_style_box(UiKit.style(Color(UiKit.GOLD, 0.7 + 0.3 * pf), Color(0, 0, 0, 0), 6, 0), Rect2(c.x - gold_w * 0.5, c.y + 3, gold_w, 16))
	var mx := r.position.x + w * avatar.meter_value()
	var mc := UiKit.CREAM if not avatar.meter_perfect() else UiKit.GOLD
	if avatar.miss_flash > 0.0:
		mc = mc.lerp(UiKit.RED, avatar.miss_flash)
	draw_style_box(UiKit.style(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 3, 0), Rect2(mx - 3, c.y - 7, 6, 36))
	draw_style_box(UiKit.style(mc, Color(0, 0, 0, 0), 2, 0), Rect2(mx - 2, c.y - 6, 4, 34))
	UiKit.draw_bar(self, Rect2(c.x - w * 0.5, c.y + 32, w, 8), e.shuck_progress(), UiKit.GREEN)
	if avatar.perfect_streak >= 2:
		var fs := int(26 + 14.0 * pf)
		var txt := ("PERFECT  x%d" % avatar.perfect_streak) + (("  ·  %d PER CRACK" % e.streak_batch()) if e.streak_batch() > 1 else "")
		draw_string(UiKit.serif(), Vector2(c.x - 350 + 2, c.y - 20 + 2), txt, HORIZONTAL_ALIGNMENT_CENTER, 700, fs, Color(0, 0, 0, 0.6))
		draw_string(UiKit.serif(), Vector2(c.x - 350, c.y - 20), txt, HORIZONTAL_ALIGNMENT_CENTER, 700, fs, UiKit.GOLD.lerp(UiKit.CREAM, pf * 0.5))
	var zi := e.shuck_zone if e.shuck_zone >= 0 else e._top_zone_in_bag()
	draw_string(font, Vector2(c.x - w * 0.5 + 1, c.y + 63), "%s  ·  %d in the bucket" % [Catalog.zone(maxi(0, zi)).oyster, e.bag_count()], HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(c.x - w * 0.5, c.y + 62), "%s  ·  %d in the bucket" % [Catalog.zone(maxi(0, zi)).oyster, e.bag_count()], HORIZONTAL_ALIGNMENT_CENTER, w, 15, UiKit.SAND)

func show_offline(amount: float, seconds: float) -> void:
	show_banner("WELCOME BACK", "You were away %s. Your crew earned %s." % [Num.duration(seconds), Num.cash(amount)], UiKit.GOLD)

## Soft colored glow around the screen edges (fades to clear toward the middle).
func _draw_vignette(s: Vector2, col: Color, depth: float) -> void:
	var clear := Color(col, 0.0)
	var o := [Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]
	var i := [Vector2(depth, depth), Vector2(s.x - depth, depth), Vector2(s.x - depth, s.y - depth), Vector2(depth, s.y - depth)]
	for k in 4:
		var n := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([col, col, clear, clear]))
