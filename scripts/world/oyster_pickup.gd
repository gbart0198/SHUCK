extends Area3D
class_name OysterPickup
## One oyster sitting in a bed. Click it (or stand in your Tide Magnet) to rake it loose.

signal raked(pickup: OysterPickup)

var zone_i := 0
var hp := 1.0
var hp_max := 1.0
var model: Node3D
var hp_label: Label3D
var shake := 0.0
var t := 0.0
var dead := false
var base_y := 0.0
var glow: OmniLight3D

func setup(z: int, hp_value: float) -> void:
	zone_i = z
	hp = hp_value
	hp_max = hp_value

func _ready() -> void:
	add_to_group("oysters")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	input_ray_pickable = true
	var zd := Catalog.zone(zone_i)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	cs.shape = sh
	cs.position = Vector3(0, 0.3, 0)
	add_child(cs)
	var size := 0.85 + float(zone_i) * 0.06
	model = MeshFactory.oyster(zd.shell, zd.meat, false, Vector3(size, 0.5 * size, 1.25 * size))
	model.rotation.y = randf() * TAU
	add_child(model)
	hp_label = Label3D.new()
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.font_size = 40
	hp_label.outline_size = 10
	hp_label.pixel_size = 0.006
	hp_label.position = Vector3(0, 1.0, 0)
	hp_label.visible = false
	hp_label.no_depth_test = true
	add_child(hp_label)
	if zone_i >= 3:
		glow = OmniLight3D.new()
		glow.light_color = zd.accent
		glow.light_energy = 0.6
		glow.omni_range = 1.6
		glow.position = Vector3(0, 0.5, 0)
		add_child(glow)
	base_y = position.y
	t = randf() * 10.0
	scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(dt: float) -> void:
	t += dt
	if model == null:
		return
	model.position.y = 0.05 + sin(t * 2.0) * 0.04
	if shake > 0.0:
		shake = maxf(0.0, shake - dt)
		model.position.x = sin(t * 80.0) * shake * 0.6
		model.scale = Vector3.ONE * (1.0 + shake * 0.8)
	else:
		model.position.x = 0.0
		model.scale = Vector3.ONE

## Returns true if this hit raked it loose.
func hit(dmg: float) -> bool:
	if dead:
		return false
	hp -= dmg
	shake = 0.18
	if hp <= 0.0:
		dead = true
		raked.emit(self)
		return true
	hp_label.visible = true
	hp_label.text = "%s / %s" % [Num.short(ceil(hp)), Num.short(hp_max)]
	var k := hp / hp_max
	hp_label.modulate = Color(1.0, 0.3, 0.3).lerp(Color(0.4, 1.0, 0.4), k)
	return false

func tooltip() -> String:
	if not Game.empire.can_enter(zone_i):
		return "%s  ·  LOCKED: buy the %s gate" % [Catalog.zone(zone_i).oyster, Catalog.zone(zone_i).name]
	return "%s  (%s hp)  ·  worth %s" % [Catalog.zone(zone_i).oyster, Num.short(ceil(hp)), Num.cash(float(Catalog.zone(zone_i).value) * Game.empire.cash_mult())]
