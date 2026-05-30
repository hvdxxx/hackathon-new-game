extends Area2D

# Ссылка на узел босса на сцене (выбирается в инспекторе)
@export var boss: CharacterBody2D

@onready var scr = preload("res://first_boss_final.gd")

# Чтобы триггер сработал только ОДИН раз
var _is_activated: bool = false

func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что вошел именно игрок и босс еще не активен
	# Предполагается, что у игрока есть имя "Player" или он в группе "player"
	if not _is_activated and body.is_in_group("player"):
		_is_activated = true
		
		print("ascassaas")
		GlobalUI.show_boss_health(boss)
		if boss.has_method("set_physics_process"):
			boss.set_physics_process(true)
		
		if boss and boss.has_method("start_boss_fight"):
			boss.start_boss_fight(body)
		
		# Опционально: выключаем мониторинг триггера, чтобы не тратить ресурсы
		set_deferred("monitoring", false)
		
		# Здесь можно вызвать метод закрытия дверей арены, если они есть
		# _close_arena_doors()
