# CameraFollow.gd
extends Camera2D

@export var follow_speed: float = 15.0
@export var lead_amount: float = 65.0
@export var smoothing_speed: float = 18.0

var shake_intensity: float = 0.0
var shake_decay: float = 12.0

var character_body: CharacterBody2D = null

func _ready() -> void:
	# Автоматически ищем CharacterBody2D в сцене
	character_body = find_character_body(get_tree().root)
	
	if not character_body:
		push_error("CameraFollow: CharacterBody2D не найден в сцене!")
	else:
		print("CameraFollow: успешно подключился к ", character_body.name)
	
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	ignore_rotation = true


func _process(delta: float) -> void:
	if not character_body:
		return
	
	var lead = Vector2.ZERO
	var vel = character_body.velocity
	
	if vel.length() > 0.1:
		lead = vel * (lead_amount / vel.length())
	
	var desired_position = character_body.global_position + lead
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Shake
	if shake_intensity > 0.1:
		var r = randf_range(-1.0, 1.0)
		offset = Vector2(
			sin(r * 25) * shake_intensity,
			cos(r * 20) * shake_intensity * 0.7
		)
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO


func find_character_body(node: Node) -> CharacterBody2D:
	if node is CharacterBody2D:
		return node
	for child in node.get_children():
		var found = find_character_body(child)
		if found:
			return found
	return null


func shake(intensity: float = 8.0, decay: float = 12.0) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_decay = decay
