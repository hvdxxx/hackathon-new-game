extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 240.0
var damage: int = 15
var lifetime: float = 2.5 # Чтобы сцена сама удалялась, если улетела за экран

func _ready() -> void:
	# Подключаем сигнал коллизии
	body_entered.connect(_on_body_entered)

func setup_boss_bullet(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	# Разворачиваем спрайт по направлению полета, если картинка имеет направление
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var knockback_dir = direction # Отталкиваем игрока туда, куда летела пуля
		if body.has_method("take_damage"):
			body.take_damage(damage, knockback_dir)
		queue_free() # Удаляем снаряд после попадания
