extends Area2D

# Используем уникальное имя узла через значок %. 
# Теперь Godot сам найдёт его в дереве, где бы он ни лежал!
@onready var blur_background = $%BlurBackground

var is_player_inside: bool = false
var is_image_open: bool = false
var player_ref: CharacterBody2D = null 

func _ready():
	# Проверяем, нашёл ли движок нашу картинку по уникальному имени
	if blur_background:
		blur_background.visible = false

func _process(_delta):
	if is_player_inside and Input.is_key_pressed(KEY_E):
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
		if is_image_open:
			close_image()
		

func open_image():
	if blur_background:
		blur_background.visible = true
		is_image_open = true
		
		# Блокируем игрока
		if player_ref:
			if "can_move" in player_ref:
				player_ref.can_move = false

func close_image():
	if blur_background:
		blur_background.visible = false
		is_image_open = false
		
		# Разблокируем игрока
		if player_ref and "can_move" in player_ref:
			player_ref.can_move = true
