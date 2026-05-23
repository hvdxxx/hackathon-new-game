extends Node2D

@onready var fade_rect: ColorRect = $Control/ColorRect
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await fade(1.0, 0.0, 2.0)

#func _process(delta: float) -> void:
	#pass

func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished
