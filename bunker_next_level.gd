extends Area2D

@onready var fade_rect: ColorRect = $Control/ColorRect

#func fade(from: float, to: float, duration: float):
	#var t = create_tween()
	#t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	#await t.finished

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_body_entered(_body: Node2D) -> void:
	#await fade(0.0, 1.0, 2.0)
	get_tree().change_scene_to_file("res://lock_two.tscn")
