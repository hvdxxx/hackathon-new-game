extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bark_sound: AudioStreamPlayer2D = $BarkDog

@export var max_speed: float = 180.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var follow_distance: float = 45.0
@export var dash_speed: float = 450.0      # скорость броска
@export var dash_duration: float = 0.45    # сколько секунд летит вперёд
@export var y_squash: float = 0.5

@export var player: Node = null

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]

var last_direction_index: int = 0

# Новые переменные для броска
enum State { FOLLOW, DASH, RETURN }
var current_state: State = State.FOLLOW
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

func _ready():
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			push_warning("Добавь героя в группу 'player'")

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	match current_state:
		State.FOLLOW:
			follow_player(delta)
		State.DASH:
			do_dash(delta)
		State.RETURN:
			return_to_player(delta)
	
	update_animation()
	move_and_slide()
	global_position = global_position.round()

# ==================== СОСТОЯНИЯ ====================

func follow_player(delta: float):
	var dir = player.global_position - global_position
	var dist = dir.length()
	
	if dist < follow_distance:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		velocity = velocity.move_toward(move_dir * max_speed, acceleration * delta)

func do_dash(delta: float):
	dash_timer -= delta
	velocity = velocity.move_toward(dash_direction * dash_speed, acceleration * delta * 2)
	
	if dash_timer <= 0:
		start_return()

func return_to_player(delta: float):
	var dir = player.global_position - global_position
	var dist = dir.length()
	
	if dist < follow_distance + 20:
		current_state = State.FOLLOW
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		velocity = velocity.move_toward(move_dir * max_speed * 1.4, acceleration * delta)  # чуть быстрее при возврате

# ==================== ЗАПУСК БРОСКА ====================

func start_dash(target_global_pos: Vector2):

	if current_state == State.DASH:
		for body in $HitArea.get_overlapping_bodies():   # сделай Area2D с именем HitArea
			if body.is_in_group("boss"):
				var hit_dir = (body.global_position - global_position).normalized()
				body.take_damage(120, hit_dir)   # ← теперь с направлением
				start_return()
				break
	
	# ←←← Воспроизводим лай
	if bark_sound and not bark_sound.playing:
		bark_sound.pitch_scale = randf_range(0.85, 1.15)  # чуть разный тон каждый раз
		bark_sound.play()
	
	dash_direction = (target_global_pos - global_position).normalized()
	dash_timer = dash_duration
	current_state = State.DASH
	
	# Можно добавить звук и эффекты позже

func start_return():
	current_state = State.RETURN

# ==================== АНИМАЦИЯ ====================

func update_animation():
	if velocity.length() > 15:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])
