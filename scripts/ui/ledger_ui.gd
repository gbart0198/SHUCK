extends Control
class_name LedgerUI
## The fisherman's ledger. Never a "YOU DIED" (SPEC §3, §7.3).

signal shop_pressed
signal next_pressed
signal lobby_pressed

var result: Dictionary = {}
var font: Font

func setup(r: Dictionary) -> void:
	result = r
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.panel(Color(0.10, 0.085, 0.07, 0.98), Color(0.42, 0.34, 0.22))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var v := UiKit.vbox(10)
	panel.add_child(v)
	var title := UiKit.title(Data.t("LEDGER_TITLE", "THE LEDGER"), 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label(Data.t("LEDGER_SUB", "The night's takings, in your own hand."), 16, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_rule())
	var pier_name := Data.t(Registry.get_pier(int(result.get("pier", 1))).name_key, "Pier")
	v.add_child(_row(Data.t("LEDGER_PIER", "Pier"), pier_name, UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_EARNINGS", "Earnings"), "¢%d" % int(result.get("base", 0)), UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_TIPS", "Tips"), "¢%d" % int(result.get("tips", 0)), UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_TOTAL", "Total"), "¢%d" % int(result.get("total", 0)), UiKit.GOLD, 24))
	v.add_child(_rule())
	v.add_child(_row(Data.t("LEDGER_WALKED", "Walked out"), str(int(result.get("walked_out", 0))),
		UiKit.RED if int(result.get("walked_out", 0)) > 0 else UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_PEARLS", "Pearls found"), "%d  (¢%d)" % [int(result.get("pearls", 0)), int(result.get("pearl_value", 0))], UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_OYSTERS", "Oysters served"), str(int(result.get("oysters", 0))), UiKit.CREAM))
	v.add_child(_row(Data.t("LEDGER_PERFECT", "Perfect pops"), str(int(result.get("perfect", 0))), UiKit.CREAM))
	v.add_child(_rule())
	var quota_met := bool(result.get("quota_met", false))
	v.add_child(_row(Data.t("LEDGER_QUOTA", "Quota"), ("MET  %d / %d" % [int(result.get("total", 0)), int(result.get("quota", 0))]) if quota_met else ("MISSED  %d / %d" % [int(result.get("total", 0)), int(result.get("quota", 0))]),
		UiKit.GREEN if quota_met else UiKit.RED))
	var stars := int(result.get("stars", 0))
	var starrow := UiKit.label("%s%s%s   %s" % ["★" if stars >= 1 else "☆", "★" if stars >= 2 else "☆", "★" if stars >= 3 else "☆",
		Data.t("LEDGER_STARS", "stars")], 30, UiKit.GOLD)
	starrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(starrow)
	v.add_child(_row(Data.t("LEDGER_XP", "XP"), "+%d  (rank %s)" % [int(result.get("xp", 0)),
		Data.t(Registry.balance.rank_names[int(result.get("rank", 0))], "Deckhand")], UiKit.CREAM))
	if not result.get("badges", []).is_empty():
		var names: Array[String] = []
		for b in result.badges:
			for bd in Registry.badges:
				if bd.id == b:
					names.append(Data.t(bd.name_key, bd.id))
		v.add_child(_row(Data.t("LEDGER_BADGES", "Badges"), ", ".join(names), UiKit.GOLD))
	if bool(result.get("boss", false)):
		v.add_child(_row(Data.t("LEDGER_BOSS", "Boss shift"),
			Data.t("LEDGER_BOSS_WIN", "The King is shucked.") if bool(result.get("boss_win", false)) else Data.t("LEDGER_BOSS_LOSE", "It got away."),
			UiKit.GREEN if bool(result.get("boss_win", false)) else UiKit.RED))
	if bool(result.get("credits", false)):
		var c := UiKit.title(Data.t("LEDGER_CREDITS", "CREDITS"), 34)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(c)
		var line := UiKit.label(Data.t("LEDGER_CREDITS_SUB", "SHUCK — a friendslop oyster bar. Thanks for playing. The Franchise is open: buy tiers 5–6."), 14, UiKit.CREAM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(line)
	v.add_child(_rule())
	var buttons := UiKit.hbox(10)
	var shop := UiKit.button(Data.t("BTN_SHOP", "Shop"), func() -> void: shop_pressed.emit(), 20, true)
	var next := UiKit.button(Data.t("BTN_NEXT", "Next shift"), func() -> void: next_pressed.emit(), 20, true)
	var lobby := UiKit.button(Data.t("BTN_LOBBY", "Lobby"), func() -> void: lobby_pressed.emit(), 20)
	buttons.add_child(shop)
	buttons.add_child(next)
	buttons.add_child(lobby)
	v.add_child(buttons)
	var saved := UiKit.label(Data.t("LEDGER_SAVED", "Saved to user://save.json"), 13, UiKit.MUTED)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(saved)

func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.32, 0.27, 0.20)
	c.custom_minimum_size = Vector2(0, 1)
	return c

func _row(a: String, b: String, color: Color, fs := 19) -> Control:
	var h := UiKit.hbox(12)
	var l := UiKit.label(a, fs, UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := UiKit.label(b, fs, color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	h.add_child(r)
	return h
