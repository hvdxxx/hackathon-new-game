extends Node2D

@onready var thoughts_label: Label = $Control/MarginContainer/Label
@onready var fade_rect: ColorRect = $Control/ColorRect
@onready var bg: TextureRect = $Background  # всё что на фоне
@onready var player_sprite = $PlayerSprite
@onready var dog1 = $Dog1
@onready var dog2 = $Dog2

func _ready():
	thoughts_label.text = " "
	fade_rect.modulate.a = 1.0
	start_intro_sequence()

func start_intro_sequence():
	await fade(1.0, 0.0, 2.0)  # убираем чёрный экран
	
	await show_thought("Холодно...", 3.0)
	await show_thought("Автобуса всё нет. Уже полчаса жду...", 4.0)
	await show_thought("Опять я одна. Как всегда.", 3.5)
	await show_thought("Может, просто пойти домой 3 км. пешком? Зачем всё это?", 4.0)
	
	#cobaki
	await show_thought("...Ой, бедные. Совсем замёрзли.", 3.0)
	
	await show_thought("На, держите... у меня есть немного печенья.", 3.5)
	
	await show_thought("Они такие радостные... хоть кто-то счастлив.", 4.0)
	
	await show_thought("Эй! Куда вы меня тащите? Стойте!", 3.0)
	await show_thought("...", 2.0)
	await show_thought("А хотя... что вы хотите показать? Ведите.", 4.5)
	
	await fade(0.0, 1.0, 2.0)
	get_tree().change_scene_to_file("res://lock_one.tscn")
	
func show_thought(text: String, time: float) -> void:
	thoughts_label.text = text
	thoughts_label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(thoughts_label, "modulate:a", 1.0, 0.8)
	await tween.finished
	
	await get_tree().create_timer(time).timeout
	
	tween = create_tween()
	tween.tween_property(thoughts_label, "modulate:a", 0.0, 0.7)
	await tween.finished
	await get_tree().create_timer(0.5).timeout  # пауза между мыслями


func fade(from: float, to: float, duration: float):
	fade_rect.modulate.a = from
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", to, duration)
	await tween.finished
	
	# Переход в игру
	#get_tree().change_scene_to_file("res://lock_one.tscn")  # или city_hub
