extends Control
class_name ShopUI

signal closed

const LINES := ["knife", "gloves", "bench", "auto", "floor"]
const LINE_KEYS := {"knife": "LINE_KNIFE", "gloves": "LINE_GLOVES", "bench": "LINE_BENCH", "auto": "LINE_AUTO", "floor": "LINE_FLOOR"}
const LINE_FALLBACK := {"knife": "Knives", "gloves": "Gloves", "bench": "The Bench", "auto": "Automation", "floor": "Shop floor"}

var content: VBoxContainer
var tab := 0
var money_label: Label
var tab_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.99)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var v := UiKit.vbox(12)
	margin.add_child(v)
	var head := UiKit.hbox(16)
	var title := UiKit.title(Data.t("SHOP_TITLE", "THE BACK ROOM"), 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	money_label = UiKit.label("", 30, UiKit.GOLD)
	head.add_child(money_label)
	v.add_child(head)
	var tabs := UiKit.hbox(8)
	for i in 3:
		var names := [Data.t("SHOP_TAB_UPGRADES", "Upgrades"), Data.t("SHOP_TAB_COSMETICS", "Cosmetics"), Data.t("SHOP_TAB_GADGETS", "Gadgets")]
		var b := UiKit.button(names[i], func() -> void:
			tab = i
			refresh(), 18, i == 0)
		tabs.add_child(b)
		tab_buttons.append(b)
	tabs.add_child(UiKit.spacer())
	tabs.add_child(UiKit.button(Data.t("BTN_CLOSE", "Close"), func() -> void: closed.emit(), 18))
	v.add_child(tabs)
	v.add_child(_rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	content = UiKit.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	refresh()

func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.3, 0.25, 0.18)
	c.custom_minimum_size = Vector2(0, 1)
	return c

func refresh() -> void:
	if content == null:
		return
	money_label.text = "¢" + str(Game.money())
	for i in tab_buttons.size():
		var b := tab_buttons[i]
		b.add_theme_stylebox_override("normal", UiKit.style(
			Color(0.6, 0.3, 0.13) if tab == i else Color(0.16, 0.21, 0.23),
			UiKit.ORANGE if tab == i else UiKit.BORDER, 4))
	for c in content.get_children():
		c.queue_free()
	match tab:
		0:
			_build_upgrades()
		1:
			_build_cosmetics()
		2:
			_build_gadgets()

func _state() -> Dictionary:
	return {"money": Game.money(), "upgrades": Game.upgrades(), "pier": Game.pier(), "franchise": Game.franchise()}

func _build_upgrades() -> void:
	for line in LINES:
		var panel := UiKit.panel()
		var h := UiKit.hbox(16)
		panel.add_child(h)
		var left := UiKit.vbox(4)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tier := Game.tier(line)
		left.add_child(UiKit.label(Data.t(LINE_KEYS[line], LINE_FALLBACK[line]) + "  ·  tier %d / 6" % tier, 22, UiKit.GOLD))
		var u := Registry.upgrade(line, tier + 1)
		if u == null:
			left.add_child(UiKit.label(Data.t("SHOP_MAXED", "Maxed. Nothing left to buy."), 17, UiKit.MUTED))
			h.add_child(left)
			continue
		left.add_child(UiKit.label(Data.t(u.name_key, "Tier %d" % u.tier), 19, UiKit.CREAM))
		left.add_child(UiKit.label(Data.t(u.desc_key, ""), 15, UiKit.MUTED))
		h.add_child(left)
		var right := UiKit.vbox(6)
		right.custom_minimum_size = Vector2(230, 0)
		var check := Economy.can_buy(_state(), line)
		var cost := UiKit.label("¢%d" % u.cost, 24, UiKit.GOLD if check.ok else UiKit.MUTED)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(cost)
		var b := UiKit.button(Data.t("SHOP_BUY", "Buy"), func() -> void:
			var r := Game.buy_upgrade(line)
			if not r.ok:
				status(r.reason)
			refresh(), 18, true)
		b.disabled = not check.ok
		if not check.ok:
			match str(check.get("reason", "")):
				"locked":
					b.text = Data.t("SHOP_LOCKED", "Locked") + " (pier %d)" % int(check.get("unlock_pier", 1))
				"money":
					b.text = Data.t("SHOP_NEED_MONEY", "Need more shells")
				"maxed":
					b.text = Data.t("SHOP_MAXED", "Maxed")
		right.add_child(b)
		h.add_child(right)
		content.add_child(panel)
	var note := UiKit.label(Data.t("SHOP_NOTE", "Tiers unlock with piers. Automation caps at grade B and halves pearl odds."), 13, UiKit.MUTED)
	content.add_child(note)

func status(reason: String) -> void:
	if reason == "":
		return
	Sfx.play("click", -8.0)

func _build_cosmetics() -> void:
	var by_slot := {}
	for c in Registry.cosmetics:
		if not by_slot.has(c.slot):
			by_slot[c.slot] = []
		by_slot[c.slot].append(c)
	for slot in by_slot.keys():
		content.add_child(UiKit.label(str(slot).to_upper(), 20, UiKit.GOLD))
		for c in by_slot[slot]:
			var h := UiKit.hbox(12)
			var owned := Game.owns_cosmetic(c.id)
			var swatch := ColorRect.new()
			swatch.color = c.color
			swatch.custom_minimum_size = Vector2(26, 26)
			h.add_child(swatch)
			var name := UiKit.label(Data.t(c.name_key, c.id), 17, UiKit.CREAM)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(name)
			if c.badge_only:
				h.add_child(UiKit.label(Data.t("SHOP_BADGE_ONLY", "badge reward"), 14, UiKit.MUTED))
			else:
				h.add_child(UiKit.label("¢%d" % c.price, 17, UiKit.GOLD))
			if owned:
				var eq: bool = Game.equipped(c.slot) == c.id
				var b := UiKit.button(Data.t("SHOP_EQUIPPED", "Equipped") if eq else Data.t("SHOP_EQUIP", "Equip"),
					func() -> void:
						Game.equip(c.slot, c.id)
						refresh()
						if Game.equipped("knife") == c.id:
							Sfx.play("click"), 14)
				b.disabled = eq
				h.add_child(b)
			elif not c.badge_only:
				var b := UiKit.button(Data.t("SHOP_BUY", "Buy"), func() -> void:
					if Game.buy_cosmetic(c.id):
						Sfx.play("money")
					refresh(), 14, true)
				b.disabled = Game.money() < c.price
				h.add_child(b)
			content.add_child(h)

func _build_gadgets() -> void:
	for g in Registry.gadgets:
		var h := UiKit.hbox(12)
		var left := UiKit.vbox(2)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(UiKit.label(Data.t(g.name_key, g.id), 19, UiKit.CREAM))
		left.add_child(UiKit.label(Data.t(g.desc_key, ""), 14, UiKit.MUTED))
		h.add_child(left)
		var owned := int(Game.state.get("gadgets", {}).get(g.id, 0))
		h.add_child(UiKit.label("×%d" % owned, 18, UiKit.MUTED))
		h.add_child(UiKit.label("¢%d" % g.cost, 18, UiKit.GOLD))
		var b := UiKit.button(Data.t("SHOP_BUY", "Buy"), func() -> void:
			if Game.money() < g.cost:
				return
			Game.add_money(-g.cost)
			var gs: Dictionary = Game.state.get("gadgets", {})
			gs[g.id] = int(gs.get(g.id, 0)) + 1
			Game.state["gadgets"] = gs
			Sfx.play("money")
			refresh(), 14, true)
		b.disabled = Game.money() < g.cost
		h.add_child(b)
		content.add_child(h)
	content.add_child(UiKit.label(Data.t("SHOP_GADGET_NOTE", "Gadgets are physical objects (M3 content; purchase and carry tracking are wired)."), 13, UiKit.MUTED))
