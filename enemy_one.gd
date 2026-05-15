extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound
@onready var hit_area: Area2D = $HitArea

@export var player: Node = null
@export var max_speed: float = 160.0
@export var acceleration: float = 650.0
@export var knockback_friction: float = 1800.0

# === ДВИЖЕНИЕ И КРУЖЕНИЕ ===
@export var ideal_distance: float = 190.0
@export var min_distance: float = 130.0
@export var orbit_speed_multiplier: float = 0.85

# === АТАКА ===
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.5
@export var attack_distance: float = 220.0

var health: int = 800
var knockback_velocity: Vector2 = Vector2.ZERO

enum State { IDLE, KNOCKBACK, ATTACKING }
var current_state: State = State.IDLE

var attack_timer: float = 0.0

# Для кружения
var orbit_direction: float = 1.0
var time_since_last_change: float = 0.0

func _ready():
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	add_to_group("boss")
	orbit_direction = 1 if randf() > 0.5 else -1
	print("Босс готов. Кружение:", "по часовой" if orbit_direction > 0 else "против часовой")

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	
	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()
	
	if attack_timer > 0:
		attack_timer -= delta
	
	match current_state:
		State.IDLE:
			handle_orbiting_movement(dir_to_player, distance, delta)
			try_to_attack(distance, dir_to_player)     # ← вот она!
		
		State.KNOCKBACK:
			if knockback_velocity.length() < 50:
				current_state = State.IDLE
		
		State.ATTACKING:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta * 2) # замедляемся при атаке
	
	move_and_slide()
	global_position = global_position.round()

# ====================== КРУЖЕНИЕ ВОКРУГ ГЕРОЯ ======================
func handle_orbiting_movement(dir_to_player: Vector2, distance: float, delta: float):
	time_since_last_change += delta
	
	# Меняем направление кружения иногда
	if time_since_last_change > randf_range(6.0, 12.0):
		orbit_direction *= -1
		time_since_last_change = 0.0
	
	var desired_velocity = Vector2.ZERO
	
	if distance < min_distance:
		desired_velocity = -dir_to_player.normalized() * max_speed * 1.1
		
	elif distance > ideal_distance + 60:
		desired_velocity = dir_to_player.normalized() * max_speed * 0.9
		
	else:
		# Основное кружение
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
	
	# Небольшая пауза после выстрела
	await get_tree().create_timer(0.4).timeout
	if current_state == State.ATTACKING:
		current_state = State.IDLE

func shoot_projectile(direction: Vector2):
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 45
	
	if projectile.has_method("setup"):
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

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO):
	health -= damage
	print("Босс получил ", damage, " урона! HP осталось: ", health)
	
	if hit_direction != Vector2.ZERO:
		apply_knockback(hit_direction, 380)
	elif player:
		var dir = (global_position - player.global_position).normalized()
		apply_knockback(dir, 350)
	
	if health <= 0:
		die()

func die():
	print("Босс повержен!")
	queue_free()
