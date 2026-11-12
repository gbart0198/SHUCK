extends Node
## Autoload "Settings": key bindings, mouse/FOV/audio options, tutorial progress.
## Stored in user://settings.json, separate from the empire save so a wipe keeps your controls.

signal changed
signal bindings_changed

const PATH := "user://settings.json"

## Rebindable actions, in the order the Controls page lists them.
const ACTIONS: Array[Dictionary] = [
	{"id": "move_forward", "label": "Move forward"},
	{"id": "move_back", "label": "Move back"},
	{"id": "move_left", "label": "Move left"},
	{"id": "move_right", "label": "Move right"},
	{"id": "sprint", "label": "Sprint"},
	{"id": "jump", "label": "Jump"},
	{"id": "interact", "label": "Rake / stab / buy"},
	{"id": "use", "label": "Use booth"},
	{"id": "menu_shop", "label": "Open Shop"},
	{"id": "menu_crew", "label": "Open Crew"},
	{"id": "menu_pets", "label": "Open Pets"},
	{"id": "menu_reshell", "label": "Open Re-Shell"},
	{"id": "menu_map", "label": "Open Map"},
]

## Defaults: "k:<physical keycode>" or "m:<mouse button index>".
const DEFAULTS := {
	"move_forward": ["k:%d" % KEY_W, "k:%d" % KEY_UP],
	"move_back": ["k:%d" % KEY_S, "k:%d" % KEY_DOWN],
	"move_left": ["k:%d" % KEY_A, "k:%d" % KEY_LEFT],
	"move_right": ["k:%d" % KEY_D, "k:%d" % KEY_RIGHT],
	"sprint": ["k:%d" % KEY_SHIFT],
	"jump": ["k:%d" % KEY_SPACE],
	"interact": ["m:%d" % MOUSE_BUTTON_LEFT],
	"use": ["k:%d" % KEY_E],
	"menu_shop": ["k:%d" % KEY_B],
	"menu_crew": ["k:%d" % KEY_C],
	"menu_pets": ["k:%d" % KEY_P],
	"menu_reshell": ["k:%d" % KEY_R],
	"menu_map": ["k:%d" % KEY_M],
}

var bindings: Dictionary = {}
var sensitivity := 1.0
var fov := 75.0
var invert_y := false
var head_bob := true
var volume := 0.8
var fullscreen := false
var vsync := true
var tutorial_done := false
var tutorial_step := 0
var persist := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--fresh" in OS.get_cmdline_user_args() or "--integration" in OS.get_cmdline_user_args():
		persist = false
	reset_bindings(false)
	if persist:
		_load()
	apply()

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	sensitivity = clampf(float(d.get("sensitivity", sensitivity)), 0.1, 4.0)
	fov = clampf(float(d.get("fov", fov)), 55.0, 110.0)
	invert_y = bool(d.get("invert_y", invert_y))
	head_bob = bool(d.get("head_bob", head_bob))
	volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	vsync = bool(d.get("vsync", vsync))
	tutorial_done = bool(d.get("tutorial_done", false))
	tutorial_step = int(d.get("tutorial_step", 0))
	var b: Variant = d.get("bindings", {})
	if typeof(b) == TYPE_DICTIONARY:
		for a in DEFAULTS.keys():
			if b.has(a) and typeof(b[a]) == TYPE_ARRAY:
				bindings[a] = Array(b[a]).map(func(x: Variant) -> String: return str(x))

func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"sensitivity": sensitivity, "fov": fov, "invert_y": invert_y, "head_bob": head_bob,
		"volume": volume, "fullscreen": fullscreen, "vsync": vsync, "tutorial_done": tutorial_done, "tutorial_step": tutorial_step,
		"bindings": bindings,
	}, "\t"))
	f.close()

## Push bindings into the InputMap and volume onto the master bus.
func apply() -> void:
	for a in DEFAULTS.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.5)
		InputMap.action_erase_events(a)
		for code in bindings.get(a, []):
			var ev := decode(str(code))
			if ev != null:
				InputMap.action_add_event(a, ev)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	_apply_window()
	changed.emit()

## Fullscreen + vsync. Skipped headless and for screenshot runs (they need a plain window).
func _apply_window() -> void:
	if DisplayServer.get_name() == "headless" or "--shot=" in " ".join(OS.get_cmdline_user_args()):
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func reset_bindings(apply_now := true) -> void:
	bindings = {}
	for a in DEFAULTS.keys():
		bindings[a] = (DEFAULTS[a] as Array).duplicate()
	if apply_now:
		apply()
		save()
		bindings_changed.emit()

## Replace the primary binding of `action`. If another action used that input it loses it.
func rebind(action: String, ev: InputEvent) -> void:
	var code := encode(ev)
	if code == "" or not DEFAULTS.has(action):
		return
	for a in bindings.keys():
		if a != action:
			bindings[a] = (bindings[a] as Array).filter(func(c: String) -> bool: return c != code)
	var list: Array = (bindings.get(action, []) as Array).filter(func(c: String) -> bool: return c != code)
	if list.is_empty():
		list.append(code)
	else:
		list[0] = code
	bindings[action] = list
	apply()
	save()
	bindings_changed.emit()

static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == KEY_ESCAPE or code == 0:
			return ""
		return "k:%d" % code
	if ev is InputEventMouseButton:
		var m := ev as InputEventMouseButton
		if m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return ""
		return "m:%d" % m.button_index
	return ""

static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "k":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "m":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null

static func code_name(code: String) -> String:
	var ev := decode(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse %d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventKey:
		var kc := (ev as InputEventKey).physical_keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(kc)) if DisplayServer.get_name() != "headless" else OS.get_keycode_string(kc)
	return "?"

## Short label for the primary binding, e.g. "E" or "LMB".
func key(action: String) -> String:
	var list: Array = bindings.get(action, [])
	if list.is_empty():
		return "unbound"
	return code_name(str(list[0]))

## All bindings, e.g. "W / Up".
func keys(action: String) -> String:
	var list: Array = bindings.get(action, [])
	if list.is_empty():
		return "unbound"
	return " / ".join(list.map(func(c: Variant) -> String: return code_name(str(c))))

func set_option(name: String, value: Variant) -> void:
	set(name, value)
	apply()
	save()
