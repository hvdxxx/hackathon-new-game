extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $gg_anime
@onready var attack_wave: AudioStreamPlayer2D = $PowerSlashAudio
@onready var attack_star: AudioStreamPlayer2D = $StarAudio

@export var dialogue_resource: DialogueResource

@export var max_speed: float = 120.0
@export var run_speed: float = 220.0
@export var acceleration: float = 600.0
@export var friction: float = 1100.0
@export var y_squash: float = 0.5

@export var power_slash_scene: PackedScene     # ← drag & drop сцену power_slash сюда
@export var star_projectile_scene: PackedScene
@export var attack_cooldown: float = 0.35      # время между атаками (в секундах)

@export var wave_damage: float = 80.0
@export var wave_duration: float = 10.0
@export var star_damage: int = 45
@export var star_duration: float = 10.0
@export var absorb_cooldown: float = 20.0

# === НАСТРОЙКИ JUICE ДЛЯ АТАКЫ ===
@export var attack_dash_force: float = 400.0   # Сила рывка вперед при ударе
@export var hitstop_duration: float = 0.05     # Длительность микро-паузы при ударе
# === ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ (КАМЕРА) ===
@export var zoom_on_attack: float = 1.15      # Насколько сильно приближать камеру (если дефолт 1.0, то 1.15 — легкий зум)
@export var zoom_duration_in: float = 0.08    # Время приближения (в сек)
@export var zoom_duration_out: float = 0.18   # Время возврата камеры (в сек)

# === I-FRAMES НАСТРОЙКИ ===
@export var iframes_duration: float = 0.7 # Длительность бессмертия в секундах
@export var blink_interval: float = 0.1 # Интервал мерцания спрайта
var is_invincible: bool = false
var iframes_timer: float = 0.0
var blink_timer: float = 0.0
var was_visible: bool = true # Для запоминания состояния видимости

var default_camera_zoom: Vector2 = Vector2.ONE

@onready var footstep_player: AudioStreamPlayer2D = $footstep

var camera_node: Camera2D

var can_move: bool = true

const Balloon = preload("res://DialogueBalloon/balloon.tscn")

var attack_timer: float = 0.0

var health: int = 100
var max_health: int = 100
var dog = null

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]
var run_anim = ["run_d", "run_ds", "run_s", "run_sa", "run_a", "run_aw", "run_w", "run_wd"]
var melee_anim = ["melee_d", "melee_ds", "melee_s", "melee_sa", "melee_a", "melee_aw", "melee_w", "melee_wd"]

var last_direction_index: int = 0

var can_absorb_dog: bool = false
var nearby_dog = null
var active_dog = null
var is_wave_active: bool = false
var wave_timer: float = 0.0
var is_star_active: bool = false
var star_timer: float = 0.0
var absorb_cooldown_timer: float = 0.0

var footstep_timer: float = 0.0
var is_moving: bool = false
var current_speed_for_steps: float = 0.0

var is_attacking: bool = false  

var _current_attack_dir: Vector2 = Vector2.ZERO

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
	# queue_free() или переход на Game Over
	get_tree().reload_current_scene()

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO):
	if is_invincible:
		return
	
	health -= damage
	GlobalUI.update_player_health()
	
	# === ЗАПУСК I-FRAMES ===
	is_invincible = true
	iframes_timer = iframes_duration
	blink_timer = 0.0
	was_visible = sprite.visible # Запоминаем, что спрайт был видим
	
	# === ТРЯСКА КАМЕРЫ ===
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		var intensity = 6.0 + (damage * 0.45)
		camera.shake(intensity, 14.0)
	
	# === KNOCKBACK (опционально) ===
	if hit_direction != Vector2.ZERO:
		velocity += hit_direction * 250
	
	if health <= 0:
		die()

func _ready():
	Global.main_hero = sprite
	add_to_group("player")
	dog = get_tree().get_first_node_in_group("dog")
	if not dog:
		push_warning("Собака не найдена! Добавь её в группу 'dog'")
	camera_node = get_viewport().get_camera_2d() as Camera2D
	#get_tree().current_scene.add_child(balloon)
	#DialogueManager.show_dialogue_balloon(dialogue_resource, "start")
	camera_node = get_viewport().get_camera_2d() as Camera2D
	
	# Запоминаем дефолтный зум твоей камеры
	if camera_node:
		default_camera_zoom = camera_node.zoom

# ←←← ВСЁ УПРАВЛЕНИЕ КЛИКАМИ ТОЛЬКО ЗДЕСЬ
func _input(event: InputEvent) -> void:
	# Активация собаки (E)
	if event.is_action_pressed("active"):
		try_absorb_dog()
	
	# Атака активной способностью (ЛКМ)
	if event.is_action_pressed("attack") and attack_timer <= 0:
		if is_wave_active:
			shoot_power_slash()
		elif is_star_active:
			shoot_star()

func _physics_process(delta: float) -> void:
	# === ТАЙМЕРЫ ===
	if absorb_cooldown_timer > 0:
		absorb_cooldown_timer -= delta
	if is_wave_active:
		wave_timer -= delta
		if wave_timer <= 0:
			end_wave()
	if is_star_active:
		star_timer -= delta
		if star_timer <= 0:
			end_star()
	if attack_timer > 0:
		attack_timer -= delta

# === ОБРАБОТКА I-FRAMES ===
	if is_invincible:
		iframes_timer -= delta
		blink_timer += delta
		
		# Мерцание спрайта
		if blink_timer >= blink_interval:
			sprite.visible = !sprite.visible
			blink_timer = 0.0
		
		# Конец неуязвимости
		if iframes_timer <= 0:
			is_invincible = false
			sprite.visible = true # Гарантируем видимость

	# === БЛОКИРОВКИ ДВИЖЕНИЯ ===
	# Если can_move равен false (например, идёт диалог) или мы атакуем — стоим на месте
	if not can_move:
		velocity = Vector2.ZERO
		is_moving = false
		$GPUParticles2D.emitting = false
		update_animation(false)
		move_and_slide()
		return

# ←←← НОВОЕ: Блокируем движение во время атаки
	if is_attacking:
		is_moving = false
		$GPUParticles2D.emitting = false
		# Плавно гасим рывок от атаки трением
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

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
	if is_attacking:
		return   # ← важно! не перебивать melee анимацию
	
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
	active_dog = nearby_dog
	var ability_id: StringName = &"wave"
	var dog_ability = nearby_dog.get("ability_id")
	if dog_ability != null:
		ability_id = StringName(str(dog_ability))
	
	if ability_id == &"star":
		start_star_ability()
	else:
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
	var dog_to_return = active_dog if active_dog else nearby_dog
	if dog_to_return and is_instance_valid(dog_to_return):
		var spawn_pos = global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		dog_to_return.reappear(spawn_pos)
	active_dog = null
	print("Способность закончилась, собака вернулась")

func start_star_ability() -> void:
	is_star_active = true
	star_timer = star_duration
	print("Собака поглощена! Звездная стрельба активирована")

func end_star() -> void:
	is_star_active = false
	var dog_to_return = active_dog if active_dog else nearby_dog
	if dog_to_return and is_instance_valid(dog_to_return):
		var spawn_pos = global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		dog_to_return.reappear(spawn_pos)
	active_dog = null
	print("Звездная способность закончилась")
	
func try_absorb_dog() -> void:
	if can_absorb_dog and nearby_dog and not is_wave_active and not is_star_active and absorb_cooldown_timer <= 0:
		absorb_dog()
	elif is_wave_active or is_star_active:
		print("Способность уже активна!")
	elif absorb_cooldown_timer > 0:
		print("Подожди, кулдаун ещё ", snapped(absorb_cooldown_timer, 0.1), " секунд")
		
func shoot_power_slash() -> void:
	if not power_slash_scene:
		push_warning("Power Slash scene не назначена!")
		return

	if is_attacking:
		return

	# === НАПРАВЛЕНИЕ УДАРА ===
	_current_attack_dir = (get_global_mouse_position() - global_position).normalized()
	if _current_attack_dir == Vector2.ZERO:
		_current_attack_dir = Vector2.RIGHT
		
	var angle = _current_attack_dir.angle()
	var angle_normalized = fposmod(angle, TAU)
	var dir_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8

	var anim_name = melee_anim[dir_index]

	# === АКТИВАЦИЯ АТАК И РЫВОК (JUICE) ===
	is_attacking = true
	velocity = _current_attack_dir * attack_dash_force

	# === ВИЗУАЛЬНЫЙ ТВИН СУЖЕНИЯ СПРАЙТА ===
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# === НОВОЕ: ПРИБЛИЖЕНИЕ КАМЕРЫ ===
	if camera_node:
		var target_zoom = default_camera_zoom * zoom_on_attack
		# Плавно зумим камеру за доли секунды до удара
		create_tween().tween_property(camera_node, "zoom", target_zoom, zoom_duration_in)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# === ВИЗУАЛ ===
	sprite.play(anim_name)

	var attack_duration: float = 0.15 
	get_tree().create_timer(attack_duration).timeout.connect(_spawn_power_slash_wave)

func shoot_star() -> void:
	if not star_projectile_scene:
		push_warning("Star projectile scene не назначена!")
		return

	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	if mouse_dir == Vector2.ZERO:
		mouse_dir = Vector2.RIGHT

	var star = star_projectile_scene.instantiate()
	get_parent().add_child(star)
	star.global_position = global_position + mouse_dir * 36 + Vector2(0, -24)

	if star.has_method("setup"):
		star.setup(mouse_dir, star_damage, self)
	
	if attack_star:
		attack_star.volume_db = randf_range(-22,-10)
		attack_star.pitch_scale = randf_range(0.9, 1.1)
		attack_star.play()
	
	attack_timer = attack_cooldown
	
# Этот метод вызывается автоматически по таймеру или сигналу окончания атаки
func _spawn_power_slash_wave() -> void:
	if not is_attacking:
		# Если атаку прервали, возвращаем камеру назад
		if camera_node:
			create_tween().tween_property(camera_node, "zoom", default_camera_zoom, zoom_duration_out)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		return

	# === СОЗДАЁМ ВОЛНУ ===
	var slash = power_slash_scene.instantiate()
	get_parent().add_child(slash)

	var spawn_offset = _current_attack_dir * 32
	spawn_offset.y -= 16

	slash.global_position = global_position + spawn_offset
	slash.setup(_current_attack_dir, int(wave_damage), self)
	
	if "rotation" in slash:
		slash.rotation = _current_attack_dir.angle()
	
	# === ЭФФЕКТЫ УДАРА (JUICE) ===
	
	# 1. Возвращаем форму спрайта назад
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 2. Тряска камеры при самом ударе
	if camera_node and camera_node.has_method("shake"):
		camera_node.shake(4.0, 10.0)
		
	# 3. НОВОЕ: ОТДАЛЕНИЕ КАМЕРЫ НАЗАД ===
	if camera_node:
		# Плавно возвращаем зум к обычному значению
		create_tween().tween_property(camera_node, "zoom", default_camera_zoom, zoom_duration_out)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) # TRANS_BACK даст легкий пружинящий эффект назад
	
	# 4. Эффект хитстопа (заморозка)
	trigger_hitstop(hitstop_duration)
	
	# === ЗВУК ===
	if attack_wave:
		attack_wave.volume_db = randf_range(-18, -8)
		attack_wave.pitch_scale = randf_range(0.85, 1.15)
		attack_wave.play()
	
	# === РАЗБЛОКИРОВКА И КУЛДАУН ===
	is_attacking = false
	attack_timer = attack_cooldown
	
	# Функция для кратковременной остановки времени
func trigger_hitstop(duration: float) -> void:
	if duration <= 0: return
	Engine.time_scale = 0.05 # Почти полная остановка мира
	await get_tree().create_timer(duration * 0.05, true, false, true).timeout # Таймер, игнорирующий time_scale
	Engine.time_scale = 1.0
