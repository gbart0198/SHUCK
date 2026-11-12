extends Area3D
class_name Station
## Anything you walk up to: shuck bench, sell pad, shop booths, zone gates.
## Proximity is a distance check from the avatar; the Area3D is only for mouse clicks.

var kind := ""          # bench | sell | bin | shop | crew | pets | reshell | gate
var zone_i := 0
var radius := 3.0
var label: Label3D
var title := ""
var shape_size := Vector3(2, 2, 2)

func setup(p_kind: String, p_zone: int, p_radius: float, p_title: String, p_size := Vector3(2, 2, 2)) -> Station:
	kind = p_kind
	zone_i = p_zone
	radius = p_radius
	title = p_title
	shape_size = p_size
	return self

func _ready() -> void:
	add_to_group("stations")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = shape_size
	cs.shape = b
	cs.position = Vector3(0, shape_size.y * 0.5, 0)
	add_child(cs)

func near(p: Vector3) -> bool:
	if kind == "gate":
		return absf(p.x - global_position.x) <= radius
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length() <= radius

func tooltip() -> String:
	match kind:
		"gate":
			var e := Game.empire
			if e.can_enter(zone_i):
				return Catalog.zone(zone_i).name
			if zone_i != e.zones_unlocked:
				return "LOCKED: unlock %s first" % Catalog.zone(zone_i - 1).name
			return "%s  ·  click to unlock for %s" % [Catalog.zone(zone_i).name, Num.cash(e.zone_cost(zone_i))]
		"bench":
			return "Shuck Bench: stand here and click to stab"
		"sell":
			return "Sell Pad: step on it to sell meat"
		"bin":
			var e2 := Game.empire
			return "Dock Bin %s / %s  ·  click to dump your bucket for the Shuckers" % [Num.short(floor(float(e2.bins[zone_i]))), Num.short(e2.storage_capacity())]
	return title
