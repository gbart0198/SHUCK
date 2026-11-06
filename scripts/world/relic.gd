extends Interactable
class_name Relic
## One missable relic per pier (SPEC §12.3).

signal collected(id: String)

var relic_id := ""
var spin: Node3D
var t := 0.0

func setup(p_id: String, kind: String) -> void:
	relic_id = p_id
	add_shape(0.35)
	prompt_key = "PROMPT_RELIC"
	prompt_fallback = "Take relic"
	spin = Node3D.new()
	add_child(spin)
	match kind:
		"jetty_wheel":
			spin.add_child(MeshFactory.cylinder(0.16, 0.05, Color(0.45, 0.30, 0.18), Vector3.ZERO, Vector3(PI * 0.5, 0, 0)))
			for i in 6:
				spin.add_child(MeshFactory.box(Vector3(0.30, 0.025, 0.025), Color(0.5, 0.34, 0.2),
					Vector3.ZERO, Vector3(0, 0, i * PI / 3.0)))
		"harbor_clam":
			spin.add_child(MeshFactory.sphere(0.18, Color(0.9, 0.35, 0.5), Vector3.ZERO, Vector3(1.0, 0.5, 0.8)))
		"raft_comb":
			spin.add_child(MeshFactory.box(Vector3(0.26, 0.04, 0.10), Color(0.85, 0.8, 0.65)))
			for i in 6:
				spin.add_child(MeshFactory.box(Vector3(0.02, 0.08, 0.02), Color(0.9, 0.85, 0.7), Vector3(-0.1 + i * 0.04, -0.05, 0)))
		"reef_lens":
			spin.add_child(MeshFactory.cylinder(0.14, 0.06, Color(0.4, 0.9, 0.85), Vector3.ZERO, Vector3(PI * 0.5, 0, 0)))
		"lighthouse_lens":
			spin.add_child(MeshFactory.sphere(0.16, Color(1.0, 0.9, 0.5), Vector3.ZERO, Vector3(1, 1.4, 1)))
		"casino_dice":
			spin.add_child(MeshFactory.box(Vector3(0.16, 0.16, 0.16), Color(0.95, 0.94, 0.9)))
			for i in 3:
				spin.add_child(MeshFactory.sphere(0.018, Color(0.1, 0.1, 0.1), Vector3(-0.04 + i * 0.04, 0.081, 0.0)))
		_:
			spin.add_child(MeshFactory.sphere(0.15, Color(0.9, 0.8, 0.4)))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.45)
	glow.light_energy = 1.2
	glow.omni_range = 1.6
	add_child(glow)
	set_process(true)

func _process(dt: float) -> void:
	t += dt
	if spin:
		spin.rotation.y = t * 1.4
		spin.position.y = 0.06 + sin(t * 2.0) * 0.03

func begin(_p: Node) -> void:
	collected.emit(relic_id)
	Sfx.play("coin")
	queue_free()
