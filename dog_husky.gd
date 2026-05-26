extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $dog_one_anime
@onready var interaction_area: Area2D = get_node_or_null("HitArea") as Area2D
@onready var button_area: Area2D = $Button/ButtonArea  # ← добавь эту Area2D
@onready var prompt: Sprite2D = $Button

@export var follow_offset: Vector2 = Vector2.ZERO # Смещение относительно игрока
@export var ability_id: StringName = &"wave"
@export var max_speed: float = 180.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var follow_distance: float = 45.0
@export var y_squash: float = 0.5

var player: CharacterBody2D = null
var is_absorbed: bool = false  # Собака сейчас внутри игрока

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]
var last_direction_index: int = 0

var player_in_range = false

signal absorbed  # Сигнал, когда игрок "вобрал" собаку

func update_animation() -> void:
	if velocity.length() > 50:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])

func _ready() -> void:
	find_player()
	Global.dog_one = $dog_one_anime
	
	#if interaction_area:
		#interaction_area.body_entered.connect(_on_hit_area_body_entered)
		#interaction_area.body_exited.connect(_on_hit_area_body_exited)
		
	#if button_area:
		#button_area.body_entered.connect(_on_button_area_body_entered)
		#button_area.body_exited.connect(_on_button_area_body_exited)
		
	if prompt:
		prompt.visible = false

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _physics_process(delta: float) -> void:
	if get_tree().get_first_node_in_group("dialogue_balloon"): 
		velocity = Vector2.ZERO
		# Тут включай анимацию покоя (idle)
		move_and_slide()
		return
	if is_absorbed or not player or not is_instance_valid(player):
		if not player or not is_instance_valid(player):
			find_player()
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	follow_player(delta)
	update_animation()
	move_and_slide()
	global_position = global_position.round()

func follow_player(delta: float) -> void:
	var target_pos = player.global_position + follow_offset
	var dir = target_pos - global_position
	var dist = dir.length()
	
	var desired_velocity = Vector2.ZERO
	var dead_zone = 5.0 # Дистанция, на которой собака полностью останавливается (чтобы не топтаться)
	
	if dist > dead_zone:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		
		# По умолчанию стремимся к максимальной скорости
		var target_speed = max_speed
		
		# Если собака вошла в радиус follow_distance, плавно сбрасываем скорость
		if dist < follow_distance:
			# Вычисляем коэффициент от 0 до 1 (0 - у цели, 1 - на границе follow_distance)
			var slow_factor = (dist - dead_zone) / (follow_distance - dead_zone)
			target_speed = max_speed * slow_factor
			
		desired_velocity = move_dir * target_speed

	# Если нам нужно остановиться (мы в мертвой зоне), используем трение (friction)
	# Иначе используем обычное ускорение (acceleration) для набора/сброса скорости
	var current_accel = acceleration if desired_velocity != Vector2.ZERO else friction
	
	# Плавно интерполируем текущую скорость к желаемой
	velocity = velocity.move_toward(desired_velocity, current_accel * delta)

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.can_absorb_dog = true   # Говорим игроку, что можно нажать E
		body.nearby_dog = self

func _on_hit_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.can_absorb_dog = false
		
func _on_button_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true

func _on_button_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false

# Вызывается из скрипта игрока
func absorb() -> void:
	is_absorbed = true
	hide()                    # делаем невидимой
	set_physics_process(false)
	emit_signal("absorbed")

# Возвращаем собаку
func reappear(new_position: Vector2) -> void:
	global_position = new_position
	is_absorbed = false
	show()
	set_physics_process(true)

# ==================== АНИМАЦИЯ =================
