extends Interactable
class_name OysterNode
## A physical oyster on the bench. Holds the pure OysterSim.

signal expired(node: OysterNode)

var sim: OysterSim
var species: SpeciesData
var slot := 0
var held := false
var freshness_left := 90.0
var escape_left := 0.0
var model: Node3D

func setup(p_species: SpeciesData, p_sim: OysterSim, p_slot: int) -> void:
	species = p_species
	sim = p_sim
	slot = p_slot
	freshness_left = Registry.balance.bench_freshness[clampi(Game.tier("bench") - 1, 0, 5)]
	escape_left = species.escape_seconds
	prompt_key = "PROMPT_OYSTER"
	prompt_fallback = "Pick up oyster"
	add_shape(maxf(0.20, species.mesh_scale.x * 0.24))
	model = MeshFactory.oyster(species, false, false)
	add_child(model)

func set_held(value: bool) -> void:
	held = value
	visible = not value
	monitoring = not value
	set_process(not value)
	if not value and model != null:
		model.queue_free()
		model = MeshFactory.oyster(species, sim.state != OysterSim.State.SPAWNED, false)
		add_child(model)

func can_interact(player: Node) -> bool:
	return not held and sim != null and sim.state == OysterSim.State.SPAWNED and player.get("held_oyster") == null

func begin(player: Node) -> void:
	player.call("pick_up", self)

func _process(dt: float) -> void:
	if held or sim == null:
		return
	if sim.state != OysterSim.State.SPAWNED:
		return
	freshness_left -= dt
	if freshness_left <= 0.0:
		sim.abandon()
		expired.emit(self)
		queue_free()
		return
	if escape_left > 0.0:
		escape_left -= dt
		if escape_left <= 0.0:
			sim.abandon()
			sim.ruin_reason = "escaped"
			expired.emit(self)
			queue_free()
			return
	# Cursed oysters twitch.
	if species.id == "cursed_oyster" and model != null:
		model.position.x = sin(Time.get_ticks_msec() * 0.03) * 0.04
		model.rotation.z = sin(Time.get_ticks_msec() * 0.021) * 0.25
