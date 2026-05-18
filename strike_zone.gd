extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_polygon: Polygon2D = $Polygon2D

@export var damage: float = 25.0
@export var warning_time: float = 0.6

# Переменная, которая скажет зоне: "Пора бить!"
var is_exploding: bool = false

func _ready() -> void:
	# 1. Коллизию ОСТАВЛЯЕМ включенной (disabled = false в инспекторе)
	collision_shape.disabled = false
	
	# 2. Делаем маркер блеклым
	visual_polygon.color.a = 0.2
	
	# 3. Красивое мигание перед ударом
	var tween = create_tween().set_loops(3)
	tween.tween_property(visual_polygon, "color:a", 0.6, warning_time / 6)
	tween.tween_property(visual_polygon, "color:a", 0.2, warning_time / 6)
	
	# 4. Таймер до взрыва
	get_tree().create_timer(warning_time).timeout.connect(execute_strike)

func execute_strike() -> void:
	# Включаем режим взрыва
	is_exploding = true
	
	# Делаем маркер ярко-красным
	visual_polygon.color = Color(1, 0, 0, 0.9)
	
	# Проверяем всех, кто СЕЙЧАС уже стоит внутри зоны
	var bodies = get_overlapping_bodies()
	for body in bodies:
		deal_damage_to_player(body)
			
	# Даем микро-задержку в 0.05 сек, чтобы зацепить игрока, если он влетел в зону в милисекунду взрыва
	get_tree().create_timer(0.05).timeout.connect(func():
		queue_free()
	)

# Вынесли урон в отдельный метод, чтобы не дублировать код
func deal_damage_to_player(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"): # Защита от регистра букв
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("💥 Игрок получил урон от АОЕ: ", damage)

# На случай, если игрок забежал в зону прямо в момент взрыва
func _on_body_entered(body: Node2D) -> void:
	if is_exploding:
		deal_damage_to_player(body)
