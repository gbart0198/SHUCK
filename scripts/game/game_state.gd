extends Node
## Persistent player state. Save is written on shift end only (SPEC §20).

var state: Dictionary = SaveGame.default_state()
var session: Dictionary = {}
var last_error := ""

func _ready() -> void:
	load_game()

func load_game() -> void:
	var r := SaveGame.load_from(SaveGame.DEFAULT_PATH)
	state = r.data
	last_error = str(r.get("error", ""))
	if not r.ok:
		# A corrupt/newer save never blocks play; start clean and keep the reason.
		state = SaveGame.default_state()

func write_save() -> Error:
	state["version"] = SaveGame.CURRENT_VERSION
	var err := SaveGame.save_to(SaveGame.DEFAULT_PATH, state)
	if err != OK:
		last_error = "write_failed"
	return err

func reset() -> void:
	state = SaveGame.default_state()
	session = {}
	write_save()

func begin_session(pier_id: int, tide_ids: Array, seed_value: int, daily := false) -> void:
	session = {
		"pier": pier_id,
		"tides": tide_ids,
		"seed": seed_value,
		"daily": daily,
		"earnings": 0,
		"tips": 0,
		"walked_out": 0,
		"pearls": 0,
		"grades": {"S": 0, "A": 0, "B": 0, "C": 0, "F": 0},
		"oysters": 0,
		"perfect": 0,
		"faints": 0,
		"served": 0,
		"ruined": 0,
		"gulled": 0,
		"luck": 0.0,
	}

func money() -> int:
	return int(state.get("money", 0))

func add_money(amount: int) -> void:
	state["money"] = money() + amount

func pier() -> int:
	return int(state.get("pier", 1))

func set_pier(p: int) -> void:
	state["pier"] = clampi(p, 1, 6)

func credits_done() -> bool:
	return bool(state.get("credits", false))

func franchise() -> bool:
	return credits_done()

func upgrades() -> Dictionary:
	return state.get("upgrades", {})

func tier(line: String) -> int:
	return int(upgrades().get(line, 1))

func buy_upgrade(line: String) -> Dictionary:
	var work := {"money": money(), "upgrades": upgrades().duplicate(), "pier": pier(), "franchise": franchise()}
	var res := Economy.buy(work, line)
	if res.ok:
		state["money"] = work.money
		state["upgrades"] = work.upgrades
		Sfx.play("money")
	return res

func add_xp(amount: int) -> void:
	state["xp"] = int(state.get("xp", 0)) + amount
	state["rank"] = rank_for_xp(int(state["xp"]))

func rank_for_xp(xp: int) -> int:
	var b := Registry.balance
	var r := 0
	for i in b.ranks.size():
		if xp >= b.ranks[i]:
			r = i
	return r

func tip_bonus() -> float:
	var b := Registry.balance
	var t := 0.0
	if tier("floor") >= 2:
		t += b.neon_tip_bonus
	t += float(mini(displayed_pearls(), b.display_pearl_cap)) * b.display_pearl_tip_bonus
	t = minf(t, b.display_pearl_tip_cap if tier("floor") < 6 else b.display_pearl_tip_cap * b.aquarium_display_mult)
	t += float(int(state.get("rank", 0))) * b.rank_tip_bonus
	t += float(state.get("relics", []).size()) * b.relic_tip_bonus
	return t

func displayed_pearls() -> int:
	return mini(Registry.balance.display_pearl_cap if Registry.balance != null else 12, state.get("pearls", []).size())

func add_pearls(pearls: Array) -> int:
	var added := 0
	var log: Dictionary = state.get("log", {})
	for p in pearls:
		var pearl: Pearl = p if p is Pearl else Pearl.from_dict(p)
		state["pearls"].append(pearl.to_dict())
		var key := "%d-%d" % [pearl.shape, pearl.colour]
		var entry: Dictionary = log.get(key, {"bestLustre": 0, "bestSize": 0.0, "count": 0})
		entry["bestLustre"] = maxi(int(entry.get("bestLustre", 0)), pearl.lustre)
		entry["bestSize"] = maxf(float(entry.get("bestSize", 0.0)), pearl.size)
		entry["count"] = int(entry.get("count", 0)) + 1
		log[key] = entry
		added += 1
	state["log"] = log
	return added

func log_entries() -> int:
	return state.get("log", {}).size()

func add_relic(id: String) -> bool:
	var relics: Array = state.get("relics", [])
	if relics.has(id):
		return false
	relics.append(id)
	state["relics"] = relics
	return true

func award_badge(id: String) -> bool:
	var badges: Array = state.get("badges", [])
	if badges.has(id):
		return false
	badges.append(id)
	state["badges"] = badges
	for b in Registry.badges:
		if b.id == id and b.reward_cosmetic != "":
			grant_cosmetic(b.reward_cosmetic)
	return true

func has_badge(id: String) -> bool:
	return state.get("badges", []).has(id)

func grant_cosmetic(id: String) -> void:
	var owned: Array = state.get("cosmetics", {}).get("owned", [])
	if not owned.has(id):
		owned.append(id)
	state["cosmetics"]["owned"] = owned

func owns_cosmetic(id: String) -> bool:
	return state.get("cosmetics", {}).get("owned", []).has(id)

func buy_cosmetic(id: String) -> bool:
	var c := Registry.get_cosmetic(id)
	if c == null or owns_cosmetic(id):
		return false
	if c.badge_only or money() < c.price:
		return false
	state["money"] = money() - c.price
	grant_cosmetic(id)
	return true

func equip(slot: String, id: String) -> void:
	state["cosmetics"]["equipped"][slot] = id

func equipped(slot: String) -> String:
	return str(state.get("cosmetics", {}).get("equipped", {}).get(slot, ""))

func stats() -> Dictionary:
	return state.get("stats", {})

func bump_stat(key: String, amount := 1) -> void:
	var s: Dictionary = state.get("stats", {})
	s[key] = int(s.get(key, 0)) + amount
	state["stats"] = s

func record_shift(result: Dictionary) -> void:
	state["shifts"] = int(state.get("shifts", 0)) + 1
	state["money"] = money() + int(result.get("total", 0))
	add_xp(int(result.get("xp", 0)))
	var best: Dictionary = state.get("tideHighScores", {})
	var key := str(result.get("tide_key", ""))
	if key != "":
		best[key] = maxi(int(best.get(key, 0)), int(result.get("total", 0)))
	state["tideHighScores"] = best
	bump_stat("walkedOut", int(result.get("walked_out", 0)))
	write_save()
