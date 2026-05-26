extends Area2D

@onready var blur_background = $%BlurBackground
@export var my_dialogue: DialogueResource
@export var dialogue_title: String = "after_znak"

var is_player_inside: bool = false
var is_image_open: bool = false
var is_dialogue_playing: bool = false # Новый флаг-предохранитель
var player_ref: CharacterBody2D = null 

func _ready():
	if blur_background:
		blur_background.visible = false

# Полностью убираем _process! Вместо него используем чистый ввод:
func _input(_event):
	# Если проигрывается диалог — игнорируем любые нажатия на Е
	if is_dialogue_playing: 
		return
		
	# Используем встроенное действие (или замени на Input.is_key_just_pressed(KEY_E))
	if is_player_inside and Input.is_action_just_pressed("active"):
		# Чтобы движок не обрабатывал это нажатие где-то ещё в этот кадр
		get_viewport().set_input_as_handled() 
		
		if not is_image_open:
			open_image()
		else:
			close_image()

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "MainHero":
		is_player_inside = true
		player_ref = body

func _on_body_exited(body):
	if body.is_in_group("player") or body.name == "MainHero":
		is_player_inside = false
		player_ref = null
		# Если игрок сбежал, просто закрываем картинку БЕЗ запуска диалога
		if is_image_open:
			blur_background.visible = false
			is_image_open = false

func open_image():
	if blur_background:
		blur_background.visible = true
		is_image_open = true
		if player_ref and "can_move" in player_ref:
			player_ref.can_move = false

# Делаем функцию асинхронной (через async/await), так как внутри будет диалог
func close_image() -> void:
	if blur_background:
		blur_background.visible = false
		is_image_open = false
		
		# Защита: если забыли перетащить файл диалога в инспектор
		if my_dialogue == null:
			if player_ref and "can_move" in player_ref:
				player_ref.can_move = true
			return
			
		# Включаем режим диалога, чтобы нельзя было спамить кнопку "Е"
		is_dialogue_playing = true
		
		# Запускаем глобальный диалог и ЖДЁМ, пока он полностью закончится
		await GlobalDialogues.start_dialogue(my_dialogue, dialogue_title)
		
		# Диалог завершился! Выключаем режим диалога
		is_dialogue_playing = false
		
		# Возвращаем контроль игроку (хотя глобальный скрипт его тоже включит, для надёжности)
		if player_ref and "can_move" in player_ref:
			player_ref.can_move = true
