extends Interactable
class_name TicketCard
## A paper ticket clipped to the rail.

signal clicked(card: TicketCard)

var ticket: TicketSim
var paper: MeshInstance3D
var label: Label3D
var active := false
var slot := 0

func setup(t: TicketSim, p_slot: int) -> void:
	ticket = t
	slot = p_slot
	add_shape(0.26)
	prompt_key = "PROMPT_TICKET"
	prompt_fallback = "Take ticket"
	var clip := MeshFactory.cylinder(0.012, 0.1, Color(0.7, 0.72, 0.74), Vector3(0, 0.13, 0), Vector3(0, 0, PI * 0.5))
	add_child(clip)
	paper = MeshFactory.box(Vector3(0.34, 0.24, 0.008), Color(0.95, 0.92, 0.83), Vector3(0, 0, 0.01))
	add_child(paper)
	label = Label3D.new()
	label.font_size = 26
	label.pixel_size = 0.0014
	label.modulate = Color(0.14, 0.12, 0.10)
	label.outline_size = 0
	label.position = Vector3(0, 0.02, 0.02)
	label.width = 230
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = ""
	add_child(label)
	set_process(true)

func _process(_dt: float) -> void:
	if ticket == null:
		return
	var text := ""
	var species_name := ""
	if ticket.species_ids.size() > 0:
		var sp := Registry.get_species(str(ticket.species_ids[0]))
		species_name = Data.t(sp.name_key, sp.id) if sp != null else str(ticket.species_ids[0])
	text = "%s x%d" % [species_name, ticket.species_ids.size()]
	if ticket.modifier != null:
		text += "\n" + Data.t(ticket.modifier.name_key, ticket.modifier.id)
	if ticket.accepted and not ticket.completed:
		text += "\n%.1fs" % ticket.patience_left
	if ticket.walked_out:
		text += "\nWALKED OUT"
	label.text = text
	if ticket.accepted and not ticket.completed:
		label.modulate = Color(0.75, 0.15, 0.12) if ticket.patience_left < 6.0 else Color(0.14, 0.12, 0.10)
	else:
		label.modulate = Color(0.14, 0.12, 0.10)

func set_active(value: bool) -> void:
	active = value
	if paper != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.98, 0.94, 0.78) if value else Color(0.95, 0.92, 0.83)
		if value:
			m.emission_enabled = true
			m.emission = Color(0.6, 0.5, 0.2)
			m.emission_energy_multiplier = 0.7
		paper.material_override = m
	scale = Vector3.ONE * (1.15 if value else 1.0)

func can_interact(_p: Node) -> bool:
	return ticket != null and not ticket.walked_out and not ticket.completed

func begin(_p: Node) -> void:
	clicked.emit(self)
