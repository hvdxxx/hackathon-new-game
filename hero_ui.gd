extends Node2D

func _ready():
	# Подключаем глобальный сигнал к нашей функции
	GlobalUI.toggle_player_hp_bar.connect(_on_toggle_player_hp_bar)
	
	# По умолчанию прячем бар при старте игры
	visible = false 

func _on_toggle_player_hp_bar(should_show: bool):
	visible = should_show
	
	# Бонус: если хочешь красивое появление через твой AnimationPlayer
	# if should_show:
	#     $AnimationPlayer.play("fade_in")
	# else:
	#     $AnimationPlayer.play("fade_out")
