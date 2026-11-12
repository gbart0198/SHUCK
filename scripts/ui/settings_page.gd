extends RefCounted
class_name SettingsPage
## The settings rows, shared by the title screen and the pause menu.
## Grouped Audio / Video / Mouse; every change applies and saves immediately (Settings.set_option).
## More options (music/sfx buses, resolution, quality presets) are planned; add them here.

static func build(body: VBoxContainer) -> void:
	_section(body, "AUDIO")
	_slider(body, "Master volume", 0.0, 1.0, 0.05, Settings.volume, "%d%%", 100.0, func(x: float) -> void: Settings.set_option("volume", x))
	_section(body, "VIDEO")
	_check(body, "Fullscreen", Settings.fullscreen, func(on: bool) -> void: Settings.set_option("fullscreen", on))
	_check(body, "VSync", Settings.vsync, func(on: bool) -> void: Settings.set_option("vsync", on))
	_slider(body, "Field of view", 55.0, 110.0, 1.0, Settings.fov, "%d", 1.0, func(x: float) -> void: Settings.set_option("fov", x))
	_check(body, "Head bob", Settings.head_bob, func(on: bool) -> void: Settings.set_option("head_bob", on))
	_section(body, "MOUSE")
	_slider(body, "Sensitivity", 0.1, 4.0, 0.05, Settings.sensitivity, "%.2f", 1.0, func(x: float) -> void: Settings.set_option("sensitivity", x))
	_check(body, "Invert mouse Y", Settings.invert_y, func(on: bool) -> void: Settings.set_option("invert_y", on))

static func _section(body: VBoxContainer, text: String) -> void:
	body.add_child(UiKit.spacer(0, 4))
	body.add_child(UiKit.tag(text, UiKit.SAND, 16))

static func _slider(body: VBoxContainer, label_text: String, min_v: float, max_v: float, step_v: float, value: float, fmt: String, show_mult: float, on_change: Callable) -> void:
	var row := UiKit.hbox(12)
	var l := UiKit.label(label_text, 18)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 28)
	row.add_child(s)
	var v := UiKit.label(_fmt(fmt, value * show_mult), 16, UiKit.MUTED)
	v.custom_minimum_size = Vector2(70, 0)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = _fmt(fmt, x * show_mult)
		on_change.call(x))
	body.add_child(row)

static func _fmt(fmt: String, x: float) -> String:
	return fmt % (int(round(x)) if fmt.contains("%d") else x)

static func _check(body: VBoxContainer, label_text: String, value: bool, on_change: Callable) -> void:
	# an On / Off pill (the stock checkbox is invisible on dark panels when unticked)
	var row := UiKit.hbox(12)
	var l := UiKit.label(label_text, 18)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 34)
	b.add_theme_font_size_override("font_size", 16)
	var paint := func(on: bool) -> void:
		b.text = "On" if on else "Off"
		UiKit.paint(b, UiKit.GREEN if on else UiKit.BORDER)
		# toggle buttons show their "pressed" box while on; keep it the same as normal
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("hover"))
	paint.call(value)
	b.toggled.connect(func(on: bool) -> void:
		paint.call(on)
		Sfx.play("click", -12.0)
		on_change.call(on))
	row.add_child(b)
	body.add_child(row)
