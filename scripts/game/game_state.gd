extends Node
## Autoload "Game": owns the Empire, saving, autosave, offline earnings, and the
## signals the HUD listens to. Every purchase goes through here so it gets a sound + toast.

signal changed
signal toast(text: String, color: Color)
signal banner(title: String, subtitle: String, color: Color)
signal sold(amount: float)
signal pet_hatched(id: String)
signal reshelled
signal zone_unlocked(i: int)

const AUTOSAVE := 20.0
## Flags that start a throwaway dev session straight into the game (no title screen, no saving).
const DEV_FLAGS := ["--fresh", "--integration", "--demo", "--at-bench", "--pause"]

var empire: Empire
var store := SaveStore.new()
var active_slot := -1            # save slot being played (-1 = none / unsaved dev session)
var in_session := false          # false = sitting on the title screen
var meta: Dictionary = {}        # slot name, created, last_played, play_time
var offline_earned := 0.0
var offline_seconds := 0.0
var save_enabled := true
var _autosave_t := 0.0
var _play_accum := 0.0
var _income_window: Array = []    # [time, amount] recent sales for a $/s readout
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	empire = Empire.new()           # also the empty backdrop behind the title screen
	var args := OS.get_cmdline_user_args()
	var dev := false
	for a in args:
		if a in DEV_FLAGS or a.begins_with("--look=") or a.begins_with("--menu=") or a.begins_with("--shot="):
			dev = true
	if dev:
		save_enabled = false
		in_session = not "--title" in args
	else:
		store.migrate_legacy()

# ------------------------------------------------------------------ save slots
func has_saves() -> bool:
	return not store.list().is_empty()

## Title screen "Continue": the most recently played slot.
func continue_latest() -> bool:
	var s := store.latest()
	return s >= 0 and load_slot(s)

func load_slot(slot: int) -> bool:
	var data := store.read(slot)
	if data.is_empty():
		push_warning("SHUCK: save slot %d unreadable" % slot)
		return false
	empire = Empire.from_dict(data.get("empire", {}))
	meta = data.get("meta", {})
	active_slot = slot
	in_session = true
	_reset_session()
	var now := Time.get_unix_time_from_system()
	if empire.last_seen > 0.0 and now > empire.last_seen + 60.0:
		offline_seconds = now - empire.last_seen
		offline_earned = empire.offline(offline_seconds)
	return true

## Title screen "New Game": a fresh empire in the next free slot (never overwrites a save).
func new_game() -> int:
	var slot := store.next_free()
	var now := Time.get_unix_time_from_system()
	empire = Empire.new()
	meta = {"name": "Save %d" % slot, "created": now, "last_played": now, "play_time": 0.0}
	active_slot = slot
	in_session = true
	_reset_session()
	Settings.tutorial_done = false
	Settings.tutorial_step = 0
	Settings.save()
	write_save()
	return slot

func delete_slot(slot: int) -> void:
	store.delete(slot)

## Back to the title screen: save, then forget the session.
func end_session() -> void:
	write_save()
	in_session = false
	active_slot = -1
	meta = {}
	empire = Empire.new()
	_reset_session()

func _reset_session() -> void:
	offline_earned = 0.0
	offline_seconds = 0.0
	_autosave_t = 0.0
	_play_accum = 0.0
	_income_window.clear()

func write_save() -> void:
	if not save_enabled or empire == null or not in_session or active_slot < 0:
		return
	var now := Time.get_unix_time_from_system()
	empire.last_seen = now
	meta["last_played"] = now
	meta["play_time"] = float(meta.get("play_time", 0.0)) + _play_accum
	_play_accum = 0.0
	store.write(active_slot, empire, meta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		write_save()

func _process(dt: float) -> void:
	if empire == null or not in_session:
		return
	if get_tree().paused:
		return
	_clock += dt
	_play_accum += dt
	var r := empire.tick(dt)
	if float(r.sold) > 0.0:
		_record_income(float(r.sold))
	if str(r.event_started) != "":
		for e in Catalog.EVENTS:
			if e.id == r.event_started:
				banner.emit(str(e.name), str(e.desc), e.color)
				Sfx.play("fanfare", -4.0)
	if str(r.event_ended) != "":
		toast.emit("Event over", Color(0.8, 0.8, 0.8))
	_autosave_t += dt
	if _autosave_t >= AUTOSAVE:
		_autosave_t = 0.0
		write_save()

func _record_income(v: float) -> void:
	_income_window.append([_clock, v])

## Cash per second over the last 10 s: your selling + the crew's.
func income_per_sec() -> float:
	while not _income_window.is_empty() and float(_income_window[0][0]) < _clock - 10.0:
		_income_window.pop_front()
	var s := 0.0
	for e in _income_window:
		s += float(e[1])
	return maxf(s / 10.0, empire.passive_income())

# ------------------------------------------------------------------ actions (UI + world call these)
func do_sell() -> float:
	var v := empire.sell()
	if v > 0.0:
		_record_income(v)
		Sfx.play("money", -2.0)
		sold.emit(v)
		changed.emit()
	return v

func buy_upgrade(id: String) -> bool:
	if empire.buy_upgrade(id):
		Sfx.play("coin", -4.0, 1.0 + randf() * 0.1)
		toast.emit("%s → Lv %d" % [Catalog.upgrade(id).name, empire.level(id)], Color(0.5, 0.9, 1.0))
		changed.emit()
		return true
	Sfx.play("fail", -10.0)
	return false

func hire(id: String) -> bool:
	if empire.hire(id):
		Sfx.play("coin", -4.0, 0.9)
		toast.emit("Hired a %s! (%d total)" % [Catalog.crew(id).name, empire.owned(id)], Color(1.0, 0.85, 0.4))
		changed.emit()
		return true
	Sfx.play("fail", -10.0)
	return false

func train(id: String) -> bool:
	if empire.train(id):
		Sfx.play("coin", -4.0, 1.1)
		var c := Catalog.crew(id)
		toast.emit("%s %s Lv %d: x%s speed" % [c.name, "firmware" if bool(c.robot) else "training", empire.train_level(id), Num.short(empire.train_mult(id))], Color(0.55, 0.9, 0.85))
		changed.emit()
		return true
	Sfx.play("fail", -10.0)
	return false

## Dump the bucket into the crew Dock Bin. Returns how many went in.
func deposit_bin(zone_i := 0) -> int:
	var n := empire.deposit_bin(zone_i)
	if n > 0:
		Sfx.play("thud", -4.0)
		Sfx.play("pop", -8.0, 0.8)
		var who := "" if empire.role_rate("shuck", zone_i) > 0.0 else "  (no Shuckers work this beach yet)"
		toast.emit("Dumped %d oyster%s in the %s Dock Bin%s" % [n, "" if n == 1 else "s", Catalog.zone(zone_i).name, who], Color(0.55, 0.85, 0.95))
		changed.emit()
	elif empire.has_oysters():
		Sfx.play("fail", -10.0)
		toast.emit("Dock Bin is full. Upgrade the Warehouse.", Color(1, 0.5, 0.4))
	else:
		Sfx.play("beep", -12.0)
		toast.emit("Your bucket is empty. Rake some oysters first.", Color(0.8, 0.8, 0.8))
	return n

func buy_lab() -> bool:
	if empire.buy_lab():
		Sfx.play("fanfare", -2.0)
		banner.emit("ROBOTICS LAB BUILT", "Robots unlocked in CREW", Color(0.3, 1.0, 1.0))
		changed.emit()
		return true
	Sfx.play("fail", -10.0)
	return false

func buy_factory() -> bool:
	if empire.buy_factory():
		Sfx.play("fanfare", -2.0)
		toast.emit("Mega-Factory Lv %d: robots x%s" % [empire.factory, Num.short(empire.robot_mult())], Color(0.3, 1.0, 1.0))
		changed.emit()
		return true
	Sfx.play("fail", -10.0)
	return false

func unlock_zone(i: int) -> bool:
	if empire.unlock_zone(i):
		Sfx.play("fanfare", -2.0)
		banner.emit("%s UNLOCKED!" % str(Catalog.zone(i).name).to_upper(), "%s live here" % Catalog.zone(i).oyster, Catalog.zone(i).accent)
		zone_unlocked.emit(i)
		changed.emit()
		write_save()
		return true
	Sfx.play("fail", -10.0)
	return false

func reshell() -> bool:
	if empire.reshell():
		Sfx.play("fanfare", 0.0, 0.8)
		banner.emit("RE-SHELLED!", "Golden Shells: %d  ·  cash x%s forever" % [empire.shells, Num.short(empire.shell_mult())], Color(1.0, 0.85, 0.3))
		reshelled.emit()
		changed.emit()
		write_save()
		return true
	Sfx.play("fail", -10.0)
	return false

func hatch(clam_id: String) -> String:
	var id := empire.hatch(clam_id)
	if id == "":
		Sfx.play("fail", -10.0)
		return ""
	var p := Catalog.pet(id)
	var rar: Dictionary = Catalog.RARITIES[int(p.rarity)]
	Sfx.play("plink", -2.0)
	if int(p.rarity) >= 4:
		Sfx.play("fanfare", -2.0)
	banner.emit("YOU GOT: %s!" % str(p.name).to_upper(), "%s  ·  x%s cash" % [rar.name, Num.short(float(p.mult))], rar.color)
	pet_hatched.emit(id)
	changed.emit()
	return id

func toggle_pet(i: int) -> void:
	if not empire.toggle_equip(i):
		toast.emit("Only %d pets can follow you" % Catalog.PET_SLOTS, Color(1, 0.5, 0.4))
	changed.emit()

func equip_best() -> void:
	empire.equip_best()
	changed.emit()

func fuse(id: String) -> void:
	var t := empire.fuse(id)
	if t != "":
		Sfx.play("fanfare", -3.0)
		toast.emit("Fused into %s!" % Catalog.pet(t).name, Catalog.RARITIES[int(Catalog.pet(t).rarity)].color)
		changed.emit()
