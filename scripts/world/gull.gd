extends Node3D
class_name Gull
## The gull. It takes an oyster. It is the joke.

var target := Vector3.ZERO
var home := Vector3(16, 7, 6)
var state := 0
var speed := 9.0
var steal: Callable
var carrying: Node3D
var t := 0.0
var wing_l: Node3D
var wing_r: Node3D

func setup(from: Vector3, to: Vector3, on_steal: Callable) -> void:
	add_child(MeshFactory.gull())
	wing_l = get_child(0).get_child(3)
	wing_r = get_child(0).get_child(4)
	position = from
	home = to
	target = to
	steal = on_steal
	look_at(target, Vector3.UP)
	set_process(true)

func _process(dt: float) -> void:
	t += dt
	if wing_l and wing_r:
		wing_l.rotation.z = sin(t * 12.0) * 0.6
		wing_r.rotation.z = -sin(t * 12.0) * 0.6
	var dir := (target - position)
	var dist := dir.length()
	if dist < 0.25:
		if state == 0:
			state = 1
			if steal.is_valid():
				var taken: Node3D = steal.call()
				if taken != null:
					carrying = taken
					taken.reparent(self)
					taken.position = Vector3(0, -0.15, 0)
			target = home
		else:
			queue_free()
		return
	position += dir.normalized() * minf(speed * dt, dist)
	rotation.y = atan2(dir.x, dir.z)
	position.y += sin(t * 6.0) * 0.003
