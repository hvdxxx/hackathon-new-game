extends CharacterBody2D

enum State { IDLE, CHASE, CIRCLE, RETREAT, TELEGRAPH_DASH, DASH, ATTACK, STUNNED }
var current_state: State = State.IDLE

@export_category("Boss Stats")
@export var max_health: float = 600.0
@onready var current_health: float = max_health
var ultimate_triggered: bool = false

@onready var boss: AnimatedSprite2D = $AnimatedSprite2D

@export_category("Combat Balance")
@export var melee_damage: float = 20.0
@export var pull_strength: float = 120.0 # Сила рывка игрока к боссу при ударе
@export var attack_range: float = 55.0  # Чуть увеличили радиус для замаха

@export_category("References")
@export var player: CharacterBody2D

var circle_direction: float = 1.0
var dash_target_direction: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_timer: Timer = $StateTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_collision: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var sword_slicing: AudioStreamPlayer2D = $SwordSlicing
@onready var sword_combat: AudioStreamPlayer2D = $SwordCombat

func _ready() -> void:
	if not player:
		# ИСПРАВЛЕНО: ищем группу "player" с маленькой буквы, как у ГГ
		player = get_tree().get_first_node_in_group("player")
	
	# ИСПРАВЛЕНО: аниматор управляет свойством monitoring. 
	# Форму коллизии (disabled) НЕ ТРОГАЕМ, она должна быть всегда включена (false)
	melee_hitbox.monitoring = false
	melee_collision.disabled = false 
	
	# Подключаем попадание по игроку
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	
	dash_cooldown.one_shot = true
	state_timer.one_shot = true
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if not player: return
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	var dir_to_player = to_player.normalized()

	# Управляем направлением хитбокса атаки (разворот влево/вправо)
	if current_state != State.DASH and current_state != State.ATTACK:
		sprite.flip_h = dir_to_player.x < 0
		# Разворачиваем Area2D вслед за игроком
		melee_hitbox.scale.x = -1.0 if dir_to_player.x < 0 else 1.0

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
		State.CHASE:
			velocity = dir_to_player * 130.0
			if distance <= attack_range:
				change_state(State.ATTACK)
			elif distance <= 130:
				change_state(State.CIRCLE)
		State.CIRCLE:
			var perpendicular_dir = Vector2(-dir_to_player.y, dir_to_player.x) * circle_direction
			var distance_correction = (distance - 110.0) * 0.5
			var final_dir = (perpendicular_dir + dir_to_player * (distance_correction / 110.0)).normalized()
			velocity = final_dir * 160.0
			
			if distance <= attack_range:
				change_state(State.ATTACK)
			elif dash_cooldown.is_stopped() and randf() < 0.015:
				change_state(State.TELEGRAPH_DASH)
		State.RETREAT:
			velocity = -dir_to_player * 155.0
			if distance >= 110.0: change_state(State.CIRCLE)
		State.TELEGRAPH_DASH:
			velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
		State.DASH:
			velocity = dash_target_direction * 520.0
			if distance <= attack_range:
				change_state(State.ATTACK)
		State.ATTACK, State.STUNNED:
			# Во время удара тормозим базовое перемещение, работает инерция твина
			velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)

	move_and_slide()

func change_state(new_state: State) -> void:
	current_state = new_state
	
	match current_state:
		State.IDLE: state_timer.start(randf_range(0.2, 0.4))
		State.CHASE: state_timer.start(randf_range(1.0, 1.8))
		State.CIRCLE:
			circle_direction = 1.0 if randf() > 0.5 else -1.0
			state_timer.start(randf_range(1.5, 2.5))
		State.RETREAT: state_timer.start(randf_range(0.4, 0.7))
		State.TELEGRAPH_DASH:
			if player: dash_target_direction = (player.global_position - global_position).normalized()
			state_timer.start(0.12)
		State.DASH:
			dash_cooldown.start(randf_range(1.5, 2.5))
			state_timer.start(0.22)
		State.ATTACK:
			execute_melee_attack()
		State.STUNNED:
			# Прерываем анимацию атаки, если босса застанили Даром Тяжести
			animation_player.stop()
			melee_hitbox.monitoring = false
			sprite.modulate = Color.RED
			state_timer.start(0.5)

func _on_state_timer_timeout() -> void:
	match current_state:
		State.IDLE: change_state(State.CHASE if global_position.distance_to(player.global_position) > 110.0 else State.CIRCLE)
		State.CHASE, State.CIRCLE, State.RETREAT:
			var roll = randf()
			change_state(State.CIRCLE if roll < 0.5 else State.CHASE)
		State.TELEGRAPH_DASH: change_state(State.DASH)
		State.DASH: change_state(State.RETREAT)
		State.STUNNED:
			sprite.modulate = Color.WHITE
			change_state(State.CHASE)

# --- БЛИЖНИЙ БОЙ БОССА: ТЯЖЕЛОЕ ОБЪЯТИЕ ---
func execute_melee_attack() -> void:
	if not player: 
		change_state(State.IDLE)
		return

	var dir = (player.global_position - global_position).normalized()
	melee_hitbox.scale.x = -1.0 if dir.x < 0 else 1.0

	var attack_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	sprite.modulate = Color(1.5, 0.4, 0.8) 
	attack_tween.tween_property(self, "global_position", global_position + dir * 25.0, 0.15)
	
	# === НОВОЕ: Включаем звук взмаха (который SwordCombat) ===
	if sword_combat:
		sword_combat.pitch_scale = randf_range(0.9, 1.1) # Немного меняем тон для разнообразия
		sword_combat.play()
		boss.play("attack_d")
	
	animation_player.play("boss_attack_melee")

# Сигнал окончания анимации атаки (вызывается из AnimationPlayer)
func _on_attack_finished() -> void:
	sprite.modulate = Color.WHITE
	# Тактика Hit-and-Run: ударил и сразу отваливает назад, разрывая дистанцию
	change_state(State.RETREAT)

# Регистрация попадания по Игроку
func _on_melee_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hit_dir = (body.global_position - global_position).normalized()
		
		if body.has_method("take_damage"):
			body.take_damage(int(melee_damage), hit_dir)
			
		# === НОВОЕ: Обработка звуков при попадании ===
		if sword_slicing:
			# Если звук промаха/взмаха всё еще играет, глушим его, чтобы не было каши
			if sword_combat and sword_combat.playing:
				sword_combat.stop()
			
			# Включаем сочный звук разрезания/попадания по игроку
			sword_slicing.pitch_scale = randf_range(0.95, 1.05)
			sword_slicing.play()

		# Визуальный отклик (Juice)
		boss.play("attack_d")
		var player_sprite = body.get_node_or_null("gg_anime")
		if player_sprite:
			var flash = create_tween()
			player_sprite.modulate = Color.RED * 1.5 
			flash.tween_property(player_sprite, "modulate", Color.WHITE, 0.15)
		

# --- СИСТЕМА УРОНА ДЛЯ БОССА ---
func take_damage(amount: float) -> void:
	if current_state == State.STUNNED and amount > 0:
		# Огребает в стане с сочным визуалом
		pass
		
	current_health -= amount
	print("Босс Любовь получил урон. HP: ", current_health, "/", max_health)
	
	# Мигание при получении урона
	var flash = create_tween()
	sprite.modulate = Color.WHITE * 2.0 # Яркая вспышка
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# Проверка фазы Ультимейта (30% HP = 180 ед.)
	if current_health <= 180.0 and not ultimate_triggered:
		ultimate_triggered = true
		# Сюда позже привяжем State.ULTIMATE («Слепая преданность»)
		print("ВНИМАНИЕ: Включается Ультимейт Босса!")
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Первый босс побежден! Демо завершено.")
	queue_free()
