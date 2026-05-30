extends Area2D

@export var my_dialogue: DialogueResource
@export var dialogue_title: String = "campfire"

var is_player_inside: bool = false
var is_dialogue_playing: bool = false 
var player_ref: CharacterBody2D = null 
var onetrick: bool = false

func _input(_event):
	if is_dialogue_playing: 
		return
		
	if is_player_inside and Input.is_action_just_pressed("active"):
		get_viewport().set_input_as_handled() 

func _on_body_entered(body):
	# Исправлено на правильное сравнение 'not onetrick'
	if body.is_in_group("player") and not onetrick:
		onetrick = true
		is_player_inside = true
		player_ref = body
		is_dialogue_playing = true
		
		# ВКЛЮЧАЕМ ХП-БАР ИГРОКА!
		# Передаем ноду игрока (body), чтобы GlobalUI узнал его max_health и текущее health
		GlobalUI.show_player_health(body)
		GlobalUI.hide_boss_health()
		# Запускаем диалог
		await GlobalDialogues.start_dialogue(my_dialogue, dialogue_title)
		
		is_dialogue_playing = false
		
		if player_ref and "can_move" in player_ref:
			player_ref.can_move = true
