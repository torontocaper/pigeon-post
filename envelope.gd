extends RigidBody2D

signal picked_up(by: Node)
signal dropped_off(at: Node)

var _carrier: Node = null

func pick_up(by: Node, socket: Node2D) -> void:
	if _carrier: return
	_carrier = by
	freeze = true        # stop physics
	reparent(socket, true)
	emit_signal("picked_up", by)

func drop_to_ground(world_parent: Node, global_pos: Vector2) -> void:
	if not _carrier: return
	_carrier = null
	reparent(world_parent, true)
	global_position = global_pos
	freeze = false       # resume physics

# Envelope.gd  (Sprite2D OR RigidBody2D version—same idea)

func deliver(at_node: Node) -> void:
	if _carrier == null:
		return
	# Tell the drop-off it was delivered (if it has the handler)
	if at_node and at_node.has_method("on_envelope_delivered"):
		at_node.on_envelope_delivered(_carrier)
	emit_signal("dropped_off", at_node)
	queue_free()
