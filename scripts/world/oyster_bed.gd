extends Node3D
class_name OysterBed
## A patch of tidal mud that keeps growing oysters back.

signal oyster_raked(pickup: OysterPickup)

const RESPAWN := 3.5

var zone_i := 0
var size := Vector2(36, 7)
var slots := 14
var spots: Array[Vector3] = []
var live: Array = []        # OysterPickup or null per slot
var timers: Array[float] = []

func setup(z: int, area: Vector2, count: int) -> void:
	zone_i = z
	size = area
	slots = count

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + zone_i
	for i in slots:
		var p := Vector3(rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.0, rng.randf_range(-size.y * 0.5, size.y * 0.5))
		spots.append(p)
		live.append(null)
		timers.append(rng.randf_range(0.0, 0.6))
		# a little mud mound under each spot
		var mound := MeshFactory.cylinder(0.55, 0.06, Catalog.zone(zone_i).sand.darkened(0.35), p + Vector3(0, 0.02, 0))
		add_child(mound)

func _process(dt: float) -> void:
	var frenzy := Game.empire != null and Game.empire.event_id == "frenzy"
	for i in slots:
		if live[i] != null and is_instance_valid(live[i]):
			continue
		live[i] = null
		timers[i] -= dt * (8.0 if frenzy else 1.0)
		if timers[i] <= 0.0:
			_spawn(i)

func _spawn(i: int) -> void:
	var o := OysterPickup.new()
	o.setup(zone_i, float(Catalog.zone(zone_i).hp))
	o.position = spots[i] + Vector3(0, 0.1, 0)
	o.raked.connect(func(p: OysterPickup) -> void:
		live[i] = null
		timers[i] = RESPAWN
		oyster_raked.emit(p))
	add_child(o)
	live[i] = o

func oysters() -> Array:
	var out := []
	for o in live:
		if o != null and is_instance_valid(o) and not o.dead:
			out.append(o)
	return out
