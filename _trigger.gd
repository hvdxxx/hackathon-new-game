extends Area2D

# Ссылки на узлы интерфейса. 
# В кавычках укажи ПРАВИЛЬНЫЙ путь до твоего CanvasLayer на сцене.
# Самый простой способ получить путь: зажми Ctrl и перетащи узел UI из дерева в этот скрипт.
@onready var blur_background = $UI/BlurBackground

var is_player_inside: bool = false
var is_image_open: bool = false
var player_ref: CharacterBody2D = null # Тут сохраним ссылку на игрока, когда он зайдёт

func _ready():
	# На всякий случай проверяем, что при старте всё скрыто
	print("--- Скрипт Area2D успешно запустился в игре! ---")
	if blur_background:
		blur_background.visible = false

func _process(_delta):
	# Если игрок внутри зоны и нажимает кнопку "Е" (в Godot по умолчанию "ui_accept" привязана к Enter/Space, 
	# но если ты настроил "E" в Настройках проекта -> Список действий, укажи своё название)
	if is_player_inside and Input.is_action_just_pressed("active"):
		print("я сработал, я показал картинку")
		if not is_image_open:
			open_image()
		else:
			close_image()
	if Input.is_action_just_pressed("active"):
		print("Движок поймал нажатие кнопки 'active'!")

# Сигнал: кто-то зашёл в зону
func _on_body_entered(body):
	print("В зону вошёл объект: ", body.name) # Вот этот принт покажет правду в дебаггер!
	if body.is_in_group("player"):
		is_player_inside = true
		player_ref = body

# Сигнал: кто-то вышел из зоны
func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_inside = false
		player_ref = null
		# Если игрок умудрился выйти (например, его оттолкнул босс), закрываем картинку
		if is_image_open:
			close_image()

func open_image():
	if blur_background and player_ref:
		blur_background.visible = true
		is_image_open = true
		player_ref.can_move = false # Выключаем движение игроку

func close_image():
	if blur_background and player_ref:
		blur_background.visible = false
		is_image_open = false
		player_ref.can_move = true # Возвращаем движение игроку
