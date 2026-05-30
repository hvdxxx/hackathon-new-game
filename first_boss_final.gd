extends CharacterBody2D

# Расширяем стейт-машину состояниями ультимейта
enum State { 
	IDLE, CHASE, CIRCLE, RETREAT, 
	TELEGRAPH_DASH, DASH, ATTACK, STUNNED,
	TELEGRAPH_LINE, ABILITY_LINE,     # Способность 1
	TELEGRAPH_BURST, ABILITY_BURST,    # Способность 2
	TELEGRAPH_ULTIMATE, ABILITY_ULTIMATE # Ультимейт
}
var current_state: State = State.IDLE

@export_category("Boss Stats")
@export var max_health: float = 600.0
@onready var current_health: float = max_health
var ultimate_triggered: bool = false

# Технический флаг для определения клона
@export var is_clone: bool = false 

@export_category("Combat Balance")
@export var melee_damage: float = 20.0
@export var line_damage: float = 35.0      # Баланс: Урон от нити
@export var burst_damage: float = 10.0     # Баланс: Урон от одного сердца
@export var ultimate_damage: float = 45.0  # Баланс: Урон от ультимейта (для клонов/фоллбека)
@export var pull_strength: float = 120.0 
@export var attack_range: float = 55.0  
@export var special_cooldown: float = 4.0  # Раз в сколько секунд босс может юзать скиллы

@export_category("Prefabs")
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

var is_dying: bool = false

func _ready() -> void:
	# 1. ОБЩАЯ ИНИЦИАЛИЗАЦИЯ ДЛЯ ВСЕХ (Оригинал + Клоны)
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if sprite:
		original_sprite_scale = sprite.scale 
		
	# ФИКС: Подключаем обработку урона хитбокса ДО выхода клона из функции!
	if melee_hitbox and not melee_hitbox.body_entered.is_connected(_on_melee_hitbox_body_entered):
		melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	
	if melee_collision:
		melee_collision.disabled = false

	state_timer.one_shot = true
	if not state_timer.timeout.is_connected(_on_state_timer_timeout):
		state_timer.timeout.connect(_on_state_timer_timeout)
		
	# === ЛОГИКА ПОВЕДЕНИЯ КЛОНА ===
	if is_clone:
		add_to_group("boss_clones")
		max_health = 1.0
		current_health = 1.0
		melee_hitbox.monitoring = true # Клоны сразу активно ищут цель для тарана
		change_state(State.ABILITY_ULTIMATE)
		return
		
	# === ЛОГИКА ТОЛЬКО НАСТОЯЩЕГО БОССА ===
	add_to_group("main_boss")
	
	melee_hitbox.monitoring = false
	line_2d.visible = false
	ray_cast.enabled = false 
	dash_cooldown.one_shot = true
	
	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if not player: return
	
	# Уменьшаем кулдаун способностей (только для настоящего босса)
	if not is_clone and current_special_cooldown > 0 and current_state != State.ABILITY_ULTIMATE:
		current_special_cooldown -= delta
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	var dir_to_player = to_player.normalized()

	# Поворот спрайта и хитбокса
	if current_state != State.DASH and current_state != State.ATTACK and current_state != State.ABILITY_LINE:
		sprite.flip_h = dir_to_player.x < 0
		melee_hitbox.scale.x = -1.0 if dir_to_player.x < 0 else 1.0

	# === ФИЗИКА КЛОНА (Таранный полет НА игрока) ===
	if is_clone:
		velocity = dir_to_player * 220.0
		move_and_slide()
		return

	# === ФИЗИКА НАСТОЯЩЕГО БОССА ===
	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
		State.CHASE:
			velocity = dir_to_player * 190.0 
			
			
			
			if current_special_cooldown <= 0 and randf() < 0.02:
				change_state(State.TELEGRAPH_LINE if randf() > 0.5 else State.TELEGRAPH_BURST)
			elif distance <= attack_range:
				change_state(State.ATTACK)
		State.CIRCLE:
			var perpendicular_dir = Vector2(-dir_to_player.y, dir_to_player.x) * circle_direction
			var distance_correction = (distance - 110.0) * 1.5
			var final_dir = (perpendicular_dir + dir_to_player * (distance_correction / 110.0)).normalized()
			velocity = final_dir * 180.0 
			
			if current_special_cooldown <= 0 and randf() < 0.04:
				change_state(State.TELEGRAPH_LINE if randf() > 0.5 else State.TELEGRAPH_BURST)
			elif distance <= attack_range:
				change_state(State.ATTACK)
			elif dash_cooldown.is_stopped() and randf() < 0.04:
				change_state(State.TELEGRAPH_DASH)
				
		State.RETREAT:
			velocity = -dir_to_player * 220.0
			if distance >= 130.0: change_state(State.CIRCLE)
			
		State.TELEGRAPH_LINE:
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
			line_2d.clear_points()
			line_2d.add_point(Vector2.ZERO)
			line_2d.add_point(to_player)
			
		State.ABILITY_ULTIMATE:
			# ИЗМЕНЕНИЕ: Настоящий босс во время ульты УБЕГАЕТ от игрока в темноту!
			velocity = -dir_to_player * 120.0
			
		State.TELEGRAPH_DASH, State.DASH, State.ATTACK, State.STUNNED, State.ABILITY_LINE, State.TELEGRAPH_BURST, State.ABILITY_BURST, State.TELEGRAPH_ULTIMATE:
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)

	move_and_slide()

func change_state(new_state: State) -> void:
	current_state = new_state
	
	match current_state:
		State.IDLE: state_timer.start(randf_range(0.1, 0.15))
		State.CHASE: state_timer.start(randf_range(0.9, 1.5))
		State.CIRCLE:
			circle_direction = 1.0 if randf() > 0.5 else -1.0
			state_timer.start(randf_range(0.5, 1.1))
		State.RETREAT: state_timer.start(randf_range(0.15, 0.3))
		
		State.TELEGRAPH_DASH:
			if player: dash_target_direction = (player.global_position - global_position).normalized()
			state_timer.start(0.1) 
			
		State.DASH:
			dash_cooldown.start(randf_range(1.0, 1.8)) 
			state_timer.start(0.22)
			
		State.ATTACK:
			execute_melee_attack()
			
		State.STUNNED:
			if is_clone: return
			animation_player.stop()
			melee_hitbox.monitoring = false
			line_2d.visible = false
			sprite.modulate = Color.RED
			state_timer.start(0.4) 
			
		State.TELEGRAPH_LINE:
			current_special_cooldown = special_cooldown 
			line_2d.visible = true
			line_2d.width = 1.5 
			line_2d.default_color = Color(1.5, 0.4, 0.8, 0.6) 
			state_timer.start(0.45) 
			
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
			state_timer.start(0.4) 
			
		State.ABILITY_BURST:
			sprite.modulate = Color.WHITE
			execute_heart_burst()
			state_timer.start(0.5)
			
		# --- РЕАЛИЗАЦИЯ УЛЬТИМЕЙТА ---
		State.TELEGRAPH_ULTIMATE:
			var ambient = get_tree().get_first_node_in_group("map_light")
			if ambient and ambient is CanvasModulate:
				var lt = create_tween()
				lt.tween_property(ambient, "color", Color(0.03, 0.01, 0.06), 0.5)
			
			sprite.modulate = Color(3.5, 0.5, 2.0)
			state_timer.start(1.2) 
			
		State.ABILITY_ULTIMATE:
			# ИЗМЕНЕНИЕ: Разделяем логику хитбоксов оригинала и копий, убираем бесконечный спавн
			if not is_clone:
				melee_hitbox.monitoring = false # Настоящий босс НЕ пытается наносить урон в ульте
				spawn_ultimate_clones() # Спавнит слуг только ОРИГИНАЛ
			else:
				melee_hitbox.monitoring = true # Копии как раз включают урон тарана
				
			state_timer.start(2.5) # Время действия ульты (после чего свет включится обратно)

func _on_state_timer_timeout() -> void:
	match current_state:
		State.IDLE: 
			change_state(State.CHASE if global_position.distance_to(player.global_position) > 110.0 else State.CIRCLE)
		State.CHASE, State.CIRCLE, State.RETREAT:
			change_state(State.CHASE if randf() < 0.8 else State.CIRCLE)
		State.TELEGRAPH_DASH: change_state(State.DASH)
		State.DASH, State.ATTACK: 
			change_state(State.CHASE if randf() < 0.6 else State.RETREAT)
		State.STUNNED:
			sprite.modulate = Color.WHITE
			change_state(State.CHASE)
		State.TELEGRAPH_LINE: change_state(State.ABILITY_LINE)
		State.ABILITY_LINE:
			line_2d.visible = false
			change_state(State.CHASE) 
		State.TELEGRAPH_BURST: change_state(State.ABILITY_BURST)
		State.ABILITY_BURST: 
			sprite.scale = original_sprite_scale
			change_state(State.CHASE)
			
		State.TELEGRAPH_ULTIMATE: change_state(State.ABILITY_ULTIMATE)
		State.ABILITY_ULTIMATE: end_ultimate()

# Способность 1: Нити привязанности
func cast_attachment_thread() -> void:
	if not player: return
	ray_cast.target_position = player.global_position - global_position
	ray_cast.force_raycast_update()
	
	if ray_cast.is_colliding():
		var target = ray_cast.get_collider()
		if target and target.is_in_group("player"):
			print("Нить поймала игрока!")
			if firstskill_audio: firstskill_audio.play()
			
			var pull_dir = (global_position - target.global_position).normalized()
			
			if target.has_method("take_damage"):
				target.take_damage(int(line_damage), pull_dir)
				
			var pull_distance = global_position.distance_to(target.global_position) - 35.0
			var pull_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			pull_tween.tween_property(target, "global_position", target.global_position + pull_dir * pull_distance, 0.7)

# Способность 2: Заботливая иллюзия
func spawn_heart_wave(count: int, angle_offset: float = 0.0) -> void:
	if sword_combat: 
		sword_combat.pitch_scale = randf_range(0.95, 1.15)
		sword_combat.play()
		
	for i in range(count):
		var angle = (i * (TAU / count)) + angle_offset
		var dir = Vector2.RIGHT.rotated(angle)
		
		var bullet = projectile_scene.instantiate()
		get_parent().add_child(bullet) 
		bullet.global_position = global_position + dir * 15.0
		
		if bullet.has_method("setup_boss_bullet"):
			bullet.setup_boss_bullet(dir, int(burst_damage))

func execute_heart_burst() -> void:
	if not projectile_scene:
		push_warning("Сцена снаряда босса не назначена в инспекторе!")
		return
		
	spawn_heart_wave(16, 0.0)
	await get_tree().create_timer(0.25).timeout
	
	if current_state == State.ABILITY_BURST:
		spawn_heart_wave(8, TAU / 32)

# Механика ультимейта: спавн 4 точек вокруг игрока крестом
func spawn_ultimate_clones() -> void:
	if not player: return
	if sword_combat: sword_combat.play()
	
	var distance_from_player = 230.0
	var spawn_points = [
		player.global_position + Vector2.UP * distance_from_player,
		player.global_position + Vector2.DOWN * distance_from_player,
		player.global_position + Vector2.LEFT * distance_from_player,
		player.global_position + Vector2.RIGHT * distance_from_player
	]
	spawn_points.shuffle()
	
	# 1. Перемещаем оригинал на случайную точку
	global_position = spawn_points[0]
	
	# 2. На оставшиеся 3 точки спавним атакующих клонов
	var boss_scene = load(scene_file_path)
	if boss_scene:
		for i in range(1, 4):
			var clone = boss_scene.instantiate()
			clone.is_clone = true
			get_parent().add_child(clone)
			clone.global_position = spawn_points[i]
			clone.get_node("AnimatedSprite2D").modulate = Color(3.5, 0.5, 2.0)

# Завершение ультимейта
func end_ultimate() -> void:
	if is_clone: return
	
	var ambient = get_tree().get_first_node_in_group("map_light")
	if ambient and ambient is CanvasModulate:
		var lt = create_tween()
		lt.tween_property(ambient, "color", '3b3b70', 0.4)
		
	sprite.modulate = "3b3b70"
	melee_hitbox.monitoring = false
	
	for node in get_tree().get_nodes_in_group("boss_clones"):
		if node != self and node.has_method("explode_clone"):
			node.explode_clone()
			
	change_state(State.RETREAT)

# Исчезновение фейка
func explode_clone() -> void:
	if is_dying: return # Если уже умирает, игнорируем повторный вызов
	is_dying = true
	
	# Отключаем коллизии самого клона, чтобы он перестал толкаться/касаться
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if melee_hitbox:
		melee_hitbox.set_deferred("monitoring", false)

	var t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "scale", Vector2.ZERO, 0.12)
	t.tween_callback(queue_free)

# --- БЛИЖНИЙ БОЙ И РЕГИСТРАЦИЯ ХИТБОКСА ---
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
		# Если это клон — он наносит урон и лопается!
		if is_clone:
			if is_dying: return # ФИКС: Если клон уже взрывается, урон не наносим!
	
			var hit_dir = (body.global_position - global_position).normalized()
			if body.has_method("take_damage"):
				body.take_damage(int(ultimate_damage), hit_dir)
			explode_clone()
			return
			
		# Обычный ближний бой оригинала вне ультимейта
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

# --- СИСТЕМА ПОЛУЧЕНИЯ УРОНА БОССОМ ---
func take_damage(amount: float) -> void:
	if is_clone:
		explode_clone()
		return
		
	current_health -= amount
	print("Босс Любовь получил урон. HP: ", current_health, "/", max_health)
	GlobalUI.update_health()
	
	var flash = create_tween()
	sprite.modulate = Color.WHITE * 2.0 
	var return_color = Color(3.5, 0.5, 2.0) if current_state == State.ABILITY_ULTIMATE else Color.WHITE
	flash.tween_property(sprite, "modulate", return_color, 0.1)
	
	if current_health <= 400.0 and not ultimate_triggered:
		ultimate_triggered = true
		print("ВНИМАНИЕ: Запуск ультимейта «Слепая преданность»!")
		change_state(State.TELEGRAPH_ULTIMATE)
		return 
		
	if current_health <= 0:
		die()

func die() -> void:
	var ambient = get_tree().get_first_node_in_group("map_light")
	if ambient and ambient is CanvasModulate:
		ambient.color = Color.WHITE
		
	set_process(false)
	set_physics_process(false)
	GlobalUI.hide_boss_health()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
