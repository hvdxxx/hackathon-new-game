extends Node2D

@onready var thoughts_label: Label = $Control/MarginContainer/Label
@onready var fade_rect: ColorRect = $Control/ColorRect
@onready var bg: TextureRect = $Background
@onready var dog1 = $Dog1
@onready var dog2 = $Dog2

# Список всех наших реплик по порядку
var intro_phrases: Array[String] = [
	"Это история",
	"Про то как я попал в зомби апокалипсис",
	"Выживал среди зомбаков"
]

var current_phrase_index: int = 0
var is_typing: bool = false
var is_sequence_active: bool = false
var current_tween: Tween

func _ready():
	thoughts_label.text = ""
	thoughts_label.visible_ratio = 0.0
	fade_rect.modulate.a = 1.0
	start_intro_sequence()

func _input(event):
	if event.is_action_pressed("ui_accept"): # Пробел / Enter
		# Если интро еще не началось или финальный экран затухает — игнорируем нажатия
		if not is_sequence_active:
			return
			
		if is_typing:
			# Если текст еще печатается — показываем его мгновенно
			complete_typing()
		else:
			# Если текст уже полностью напечатан — идем к следующему шагу
			advance_sequence()

func start_intro_sequence():
	# Затемнение исчезает
	await fade(1.0, 0.0, 2.0)
	
	# Разрешаем игроку кликать, так как интро началось
	is_sequence_active = true
	
	# Показываем самую первую фразу
	show_current_phrase()

func show_current_phrase():
	# Если фразы закончились — запускаем финал
	if current_phrase_index >= intro_phrases.size():
		end_intro_sequence()
		return
		
	var text_to_show = intro_phrases[current_phrase_index]
	thoughts_label.text = text_to_show
	thoughts_label.visible_ratio = 0.0
	is_typing = true
	
	# Запускаем плавное появление букв
	current_tween = create_tween()
	# Скорость: 0.03 сек на символ
	var duration = text_to_show.length() * 0.03
	current_tween.tween_property(thoughts_label, "visible_ratio", 1.0, duration)
	
	# Когда твин доработает сам, вызываем функцию окончания печати
	current_tween.finished.connect(_on_typing_finished)

func _on_typing_finished():
	is_typing = false

func complete_typing():
	# Если игрок нажал пробел ВО ВРЕМЯ печати
	if current_tween and current_tween.is_running():
		current_tween.kill() # Крах анимации, останавливаем её
	thoughts_label.visible_ratio = 1.0
	is_typing = false

func advance_sequence():
	# Переходим к следующему индексу в массиве и показываем текст
	current_phrase_index += 1
	show_current_phrase()

func end_intro_sequence():
	# Блокируем клики, чтобы игрок не спамил во время финального затухания
	is_sequence_active = false
	
	# Смена фона или показ собак (если нужно, раскомментируй)
	# await change_background("res://assets/backgrounds/bus_stop_night_2.png")
	# await show_dogs()
	
	# Финальный уход в чёрный и смена сцены
	await fade(0.0, 1.0, 2.0)
	get_tree().change_scene_to_file("res://lock_one.tscn")

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (ЗДЕСЬ ВСЁ ХОРОШО) ---

func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished

func change_background(path: String):
	var t = create_tween()
	t.tween_property(bg, "modulate:a", 0.0, 0.5)
	await t.finished
	bg.texture = load(path)
	
	var t2 = create_tween()
	t2.tween_property(bg, "modulate:a", 1.0, 0.5)
	await t2.finished

func show_dogs():
	dog1.show()
	dog2.show()
	var t = create_tween().set_parallel(true)
	t.tween_property(dog1, "modulate:a", 1.0, 1.0).from(0.0)
	t.tween_property(dog2, "modulate:a", 1.0, 1.0).from(0.0)
	await t.finished
