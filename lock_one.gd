extends Node2D

@export var dialogue_resource: DialogueResource

@onready var fade_rect: ColorRect = $Control/ColorRect

const Balloon = preload("res://DialogueBalloon/balloon.tscn")

@onready var main_hero: AnimatedSprite2D = $MainHero/gg_anime
@onready var dog_one: AnimatedSprite2D = $LittleDog_one/dog_one_anime
@onready var dog_two: AnimatedSprite2D = $LittleDog_two/dog_two_anime

func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished

func _ready():
	main_hero.play("idle_sa")
	
	# 1. Находим игрока и собак
	var dogs = get_tree().get_nodes_in_group("dog")
	var player = get_tree().get_first_node_in_group("player")
	
	# 2. Выключаем управление перед сценой
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)
	for dog in dogs:
		dog.set_physics_process(false)
		
	# 3. Ждем окончания эффекта появления (fade)
	await fade(1.0, 0.0, 2.0)
	
	# 4. Создаем и показываем диалог
	var balloon: Node = Balloon.instantiate()
	get_tree().current_scene.add_child(balloon)
	DialogueManager.show_dialogue_balloon(dialogue_resource, "start")
	
	# 5. МАГИЯ: Говорим коду ЖДАТЬ, пока DialogueManager не подаст сигнал "диалог окончен"
	await DialogueManager.dialogue_ended
	
	# 6. Только ТЕПЕРЬ, когда диалог закрылся, возвращаем управление
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)
	for dog in dogs:
		dog.set_physics_process(true) # Собаке тоже возвращаем физику!

func dogs_eating():
	var dogs = get_tree().get_nodes_in_group("dog")
	var player = get_tree().get_first_node_in_group("player")
	#================CONTROL_OFF======================
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	for dog in dogs:
		dog.set_physics_process(false)
	#================CONTROL_OFF======================
	var escape_tween = create_tween().set_parallel(true)
	var exit_position = Vector2(140, 210)
	dog_one.play("walk_ds")
	dog_two.play("walk_ds")
	for dog in dogs:
		var dog_offset = Vector2(randf_range(-40, 40), randf_range(-20, 20))
		escape_tween.tween_property(dog, "global_position", exit_position + dog_offset, 3.0)
		
	escape_tween.chain().tween_callback(func():
		dog_one.play("idle_wd")
		dog_two.play("idle_wd")
	)
	
func start_epic_escape():
	var player = get_tree().get_first_node_in_group("player")
	var dogs = get_tree().get_nodes_in_group("dog")
	
	if not player or dogs.is_empty():
		push_error("нету игрока или собаки")
		change_to_hub()
		return

	# Отключаем управление игроку, чтобы во время уноса в закат он не нажимал WASD
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)

	# Выключаем скрипт собак, чтобы они перестали просто ходить за ГГ, 
	# и мы могли утащить их Твином за экран вместе с игроком
	for dog in dogs:
		dog.set_physics_process(false)

	# Создаем Твин для эпичного побега
	var escape_tween = create_tween().set_parallel(true)
	
	# Точка за экраном (в изометрии вправо-вверх улетают)
	var exit_position = player.global_position + Vector2(550, 500) 
	
	# Уносим Аллаха
	escape_tween.tween_property(player, "global_position", exit_position, 3.0)
	
	# Уносим собак рядышком
	for dog in dogs:
		var dog_offset = Vector2(randf_range(-40, 40), randf_range(-20, 20))
		escape_tween.tween_property(dog, "global_position", exit_position + dog_offset, 3.0)
	
	main_hero.play("run_ds")
	dog_one.play("walk_ds")
	dog_two.play("walk_ds")
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)

func change_to_hub():
	print("Переходим в хаб!")
	await fade(0.0, 1.0, 2.0)
	get_tree().change_scene_to_file("res://hub_one.tscn")
