extends RefCounted
class_name SaveGame
## user://save.json — versioned, written on shift end only (SPEC §20).

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://save.json"

static func default_state() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"money": 0,
		"xp": 0,
		"rank": 0,
		"pier": 1,
		"upgrades": {"knife": 1, "gloves": 1, "bench": 1, "auto": 1, "floor": 1},
		"gadgets": {"chiller": 0, "prybar": 0},
		"pearls": [],
		"log": {},
		"relics": [],
		"badges": [],
		"cosmetics": {"owned": [], "equipped": {"hat": "", "knife": ""}},
		"stats": {"oysters": 0, "perfect": 0, "faints": 0, "walkedOut": 0},
		"shifts": 0,
		"tideHighScores": {},
		"credits": false,
		"bosses": [],
		"settings": {"fov": 75.0, "head_bob": true, "ghost_hand": true, "subtitles": true, "invert_y": false, "sensitivity": 1.0},
	}

static func to_json(state: Dictionary) -> String:
	return JSON.stringify(state, "\t")

## Returns { ok, data, error }. Unknown/newer versions are refused, not silently loaded.
static func from_json(text: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK:
		return {"ok": false, "error": "not_json", "data": default_state()}
	var parsed: Variant = j.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "not_json", "data": default_state()}
	var d: Dictionary = parsed
	if not d.has("version"):
		return {"ok": false, "error": "no_version", "data": default_state()}
	var v := int(d.get("version", -1))
	if v > CURRENT_VERSION:
		return {"ok": false, "error": "newer_version", "data": default_state(), "version": v}
	if v < 1:
		return {"ok": false, "error": "bad_version", "data": default_state(), "version": v}
	return {"ok": true, "error": "", "data": migrate(d)}

static func migrate(d: Dictionary) -> Dictionary:
	var base := default_state()
	for k in base.keys():
		if not d.has(k):
			d[k] = base[k]
	# nested defaults keep old saves readable
	for nested in ["upgrades", "stats", "cosmetics", "gadgets", "settings"]:
		var got: Dictionary = d.get(nested, {})
		var defs: Dictionary = base[nested]
		for k in defs.keys():
			if not got.has(k):
				got[k] = defs[k]
		d[nested] = got
	d["version"] = CURRENT_VERSION
	return d

static func save_to(path: String, state: Dictionary) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(state))
	f.close()
	return OK

static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing", "data": default_state()}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "unreadable", "data": default_state()}
	var text := f.get_as_text()
	f.close()
	return from_json(text)
