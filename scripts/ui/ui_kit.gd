extends RefCounted
class_name UiKit
## The SHUCK look, beach edition: deep dusk-sea panels framed in sand-coloured rope,
## cream type, serif headings like a painted harbour sign, sea-glass + sunset-coral accents.
## Still muted and low-saturation so it sits with the foggy pier world. Every screen builds from these.

# ---- palette
const BG := Color(0.05, 0.09, 0.105, 0.96)
const PANEL := Color(0.065, 0.11, 0.125, 0.96)       # deep water at dusk
const PANEL_LIGHT := Color(0.13, 0.15, 0.145, 1.0)    # wet sand plank
const HUD_BG := Color(0.05, 0.09, 0.105, 0.80)
const BORDER := Color(0.42, 0.37, 0.27, 1.0)          # rope
const ROPE := Color(0.62, 0.53, 0.37, 1.0)
const SHADOW := Color(0.01, 0.02, 0.03, 0.45)
const CREAM := Color(0.95, 0.91, 0.82)
const SAND := Color(0.84, 0.74, 0.55)
const MUTED := Color(0.63, 0.70, 0.68)                 # sea-foam grey
const ORANGE := Color(0.93, 0.52, 0.31)                # sunset coral
const GREEN := Color(0.47, 0.82, 0.68)                 # sea glass
const RED := Color(0.90, 0.35, 0.32)
const GOLD := Color(1.0, 0.84, 0.42)
const BLUE := Color(0.38, 0.63, 0.72)
const PINK := Color(0.82, 0.52, 0.58)                  # shell pink
const PURPLE := Color(0.58, 0.47, 0.72)
## Button fills: driftwood, dark coral, dark sea glass.
const BTN := Color(0.21, 0.19, 0.16)
const BTN_ACCENT := Color(0.52, 0.25, 0.14)
const BTN_GOOD := Color(0.13, 0.33, 0.30)

static var _serif: Font

static func font() -> Font:
	return ThemeDB.fallback_font

## Serif for headings (painted-sign feel). Falls back to the default font if none is installed.
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
		f.font_weight = 700
		f.fallbacks = [ThemeDB.fallback_font]
		_serif = f
	return _serif

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	t.set_color("font_color", "CheckBox", CREAM)
	# slim sand scrollbars
	var track := style(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 4, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var grab := style(BORDER, Color(0, 0, 0, 0), 4, 0)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", style(ROPE, Color(0, 0, 0, 0), 4, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", style(SAND, Color(0, 0, 0, 0), 4, 0))
	# sliders + checkboxes in the pause menu
	t.set_stylebox("slider", "HSlider", style(Color(0.03, 0.06, 0.07), BORDER, 4, 1))
	t.set_stylebox("grabber_area", "HSlider", style(BTN_GOOD.lightened(0.15), Color(0, 0, 0, 0), 4, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(GREEN.darkened(0.2), Color(0, 0, 0, 0), 4, 0))
	return t

static func style(bg: Color, border: Color = BORDER, radius := 10, border_w := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s

static func panel(bg := PANEL, border := BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(bg, border)
	s.shadow_color = SHADOW
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", s)
	return p

static func label(text: String, size := 18, color := CREAM, _outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Serif heading with a soft drop shadow, like paint on a weathered board.
static func title(text: String, size := 46, color := GOLD) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", serif())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

## Small caps-style section tag (e.g. "NEXT", "THE OPERATION").
static func tag(text: String, color := SAND, size := 13) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", serif())
	return l

## `color` is the hover border accent; fills stay muted.
static func button(text: String, cb: Callable, size := 18, color := ORANGE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	paint(b, color)
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: Sfx.play("click", -12.0))
	return b

static func paint(b: Button, color: Color) -> void:
	var bg := BTN
	if color == GREEN or color == BTN_GOOD:
		bg = BTN_GOOD
	elif color == ORANGE or color == GOLD:
		bg = BTN_ACCENT
	b.add_theme_stylebox_override("normal", _btn_style(bg, color.darkened(0.4)))
	b.add_theme_stylebox_override("hover", _btn_style(bg.lightened(0.12), color))
	var pressed := _btn_style(bg.darkened(0.2), GOLD)
	pressed.border_width_bottom = 1
	pressed.content_margin_top += 2
	b.add_theme_stylebox_override("pressed", pressed)
	var dis := _btn_style(bg.darkened(0.4).lerp(BTN.darkened(0.3), 0.6), BORDER.darkened(0.45))
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))

## Buttons have a thicker bottom edge so they read as chunky wooden blocks.
static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := style(bg, border, 8, 2)
	s.border_width_bottom = 4
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func spacer(min_x := 0, min_y := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_x, min_y)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## A small keycap, e.g. [E], used in prompts and the tutorial.
static func keycap(text: String, size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(Color(0.17, 0.16, 0.14), SAND.darkened(0.25), 5, 1)
	s.border_width_bottom = 3
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 1
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, size, CREAM))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## A pill-shaped value chip ("$1.2K", "12 pearls").
static func chip(text: String, color := CREAM, size := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(Color(0.03, 0.06, 0.07, 0.85), color.darkened(0.45), 14, 1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, color)
	l.name = "Text"
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func set_chip(c: PanelContainer, text: String) -> void:
	(c.get_node("Text") as Label).text = text

## A hand-drawn wave line, used as a divider under headings.
static func wave(color := BORDER, height := 10.0) -> Control:
	var w := Wave.new()
	w.color = color
	w.custom_minimum_size = Vector2(0, height)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

## A slim rounded fill bar (bucket, Dock Bin, Meat Crate).
static func bar(fill: Color, height := 8.0) -> Bar:
	var b := Bar.new()
	b.fill = fill
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func rarity_color(r: int) -> Color:
	return Catalog.RARITIES[clampi(r, 0, Catalog.RARITIES.size() - 1)].color

## Anchor a control to a preset and offset it from that anchor point.
static func anchor(c: Control, preset: int, off: Vector2) -> void:
	c.set_anchors_preset(preset)
	var sz := c.custom_minimum_size
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_WIDE]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN

## Rounded track + fill drawn with style boxes (used by HUD bars and meters).
static func draw_bar(ci: CanvasItem, r: Rect2, k: float, fill: Color, track := Color(0.03, 0.06, 0.07, 0.85), edge := BORDER) -> void:
	var rad := int(r.size.y * 0.5)
	var t := style(track, edge, rad, 1)
	ci.draw_style_box(t, r)
	k = clampf(k, 0.0, 1.0)
	if k > 0.0:
		var fr := Rect2(r.position + Vector2(2, 2), Vector2(maxf(r.size.y - 4.0, (r.size.x - 4.0) * k), r.size.y - 4.0))
		var f := style(fill, Color(0, 0, 0, 0), maxi(1, rad - 2), 0)
		ci.draw_style_box(f, fr)
		# a thin highlight like wet light on the top edge
		ci.draw_line(fr.position + Vector2(rad, 1), fr.position + Vector2(fr.size.x - rad, 1), Color(1, 1, 1, 0.18), 1.0)


class Wave extends Control:
	var color := Color(0.42, 0.37, 0.27)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array()
		var steps := int(w / 6.0) + 1
		for i in steps + 1:
			var x := minf(w, float(i) * 6.0)
			pts.append(Vector2(x, h * 0.5 + sin(x / w * TAU * maxf(3.0, w / 90.0)) * h * 0.3))
		if pts.size() >= 2:
			draw_polyline(pts, color, 2.0, true)


class Bar extends Control:
	var fill := Color(0.47, 0.82, 0.68)
	var value := 0.0

	func set_value(v: float) -> void:
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()

	func _draw() -> void:
		UiKit.draw_bar(self, Rect2(Vector2.ZERO, size), value, fill)


## A small hand-drawn glyph (no emoji fonts needed): coin, oyster, meat, pearl, shell, crew, spark.
static func icon(kind: String, px := 22.0) -> Icon:
	var i := Icon.new()
	i.kind = kind
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i


class Icon extends Control:
	var kind := "coin"

	static func _oval(c: Vector2, r: Vector2, n := 20) -> PackedVector2Array:
		var p := PackedVector2Array()
		for k in n:
			var a := TAU * float(k) / float(n)
			p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return p

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var u := s / 22.0
		match kind:
			"coin":
				draw_circle(c, 10.0 * u, Color(0.62, 0.45, 0.12))
				draw_circle(c, 8.6 * u, Color(1.0, 0.82, 0.38))
				draw_arc(c, 6.2 * u, 0, TAU, 24, Color(0.78, 0.58, 0.18), 1.4 * u, true)
				draw_arc(c + Vector2(-2, -2) * u, 4.0 * u, PI * 1.05, PI * 1.6, 8, Color(1, 1, 1, 0.6), 1.4 * u, true)
			"oyster":
				var body := _oval(c + Vector2(0, 1) * u, Vector2(10, 7) * u)
				draw_colored_polygon(body, Color(0.47, 0.52, 0.54))
				draw_polyline(body + PackedVector2Array([body[0]]), Color(0.25, 0.28, 0.3), 1.2 * u, true)
				for k in 3:
					draw_arc(c + Vector2(-9, 1) * u, (5.0 + k * 3.5) * u, -0.7, 0.7, 10, Color(0.3, 0.33, 0.35), 1.1 * u, true)
			"meat":
				draw_colored_polygon(_oval(c + Vector2(0, 2) * u, Vector2(10, 6.5) * u), Color(0.36, 0.38, 0.4))
				draw_colored_polygon(_oval(c + Vector2(0, 1) * u, Vector2(7.5, 4.6) * u), Color(0.95, 0.82, 0.74))
				draw_circle(c + Vector2(-2.5, -0.5) * u, 1.6 * u, Color(1, 1, 1, 0.55))
			"pearl":
				draw_circle(c, 8.0 * u, Color(0.78, 0.76, 0.8))
				draw_circle(c + Vector2(-0.5, -0.5) * u, 7.0 * u, Color(0.96, 0.94, 0.92))
				draw_circle(c + Vector2(-2.5, -2.5) * u, 2.2 * u, Color(1, 1, 1, 0.9))
			"shell":
				var pts := PackedVector2Array([c + Vector2(0, 8) * u])
				for k in 9:
					var a := PI + PI * float(k) / 8.0
					pts.append(c + Vector2(cos(a) * 10.0, 3.0 + sin(a) * 10.0) * u)
				draw_colored_polygon(pts, Color(1.0, 0.8, 0.35))
				for k in 5:
					var a := PI + PI * (0.1 + 0.8 * float(k) / 4.0)
					draw_line(c + Vector2(0, 8) * u, c + Vector2(cos(a) * 9.0, 3.0 + sin(a) * 9.0) * u, Color(0.7, 0.5, 0.15), 1.1 * u, true)
			"crew":
				draw_circle(c + Vector2(0, -4) * u, 4.2 * u, Color(0.85, 0.66, 0.5))
				draw_colored_polygon(_oval(c + Vector2(0, 7) * u, Vector2(8, 6) * u), Color(0.93, 0.52, 0.31))
			"spark":
				var pts := PackedVector2Array()
				for k in 8:
					var a := TAU * float(k) / 8.0 - PI * 0.5
					var rr := (10.0 if k % 2 == 0 else 3.5) * u
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, Color(1.0, 0.86, 0.4))
