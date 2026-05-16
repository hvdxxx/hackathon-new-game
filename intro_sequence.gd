extends Node2D

@onready var thoughts_label: Label = $Control/MarginContainer/Label
@onready var fade_rect: ColorRect = $Control/ColorRect
@onready var bg: TextureRect = $Background
@onready var dog1 = $Dog1
@onready var dog2 = $Dog2

var can_advance = false
var is_typing = false
var current_tween: Tween

func _ready():
	thoughts_label.text = ""
	thoughts_label.visible_ratio = 0.0
	fade_rect.modulate.a = 1.0
	start_intro_sequence()

func _input(event):
	if event.is_action_pressed("ui_accept"): # Пробел / Enter
		if is_typing:
			# Если текст еще печатается — показываем его мгновенно
			complete_typing()
		else:
			# Если текст уже напечатан — разрешаем переход к следующему
			can_advance = true

func start_intro_sequence():
	await fade(1.0, 0.0, 2.0)
	
	# ЭТАП 1
	await typewriter_text("Холодно...")
	await typewriter_text("Автобуса всё нет. Уже полчаса жду...")
	await typewriter_text("Опять я одна. Как всегда.")
	
	# Смена фона
	await change_background("res://assets/backgrounds/bus_stop_night_2.png")
	
	# ЭТАП 2
	#await show_dogs()
	await typewriter_text("...Ой, бедные. Совсем замёрзли.")
	await typewriter_text("На, держите... у меня есть немного печенья.")
	
	# ФИНАЛ
	await fade(0.0, 1.0, 2.0)
	get_tree().change_scene_to_file("res://lock_one.tscn")

func typewriter_text(text: String):
	thoughts_label.text = text
	thoughts_label.visible_ratio = 0.0
	is_typing = true
	can_advance = false
	
	# Скорость печати: 0.05 сек на символ
	current_tween = create_tween()
	current_tween.tween_property(thoughts_label, "visible_ratio", 1.0, text.length() * 0.03)
	
	# Ждем либо окончания анимации, либо клика игрока
	await current_tween.finished
	is_typing = false
	
	# Ждем нажатия для перехода к следующей фразе
	while not can_advance:
		await get_tree().process_frame
	can_advance = false 

func complete_typing():
	if current_tween and current_tween.is_running():
		current_tween.kill() # Останавливаем анимацию
	thoughts_label.visible_ratio = 1.0
	is_typing = false

func fade(from: float, to: float, duration: float):
	var t = create_tween()
	t.tween_property(fade_rect, "modulate:a", to, duration).from(from)
	await t.finished

func change_background(path: String):
	var t = create_tween()
	await t.tween_property(bg, "modulate:a", 0.0, 0.5).finished
	bg.texture = load(path)
	await create_tween().tween_property(bg, "modulate:a", 1.0, 0.5).finished

func show_dogs():
	dog1.show()
	dog2.show()
	var t = create_tween().set_parallel(true)
	t.tween_property(dog1, "modulate:a", 1.0, 1.0).from(0.0)
	t.tween_property(dog2, "modulate:a", 1.0, 1.0).from(0.0)
	await t.finished
