extends RefCounted
class_name GradeLogic
## Grade bucketing, price multipliers and tips (SPEC §7.1).

const ORDER := ["F", "C", "B", "A", "S"]

static func rank(id: String) -> int:
	return ORDER.find(id)

static func bucket(score: int, data: GradeData) -> String:
	for g in data.grades:
		if score >= int(g.get("min_score", -9999)):
			return str(g.get("id", "C"))
	return "C"

static func price_mult(id: String, data: GradeData) -> float:
	return float(data.get_grade(id).get("price_mult", 1.0))

static func tip_pct(id: String, data: GradeData) -> float:
	return float(data.get_grade(id).get("tip_pct", 0.0))

static func colour(id: String, data: GradeData) -> Color:
	return data.get_grade(id).get("color", Color.WHITE)

static func lower(id: String, steps := 1) -> String:
	var r := rank(id) - steps
	return ORDER[clampi(r, 0, ORDER.size() - 1)]

static func raise_to(id: String, floor_id: String) -> String:
	return ORDER[maxi(rank(id), rank(floor_id))]

static func cap_at(id: String, cap_id: String) -> String:
	return ORDER[mini(rank(id), rank(cap_id))]
