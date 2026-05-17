extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

@export var speed: float = 650.0
@export var lifetime: float = 0.25
@export var damage: int = 45

var direction: Vector2 = Vector2.ZERO
var has_hit: bool = false
var shooter: Node2D = null

func _ready() -> void:

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if sprite:
		sprite.play("default")
	
	# Автоудаление
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO and not has_hit:
		position += direction * speed * delta


# === Основная функция вызова из игрока ===
func setup(dir: Vector2, dmg: int = -1, player_node: Node2D = null) -> void:
	shooter = player_node
	direction = dir.normalized()
	
	if dmg > 0:
		damage = dmg
	
	rotation = direction.angle()
	scale = Vector2(1.4, 0.7)
	
	# Небольшая задержка, чтобы волна не ударила сразу по игроку
	collision.set_deferred("disabled", true)
	await get_tree().create_timer(0.05).timeout
	collision.set_deferred("disabled", false)


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	if body == shooter:
		return
	
	print("Волна ударила: ", body.name, " | Группы: ", body.get_groups())  # ← для отладки
	
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		if body.has_method("take_damage"):
			body.take_damage(damage, direction, false)   # false = без knockback
			print("Урон ", damage, " нанесён по ", body.name)
			has_hit = true
			queue_free()
		else:
			print("У врага нет метода take_damage!")
	else:
		# Если попало во что-то другое
		has_hit = true
		queue_free()
