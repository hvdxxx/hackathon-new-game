extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 320.0
@export var lifetime: float = 4.0
@export var damage: int = 25

var direction: Vector2 = Vector2.ZERO
var timer: float = 0.0

func _ready():
	# Подключаем сигнал
	body_entered.connect(_on_body_entered)
	
	sprite.play("default")
	
	# Автоуничтожение
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float):
	if direction != Vector2.ZERO:
		position += direction * speed * delta

# ====================== ЗАПУСК ИЗ БОССА ======================
func setup(new_direction: Vector2, new_speed: float = -1):
	direction = new_direction.normalized()
	
	if new_speed > 0:
		speed = new_speed
	
	# Поворачиваем спрайт по направлению
	rotation = direction.angle()

# Дополнительно делаем метод launch, чтобы босс тоже мог его использовать
func launch(new_direction: Vector2, _target = null):
	setup(new_direction)

# ====================== СТОЛКНОВЕНИЯ ======================
func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		print("Снаряд попал в игрока!")
		
		if body.has_method("take_damage"):
			body.take_damage(damage)   # ← наносим урон
		
		queue_free()
	
	elif body.is_in_group("boss"):
		pass                      # не взрываемся от босса
	else:
		queue_free()              # стена, дерево и т.д.
