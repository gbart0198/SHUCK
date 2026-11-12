extends Control
class_name TitleMenu
## Main menu over a slow pan of the dusk coast: Continue · Load Save · New Game · Settings · Quit.
## Picking a save sets up the session on the Game autoload and emits `started`; main.gd then
## reloads the scene into play. Pages: main / load / settings. Esc goes back a page.

signal started
signal quit_requested

const COL_W := 400.0
const PAGE_W := 660.0

var page := "main"
var holder: VBoxContainer
var arming := -1                # slot whose Delete was clicked once (click again to confirm)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# a soft shade on the left so the menu reads over the world
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.05, 0.06, 0.88))
	g.set_color(1, Color(0.02, 0.05, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	add_child(shade)
	var col := UiKit.vbox(6)
	col.custom_minimum_size = Vector2(PAGE_W, 0)
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 80
	col.offset_right = 80 + PAGE_W
	col.offset_top = 70
	col.offset_bottom = -50
	add_child(col)
	col.add_child(UiKit.title("SHUCK", 112, UiKit.GOLD))
	var sub := UiKit.tag("AN OYSTER SIMULATOR", UiKit.SAND, 20)
	col.add_child(sub)
	var w := UiKit.wave(UiKit.BORDER, 14)
	w.size_flags_horizontal = Control.SIZE_FILL
	w.custom_minimum_size = Vector2(COL_W, 14)
	col.add_child(w)
	col.add_child(UiKit.spacer(0, 18))
	holder = UiKit.vbox(10)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	var hint := UiKit.label("v0.9  ·  Esc goes back", 14, UiKit.MUTED)
	col.add_child(hint)
	show_page("main")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if page != "main":
			show_page("main")
		get_viewport().set_input_as_handled()

func show_page(p: String) -> void:
	page = p
	arming = -1
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	match p:
		"main": _main()
		"load": _load()
		"settings": _settings()

func _big(text: String, cb: Callable, color := UiKit.BLUE) -> Button:
	var b := UiKit.button(text, cb, 24, color)
	b.custom_minimum_size = Vector2(COL_W, 58)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	holder.add_child(b)
	return b

# ------------------------------------------------------------------ pages
func _main() -> void:
	var saves := Game.store.list()
	var cont := _big("Continue", func() -> void:
		if Game.continue_latest():
			started.emit(), UiKit.GREEN)
	cont.name = "Continue"
	if saves.is_empty():
		cont.disabled = true
		holder.add_child(_detail("No saves yet. Start a New Game."))
	else:
		holder.add_child(_detail(_summary(saves[0])))
	var load_b := _big("Load Save", func() -> void: show_page("load"))
	load_b.name = "Load"
	load_b.disabled = saves.is_empty()
	var new_b := _big("New Game", func() -> void:
		Game.new_game()
		started.emit(), UiKit.GOLD)
	new_b.name = "New"
	_big("Settings", func() -> void: show_page("settings")).name = "Settings"
	holder.add_child(UiKit.spacer(0, 8))
	_big("Quit", func() -> void: quit_requested.emit(), UiKit.RED).name = "Quit"

func _detail(text: String) -> Label:
	var l := UiKit.label(text, 15, UiKit.MUTED)
	l.custom_minimum_size = Vector2(COL_W, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _summary(s: Dictionary) -> String:
	return "%s  ·  %s  ·  %s  ·  %s played" % [s.name, s.zone, Num.cash(float(s.cash)), Num.duration(float(s.play_time))]

static func _ago(t: float) -> String:
	var d := Time.get_unix_time_from_system() - t
	if t <= 0.0:
		return "never"
	if d < 60.0:
		return "just now"
	return "%s ago" % Num.duration(d)

func _page_panel(title_text: String) -> VBoxContainer:
	var p := UiKit.panel(UiKit.PANEL)
	p.custom_minimum_size = Vector2(PAGE_W, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.title(title_text, 34, UiKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := UiKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var back := UiKit.button("Back", func() -> void: show_page("main"), 18)
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(back)
	return body

func _load() -> void:
	var body := _page_panel("LOAD SAVE")
	var saves := Game.store.list()
	if saves.is_empty():
		body.add_child(UiKit.label("No saves yet.", 18, UiKit.MUTED))
		return
	for s in saves:
		var slot := int(s.slot)
		var row := PanelContainer.new()
		var rs := UiKit.style(UiKit.PANEL_LIGHT, UiKit.BORDER.darkened(0.25), 10, 1)
		rs.border_width_left = 6
		row.add_theme_stylebox_override("panel", rs)
		body.add_child(row)
		var h := UiKit.hbox(12)
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UiKit.title(str(s.name), 24, UiKit.CREAM))
		info.add_child(UiKit.label("%s  ·  %s  ·  %s%s" % [s.zone, s.rank, Num.cash(float(s.cash)), ("  ·  %d Golden Shell%s" % [s.shells, "" if int(s.shells) == 1 else "s"]) if int(s.shells) > 0 else ""], 15, UiKit.MUTED))
		info.add_child(UiKit.label("Played %s  ·  last played %s" % [Num.duration(float(s.play_time)), _ago(float(s.last_played))], 14, UiKit.MUTED))
		var btns := UiKit.vbox(6)
		btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(btns)
		var lb := UiKit.button("LOAD", func() -> void:
			if Game.load_slot(slot):
				started.emit(), 18, UiKit.GREEN)
		lb.custom_minimum_size = Vector2(140, 40)
		btns.add_child(lb)
		var db := UiKit.button("DELETE", func() -> void: pass, 16, UiKit.RED)
		db.custom_minimum_size = Vector2(140, 36)
		db.pressed.connect(func() -> void:
			if arming == slot:
				Game.delete_slot(slot)
				show_page("load" if Game.has_saves() else "main")
			else:
				arming = slot
				db.text = "CONFIRM?")
		btns.add_child(db)

func _settings() -> void:
	var body := _page_panel("SETTINGS")
	SettingsPage.build(body)
	body.add_child(UiKit.label("More audio and video options are on the way.", 14, UiKit.MUTED))
