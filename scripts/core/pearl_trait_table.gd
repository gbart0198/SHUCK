extends Resource
class_name PearlTraitTable
## Trait weights, rolled after shape/colour (SPEC §8.2).

@export var ids := PackedStringArray()
@export var weights := PackedFloat32Array()
@export var value_mults := PackedFloat32Array()

func total_weight() -> float:
	var t := 0.0
	for w in weights:
		t += w
	return t
