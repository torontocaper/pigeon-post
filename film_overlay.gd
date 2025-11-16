extends ColorRect

func _ready() -> void:
	# Initialize shader parameters based on the actual viewport
	material.set_shader_parameter("viewport_size", get_viewport_rect().size)

func _process(_delta: float) -> void:
	# Continuously update time for animated grain
	material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
