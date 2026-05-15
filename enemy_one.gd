extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

@export var player: Node = null
@export var max_speed: float = 140.0
@export var acceleration: float = 650.0
@export var knockback_friction: float = 800.0   # насколько быстро затухает отталкивание

# Дистанции
@export var ideal_distance: float = 180.0
@export var min_distance: float = 120.0

@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.5

var health: int = 800

# Новые переменные для плавного отталкивания
var knockback_velocity: Vector2 = Vector2.ZERO

enum State { IDLE, KNOCKBACK }
var current_state: State = State.IDLE

func _ready():
	if not player:
		player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# Затухание отталкивания
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	
	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()
	
	match current_state:
		State.IDLE:
			handle_normal_movement(dir_to_player, distance, delta)
		State.KNOCKBACK:
			if knockback_velocity.length() < 50:
				current_state = State.IDLE
	
	# Атаки
	# attack_timer -= delta  ← можешь вернуть таймер атак позже
	
	move_and_slide()
	global_position = global_position.round()


func handle_normal_movement(dir_to_player: Vector2, distance: float, delta: float):
	var desired_dir = dir_to_player.normalized()
	
	# Если слишком близко — отлетаем
	if distance < min_distance:
		desired_dir = -desired_dir
	
	# Лёгкое случайное кружение на комфортной дистанции
	elif distance < ideal_distance + 40:
		desired_dir = desired_dir.rotated(randf_range(-1.0, 1.0))
	
	var target_velocity = desired_dir * max_speed
	
	# Плавно смешиваем нормальное движение + отталкивание
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	velocity += knockback_velocity


# ====================== ОТТАЛКИВАНИЕ ======================
func apply_knockback(direction: Vector2, strength: float = 400.0):
	knockback_velocity += direction.normalized() * strength
	current_state = State.KNOCKBACK


# ====================== УРОН ОТ СОБАКИ ======================
func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO):
	health -= damage
	print("Босс получил", damage, "урона! HP:", health)
	
	if hit_direction != Vector2.ZERO:
		apply_knockback(hit_direction, 380)
	else:
		# если направление неизвестно — отталкиваем от игрока
		if player:
			var dir = (global_position - player.global_position).normalized()
			apply_knockback(dir, 350)
	
	# Можно добавить flash эффекты, звук и т.д. позже
	
	if health <= 0:
		die()


func die():
	print("Босс повержен!")
	queue_free()
