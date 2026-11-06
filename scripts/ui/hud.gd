extends Control
class_name Hud
## All shift HUD drawing. No scene-tree widgets, one canvas pass.

var shift: Node
var font: Font
var hide_ui := false
var prompt_text := ""
var prompt_key := "LMB"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	queue_redraw()

func _fmt_time(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	return "%d:%02d" % [s / 60, s % 60]

func _draw() -> void:
	if shift == null or hide_ui:
		return
	var s: Vector2 = get_viewport_rect().size
	var margin := 28.0
	var pier_name := Data.t(shift.pier.name_key, "THE PIER")
	var money := int(shift.earnings) + int(shift.tips)
	# top bar
	draw_rect(Rect2(0, 0, s.x, 6), UiKit.ORANGE)
	draw_string(font, Vector2(margin, 42), "SHUCK  ·  " + pier_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.CREAM)
	var timer_col := UiKit.RED if shift.time_left < 20.0 else UiKit.MUTED
	draw_string(font, Vector2(s.x - margin - 240, 42), _fmt_time(shift.time_left), HORIZONTAL_ALIGNMENT_RIGHT, 240, 28, timer_col)
	# money
	draw_string(font, Vector2(margin, 92), "¢%d" % money, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UiKit.GOLD)
	draw_string(font, Vector2(margin, 118), "base %d  ·  tips %d" % [shift.earnings, shift.tips], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.MUTED)
	if shift.boss_mode:
		draw_string(font, Vector2(s.x * 0.5 - 200, 42), "BOSS SHIFT", HORIZONTAL_ALIGNMENT_CENTER, 400, 26, UiKit.RED)
		draw_string(font, Vector2(s.x * 0.5 - 200, 72), _fmt_time(shift.boss_time), HORIZONTAL_ALIGNMENT_CENTER, 400, 22,
			UiKit.RED if shift.boss_time < 30.0 else UiKit.CREAM)
	# quota
	var qw := 340.0
	var qx := s.x - margin - qw
	var qy := 66.0
	draw_rect(Rect2(qx, qy, qw, 18), Color(0.07, 0.08, 0.09, 0.9))
	var qv: float = clampf((float(shift.earnings + shift.tips) / maxf(1.0, float(shift.quota))), 0.0, 1.0)
	draw_rect(Rect2(qx, qy, qw * qv, 18), UiKit.GREEN if qv >= 1.0 else UiKit.ORANGE)
	draw_rect(Rect2(qx, qy, qw, 18), UiKit.BORDER, false, 2.0)
	draw_string(font, Vector2(qx - 120, qy + 16), "QUOTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.MUTED)
	draw_string(font, Vector2(qx + 8, qy + 16), "%d / %d" % [shift.earnings + shift.tips, shift.quota], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.05, 0.06, 0.06))
	draw_string(font, Vector2(qx, qy + 40), "walked out %d   ·   pearls %d   ·   rail %d" %
		[shift.walked_out, shift.pearls_found.size(), shift.cards.size()], HORIZONTAL_ALIGNMENT_RIGHT, qw, 15, UiKit.MUTED)
	# active ticket
	if shift.active_ticket != null:
		var t: TicketSim = shift.active_ticket
		var box := Rect2(s.x - margin - 400, s.y - 190, 380, 118)
		draw_rect(box, Color(0.06, 0.08, 0.09, 0.92))
		draw_rect(box, UiKit.ORANGE, false, 2.0)
		var species_name := ""
		if t.species_ids.size() > 0:
			var sp := Registry.get_species(str(t.species_ids[0]))
			species_name = Data.t(sp.name_key, sp.id) if sp != null else str(t.species_ids[0])
		draw_string(font, box.position + Vector2(14, 28), "TICKET #%d  ·  %s x%d" % [t.id, species_name, t.species_ids.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.CREAM)
		if t.modifier != null:
			draw_string(font, box.position + Vector2(14, 52), Data.t(t.modifier.name_key, t.modifier.id),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiKit.GOLD)
		var pw := 340.0
		draw_rect(Rect2(box.position + Vector2(14, 68), Vector2(pw, 14)), Color(0.1, 0.1, 0.1))
		var pf: float = clampf(t.patience_left / maxf(0.01, t.patience_max), 0.0, 1.0)
		draw_rect(Rect2(box.position + Vector2(14, 68), Vector2(pw * pf, 14)), UiKit.RED if pf < 0.3 else UiKit.GREEN)
		draw_string(font, box.position + Vector2(14, 104), "%.1fs patience" % t.patience_left,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.MUTED)
		draw_string(font, box.position + Vector2(200, 104), "plate: %d" % (shift.plate.portions.size() if shift.plate else 0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.MUTED)
	# gadgets
	var pry := int(Game.state.get("gadgets", {}).get("prybar", 0))
	var pag := int(Game.state.get("gadgets", {}).get("pager", 0))
	if pry + pag > 0:
		draw_string(font, Vector2(margin, s.y - 250), "1 PRY BAR ×%d    2 PAGER ×%d" % [pry, pag],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.MUTED)
	# crosshair
	if shift.player != null and not shift.player.is_gesturing():
		draw_circle(s * 0.5, 3.0, Color(1, 1, 1, 0.65))
	# prompt
	if prompt_text != "":
		var w := 700.0
		draw_rect(Rect2(s.x * 0.5 - w * 0.5, s.y - 96, w, 40), Color(0.05, 0.06, 0.07, 0.72))
		draw_string(font, Vector2(s.x * 0.5 - w * 0.5 + 20, s.y - 69), "[%s]  %s" % [prompt_key, prompt_text],
			HORIZONTAL_ALIGNMENT_CENTER, w - 40, 20, UiKit.CREAM)
	# status
	if shift.player != null and shift.player.nicked:
		draw_string(font, Vector2(margin, s.y - 220), "NICKED — bleeding", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.RED)
	if shift.player != null and shift.player.rash:
		draw_string(font, Vector2(margin, s.y - 244), "BARNACLE RASH — tolerance -20%", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.RED)
	# subtitle
	if shift.subtitle_timer > 0.0 and shift.subtitle != "":
		var w2 := 900.0
		draw_rect(Rect2(s.x * 0.5 - w2 * 0.5, s.y - 152, w2, 34), Color(0.02, 0.02, 0.03, 0.6))
		draw_string(font, Vector2(s.x * 0.5 - w2 * 0.5, s.y - 129), shift.subtitle, HORIZONTAL_ALIGNMENT_CENTER, w2, 19, UiKit.CREAM)
	# ghost hand
	if shift.ghost and shift.player != null and shift.player.is_gesturing():
		var hint := ""
		match shift.player.gesture_phase:
			Player.G.DRILL: hint = "GHOST HAND: hold LMB and keep the cursor inside the ring"
			Player.G.WEDGE: hint = "GHOST HAND: hold LMB, release inside the green band"
			Player.G.POP: hint = "GHOST HAND: click when the ring reaches the dot"
			Player.G.SLIDE: hint = "GHOST HAND: hold LMB, drag right along the seam"
			Player.G.RESEAT: hint = "GHOST HAND: hold LMB, drag to the plate, release"
		if hint != "":
			draw_string(font, Vector2(0, 130), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.95, 0.88, 0.6, 0.8))
	# co-op crew
	if Net.player_count() > 1:
		draw_string(font, Vector2(s.x - margin - 200, s.y - 28), "crew: %d" % Net.player_count(),
			HORIZONTAL_ALIGNMENT_RIGHT, 200, 16, UiKit.MUTED)
