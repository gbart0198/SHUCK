extends Control
class_name Tutorial
## First-run walkthrough. Each step names the keys you actually have bound and advances when
## you do the thing. Progress is kept in Settings; skip or replay it from the pause menu.

var avatar: Avatar
var active := false
var step := 0
var base := 0.0
var t := 0.0
var sprint_t := 0.0
var did_jump := false
var flags := {}
var box: PanelContainer
var head_lbl: Label
var body_lbl: Label
var bar: ColorRect

func steps() -> Array[Dictionary]:
	var k := func(a: String) -> String: return "[%s]" % Settings.key(a)
	var move := "[%s][%s][%s][%s]" % [Settings.key("move_forward"), Settings.key("move_left"), Settings.key("move_back"), Settings.key("move_right")]
	return [
		{"title": "Look around", "text": "Move the mouse to look around the mudflat."},
		{"title": "Walk", "text": "Walk with %s." % move},
		{"title": "Sprint", "text": "Hold %s while walking to sprint." % k.call("sprint")},
		{"title": "Jump", "text": "Press %s to jump." % k.call("jump")},
		{"title": "Rake an oyster", "text": "Walk onto the mudflat (toward the water). Aim the dot at an oyster and press %s until it comes loose." % k.call("interact")},
		{"title": "Fill your bucket", "text": "Rake a few more. Hold %s to keep raking. Your bucket is the bar at the bottom." % k.call("interact")},
		{"title": "Shuck", "text": "Go to the SHUCK shack on the boardwalk. Stand at the bench and press %s to stab. Time it on the gold band for a PERFECT (double meat)." % k.call("interact")},
		{"title": "Sell", "text": "Walk onto the SELL dock next door. Standing on it sells all your meat."},
		{"title": "Spend it", "text": "Press %s to open the Shop and buy Rake Power or a Bigger Bucket. Booths behind the boardwalk open the same menus when you walk up and press %s." % [k.call("menu_shop"), k.call("use")]},
		{"title": "You're set", "text": "Press [Esc] any time to pause, rebind keys, change settings or replay this tutorial. %s Crew, %s Pets, %s Map." % [k.call("menu_crew"), k.call("menu_pets"), k.call("menu_map")]},
	]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = UiKit.panel(Color(UiKit.HUD_BG, 0.92), UiKit.ORANGE.darkened(0.25))
	box.custom_minimum_size = Vector2(560, 0)
	UiKit.anchor(box, Control.PRESET_CENTER_TOP, Vector2(-280, 64))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var v := UiKit.vbox(4)
	box.add_child(v)
	head_lbl = UiKit.label("", 14, UiKit.ORANGE)
	v.add_child(head_lbl)
	body_lbl = UiKit.label("", 18, UiKit.CREAM)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(530, 0)
	v.add_child(body_lbl)
	bar = ColorRect.new()
	bar.color = UiKit.ORANGE
	bar.custom_minimum_size = Vector2(0, 3)
	v.add_child(bar)
	Settings.bindings_changed.connect(_show)
	if avatar:
		avatar.jumped.connect(func() -> void: did_jump = true)
	if Settings.tutorial_done:
		active = false
		box.visible = false
	else:
		start(Settings.tutorial_step)

func start(from := 0) -> void:
	active = true
	box.visible = true
	_enter(clampi(from, 0, steps().size() - 1))

func restart() -> void:
	Settings.tutorial_done = false
	Settings.tutorial_step = 0
	Settings.save()
	start(0)

func skip() -> void:
	active = false
	box.visible = false
	Settings.tutorial_done = true
	Settings.save()

## Main tells the tutorial about things it can't observe (menu opened, pause opened).
func notify(what: String) -> void:
	flags[what] = true

func _enter(i: int) -> void:
	step = i
	t = 0.0
	sprint_t = 0.0
	did_jump = false
	flags = {}
	var e := Game.empire
	match step:
		0: base = avatar.look_total if avatar else 0.0
		1: base = avatar.walked if avatar else 0.0
		4, 5: base = float(e.stats.get("caught", 0))
		6: base = float(e.stats.get("shucked", 0))
		7: base = float(e.stats.get("sold", 0))
		8: base = _levels()
	Settings.tutorial_step = step
	Settings.save()
	_show()

func _levels() -> float:
	var n := 0
	for u in Game.empire.upgrades.values():
		n += int(u)
	return float(n)

func _show() -> void:
	if not active:
		return
	var s := steps()
	var d: Dictionary = s[step]
	head_lbl.text = "TUTORIAL  %d / %d  ·  %s" % [step + 1, s.size(), str(d.title).to_upper()]
	body_lbl.text = str(d.text)

func _done_now() -> bool:
	var e := Game.empire
	match step:
		0: return avatar != null and avatar.look_total - base > 300.0
		1: return avatar != null and avatar.walked - base > 4.0
		2: return sprint_t > 0.8
		3: return did_jump
		4: return float(e.stats.get("caught", 0)) >= base + 1.0
		5: return float(e.stats.get("caught", 0)) >= base + 2.0 or e.bag_full()
		6: return float(e.stats.get("shucked", 0)) >= base + 1.0
		7: return float(e.stats.get("sold", 0)) > base
		8: return _levels() > base or flags.has("menu_shop")
		9: return t > 9.0 or flags.has("pause")
	return true

func _process(dt: float) -> void:
	if not active:
		return
	t += dt
	if step == 2 and avatar != null and Input.is_action_pressed("sprint") and Vector2(avatar.velocity.x, avatar.velocity.z).length() > 1.0:
		sprint_t += dt
	bar.custom_minimum_size.x = 530.0 * clampf(float(step) / float(steps().size()), 0.0, 1.0)
	if _done_now():
		Sfx.play("plink", -10.0, 1.2)
		if step + 1 >= steps().size():
			skip()
			Game.toast.emit("Tutorial complete. Go build an empire.", UiKit.GOLD)
			return
		_enter(step + 1)
