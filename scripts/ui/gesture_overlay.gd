extends Control
class_name GestureOverlay
## Draws the four gesture skill checks and the grade stamp. Reads Player.gesture_info().

var player: Player
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var info := player.gesture_info()
	var s: Vector2 = get_viewport_rect().size
	var phase: int = info.phase
	match phase:
		Player.G.DRILL:
			_draw_drill(info, s)
		Player.G.WEDGE:
			_draw_wedge(info, s)
		Player.G.POP:
			_draw_pop(info, s)
		Player.G.SLIDE:
			_draw_slide(info, s)
		Player.G.RESEAT:
			_draw_reseat(info, s)
	if info.nicked:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.02, 0.03, 0.18), false, 16.0)
	_draw_toast(info, s)
	_draw_grade(info, s)

func _text(pos: Vector2, text: String, fs := 20, color := UiKit.CREAM, width := 900.0) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, color)

func _draw_wedge(info: Dictionary, s: Vector2) -> void:
	var w := 460.0
	var h := 30.0
	var pos := Vector2(s.x * 0.5 - w * 0.5, s.y * 0.78)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.06, 0.07, 0.08, 0.85))
	var band: Vector2 = info.band
	draw_rect(Rect2(pos + Vector2(band.x * w, 0), Vector2((band.y - band.x) * w, h)), Color(0.25, 0.75, 0.4, 0.85))
	draw_rect(Rect2(pos + Vector2(0.40 * w, 0), Vector2(0.15 * w, h)), Color(0.75, 0.55, 0.2, 0.35))
	var v: float = clampf(info.wedge, 0.0, 1.0)
	draw_rect(Rect2(pos + Vector2(v * w - 2, -6), Vector2(4, h + 12)), Color(1, 1, 1))
	if info.wedge > 1.0:
		draw_rect(Rect2(pos + Vector2(w - 8, -6), Vector2(8, h + 12)), Color(0.9, 0.2, 0.2))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.8, 0.85, 0.85), false, 2.0)
	var hint := "HOLD LMB — release inside the green"
	if info.wedge >= 0.40 and info.wedge <= 1.0:
		hint = "RELEASE"
	if info.wedge > 1.0:
		hint = "TOO LONG — slip"
	_text(pos + Vector2(0, -18), hint, 22, UiKit.GOLD, w)
	_text(pos + Vector2(0, h + 34), "0.55–0.75 is clean  •  0.40–0.55 snags  •  >1.00 slips", 16, UiKit.MUTED, w)

func _draw_pop(info: Dictionary, s: Vector2) -> void:
	var center := Vector2(s.x * 0.5, s.y * 0.50)
	var R := 155.0
	var ring: float = info.pop_ring
	draw_circle(center, R, Color(0.05, 0.06, 0.07, 0.35))
	draw_arc(center, R, 0, TAU, 64, Color(0.55, 0.62, 0.62, 0.6), 2.0)
	var dot_r := R * 0.30
	draw_circle(center, dot_r, Color(0.2, 0.5, 0.35, 0.5))
	draw_arc(center, dot_r, 0, TAU, 40, Color(0.85, 0.95, 0.85), 2.0)
	var rr := maxf(0.0, ring) * R
	var col := Color(0.95, 0.4, 0.3)
	if ring <= 0.60:
		col = Color(0.95, 0.85, 0.4)
	if ring <= 0.30:
		col = Color(0.5, 1.0, 0.6)
	draw_arc(center, maxf(rr, 1.0), 0, TAU, 96, col, 9.0)
	# closing sweep line
	if info.pop_active:
		draw_line(center, center + Vector2(0, -maxf(rr, 1.0)), Color(1, 1, 1, 0.25), 2.0)
	_text(center + Vector2(-R, R + 52), "CLICK when the ring reaches the dot", 22, UiKit.GOLD, R * 2.0)
	_text(center + Vector2(-R, R + 80), "inner 30% = clean pop  •  30–60% = normal  •  outside = cracked", 15, UiKit.MUTED, R * 2.0)
	_text(center + Vector2(-R, -R - 24), "POP", 26, UiKit.CREAM, R * 2.0)

func _draw_slide(info: Dictionary, s: Vector2) -> void:
	var pts: PackedVector2Array = info.slide_seam
	var tol: float = info.slide_tolerance
	# tolerance band
	draw_polyline(pts, Color(0.25, 0.55, 0.4, 0.28), maxf(tol * 2.0, 4.0))
	draw_polyline(pts, Color(0.9, 0.95, 0.9, 0.85), 3.0)
	# seam arrow
	if pts.size() > 1:
		draw_line(pts[0], pts[0] + Vector2(-26, 0), Color(0.9, 0.95, 0.9, 0.5), 2.0)
		draw_free_arrow(pts[pts.size() - 1])
	var cursor: Vector2 = info.virtual_mouse + Vector2(0, float(info.get("slide_wander", 0.0)))
	var progress: float = info.slide_progress
	var idx := clampi(int(progress * (pts.size() - 1)), 0, pts.size() - 1)
	var seam: Vector2 = pts[idx]
	var offline := absf(cursor.y - seam.y)
	var inside := offline <= tol
	var col := Color(0.55, 1.0, 0.6) if inside else Color(1.0, 0.4, 0.3)
	draw_line(seam, cursor, Color(col.r, col.g, col.b, 0.35), 2.0)
	# knife cursor
	draw_line(cursor, cursor + Vector2(-18, 10), Color(0.95, 0.95, 0.95), 5.0)
	draw_circle(cursor, 4.0, col)
	draw_circle(info.virtual_mouse, 2.0, Color(1, 1, 1, 0.35))
	draw_rect(Rect2(Vector2(s.x * 0.5 - 460, s.y * 0.62), Vector2(920, 64)), Color(0.03, 0.04, 0.05, 0.62))
	_text(Vector2(s.x * 0.5 - 450, s.y * 0.62 + 26), "DRAG along the seam — hold LMB, follow the line", 22, UiKit.GOLD, 900)
	var off := "off-line %.1f px  •  tolerance %.1f px  •  stab at 40" % [offline, tol]
	_text(Vector2(s.x * 0.5 - 450, s.y * 0.62 + 52), off, 16, UiKit.MUTED, 900)
	# progress
	var bar := Rect2(Vector2(s.x * 0.5 - 200, s.y * 0.75), Vector2(400, 10))
	draw_rect(bar, Color(0.08, 0.09, 0.1, 0.8))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color(0.6, 0.9, 0.7))

func draw_free_arrow(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10), p + Vector2(18, 0), p + Vector2(0, 10)]),
		Color(0.9, 0.95, 0.9, 0.7))

func _draw_reseat(info: Dictionary, s: Vector2) -> void:
	var center: Vector2 = info.plate_center
	var rect := Rect2(center - Vector2(120, 76), Vector2(240, 152))
	draw_rect(rect, Color(0.18, 0.35, 0.25, 0.30))
	draw_rect(rect, Color(0.55, 0.9, 0.65, 0.9), false, 3.0)
	draw_circle(center, 44.0, Color(0.9, 0.9, 0.95, 0.10))
	var p: Vector2 = info.reseat
	draw_circle(p, 16.0, Color(0.93, 0.88, 0.76))
	draw_arc(p, 18.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
	draw_rect(Rect2(Vector2(s.x * 0.5 - 460, s.y * 0.62), Vector2(920, 64)), Color(0.03, 0.04, 0.05, 0.62))
	_text(Vector2(s.x * 0.5 - 450, s.y * 0.62 + 26), "HOLD LMB to pinch — release over the plate", 22, UiKit.GOLD, 900)
	_text(Vector2(s.x * 0.5 - 450, s.y * 0.62 + 52), "Release anywhere else and it is ruined", 16, UiKit.MUTED, 900)

func _draw_drill(info: Dictionary, s: Vector2) -> void:
	var center: Vector2 = info.get("drill_center", s * 0.5)
	var radius: float = info.get("drill_radius", 100.0)
	draw_circle(center, radius, Color(0.2, 0.5, 0.4, 0.18))
	draw_arc(center, radius, 0, TAU, 48, Color(0.5, 0.95, 0.7, 0.9), 3.0)
	draw_circle(info.virtual_mouse, 6.0, Color(1, 1, 1))
	var p: float = info.drill
	draw_arc(center, radius + 16.0, -PI * 0.5, -PI * 0.5 + TAU * p, 48, UiKit.GOLD, 4.0)
	_text(Vector2(s.x * 0.5 - 450, s.y * 0.30), "DRILL — hold still inside the ring", 24, UiKit.GOLD, 900)

func _draw_toast(info: Dictionary, s: Vector2) -> void:
	var t: float = info.toast_timer
	var text: String = info.toast
	if t <= 0.0 or text == "":
		return
	var a := clampf(t / 0.5, 0.0, 1.0)
	draw_rect(Rect2(Vector2(s.x * 0.5 - 430, s.y * 0.86), Vector2(860, 44)), Color(0.05, 0.06, 0.07, 0.75 * a))
	_text(Vector2(s.x * 0.5 - 430, s.y * 0.86 + 30), text, 20, Color(0.95, 0.9, 0.8, a), 860)

func _draw_grade(info: Dictionary, s: Vector2) -> void:
	var t: float = info.grade_timer
	if t <= 0.0:
		return
	var g: String = info.grade
	if g == "":
		return
	var col := GradeLogic.colour(g, Registry.grade_data)
	var a := clampf(t / 0.6, 0.0, 1.0)
	var scale_t := 1.0 + maxf(0.0, (1.6 - t)) * 0.35
	var fs := int(150.0 * scale_t)
	var center := Vector2(s.x * 0.5, s.y * 0.30)
	draw_circle(center, 120.0 * scale_t, Color(0.03, 0.04, 0.05, 0.35 * a))
	draw_string(font, center + Vector2(-150, 60), g, HORIZONTAL_ALIGNMENT_CENTER, 300, fs, Color(col.r, col.g, col.b, a))
	var label: String = {
		"S": "PERFECT", "A": "CLEAN", "B": "STANDARD", "C": "RUSHED", "F": "BUTCHERED",
	}.get(g, "")
	draw_string(font, center + Vector2(-150, 104), label, HORIZONTAL_ALIGNMENT_CENTER, 300, 22,
		Color(0.95, 0.92, 0.84, a))
