extends RefCounted
class_name UiKit
## Tiny styling helpers so all screens share one look.

const BG := Color(0.055, 0.075, 0.09, 0.96)
const PANEL := Color(0.09, 0.12, 0.14, 0.98)
const BORDER := Color(0.20, 0.27, 0.30, 1.0)
const CREAM := Color(0.94, 0.91, 0.83)
const MUTED := Color(0.62, 0.68, 0.68)
const ORANGE := Color(0.90, 0.46, 0.22)
const GREEN := Color(0.45, 0.85, 0.55)
const RED := Color(0.90, 0.32, 0.30)
const GOLD := Color(1.0, 0.84, 0.35)

static func style(bg: Color, border: Color, radius := 6, border_w := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

static func panel(bg := PANEL, border := BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border))
	return p

static func label(text: String, size := 18, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 46) -> Label:
	var l := label(text, size, GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

static func button(text: String, cb: Callable, size := 18, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var bg := Color(0.16, 0.21, 0.23) if not accent else Color(0.55, 0.26, 0.12)
	b.add_theme_stylebox_override("normal", style(bg, BORDER, 4))
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.12), ORANGE, 4))
	b.add_theme_stylebox_override("pressed", style(bg.darkened(0.2), GOLD, 4))
	b.add_theme_stylebox_override("disabled", style(bg.darkened(0.35), BORDER.darkened(0.3), 4))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	b.pressed.connect(cb)
	return b

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
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func bar(value: float, max_value: float, width: float, height: float, fill: Color, bg := Color(0.1, 0.12, 0.13)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, 0, width, height), bg)
		var w: float = 0.0
		if max_value > 0.0:
			w = clampf(value / max_value, 0.0, 1.0) * width
		c.draw_rect(Rect2(0, 0, w, height), fill))
	return c

static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c

static func overlay_root() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root
