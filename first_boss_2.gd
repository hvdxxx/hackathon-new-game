extends CharacterBody2D

# Расширяем стейт-машину новыми состояниями способностей
enum State { 
	IDLE, CHASE, CIRCLE, RETREAT, 
	TELEGRAPH_DASH, DASH, ATTACK, STUNNED,
	TELEGRAPH_LINE, ABILITY_LINE,     # Способность 1
	TELEGRAPH_BURST, ABILITY_BURST     # Способность 2
}
var current_state: State = State.IDLE

@export_category("Boss Stats")
@export var max_health: float = 600.0
@onready var current_health: float = max_health
var ultimate_triggered: bool = false

@export_category("Combat Balance")
@export var melee_damage: float = 20.0
@export var pull_strength: float = 120.0 
@export var attack_range: float = 55.0  
@export var special_cooldown: float = 4.0 # Раз в сколько секунд босс может юзать скиллы

@export_category("Prefabs")
# Перетащи сюда сцену снаряда босса (создадим на Шаге 3)
@export var projectile_scene: PackedScene 

@export_category("References")
@export var player: CharacterBody2D

var original_sprite_scale: Vector2 = Vector2(5.0, 5.0)

var circle_direction: float = 1.0
var dash_target_direction: Vector2 = Vector2.ZERO
var current_special_cooldown: float = 2.0 # Стартовая задержка перед первым скиллом

@onready var boss: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_timer: Timer = $StateTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_collision: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Новые ноды для первой способности
@onready var line_2d: Line2D = $Line2D
@onready var ray_cast: RayCast2D = $RayCast2D

# Аудио
@onready var sword_slicing: AudioStreamPlayer2D = $SwordSlicing
@onready var sword_combat: AudioStreamPlayer2D = $SwordCombat
@onready var firstskill_audio: AudioStreamPlayer2D = $firstskill

func _ready() -> void:
	GlobalUI.show_boss_health(self)
	if sprite:
		original_sprite_scale = sprite.scale # Запоминаем, что он равен (5, 5)
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	melee_hitbox.monitoring = false
	melee_collision.disabled = false 
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	
	line_2d.visible = false
	ray_cast.enabled = false # Руками включаем только в момент каста
	
	dash_cooldown.one_shot = true
	state_timer.one_shot = true
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if not player: return
	
	# Уменьшаем общий кулдаун способностей босса
	if current_special_cooldown > 0:
		current_special_cooldown -= delta
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	var dir_to_player = to_player.normalized()

	# Поворот спрайта и хитбокса
	if current_state != State.DASH and current_state != State.ATTACK and current_state != State.ABILITY_LINE:
		sprite.flip_h = dir_to_player.x < 0
		melee_hitbox.scale.x = -1.0 if dir_to_player.x < 0 else 1.0

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
		State.CHASE:
			velocity = dir_to_player * 190.0 # ОЧЕНЬ БЫСТРО (было 130)! Теперь он почти догоняет спринтующего ГГ
			
			# Прямо во время бега босс может резко решить прожать магию, если она не на КД
			if current_special_cooldown <= 0 and randf() < 0.02:
				change_state(State.TELEGRAPH_LINE if randf() > 0.5 else State.TELEGRAPH_BURST)
			elif distance <= attack_range:
				change_state(State.ATTACK)
		State.CIRCLE:
			var perpendicular_dir = Vector2(-dir_to_player.y, dir_to_player.x) * circle_direction
			var distance_correction = (distance - 110.0) * 0.5
			var final_dir = (perpendicular_dir + dir_to_player * (distance_correction / 110.0)).normalized()
			velocity = final_dir * 180.0 # Быстрое кружение (было 160)
			
			# Повышаем шанс каста магии или дэша во время кружения (было 0.01 и 0.015)
			if current_special_cooldown <= 0 and randf() < 0.04:
				change_state(State.TELEGRAPH_LINE if randf() > 0.5 else State.TELEGRAPH_BURST)
			elif distance <= attack_range:
				change_state(State.ATTACK)
			elif dash_cooldown.is_stopped() and randf() < 0.04:
				change_state(State.TELEGRAPH_DASH)
				
		State.RETREAT:
			velocity = -dir_to_player * 155.0
			if distance >= 110.0: change_state(State.CIRCLE)
			
		State.TELEGRAPH_LINE:
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
			# Динамически обновляем лазерный прицел на игрока (локальные координаты)
			line_2d.clear_points()
			line_2d.add_point(Vector2.ZERO)
			line_2d.add_point(to_player)
			
		State.TELEGRAPH_DASH, State.DASH, State.ATTACK, State.STUNNED, State.ABILITY_LINE, State.TELEGRAPH_BURST, State.ABILITY_BURST:
			velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)

	move_and_slide()

func change_state(new_state: State) -> void:
	current_state = new_state
	
	match current_state:
		# Босс думает СВЕРХБЫСТРО (было 0.2-0.4)
		State.IDLE: state_timer.start(randf_range(0.05, 0.15))
		
		# Фаза погони стала короче, босс быстрее принимает решения (было 1.0-1.8)
		State.CHASE: state_timer.start(randf_range(0.5, 0.9))
		
		# Время кружения урезано в два раза! Чисто для маневра (было 1.5-2.5)
		State.CIRCLE:
			circle_direction = 1.0 if randf() > 0.5 else -1.0
			state_timer.start(randf_range(0.5, 1.1))
			
		# Отход назад стал мимолетным — чисто разорвать анимацию (было 0.4-0.7)
		State.RETREAT: state_timer.start(randf_range(0.15, 0.3))
		
		State.TELEGRAPH_DASH:
			if player: dash_target_direction = (player.global_position - global_position).normalized()
			state_timer.start(0.1) # Быстрее прыгает
			
		State.DASH:
			dash_cooldown.start(randf_range(1.0, 1.8)) # Дэш откатывается быстрее
			state_timer.start(0.22)
			
		State.ATTACK:
			execute_melee_attack()
			
		State.STUNNED:
			animation_player.stop()
			melee_hitbox.monitoring = false
			line_2d.visible = false
			sprite.modulate = Color.RED
			state_timer.start(0.4) # Стан чуть короче, чтобы босс оставался опасным
			
		# --- СКАСТУЙ ЕСЛИ СМОЖЕШЬ: УРЕЗАЕМ ТЕЛЕГРАФЫ СПОСОБНОСТЕЙ ---
		State.TELEGRAPH_LINE:
			current_special_cooldown = special_cooldown 
			line_2d.visible = true
			line_2d.width = 1.5 
			line_2d.default_color = Color(1.5, 0.4, 0.8, 0.6) 
			state_timer.start(0.45) # В ДВА РАЗА БЫСТРЕЕ! Игроку придется резко уворачиваться (было 0.9)
			
		State.ABILITY_LINE:
			line_2d.width = 7.0 
			line_2d.default_color = Color(2.5, 0.2, 0.6, 1.0) 
			cast_attachment_thread()
			state_timer.start(0.2) 
			
		State.TELEGRAPH_BURST:
			current_special_cooldown = special_cooldown
			var t = create_tween().set_loops(2)
			t.tween_property(sprite, "scale", original_sprite_scale * Vector2(1.2, 0.8), 0.1)
			t.tween_property(sprite, "scale", original_sprite_scale, 0.1)
			sprite.modulate = Color(2.0, 0.5, 0.5) 
			state_timer.start(0.4) # Быстрая пульсация перед взрывом (было 0.6)
			
		State.ABILITY_BURST:
			sprite.modulate = Color.WHITE
			execute_heart_burst()
			state_timer.start(0.5)

func _on_state_timer_timeout() -> void:
	match current_state:
		State.IDLE: 
			change_state(State.CHASE if global_position.distance_to(player.global_position) > 110.0 else State.CIRCLE)
			
		State.CHASE, State.CIRCLE, State.RETREAT:
			# Босс теперь ОЧЕНЬ хочет атаковать. Шанс погони 80%, кружения — всего 20%
			change_state(State.CHASE if randf() < 0.8 else State.CIRCLE)
			
		State.TELEGRAPH_DASH: change_state(State.DASH)
		
		State.DASH, State.ATTACK: 
			# Вместо постоянного RETREAT: 60% шанс сразу продолжить прессовать (CHASE) 
			# и только 40% шанс слегка отойти назад
			if randf() < 0.6:
				change_state(State.CHASE)
			else:
				change_state(State.RETREAT)
				
		State.STUNNED:
			sprite.modulate = Color.WHITE
			change_state(State.CHASE)
			
		State.TELEGRAPH_LINE: change_state(State.ABILITY_LINE)
		State.ABILITY_LINE:
			line_2d.visible = false
			change_state(State.CHASE) # После притягивания нитью — сразу бежит бить лицо!
			
		State.TELEGRAPH_BURST: change_state(State.ABILITY_BURST)
		State.ABILITY_BURST: 
			sprite.scale = original_sprite_scale
			# После взрыва колец сердец босс не убегает, а сразу переключается на преследование
			change_state(State.CHASE)

# Резолв Способности 1: проверка попадания луча через RayCast
func cast_attachment_thread() -> void:
	if not player: return
	
	# Направляем физический RayCast в сторону игрока
	ray_cast.target_position = player.global_position - global_position
	ray_cast.force_raycast_update()
	
	if ray_cast.is_colliding():
		var target = ray_cast.get_collider()
		if target and target.is_in_group("player"):
			print("Нить поймала игрока!")
			if firstskill_audio: firstskill_audio.play() # Используем звук попадания
			
			# Притягиваем игрока прямо к боссу через сочный плавный Tween
			var pull_dir = (global_position - target.global_position).normalized()
			var pull_distance = global_position.distance_to(target.global_position) - 35.0
			
			var pull_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			pull_tween.tween_property(target, "global_position", target.global_position + pull_dir * pull_distance, 0.2)

# Резолв Способности 2: Спавн веера снарядов
# Вспомогательная функция: спавнит ОДНУ волну сердец
func spawn_heart_wave(count: int, angle_offset: float = 0.0) -> void:
	# Воспроизводим звук взмаха/каста для каждой волны
	if sword_combat: 
		sword_combat.pitch_scale = randf_range(0.95, 1.15)
		sword_combat.play()
		
	for i in range(count):
		# Считаем базовый угол распределения + добавляем смещение волны
		var angle = (i * (TAU / count)) + angle_offset
		var dir = Vector2.RIGHT.rotated(angle)
		
		var bullet = projectile_scene.instantiate()
		get_parent().add_child(bullet) 
		bullet.global_position = global_position + dir * 15.0
		
		if bullet.has_method("setup_boss_bullet"):
			bullet.setup_boss_bullet(dir, 15)

# Главная функция способности 2 (теперь она двухволновая и асинхронная)
func execute_heart_burst() -> void:
	if not projectile_scene:
		push_warning("Сцена снаряда босса не назначена в инспекторе!")
		return
		
	# --- ПЕРВАЯ ВОЛНА: 16 сердец ---
	spawn_heart_wave(16, 0.0)
	
	# Ждем паузу между волнами (например, 0.25 секунды)
	await get_tree().create_timer(0.25).timeout
	
	# КРИТИЧЕСКИ ВАЖНАЯ ПРОВЕРКА: 
	# Пока шла пауза 0.25 сек, игрока мог влить в босса стан или убить его.
	# Выпускаем вторую волну только если босс ВСЕ ЕЩЕ находится в состоянии каста способности.
	if current_state == State.ABILITY_BURST:
		# --- ВТОРАЯ ВОЛНА: 8 сердец ---
		# Смещаем угол на половину шага (TAU / 32), чтобы снаряды летели в промежутки первой волны
		spawn_heart_wave(8, TAU / 32)

# --- ОСТАЛЬНОЙ КОД БЛИЖНЕГО БОЯ И УРОНА (БЕЗ ИЗМЕНЕНИЙ) ---
func execute_melee_attack() -> void:
	if not player: return
	var dir = (player.global_position - global_position).normalized()
	melee_hitbox.scale.x = -1.0 if dir.x < 0 else 1.0
	var attack_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	sprite.modulate = Color(1.5, 0.4, 0.8) 
	attack_tween.tween_property(self, "global_position", global_position + dir * 25.0, 0.15)
	if sword_combat:
		sword_combat.pitch_scale = randf_range(0.9, 1.1)
		sword_combat.play()
		boss.play("attack_d")
	animation_player.play("boss_attack_melee")

func _on_attack_finished() -> void:
	sprite.modulate = Color.WHITE
	change_state(State.RETREAT)

func _on_melee_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hit_dir = (body.global_position - global_position).normalized()
		if body.has_method("take_damage"):
			body.take_damage(int(melee_damage), hit_dir)
		if sword_slicing:
			if sword_combat and sword_combat.playing: sword_combat.stop()
			sword_slicing.pitch_scale = randf_range(0.95, 1.05)
			sword_slicing.play()
		boss.play("attack_d")
		var player_sprite = body.get_node_or_null("gg_anime")
		if player_sprite:
			var flash = create_tween()
			player_sprite.modulate = Color.RED * 1.5 
			flash.tween_property(player_sprite, "modulate", Color.WHITE, 0.15)

func take_damage(amount: float) -> void:
	current_health -= amount
	print("Босс Любовь получил урон. HP: ", current_health, "/", max_health)
	GlobalUI.update_health()
	var flash = create_tween()
	sprite.modulate = Color.WHITE * 2.0 
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if current_health <= 180.0 and not ultimate_triggered:
		ultimate_triggered = true
		print("ВНИМАНИЕ: Включается Ультимейт Босса!")
	if current_health <= 0:
		die()

func die() -> void:
	set_process(false)
	set_physics_process(false)
	GlobalUI.hide_boss_health()
	# Безопасно отключаем слои коллизий через set_deferred.
	# В Godot нельзя менять физические слои прямо во время просчета коллизий (внутри зоны),
	# поэтому используем set_deferred — это скажет движку "отключи слои в следующем кадре".
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
