extends Camera2D

# Отступ от краев экрана в пикселях, чтобы карта не прилипала к границам
@export var margin: float = 50.0

func _ready() -> void:
	# 1. Ждем один кадр, чтобы все узлы и Viewport успели инициализироваться
	await get_tree().process_frame
	
	# 2. Ищем тайлмап по точному имени из твоей сцены
	var tilemap = get_tree().root.find_child("MainTile", true, false)
	
	if tilemap:
		var map_rect = tilemap.get_used_rect()
		var cell_size = tilemap.tile_set.tile_size
		
		# Вычисляем размер всей карты в пикселях
		var map_width_px = map_rect.size.x * cell_size.x
		var map_height_px = map_rect.size.y * cell_size.y
		
		# Получаем размер окна игры (экрана)
		var screen_size = get_viewport().get_visible_rect().size
		
		# Рассчитываем необходимый зум для ширины и высоты отдельно
		# (Добавляем margin * 2, чтобы отступы были с обеих сторон)
		var zoom_x = screen_size.x / (map_width_px + (margin * 2))
		var zoom_y = screen_size.y / (map_height_px + (margin * 2))
		
		# Выбираем минимальный зум, чтобы вся карта влезла и по ширине, и по высоте
		var final_zoom = min(zoom_x, zoom_y)
		
		# Применяем зум к камере
		zoom = Vector2(final_zoom, final_zoom)
		
		# Устанавливаем лимиты, чтобы камера не уезжала за пределы
		limit_left = map_rect.position.x * cell_size.x
		limit_right = map_rect.end.x * cell_size.x
		limit_top = map_rect.position.y * cell_size.y
		limit_bottom = map_rect.end.y * cell_size.y
		
		# Центрируем камеру на центр тайлмапа, если игрок еще не сдвинулся
		position = Vector2(
			(map_rect.position.x + map_rect.size.x / 2.0) * cell_size.x,
			(map_rect.position.y + map_rect.size.y / 2.0) * cell_size.y
		)
	else:
		print("Тайлмап MainTile не найден!")
