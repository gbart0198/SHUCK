extends RefCounted
class_name SaveStore
## Save slots on disk: <dir>/slot_<n>.json, each {"meta": {...}, "empire": Empire.to_dict()}.
## Pure file logic (no nodes) so the smoke test can drive it in a scratch folder.
## The Game autoload owns one of these for user://saves.

const LEGACY_PATH := "user://shuck_sim.json"   # the single save from before save slots

var dir := "user://saves"

func _init(p_dir := "user://saves") -> void:
	dir = p_dir

func path(slot: int) -> String:
	return "%s/slot_%d.json" % [dir, slot]

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))

## Every slot on disk, most recently played first. Each entry: meta + {slot, cash, rank, zone, ...}.
func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not (f.begins_with("slot_") and f.ends_with(".json")):
			continue
		var slot := int(f.trim_prefix("slot_").trim_suffix(".json"))
		var data := read(slot)
		if data.is_empty():
			continue
		var meta: Dictionary = data.get("meta", {})
		var e: Dictionary = data.get("empire", {})
		var zi := clampi(int(e.get("zones_unlocked", 1)) - 1, 0, Catalog.ZONES.size() - 1)
		out.append({
			"slot": slot,
			"name": str(meta.get("name", "Save %d" % slot)),
			"last_played": float(meta.get("last_played", 0.0)),
			"play_time": float(meta.get("play_time", 0.0)),
			"cash": float(e.get("cash", 0.0)),
			"rank": str(Catalog.RANKS[Catalog.rank_index(float(e.get("total_earned", 0.0)))].name),
			"zone": str(Catalog.zone(zi).name),
			"shells": int(e.get("shells", 0)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.last_played) > float(b.last_played))
	return out

func latest() -> int:
	var l := list()
	return -1 if l.is_empty() else int(l[0].slot)

func next_free() -> int:
	var n := 1
	while exists(n):
		n += 1
	return n

func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v

func write(slot: int, empire: Empire, meta: Dictionary) -> bool:
	_ensure_dir()
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"meta": meta, "empire": empire.to_dict()}, "\t"))
	f.close()
	return true

func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))

## Pre-slot saves lived in one file. Move it into slot 1 (keeping a .bak) the first time we run.
func migrate_legacy(legacy := LEGACY_PATH) -> int:
	if not FileAccess.file_exists(legacy) or not list().is_empty():
		return -1
	var f := FileAccess.open(legacy, FileAccess.READ)
	if f == null:
		return -1
	var v: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(v) != TYPE_DICTIONARY:
		return -1
	var e := Empire.from_dict(v)
	var t := float(e.last_seen) if e.last_seen > 0.0 else Time.get_unix_time_from_system()
	write(1, e, {"name": "Save 1", "created": t, "last_played": t, "play_time": 0.0})
	DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(legacy + ".bak"))
	return 1
