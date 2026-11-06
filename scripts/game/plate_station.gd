extends Interactable
class_name PlateStation
## Plated oysters wait here. Interacting serves one to the active ticket.

signal serve_requested
signal plated_changed

var portions: Array[Dictionary] = []
var meats: Array[Node3D] = []
var label: Label3D

func _ready() -> void:
	super._ready()
	add_shape(0.45)
	prompt_key = "PROMPT_SERVE"
	prompt_fallback = "Serve plate"
	label = Label3D.new()
	label.font_size = 40
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.35, 0)
	label.modulate = Color(1, 1, 1, 0.8)
	add_child(label)
	_refresh_label()

func add_plated(sim: OysterSim) -> void:
	for i in maxi(1, sim.plated_portions):
		portions.append({"sim": sim, "grade": sim.grade, "species": sim.species})
		var m := MeshFactory.meat(sim.species)
		m.position = Vector3(-0.18 + 0.18 * (meats.size() % 3), 0.09 + 0.03 * int(meats.size() / 3), 0.0)
		m.scale = Vector3(0.9, 0.9, 0.9)
		add_child(m)
		meats.append(m)
	plated_changed.emit()
	_refresh_label()

func can_interact(_player: Node) -> bool:
	return not portions.is_empty()

func begin(_player: Node) -> void:
	serve_requested.emit()

func take_one() -> Dictionary:
	if portions.is_empty():
		return {}
	var p: Dictionary = portions.pop_front()
	if not meats.is_empty():
		var m: Node3D = meats.pop_front()
		m.queue_free()
	plated_changed.emit()
	_refresh_label()
	return p

func clear_plate() -> void:
	for m in meats:
		if is_instance_valid(m):
			m.queue_free()
	meats.clear()
	portions.clear()
	plated_changed.emit()
	_refresh_label()

func _refresh_label() -> void:
	if label == null:
		return
	label.text = "" if portions.is_empty() else "%d on the pass" % portions.size()
	label.visible = not portions.is_empty()
