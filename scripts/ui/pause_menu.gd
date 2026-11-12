extends Control
class_name PauseMenu
## Esc menu. Pauses the world. Pages: main, How to Play, Controls (rebind), Settings.

signal resumed
signal quit_requested
signal main_menu_requested
signal tutorial_replay
signal tutorial_skip

var page := "main"
var body: VBoxContainer
var title_lbl: Label
var waiting_for := ""        # action being rebound
var wait_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var win := UiKit.panel()
	win.custom_minimum_size = Vector2(760, 640)
	UiKit.anchor(win, Control.PRESET_CENTER, Vector2(-380, -320))
	add_child(win)
	var v := UiKit.vbox(12)
	win.add_child(v)
	title_lbl = UiKit.title("PAUSED", 44)
	v.add_child(title_lbl)
	v.add_child(UiKit.wave(UiKit.BORDER, 12))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = UiKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	show_page("main")

func _input(event: InputEvent) -> void:
	if waiting_for != "":
		if event is InputEventMouseMotion:
			return
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			waiting_for = ""
			show_page("controls")
			get_viewport().set_input_as_handled()
			return
		if (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			if Settings.encode(event) != "":
				Settings.rebind(waiting_for, event)
				Sfx.play("coin", -10.0)
				waiting_for = ""
				get_viewport().set_input_as_handled()
				call_deferred("show_page", "controls")
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if page == "main":
			resumed.emit()
		else:
			show_page("main")

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()

func _btn(text: String, cb: Callable, color := UiKit.ORANGE) -> Button:
	var b := UiKit.button(text, cb, 22, color)
	b.custom_minimum_size = Vector2(0, 52)
	body.add_child(b)
	return b

func show_page(p: String) -> void:
	page = p
	_clear()
	match p:
		"main": _main()
		"howto": _howto()
		"controls": _controls()
		"settings": _settings()

func _main() -> void:
	title_lbl.text = "PAUSED"
	_btn("Resume", func() -> void: resumed.emit(), UiKit.GREEN)
	_btn("How to play", func() -> void: show_page("howto"), UiKit.BLUE)
	_btn("Controls", func() -> void: show_page("controls"), UiKit.BLUE)
	_btn("Settings", func() -> void: show_page("settings"), UiKit.BLUE)
	if Settings.tutorial_done:
		_btn("Replay tutorial", func() -> void:
			tutorial_replay.emit()
			resumed.emit(), UiKit.BLUE)
	else:
		_btn("Skip tutorial", func() -> void:
			tutorial_skip.emit()
			show_page("main"), UiKit.BLUE)
	body.add_child(UiKit.spacer(0, 10))
	_btn("Save and return to main menu", func() -> void: main_menu_requested.emit(), UiKit.ORANGE)
	_btn("Save and quit", func() -> void: quit_requested.emit(), UiKit.RED)
	var hint := UiKit.label("Esc to resume.  The game saves itself every 20 seconds.", 14, UiKit.MUTED)
	body.add_child(hint)

func _howto() -> void:
	title_lbl.text = "HOW TO PLAY"
	var k := func(a: String) -> String: return Settings.keys(a)
	var text := """THE LOOP
1. Rake: walk onto the mudflat, aim the dot at an oyster and click (%s). Hold to keep raking.
2. Shuck: stand at a SHUCK shack's bench and click to stab. Stab on the gold band for a PERFECT: double meat and better pearl odds.
3. Sell: walk onto a SELL dock. Your meat, and anything in the crew's Meat Crate, turns into cash.

GROWING
• Shop (%s): rake, bucket, knife, meat quality, boots, pearl luck, tide magnet, warehouse.
• Gates: walk up to a gate and press %s to open the next stretch of coast. Better oysters live further along.
• Crew (%s): Deckhands rake into the Dock Bin, Shuckers fill the Meat Crate, and one Coordinator per beach sells it all and speeds every worker up (+50% each). Then the Robotics Lab, robots and the Mega-Factory.
• Pets (%s): pearls from shucking crack Mystery Clams. Pets multiply all cash; fuse three duplicates.
• Re-Shell (%s): once a run has earned enough, trade it all for a Golden Shell (+50%% cash forever).
• Map (%s): teleport to any coast you've opened.

MOVING
Walk %s / %s / %s / %s   ·   Sprint %s   ·   Jump %s   ·   Use %s
Everything can be rebound under Controls.""" % [
		k.call("interact"), k.call("menu_shop"), k.call("use"), k.call("menu_crew"), k.call("menu_pets"), k.call("menu_reshell"), k.call("menu_map"),
		k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right"), k.call("sprint"), k.call("jump"), k.call("use")]
	var l := UiKit.label(text, 16, UiKit.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	body.add_child(l)
	_btn("Back", func() -> void: show_page("main"))

func _controls() -> void:
	title_lbl.text = "CONTROLS"
	body.add_child(UiKit.label("Click a binding, then press a key or mouse button. Esc cancels.", 15, UiKit.MUTED))
	for a in Settings.ACTIONS:
		var id := str(a.id)
		var row := UiKit.hbox(12)
		var name := UiKit.label(str(a.label), 18)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var b := UiKit.button(Settings.keys(id), func() -> void: pass, 18, UiKit.BLUE)
		b.custom_minimum_size = Vector2(240, 40)
		b.pressed.connect(func() -> void:
			waiting_for = id
			wait_btn = b
			b.text = "press a key...")
		row.add_child(b)
		body.add_child(row)
	var fixed := UiKit.label("Pause: Esc (fixed)", 15, UiKit.MUTED)
	body.add_child(fixed)
	var h := UiKit.hbox(8)
	body.add_child(h)
	var reset := UiKit.button("Reset to defaults", func() -> void:
		Settings.reset_bindings()
		show_page("controls"), 18, UiKit.RED)
	reset.custom_minimum_size = Vector2(0, 44)
	h.add_child(reset)
	var back := UiKit.button("Back", func() -> void: show_page("main"), 18)
	back.custom_minimum_size = Vector2(160, 44)
	h.add_child(back)

func _settings() -> void:
	title_lbl.text = "SETTINGS"
	SettingsPage.build(body)
	body.add_child(UiKit.spacer(0, 6))
	_btn("Back", func() -> void: show_page("main"))
