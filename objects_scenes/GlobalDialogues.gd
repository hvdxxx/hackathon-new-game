extends Node

const BALLOON_SCENE = preload("res://DialogueBalloon/balloon.tscn")

# Функция теперь возвращает управление только после того, как дойдёт до конца
func start_dialogue(resource: DialogueResource, title: String = "start") -> void:
	if resource == null:
		push_error("Ресурс диалога пустой!")
		return

	var balloon: Node = BALLOON_SCENE.instantiate()
	get_tree().root.add_child(balloon)
	
	var dogs = get_tree().get_nodes_in_group("dog")
	var player = get_tree().get_first_node_in_group("player")
	
	# Выключаем физику и анимации движения героя и собаки
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)
	for dog in dogs:
		dog.set_physics_process(false)
		
	# Запускаем баллон
	balloon.start(resource, title)
	
	# ЖДЁМ здесь, пока плагин Dialogue Manager закончит работу
	await DialogueManager.dialogue_ended
	
	# Включаем всё обратно
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)
	for dog in dogs:
		dog.set_physics_process(true)
