extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bark_sound: AudioStreamPlayer2D = $BarkDog
@onready var hit_area: Area2D = $HitArea

@export var max_speed: float = 180.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var follow_distance: float = 45.0
@export var dash_speed: float = 450.0
@export var dash_duration: float = 0.45
@export var y_squash: float = 0.5

var player: CharacterBody2D = null

enum State { FOLLOW, DASH, RETURN }
var current_state: State = State.FOLLOW

var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]
var last_direction_index: int = 0

func _ready() -> void:
	find_player()
	
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)


func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	if not player:
		push_warning("Собака не нашла игрока! Убедись, что герой добавлен в группу 'player'")


func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		find_player()
		if not player:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
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
func follow_player(delta: float) -> void:
	var dir = player.global_position - global_position
	var dist = dir.length()
	
	if dist < follow_distance:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		velocity = velocity.move_toward(move_dir * max_speed, acceleration * delta)


func do_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = velocity.move_toward(dash_direction * dash_speed, acceleration * delta * 2)
	
	if dash_timer <= 0:
		start_return()


func return_to_player(delta: float) -> void:
	var dir = player.global_position - global_position
	var dist = dir.length()
	
	if dist < follow_distance + 20:
		current_state = State.FOLLOW
	else:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		velocity = velocity.move_toward(move_dir * max_speed * 1.4, acceleration * delta)


# ==================== ДЭШ ====================
func start_dash(target_global_pos: Vector2) -> void:
	if current_state == State.DASH:
		return
	
	if bark_sound and not bark_sound.playing:
		bark_sound.pitch_scale = randf_range(0.85, 1.15)
		bark_sound.play()
	
	dash_direction = (target_global_pos - global_position).normalized()
	dash_timer = dash_duration
	current_state = State.DASH


func start_return() -> void:
	current_state = State.RETURN


# ==================== УРОН ====================
func _on_hit_area_body_entered(body: Node2D) -> void:
	if current_state != State.DASH:
		return
	
	if body.is_in_group("boss") and body.has_method("take_damage"):
		var hit_dir = (body.global_position - global_position).normalized()
		body.take_damage(120, hit_dir)
		start_return()


# ==================== АНИМАЦИЯ ====================
func update_animation() -> void:
	if velocity.length() > 15:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])
