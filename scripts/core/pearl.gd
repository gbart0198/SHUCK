extends Resource
class_name Pearl
## A rolled pearl. Rolled at oyster spawn, never on open (SPEC §5.5).

@export var shape := 0
@export var colour := 0
@export var lustre := 1
@export var size := 6.0
@export var trait_id := "common"
@export var pier := 1
@export var value := 0
@export var named := ""

func to_dict() -> Dictionary:
	return {
		"shape": shape,
		"colour": colour,
		"lustre": lustre,
		"size": size,
		"trait": trait_id,
		"pier": pier,
		"value": value,
		"named": named,
	}

static func from_dict(d: Dictionary) -> Pearl:
	var p := Pearl.new()
	p.shape = int(d.get("shape", 0))
	p.colour = int(d.get("colour", 0))
	p.lustre = int(d.get("lustre", 1))
	p.size = float(d.get("size", 6.0))
	p.trait_id = str(d.get("trait", "common"))
	p.pier = int(d.get("pier", 1))
	p.value = int(d.get("value", 0))
	p.named = str(d.get("named", ""))
	return p
