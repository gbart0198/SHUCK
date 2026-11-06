extends Resource
class_name SpeciesData
## One oyster species (SPEC §6).

@export var id := ""
@export var name_key := ""
@export var pier := 1
@export var difficulty_key := ""
@export var value_cents := 8
@export var pearl_chance := 0.04
## Overrides the knife slide tolerance when > 0 (Dock Blue 8, Razor 14).
@export var slide_tolerance := 0.0
## 1.0 normal, 0.75 Kumamoto.
@export var meter_window_scale := 1.0
## Extra seconds per gesture (Gigas 0.3).
@export var gesture_time_add := 0.0
@export var meat_yield := 1
## Razor Clam breaks above this fraction of hover speed (0 = no limit).
@export var max_slide_speed_scale := 0.0
@export var drill_seconds := 0.0
@export var drill_wobble := 0.0
@export var requires_gloves_tier := 0
@export var escape_seconds := 0.0
@export var notes_key := ""
@export var is_boss := false
@export var shell_color := Color(0.62, 0.64, 0.60)
@export var ridge_color := Color(0.45, 0.48, 0.45)
@export var meat_color := Color(0.93, 0.88, 0.76)
@export var mesh_scale := Vector3(1.0, 0.42, 1.25)
