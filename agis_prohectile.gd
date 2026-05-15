extends Area2D

@export var speed: float = 300.0
@export var lifetime: float = 4.0     # сколько секунд живёт
@export var damage: int = 25

var direction: Vector2 = Vector2.ZERO
var timer: float = 0.0

func _ready():
	# Подключаем сигнал столкновения
	body_entered.connect(_on_body_entered)
	
	# Автоудаление через время
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float):
	if direction != Vector2.ZERO:
		position += direction * speed * delta

# Вызывается из босса при создании снаряда
func setup(new_direction: Vector2, new_speed: float = -1):
	direction = new_direction.normalized()
	if new_speed > 0:
		speed = new_speed
	
	# Поворачиваем спрайт в сторону полёта (для изометрии чуть сложнее)
	rotation = direction.angle()

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Здесь можно нанести урон игроку
		print("Снаряд попал в игрока!")
		queue_free()
	elif body.is_in_group("boss"):  # чтобы не бил самого себя
		pass
	else:
		queue_free()  # уничтожается при любом другом столкновении
