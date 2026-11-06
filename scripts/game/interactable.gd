extends Area3D
class_name Interactable
## The one interaction interface: can_interact / begin / tick / end (SPEC §20).

@export var prompt_key := ""
@export var prompt_fallback := "Interact"
@export var enabled := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false

func can_interact(_player: Node) -> bool:
	return enabled

func begin(_player: Node) -> void:
	pass

func tick(_player: Node, _delta: float) -> void:
	pass

func end(_player: Node) -> void:
	pass

func prompt_text() -> String:
	return Data.t(prompt_key, prompt_fallback)

func add_shape(radius := 0.22) -> void:
	if get_child_count() > 0 and get_child(0) is CollisionShape3D:
		return
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
