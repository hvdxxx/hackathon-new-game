extends Node2D

# Наш аудио-арсенал
@onready var play_sound: AudioStreamPlayer2D = $select_play
@onready var others_sound: AudioStreamPlayer2D = $select_others
@onready var scr: AudioStreamPlayer2D = $scrolling

func _ready() -> void:
	# Нам пока не нужен старт, метод чистый
	pass

# Вспомогательные функции для воспроизведения
func play_audio() -> void:
	if play_sound:
		play_sound.play()
		print("ura allah")
		
func others_audio() -> void:
	if others_sound:
		others_sound.play()
		print("boom")
		
func play_scroling_sound() -> void:
	if scr:
		scr.play()
		print("hover") # Изменил текст, чтобы ты в консоли отличал клик от наведения

# --- СИГНАЛЫ КЛИКОВ (Button.pressed) ---

func _on_play_pressed() -> void:
	play_audio()
	get_tree().change_scene_to_file("res://intro_sequence.tscn")

func _on_exit_pressed() -> void:
	others_audio()
	get_tree().quit()

func _on_button_pressed() -> void: # Если добавишь кнопку настроек
	others_audio()

# --- СИГНАЛЫ НАВЕДЕНИЯ (Button.mouse_entered) ---
# Теперь они цепляются напрямую к кнопкам, без физических зон!

func _on_play_mouse_entered() -> void:
	play_scroling_sound()

func _on_button_mouse_entered() -> void:
	play_scroling_sound()

func _on_exit_mouse_entered() -> void:
	play_scroling_sound()

# --- СИГНАЛЫ ЗАВЕРШЕНИЯ ЗВУКА (AudioStreamPlayer2D.finished) ---
# Твоё отличное решение: ждём конца звука, а потом меняем сцену или выходим

#func _on_select_play_finished() -> void:
	#get_tree().change_scene_to_file("res://intro_sequence.tscn")

#func _on_select_others_finished() -> void:
	#get_tree().quit()
