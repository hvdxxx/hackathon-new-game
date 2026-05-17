extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_speed: float = 120.0
@export var run_speed: float = 220.0
@export var acceleration: float = 600.0
@export var friction: float = 1100.0
@export var y_squash: float = 0.5

@export var power_slash_scene: PackedScene     # ← drag & drop сцену power_slash сюда
@export var attack_cooldown: float = 0.35      # время между атаками (в секундах)

@export var wave_damage: float = 80.0
@export var wave_duration: float = 10.0
@export var absorb_cooldown: float = 20.0

@onready var footstep_player: AudioStreamPlayer2D = $footstep

var attack_timer: float = 0.0

var health: int = 200
var max_health: int = 200
var dog = null

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]
var run_anim = ["run_d", "run_ds", "run_s", "run_sa", "run_a", "run_aw", "run_w", "run_wd"]

var last_direction_index: int = 0

var can_absorb_dog: bool = false
var nearby_dog = null
var is_wave_active: bool = false
var wave_timer: float = 0.0
var absorb_cooldown_timer: float = 0.0

var footstep_timer: float = 0.0
var is_moving: bool = false
var current_speed_for_steps: float = 0.0

# Настройка интервалов между шагами (в секундах)
@export var walk_step_interval: float = 0.45
@export var run_step_interval: float = 0.25

func play_footstep() -> void:
	if footstep_player.playing:
		footstep_player.stop()
	
	# Лёгкая вариация
	footstep_player.pitch_scale = randf_range(1.2, 1.5)
	footstep_player.volume_db = randf_range(-40, -25)  # чуть тише/громче
	footstep_player.play()
	
func handle_footsteps(delta: float, is_running: bool) -> void:
	if not is_moving or velocity.length() < 30:
		footstep_timer = 0.0
		return
	
	var step_interval = run_step_interval if is_running else walk_step_interval
	
	footstep_timer += delta
	
	if footstep_timer >= step_interval:
		play_footstep()
		footstep_timer = 0.0

func die():
	print("ИГРОК ПОГИБ!")
	# queue_free() или переход на Game Over
	# get_tree().reload_current_scene() — для теста

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO):
	health -= damage
	print("Игрок получил ", damage, " урона! HP: ", health, "/", max_health)
	
	# === ТРЯСКА КАМЕРЫ ===
	var camera = get_viewport().get_camera_2d()   # находим камеру
	if camera and camera.has_method("shake"):
		# Сильнее трясёт при большем уроне
		var intensity = 6.0 + (damage * 0.35)
		camera.shake(intensity, 14.0)
	
	# Можно добавить knockback потом
	if hit_direction != Vector2.ZERO:
		velocity += hit_direction * 250   # пример отталкивания
	
	if health <= 0:
		die()

func _ready():
	add_to_group("player")
	dog = get_tree().get_first_node_in_group("dog")
	if not dog:
		push_warning("Собака не найдена! Добавь её в группу 'dog'")

# ←←← ВСЁ УПРАВЛЕНИЕ КЛИКАМИ ТОЛЬКО ЗДЕСЬ
func _input(event: InputEvent) -> void:
	# Активация собаки (E)
	if event.is_action_pressed("active"):
		try_absorb_dog()
	
	# Атака магической волной (ЛКМ)
	if event.is_action_pressed("attack") and is_wave_active and attack_timer <= 0:
		shoot_power_slash()

func _physics_process(delta: float) -> void:
	# === ТАЙМЕРЫ ===
	if absorb_cooldown_timer > 0:
		absorb_cooldown_timer -= delta
	if is_wave_active:
		wave_timer -= delta
		if wave_timer <= 0:
			end_wave()
	if attack_timer > 0:
		attack_timer -= delta

	# === ДВИЖЕНИЕ ===
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running = Input.is_action_pressed("run")
	
	if input != Vector2.ZERO:
		var move_dir = Vector2(input.x, input.y * y_squash).normalized()
		var current_speed = run_speed if is_running else max_speed
		
		velocity = move_dir * current_speed
		current_speed_for_steps = current_speed
		is_moving = true
		
		update_animation(is_running)
	else:
		velocity = Vector2.ZERO
		is_moving = false
		update_animation(false)

	if velocity.length() > 0:
		$GPUParticles2D.emitting = true
	else:
		$GPUParticles2D.emitting = false

	move_and_slide()
	global_position = global_position.round()

	# === ЗВУКИ ШАГОВ ===
	handle_footsteps(delta, is_running)


func update_animation(running: bool = false):
	if velocity.length() > 10:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		
		if running:
			sprite.play(run_anim[last_direction_index])
		else:
			sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])
		
func absorb_dog() -> void:
	if not nearby_dog:
		return
	
	nearby_dog.absorb()
	start_wave_ability()
	absorb_cooldown_timer = absorb_cooldown

func start_wave_ability() -> void:
	is_wave_active = true
	wave_timer = wave_duration
	# Здесь можно поменять анимацию игрока, включить партиклы и т.д.
	print("Собака поглощена! Магическая волна активирована на 10 сек")

func end_wave() -> void:
	is_wave_active = false
	# Возвращаем собаку рядом с игроком
	if nearby_dog:
		var spawn_pos = global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		nearby_dog.reappear(spawn_pos)
	print("Способность закончилась, собака вернулась")
	
func try_absorb_dog() -> void:
	if can_absorb_dog and nearby_dog and not is_wave_active and absorb_cooldown_timer <= 0:
		absorb_dog()
	elif is_wave_active:
		print("Способность уже активна!")
	elif absorb_cooldown_timer > 0:
		print("Подожди, кулдаун ещё ", snapped(absorb_cooldown_timer, 0.1), " секунд")
		
func shoot_power_slash() -> void:
	if not power_slash_scene:
		push_warning("Power Slash scene не назначена!")
		return
	
	var slash = power_slash_scene.instantiate()
	get_parent().add_child(slash)
	
	# Спавним немного перед игроком
	var spawn_offset = Vector2.RIGHT.rotated(velocity.angle())
	spawn_offset.y -= 30
	
	slash.global_position = global_position + spawn_offset
	
	# Направление в сторону мыши
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	
	# Вызываем setup
	slash.setup(mouse_dir, int(wave_damage), self)   # ← передаём себя как shooter
	
	attack_timer = attack_cooldown
