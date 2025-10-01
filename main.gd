# Level.gd
extends Node

@onready var drop: Area2D = $DropOffArea   # adjust path if different
@onready var game_over_ui: Control = %GameOver   # your hidden container

func _ready() -> void:
	game_over_ui.visible = false
	drop.connect("delivered", _on_delivered)

func _on_delivered(_by: Node) -> void:
	game_over_ui.visible = true
	# Run the quit after 3 seconds
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
