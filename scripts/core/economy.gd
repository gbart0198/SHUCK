extends RefCounted
class_name Economy
## Upgrade purchase rules and costs (SPEC §10). Stateless, so tests call it directly.

static func owned_tier(upgrades: Dictionary, line: String) -> int:
	return int(upgrades.get(line, 1))

static func next_upgrade(upgrades: Dictionary, line: String) -> UpgradeData:
	var tier := owned_tier(upgrades, line) + 1
	return Registry.upgrade(line, tier)

static func is_unlocked(line: String, tier: int, pier: int, franchise := false) -> bool:
	var u := Registry.upgrade(line, tier)
	if u == null:
		return false
	if tier <= 1:
		return true
	if u.unlock_pier <= 0:
		return franchise
	return pier >= u.unlock_pier

## state: { money:int, upgrades:Dictionary, pier:int, franchise:bool }
static func can_buy(state: Dictionary, line: String) -> Dictionary:
	var upgrades: Dictionary = state.get("upgrades", {})
	var tier := owned_tier(upgrades, line)
	if tier >= 6:
		return {"ok": false, "reason": "maxed"}
	var u := next_upgrade(upgrades, line)
	if u == null:
		return {"ok": false, "reason": "no_data"}
	var pier := int(state.get("pier", 1))
	if not is_unlocked(line, u.tier, pier, bool(state.get("franchise", false))):
		return {"ok": false, "reason": "locked", "cost": u.cost, "tier": u.tier, "unlock_pier": u.unlock_pier}
	if int(state.get("money", 0)) < u.cost:
		return {"ok": false, "reason": "money", "cost": u.cost, "tier": u.tier}
	return {"ok": true, "reason": "", "cost": u.cost, "tier": u.tier, "name_key": u.name_key}

## Applies the purchase to a state dictionary in place and returns the result.
static func buy(state: Dictionary, line: String) -> Dictionary:
	var check := can_buy(state, line)
	if not check.ok:
		return check
	var upgrades: Dictionary = state.get("upgrades", {})
	upgrades[line] = int(check.tier)
	state["upgrades"] = upgrades
	state["money"] = int(state.get("money", 0)) - int(check.cost)
	return check

static func total_ladder_cost() -> int:
	Registry.ensure_loaded()
	var total := 0
	for u in Registry.upgrades:
		total += u.cost
	return total
