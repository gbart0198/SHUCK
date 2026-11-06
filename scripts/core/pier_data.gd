extends Resource
class_name PierData
## One pier: economy, species pool, look and hazard (SPEC §9, §13).

@export var id := 1
@export var name_key := ""
@export var tagline_key := ""
@export var ticket_count := 8
@export var quota := 120
@export var price_scale := 1.0
@export var shift_seconds := 480.0
@export var spawn_interval := 55.0
@export var species: PackedStringArray = PackedStringArray()
@export var hazard_key := ""
@export var has_boss := false
@export var boss_species := ""
@export var boss_seconds := 180.0
@export var relic_id := ""
@export var named_pearl := ""
@export var chaos_weights := PackedFloat32Array()
@export var sky_top := Color(0.09, 0.16, 0.24)
@export var sky_bottom := Color(0.55, 0.42, 0.30)
@export var fog_color := Color(0.35, 0.38, 0.40)
@export var light_color := Color(1.0, 0.86, 0.66)
@export var light_energy := 1.4
@export var water_color := Color(0.08, 0.22, 0.28)
@export var wood_color := Color(0.34, 0.24, 0.16)
@export var wall_color := Color(0.22, 0.26, 0.27)
@export var accent_color := Color(0.85, 0.45, 0.25)
@export var ambient_energy := 0.55
@export var gull_count := 3
@export var tilt := 0.0
@export var low_gravity := false
@export var darkness := 0.0
