extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 650.0
@export var lifetime: float = 0.25
@export var damage: int = 45

var direction: Vector2 = Vector2.ZERO
var has_hit: bool = false
var shooter: Node2D = null
var time_alive: float = 0.0  # Будем безопасно считать время жизни пули здесь

func _ready() -> void:
	# 1. Подключаем правильный сигнал AREA_ENTERED вместо body_entered.
	# Это позволит пуле находить зону Hurtbox внутри босса.
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	sprite.play("default")

func _physics_process(delta: float) -> void:
	# Безопасный таймер автоудаления без await
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return # Выходим из функции, так как пули больше нет

	# Движение пули
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

# Переименовали в _on_area_entered, так как ловим Hurtbox (Area2D) босса
func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return
		
	# Защита: если пуля коснулась Hurtbox-а того, кто её выпустил (игрока) — игнорируем
	if area.get_parent() == shooter:
		return
	
	print("Волна пересекла зону: ", area.name, " у объекта: ", area.get_parent().name)
	
	# Проверяем группу на самой зоне Hurtbox (как мы настраивали у босса)
	if area.is_in_group("enemy") or area.is_in_group("boss"):
		# Урон наносим родителю зоны (самому боссу CharacterBody2D)
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage) # Без knockback
			print("Урон ", damage, " нанесён по ", target.name)
			has_hit = true
			queue_free() # Удаляем пулю, она выполнила цель
		else:
			print("У объекта ", target.name, " нет метода take_damage!")
