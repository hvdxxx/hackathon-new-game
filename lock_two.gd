extends Node2D

@export var my_dialogue: DialogueResource
@export var dialogue_title: String = "lock_two"

@onready var player_ref: CharacterBody2D = $MainHero
@onready var boss_ref: CharacterBody2D = $First_boss
# Called when the node enters the scene tree for the first time.

@onready var fade_rect: ColorRect = $Control/ColorRect
# Called when the node enters the scene tree for the first time.
var is_dialogue_playing: bool


func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished

func _ready() -> void:
	GlobalUI.show_player_health(player_ref)
	GlobalUI.hide_boss_health()
	if boss_ref.has_method("set_physics_process"):
		boss_ref.set_physics_process(false)
	await fade(1.0, 0.0, 2.0)
	is_dialogue_playing = true
		
		# Запускаем глобальный диалог и ЖДЁМ, пока он полностью закончится
	GlobalDialogues.start_dialogue(my_dialogue, dialogue_title)
		
		# Диалог завершился! Выключаем режим диалога
	is_dialogue_playing = false
