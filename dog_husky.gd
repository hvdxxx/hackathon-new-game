extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_speed: float = 180.0
@export var acceleration: float = 600.0
@export var friction: float = 1100.0
@export var follow_distance: float = 45.0
@export var y_squash: float = 0.5

@export var player: Node = null

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]

var last_direction_index: int = 0

func _ready():
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
		if not player:
			push_warning("Добавь героя в 'player'")

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	var direction_to_player = player.global_position - global_position
	var distance = direction_to_player.length()
	
	if distance < follow_distance:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		var move_dir = direction_to_player.normalized()
		move_dir = Vector2(move_dir.x, move_dir.y * y_squash).normalized()
		
		velocity = velocity.move_toward(move_dir * max_speed, acceleration * delta)
	
	update_animation()
	move_and_slide()
	global_position = global_position.round()


func update_animation():
	if velocity.length() > 10:
		var angle = velocity.angle()
		var angle_normalized = fposmod(angle, TAU)
		last_direction_index = int(snapped(angle_normalized, TAU / 8) / (TAU / 8)) % 8
		sprite.play(walk_anim[last_direction_index])
	else:
		sprite.play(idle_anim[last_direction_index])
