# CameraFollow.gd
extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 10.0
@export var lead_amount: float = 60.0

var shake_intensity: float = 0.0
var shake_decay: float = 10.0
var shake_random: float = 0.0  # для более "дерганой" тряски

func _ready() -> void:
	if not target:
		target = get_parent()
	
	position_smoothing_enabled = true
	position_smoothing_speed = 12.0

func _process(delta: float) -> void:
	if not target:
		return
	
	# Следование с опережением (lead)
	var lead = target.velocity * (lead_amount / max(target.velocity.length(), 1.0))
	var desired_position = target.global_position + lead
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# === ШЕЙК ===
	if shake_intensity > 0.1:
		shake_random = randf_range(-1.0, 1.0)  # каждый кадр новый рандом
		
		var shake_offset = Vector2(
			sin(shake_random * 25) * shake_intensity,   # более органичная тряска
			cos(shake_random * 20) * shake_intensity * 0.7
		)
		
		offset = shake_offset
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO

# Вызывай эту функцию при ударе
func shake(intensity: float = 8.0, decay: float = 12.0):
	shake_intensity = max(shake_intensity, intensity)
	shake_decay = decay
