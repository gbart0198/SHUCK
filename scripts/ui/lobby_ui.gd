extends Control
class_name LobbyUI

signal start_requested(pier: int, tides: Array, boss: bool, daily: bool)
signal shop_requested
signal log_requested
signal quit_requested

var selected_pier := 1
var selected_tides: Array = []
var boss_toggle := false
var daily := false
var pier_box: HBoxContainer
var tide_box: GridContainer
var stats_box: VBoxContainer
var mult_label: Label
var start_btn: Button
var status_label: Label
var net_ip: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selected_pier = clampi(int(Game.state.get("pier", 1)), 1, 6)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.06, 0.09))
	grad.set_color(1, Color(0.10, 0.09, 0.08))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0.3, 1.0)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	# decorative water band
	var water := ColorRect.new()
	water.color = Color(0.05, 0.12, 0.16, 0.55)
	water.position = Vector2(0, 0)
	water.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	water.offset_top = -180
	water.offset_bottom = 0
	add_child(water)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var root := UiKit.vbox(12)
	margin.add_child(root)

	var header := UiKit.hbox(20)
	var title_box := UiKit.vbox(2)
	var title := UiKit.title("SHUCK", 76)
	title_box.add_child(title)
	title_box.add_child(UiKit.label(Data.t("TAGLINE", "Four hands. One knife. No refunds."), 20, UiKit.MUTED))
	title_box.add_child(UiKit.label(Data.t("LOBBY_SUB", "A friendslop oyster bar at the end of a rotting pier."), 15, UiKit.MUTED))
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	stats_box = UiKit.vbox(4)
	stats_box.custom_minimum_size = Vector2(360, 0)
	header.add_child(stats_box)
	root.add_child(header)
	root.add_child(_rule())

	var cols := UiKit.hbox(24)
	var left := UiKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UiKit.vbox(8)
	right.custom_minimum_size = Vector2(430, 0)
	cols.add_child(left)
	cols.add_child(right)
	root.add_child(cols)

	left.add_child(UiKit.label(Data.t("LOBBY_PIER", "Choose a pier"), 22, UiKit.GOLD))
	pier_box = UiKit.hbox(8)
	left.add_child(pier_box)
	left.add_child(UiKit.label(Data.t("LOBBY_TIDES", "Tides (stackable difficulty, payout multiplier)"), 22, UiKit.GOLD))
	tide_box = GridContainer.new()
	tide_box.columns = 2
	tide_box.add_theme_constant_override("h_separation", 20)
	tide_box.add_theme_constant_override("v_separation", 6)
	left.add_child(tide_box)
	mult_label = UiKit.label("", 17, UiKit.MUTED)
	left.add_child(mult_label)
	left.add_child(UiKit.spacer(0, 10))
	var how := UiKit.panel(Color(0.07, 0.09, 0.10, 0.92))
	how.custom_minimum_size = Vector2(760, 0)
	var hv := UiKit.vbox(4)
	how.add_child(hv)
	hv.add_child(UiKit.label(Data.t("HOW_TITLE", "THE SHUCK — four gestures"), 20, UiKit.GOLD))
	for line_key in ["HOW_WEDGE", "HOW_POP", "HOW_SLIDE", "HOW_RESEAT"]:
		hv.add_child(UiKit.label(Data.t(line_key, ""), 14, UiKit.CREAM))
	hv.add_child(UiKit.label(Data.t("HOW_LOOP", "Take a ticket, shuck its oysters, click the plate to serve. The ledger pays at the end of the shift."), 13, UiKit.MUTED))
	left.add_child(how)

	right.add_child(UiKit.label(Data.t("LOBBY_ACTIONS", "Service"), 22, UiKit.GOLD))
	start_btn = UiKit.button(Data.t("BTN_START", "Start shift"), _on_start, 24, true)
	start_btn.custom_minimum_size = Vector2(0, 54)
	right.add_child(start_btn)
	right.add_child(UiKit.button(Data.t("BTN_DAILY", "Daily Tide (seeded shift)"), _on_daily, 18))
	var row := UiKit.hbox(8)
	row.add_child(UiKit.button(Data.t("BTN_SHOP", "Shop"), func() -> void: shop_requested.emit(), 18))
	row.add_child(UiKit.button(Data.t("BTN_LOG", "Pearl log"), func() -> void: log_requested.emit(), 18))
	right.add_child(row)
	right.add_child(UiKit.label(Data.t("LOBBY_NET", "Co-op (M4, experimental)"), 16, UiKit.MUTED))
	right.add_child(UiKit.label(Data.t("LOBBY_NET_NOTE", "Connection + shift seed only. Live co-op verbs are not implemented."), 12, UiKit.MUTED))
	var netrow := UiKit.hbox(8)
	net_ip = LineEdit.new()
	net_ip.text = "127.0.0.1"
	net_ip.custom_minimum_size = Vector2(150, 0)
	netrow.add_child(net_ip)
	netrow.add_child(UiKit.button(Data.t("BTN_HOST", "Host"), _on_host, 15))
	netrow.add_child(UiKit.button(Data.t("BTN_JOIN", "Join"), _on_join, 15))
	right.add_child(netrow)
	status_label = UiKit.label("", 14, UiKit.MUTED)
	right.add_child(status_label)
	right.add_child(UiKit.spacer(0, 10))
	right.add_child(UiKit.button(Data.t("BTN_QUIT", "Quit"), func() -> void: quit_requested.emit(), 16))
	var help := Data.t("LOBBY_CONTROLS", "WASD move · mouse look · LMB interact / hold gestures · Esc pause · P photo mode · Shift sprint")
	right.add_child(UiKit.label(help, 13, UiKit.MUTED))

	_refresh_stats()
	_build_piers()
	_build_tides()
	_refresh_mult()
	if Game.last_error != "" and Game.last_error != "missing":
		status_label.text = "save: " + Game.last_error
	elif FileAccess.file_exists(SaveGame.DEFAULT_PATH):
		status_label.text = Data.t("LOBBY_SAVED", "Save loaded from user://save.json")

func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.30, 0.25, 0.18)
	c.custom_minimum_size = Vector2(0, 1)
	return c

func _refresh_stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	stats_box.add_child(_stat_row(Data.t("STAT_MONEY", "Shells"), "¢" + str(Game.money()), UiKit.GOLD))
	stats_box.add_child(_stat_row(Data.t("STAT_RANK", "Rank"),
		Data.t(Registry.balance.rank_names[int(Game.state.get("rank", 0))], "Deckhand"), UiKit.CREAM))
	stats_box.add_child(_stat_row(Data.t("STAT_PIER", "Highest pier"), str(Game.state.get("pier", 1)) + " / 6", UiKit.CREAM))
	stats_box.add_child(_stat_row(Data.t("STAT_SHIFTS", "Shifts"), str(Game.state.get("shifts", 0)), UiKit.CREAM))
	stats_box.add_child(_stat_row(Data.t("STAT_LOG", "Pearl log"), "%d / 48" % Game.log_entries(), UiKit.CREAM))
	stats_box.add_child(_stat_row(Data.t("STAT_BADGES", "Badges"), "%d / 12" % Game.state.get("badges", []).size(), UiKit.CREAM))
	if not Game.state.get("credits", false):
		stats_box.add_child(_stat_row(Data.t("STAT_CREDITS", "Credits"), Data.t("STAT_LOCKED", "locked"), UiKit.MUTED))

func _stat_row(a: String, b: String, color: Color) -> Control:
	var h := UiKit.hbox(10)
	var l := UiKit.label(a, 16, UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := UiKit.label(b, 18, color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	h.add_child(r)
	return h

func _build_piers() -> void:
	for c in pier_box.get_children():
		c.queue_free()
	var unlocked := int(Game.state.get("pier", 1))
	for i in range(1, 7):
		var p := Registry.get_pier(i)
		var b := Button.new()
		b.text = Data.t(p.name_key, "Pier %d" % i)
		b.custom_minimum_size = Vector2(150, 44)
		b.add_theme_font_size_override("font_size", 15)
		var sel := i == selected_pier
		var bg := Color(0.16, 0.21, 0.23) if not sel else Color(0.6, 0.3, 0.13)
		b.add_theme_stylebox_override("normal", UiKit.style(bg, UiKit.ORANGE if sel else UiKit.BORDER, 4))
		b.add_theme_stylebox_override("hover", UiKit.style(bg.lightened(0.1), UiKit.ORANGE, 4))
		b.add_theme_color_override("font_color", UiKit.CREAM)
		if i > unlocked:
			b.disabled = true
			b.text += "\n" + Data.t("LOBBY_LOCKED", "locked")
			b.add_theme_color_override("font_disabled_color", UiKit.MUTED.darkened(0.3))
		b.pressed.connect(func() -> void:
			selected_pier = i
			boss_toggle = false
			_build_piers())
		pier_box.add_child(b)

func _build_tides() -> void:
	for c in tide_box.get_children():
		c.queue_free()
	for t in Registry.tides:
		var cb := CheckBox.new()
		cb.text = "%s  ×%.1f  — %s" % [Data.t(t.name_key, t.id), t.payout_mult, Data.t(t.desc_key, "")]
		cb.add_theme_font_size_override("font_size", 14)
		cb.button_pressed = selected_tides.has(t.id)
		cb.toggled.connect(func(on: bool) -> void:
			if on and not selected_tides.has(t.id):
				selected_tides.append(t.id)
			elif not on:
				selected_tides.erase(t.id)
			_refresh_mult())
		tide_box.add_child(cb)
	var boss_row := UiKit.hbox(6)
	var p := Registry.get_pier(selected_pier)
	if p.has_boss and selected_pier >= 3:
		var bcb := CheckBox.new()
		var beaten: bool = Game.state.get("bosses", []).has(selected_pier)
		bcb.text = Data.t("LOBBY_BOSS", "Boss shift (3 min, Named Pearl)") + (" — beaten" if beaten else "")
		bcb.button_pressed = boss_toggle
		bcb.disabled = beaten
		bcb.add_theme_font_size_override("font_size", 14)
		bcb.toggled.connect(func(on: bool) -> void: boss_toggle = on)
		boss_row.add_child(bcb)
	tide_box.add_child(boss_row)

func _refresh_mult() -> void:
	var m := 1.0
	for t in selected_tides:
		var td := Registry.get_tide(str(t))
		if td != null:
			m *= td.payout_mult
	mult_label.text = Data.t("LOBBY_MULT", "Selected Tides") + ": %d   ·   payout ×%.2f" % [selected_tides.size(), m]
	if start_btn:
		start_btn.text = Data.t("BTN_START", "Start shift")
		if boss_toggle:
			start_btn.text = Data.t("BTN_START_BOSS", "Start BOSS shift")
		if daily:
			start_btn.text = Data.t("BTN_START_DAILY", "Start Daily Tide")

func _on_start() -> void:
	daily = false
	start_requested.emit(selected_pier, selected_tides.duplicate(), boss_toggle and selected_pier >= 3, false)

func _on_daily() -> void:
	var date := int(Time.get_unix_time_from_system() / 86400.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = date
	var picks: Array = []
	var pool := Registry.tides.duplicate()
	for i in 2:
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		picks.append(pool[idx].id)
		pool.remove_at(idx)
	selected_pier = clampi(int(Game.state.get("pier", 1)), 1, 6)
	start_requested.emit(selected_pier, picks, false, true)

func _on_host() -> void:
	if Net.host_shift(int(Time.get_unix_time_from_system())):
		status_label.text = Data.t("NET_HOSTING", "Hosting on port 24777 — share your IP.")
	else:
		status_label.text = Data.t("NET_FAIL", "Could not host.")

func _on_join() -> void:
	if Net.join(net_ip.text.strip_edges()):
		status_label.text = Data.t("NET_JOINING", "Joining " + net_ip.text + " …")
	else:
		status_label.text = Data.t("NET_FAIL", "Could not join.")
