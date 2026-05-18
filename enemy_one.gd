extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound
@onready var hit_area: Area2D = $HitArea
@onready var proj_sound: AudioStreamPlayer2D = $Blast
@onready var ability_timer: Timer = $AbilityTimer

@export var player: Node = null
@export var max_speed: float = 160.0
@export var acceleration: float = 650.0
@export var knockback_friction: float = 1800.0

# === ДВИЖЕНИЕ И КРУЖЕНИЕ ===
@export var ideal_distance: float = 190.0
@export var min_distance: float = 130.0
@export var orbit_speed_multiplier: float = 0.85

# === ПАРЕНИЕ ===
@export var hover_amplitude: float = 0
@export var hover_speed: float = 0

# === ТРЯСКА ПРИ УРОНЕ ===
@export var hit_shake_intensity: float = 8.0      # Сила тряски
@export var hit_shake_duration: float = 0.35      # Длительность тряски

# === АТАКА ===
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.5
@export var attack_distance: float = 220.0

# === SOSTOYANIYA ===
enum BossState { IDLE, KNOCKBACK, ATTACKING, ATTACK_COMBOS, ULTIMATE, DEAD }
var current_state: BossState = BossState.IDLE
var is_ultimate_used: bool = false

var health: int = 800
@export var max_health: int = 800
var knockback_velocity: Vector2 = Vector2.ZERO


var attack_timer: float = 0.0

# Для кружения
var orbit_direction: float = 1.0
var time_since_last_change: float = 0.0

# Для парения
var hover_time: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var base_hover_y: float = 0.0   # ← новое
var base_sprite_offset: Vector2 = Vector2.ZERO # ← Добавь эту строчку

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
	
	sprite.play("walk")
	
	# ЗАПОМИНАЕМ НАСТРОЙКИ ИЗ РЕДАКТОРА:
	base_hover_y = sprite.position.y        # Запомнили позицию (например, 0)
	base_sprite_offset = sprite.offset      # Запомнили твой оффсет Y = -97
	base_position = global_position
	
	print("Босс готов. Исходный оффсет спрайта: ", base_sprite_offset)

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
		BossState.IDLE:
			handle_orbiting_movement(dir_to_player, distance, delta)
			try_to_attack(distance, dir_to_player)
		
		BossState.KNOCKBACK:
			if knockback_velocity.length() < 50:
				current_state = BossState.IDLE
			# Можно дополнительно замедлять velocity
			velocity = velocity.move_toward(knockback_velocity, acceleration * delta * 1.5)
		
		BossState.ATTACKING:
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
		# Прибавляем тряску к базовому оффсету, чтобы босс не падал вниз при получении урона
		sprite.offset = base_sprite_offset + Vector2(offset_x, offset_y)
	else:
		# Возвращаем исходный оффсет, который настроен в инспекторе (-97)
		sprite.offset = base_sprite_offset

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
	current_state = BossState.ATTACKING
	attack_timer = attack_cooldown
	shoot_projectile(dir_to_player.normalized())
	
	await get_tree().create_timer(0.4).timeout
	if current_state == BossState.ATTACKING:
		current_state = BossState.IDLE

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
	current_state = BossState.KNOCKBACK

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO, apply_kb: bool = true):
	
	# ЗАЩИТА №1: Если флаг смерти уже поднят — МГНОВЕННО игнорируем всё, что летит в босса
	if is_dead:
		return  
	
	health -= damage
	if health < 0:
		health = 0
	
	# ПРОВЕРКА НА СМЕРТЬ
	if health <= 0:
		is_dead = true # Мгновенно фиксируем смерть, чтобы функция больше не срабатывала!
		
		# ЗАЩИТА №2: Мгновенно отключаем Хёртбокс (зону получения урона), 
		# чтобы волна атаки больше не могла его задеть ни в этом, ни в следующем кадре.
		# Замени "Hurtbox" на точное имя ноды твоей зоны урона у босса, если оно другое.
		var hurtbox = get_node_or_null("Hurtbox")
		if hurtbox:
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
		
		GlobalUI.hide_boss_health() # Прячем бар
		die()                       # Уходим в функцию смерти
		return                      # Выходим, чтобы код ниже не выполнялся
		
	# Код ниже сработает, только если босс ВЫЖИЛ
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


func die():
	print("Босс повержен!")
	
	# Полностью отключаем просчет физики и процесса для босса
	set_process(false)
	set_physics_process(false)
	
	# Безопасно отключаем слои коллизий через set_deferred.
	# В Godot нельзя менять физические слои прямо во время просчета коллизий (внутри зоны),
	# поэтому используем set_deferred — это скажет движку "отключи слои в следующем кадре".
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# Даем 1 секунду на анимацию
	await get_tree().create_timer(1.0).timeout  
	
	# Удаляем босса
	queue_free()

# Этот метод вызовется сам, когда таймер досчитает до нуля
func _on_ability_timer_timeout() -> void:
	if current_state == BossState.DEAD:
		return

	# Проверяем Лоу ХП (меньше 30%)
	if health <= (max_health * 0.3) and not is_ultimate_used:
		trigger_ultimate()
		return
	
	# Если ХП нормальное — бахаем комбо из двух способностей!
	spawn_linear_strike()

# ФУНКЦИЯ ДЛЯ КОМБО (Скилл 1 + Скилл 2)
func spawn_linear_strike() -> void:
	print("⚡ Удар по расписанию!")
	
	# Ищем игрока через группу
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Инстанцируем нашу новую безопасную изометрическую зону
		var strike_zone = preload("res://StrikeZone.tscn").instantiate()
		
		# ВАЖНО: Мы не крутим её через look_at.
		# Мы берем глобальную позицию игрока ОДИН раз в момент старта атаки.
		# Таким образом, маркер появится там, где стоял игрок, а у игрока будет 0.6 секунды, чтобы выбежать.
		strike_zone.global_position = player.global_position
		
		# Добавляем зону на уровень (к родителю босса), чтобы она не двигалась вместе с боссом
		get_parent().add_child(strike_zone)

# ФУНКЦИЯ ДЛЯ УЛЬТЫ (Автобус)
func trigger_ultimate():
	pass
