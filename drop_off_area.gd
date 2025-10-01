# DropOffArea.gd
extends Area2D
signal delivered(by: Node)

# Called by the envelope right before it frees itself.
func on_envelope_delivered(by: Node) -> void:
	emit_signal("delivered", by)
