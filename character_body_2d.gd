extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_speed: float = 120.0
@export var run_speed: float = 220.0
@export var acceleration: float = 600.0
@export var friction: float = 1100.0
@export var y_squash: float = 0.5

var health: int = 200
var max_health: int = 200
var dog = null

var walk_anim = ["walk_d", "walk_ds", "walk_s", "walk_sa", "walk_a", "walk_aw", "walk_w", "walk_wd"]
var idle_anim = ["idle_d", "idle_ds", "idle_s", "idle_sa", "idle_a", "idle_aw", "idle_w", "idle_wd"]
var run_anim = ["run_d", "run_ds", "run_s", "run_sa", "run_a", "run_aw", "run_w", "run_wd"]

var last_direction_index: int = 0

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
func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dog and dog.current_state != dog.State.DASH:
			dog.start_dash(get_global_mouse_position())

func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input != Vector2.ZERO:
		var move_dir = Vector2(input.x, input.y * y_squash).normalized()
		var is_running = Input.is_action_pressed("run")
		var current_speed = run_speed if is_running else max_speed
		
		velocity = move_dir * current_speed          # для игрока можно напрямую
		update_animation(is_running)
	else:
		velocity = Vector2.ZERO
		update_animation(false)
	
	move_and_slide()
	global_position = global_position.round()


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
