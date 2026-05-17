extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound
@onready var hit_area: Area2D = $HitArea
@onready var proj_sound: AudioStreamPlayer2D = $Blast

@export var player: Node = null
@export var max_speed: float = 160.0
@export var acceleration: float = 650.0
@export var knockback_friction: float = 1800.0

# === ДВИЖЕНИЕ И КРУЖЕНИЕ ===
@export var ideal_distance: float = 190.0
@export var min_distance: float = 130.0
@export var orbit_speed_multiplier: float = 0.85

# === ПАРЕНИЕ ===
@export var hover_amplitude: float = 12.0
@export var hover_speed: float = 3.5

# === ТРЯСКА ПРИ УРОНЕ ===
@export var hit_shake_intensity: float = 8.0      # Сила тряски
@export var hit_shake_duration: float = 0.35      # Длительность тряски

# === АТАКА ===
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.5
@export var attack_distance: float = 220.0



var health: int = 800
@export var max_health: int = 800
var knockback_velocity: Vector2 = Vector2.ZERO

enum State { IDLE, KNOCKBACK, ATTACKING }
var current_state: State = State.IDLE

var attack_timer: float = 0.0

# Для кружения
var orbit_direction: float = 1.0
var time_since_last_change: float = 0.0

# Для парения
var hover_time: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var base_hover_y: float = 0.0   # ← новое

# Для тряски при уроне
var shake_time: float = 0.0
var shake_intensity: float = 0.0

var is_dead: bool = false

func _ready():
	health = max_health
	GlobalUI.show_boss_health(self)
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	add_to_group("boss")
	orbit_direction = 1 if randf() > 0.5 else -1
	base_position = global_position
	sprite.play("walk")
	
	base_hover_y = sprite.position.y   # запоминаем исходную позицию спрайта
	base_position = global_position
	
	print("Босс готов → Кружение + Парение + Hit Shake")

func _physics_process(delta: float) -> void:
	if not player: return
	
	hover_time += delta * hover_speed
	shake_time -= delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()

	if attack_timer > 0:
		attack_timer -= delta

	match current_state:
		State.IDLE:
			handle_orbiting_movement(dir_to_player, distance, delta)
			try_to_attack(distance, dir_to_player)
		
		State.KNOCKBACK:
			if knockback_velocity.length() < 50:
				current_state = State.IDLE
			# Можно дополнительно замедлять velocity
			velocity = velocity.move_toward(knockback_velocity, acceleration * delta * 1.5)
		
		State.ATTACKING:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta * 3)

	# Применяем knockback
	velocity += knockback_velocity

	move_and_slide()          # ← ВСЕГДА в конце!

	apply_hover_effect()
	apply_hit_shake()

	# округление
	global_position = global_position.round()

# ====================== ПАРЕНИЕ ======================
func apply_hover_effect():
	var hover_offset = sin(hover_time) * hover_amplitude
	var extra_wave = sin(hover_time * 1.7) * (hover_amplitude * 0.35)
	
	sprite.position.y = base_hover_y + hover_offset + extra_wave

# ====================== ТРЯСКА ПРИ УРОНЕ ======================
func apply_hit_shake():
	if shake_time > 0:
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity * 0.6, shake_intensity * 0.6)
		sprite.offset = Vector2(offset_x, offset_y)
	else:
		sprite.offset = Vector2.ZERO

func start_hit_shake(intensity: float = 0.0):
	shake_intensity = max(hit_shake_intensity, intensity)
	shake_time = hit_shake_duration

# ====================== КРУЖЕНИЕ ======================
func handle_orbiting_movement(dir_to_player: Vector2, distance: float, delta: float):
	time_since_last_change += delta
	if time_since_last_change > randf_range(6.0, 12.0):
		orbit_direction *= -1
		time_since_last_change = 0.0
	
	var desired_velocity = Vector2.ZERO
	
	if distance < min_distance:
		desired_velocity = -dir_to_player.normalized() * max_speed * 1.1
	elif distance > ideal_distance + 60:
		desired_velocity = dir_to_player.normalized() * max_speed * 0.9
	else:
		var to_player_norm = dir_to_player.normalized()
		var perpendicular = Vector2(-to_player_norm.y, to_player_norm.x) * orbit_direction
		var radial_component = (distance - ideal_distance) * -0.45
		
		desired_velocity = perpendicular * max_speed * orbit_speed_multiplier + \
						  to_player_norm * radial_component
		desired_velocity = desired_velocity.rotated(randf_range(-0.5, 0.5))
	
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	velocity += knockback_velocity

# ====================== АТАКА ======================
func try_to_attack(distance: float, dir_to_player: Vector2):
	if attack_timer > 0 or distance > attack_distance or not projectile_scene:
		return
	current_state = State.ATTACKING
	attack_timer = attack_cooldown
	shoot_projectile(dir_to_player.normalized())
	
	await get_tree().create_timer(0.4).timeout
	if current_state == State.ATTACKING:
		current_state = State.IDLE

func shoot_projectile(direction: Vector2):
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 45
	
	if projectile.has_method("setup"):
		if proj_sound and not proj_sound.playing:
			proj_sound.pitch_scale = randf_range(0.85, 1.15)  # чуть разный тон каждый раз
			proj_sound.play()
		projectile.setup(direction)
	elif projectile.has_method("launch"):
		projectile.launch(direction)
	else:
		if "velocity" in projectile:
			projectile.velocity = direction * 320
	
	if attack_sound:
		attack_sound.pitch_scale = randf_range(0.9, 1.1)
		attack_sound.play()

# ====================== УРОН ======================
func apply_knockback(direction: Vector2, strength: float = 400.0):
	knockback_velocity += direction.normalized() * strength
	current_state = State.KNOCKBACK

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO, apply_kb: bool = true):
	
	if is_dead or health <= 0:
		return  # ← сразу выходим, если уже мёртв
	
	health -= damage
	if health < 0:
		health = 0
	
	GlobalUI.update_health()
	
	start_hit_shake(damage * 0.15)
	
	if hit_direction != Vector2.ZERO:
		if apply_kb:
			apply_knockback(hit_direction, 380)
		else:
			velocity += hit_direction * 120.0
	elif player:
		var dir = (global_position - player.global_position).normalized()
		apply_knockback(dir, 280)
	
	if health <= 0 and not is_dead:
		is_dead = true
		GlobalUI.hide_boss_health()
		die()


func die():
	print("Босс повержен!")
	GlobalUI.hide_boss_health()
	
	# Отключаем все коллизии, чтобы больше не получал урон
	set_collision_layer_value(1, false)   # подставь правильный слой босса
	set_collision_mask_value(1, false)
	
	await get_tree().create_timer(1.0).timeout  # даём время на анимацию смерти
	
	queue_free()
