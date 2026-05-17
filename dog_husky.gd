extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea  # ← добавь эту Area2D

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

signal absorbed  # Сигнал, когда игрок "вобрал" собаку

func update_animation() -> void:
	if velocity.length() > 15:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])

func _ready() -> void:
	find_player()
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_hit_area_body_entered)
		interaction_area.body_exited.connect(_on_hit_area_body_exited)

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _physics_process(delta: float) -> void:
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
	var dir = player.global_position - global_position
	var dist = dir.length()
	
	if dist < follow_distance:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var move_dir = dir.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		velocity = velocity.move_toward(move_dir * max_speed, acceleration * delta)

# ==================== ВЗАИМОДЕЙСТВИЕ ====================
func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.can_absorb_dog = true   # Говорим игроку, что можно нажать E
		body.nearby_dog = self

func _on_hit_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.can_absorb_dog = false

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


func _on_hit_area_body_shape_exited(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	pass # Replace with function body.
