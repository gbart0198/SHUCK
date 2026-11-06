extends Resource
class_name GradeData
## Grade buckets and their pay/tip multipliers (SPEC §7.1).

@export var grades: Array[Dictionary] = []

func get_grade(id: String) -> Dictionary:
	for g in grades:
		if g.get("id", "") == id:
			return g
	return grades[grades.size() - 1]

func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for g in grades:
		out.append(g.get("id", ""))
	return out
