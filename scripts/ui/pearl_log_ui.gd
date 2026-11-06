extends Control
class_name PearlLogUI

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.99)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var v := UiKit.vbox(10)
	margin.add_child(v)
	var head := UiKit.hbox(16)
	var title := UiKit.title(Data.t("LOG_TITLE", "THE PEARL LOG"), 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.label("%d / 48" % Game.log_entries(), 26, UiKit.GOLD))
	head.add_child(UiKit.button(Data.t("BTN_CLOSE", "Close"), func() -> void: closed.emit(), 18))
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var body := UiKit.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(UiKit.label(Data.t("LOG_SHAPES", "6 shapes × 8 colours. Shape and count, not colour alone."), 15, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var log: Dictionary = Game.state.get("log", {})
	var cfg := Registry.pearl_config
	for shape in 6:
		for colour in 8:
			var key := "%d-%d" % [shape, colour]
			var cell := UiKit.panel(Color(0.07, 0.09, 0.10) if not log.has(key) else Color(0.12, 0.14, 0.11),
				Color(0.22, 0.27, 0.28) if not log.has(key) else Color(0.55, 0.6, 0.35))
			cell.custom_minimum_size = Vector2(185, 74)
			var cv := UiKit.vbox(0)
			cell.add_child(cv)
			var nm := UiKit.label("%s %s" % [cfg.colours[colour], cfg.shapes[shape]], 13,
				UiKit.CREAM if log.has(key) else UiKit.MUTED.darkened(0.25))
			cv.add_child(nm)
			if log.has(key):
				var e: Dictionary = log[key]
				cv.add_child(UiKit.label("×%d  L%d  %.1fmm" % [int(e.count), int(e.bestLustre), float(e.bestSize)], 13, UiKit.GOLD))
			else:
				cv.add_child(UiKit.label("—", 13, UiKit.MUTED.darkened(0.4)))
			grid.add_child(cell)
	body.add_child(grid)

	body.add_child(UiKit.label(Data.t("LOG_NAMED", "Named pearls"), 22, UiKit.GOLD))
	var named_box := UiKit.hbox(10)
	var owned_named := []
	for p in Game.state.get("pearls", []):
		if str(p.get("named", "")) != "":
			owned_named.append(str(p.named))
	for d in cfg.named_pearls:
		var has: bool = owned_named.has(str(d.id))
		var pnl := UiKit.panel(Color(0.10, 0.09, 0.07) if has else Color(0.07, 0.08, 0.09))
		pnl.custom_minimum_size = Vector2(180, 90)
		var pv := UiKit.vbox(2)
		pnl.add_child(pv)
		pv.add_child(UiKit.label(str(d.name), 15, UiKit.GOLD if has else UiKit.MUTED))
		pv.add_child(UiKit.label(Data.t("LOG_PIER", "Pier") + " %d" % int(d.pier), 12, UiKit.MUTED))
		pv.add_child(UiKit.label(str(d.flavour) if has else Data.t("LOG_LOCKED", "not found"), 11, UiKit.MUTED))
		named_box.add_child(pnl)
	body.add_child(named_box)

	body.add_child(UiKit.label(Data.t("LOG_COLLECTIONS", "Relics, badges, cosmetics"), 22, UiKit.GOLD))
	var relics := UiKit.label(Data.t("LOG_RELICS", "Relics") + ": " + (", ".join(Game.state.get("relics", [])) if not Game.state.get("relics", []).is_empty() else "—"), 15, UiKit.CREAM)
	body.add_child(relics)
	var badge_names: Array[String] = []
	for b in Registry.badges:
		if Game.has_badge(b.id):
			badge_names.append(Data.t(b.name_key, b.id))
	body.add_child(UiKit.label(Data.t("LOG_BADGES", "Badges") + ": " + (", ".join(badge_names) if not badge_names.is_empty() else "—"), 15, UiKit.CREAM))
	body.add_child(UiKit.label(Data.t("LOG_COSMETICS", "Cosmetics owned") + ": " + str(Game.state.get("cosmetics", {}).get("owned", []).size()), 15, UiKit.CREAM))
