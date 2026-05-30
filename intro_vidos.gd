extends Node2D

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var fade_rect: ColorRect = $Control/ColorRect

func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished

func _ready() -> void:
	await fade(1.0, 0.0, 2.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_video_stream_player_finished() -> void:
	get_tree().change_scene_to_file("res://lock_one.tscn")
