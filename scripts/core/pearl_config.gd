extends Resource
class_name PearlConfig
## Shapes, colours, lustre and value curve for pearls (SPEC §8.1).

@export var shapes := PackedStringArray(["Round", "Button", "Drop", "Oval", "Baroque", "Circled"])
@export var colours := PackedStringArray(["White", "Cream", "Pink", "Lavender", "Gold", "Peacock", "Black", "Iris"])
@export var colour_values := PackedColorArray()
@export var colour_mults := PackedFloat32Array()
@export var lustre_mults := PackedFloat32Array([1.0, 1.6, 2.2, 3.0, 4.0])
@export var base_value := 40.0
@export var size_min := 3.0
@export var size_max := 14.0
@export var size_curve := 2.2
@export var flawed_mult := 0.4
@export var mother_of_pearl_value := 2500
@export var tidewrought_value := 5000
@export var named_pearls: Array[Dictionary] = []
