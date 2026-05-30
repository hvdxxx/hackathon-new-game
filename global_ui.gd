# global_ui.gd
extends Node

# Ссылка на общую сцену интерфейса (бывшая BossUI)
var ui_instance: Node = null

# Ссылки на текущие объекты для обновления данных
var current_boss = null
var current_player = null

# Универсальная функция инициализации интерфейса
func _ensure_ui_loaded():
	if ui_instance == null:
		ui_instance = preload("res://BossUI.tscn").instantiate()
		add_child(ui_instance)

# ====================== ЛОГИКА БОССА (Твой проверенный код) ======================

func show_boss_health(boss_node: Node):
	_ensure_ui_loaded()
	current_boss = boss_node
	
	var canvas = ui_instance.get_node_or_null("CanvasLayer")
	if canvas: canvas.visible = true
	
	var boss_bar = ui_instance.get_node_or_null("CanvasLayer/Control/TextureProgressBar")
	if boss_bar: 
		boss_bar.visible = true
		
		# === НОВОЕ: Динамическая настройка максимального HP ===
		# Проверяем, есть ли вообще у этого босса переменная max_health, чтобы игра не вылетала
		if "max_health" in boss_node:
			boss_bar.max_value = boss_node.max_health
		else:
			# На всякий случай дефолтное значение, если забыли указать в боссе
			boss_bar.max_value = 100.0 
	
	var boss_text = ui_instance.get_node_or_null("CanvasLayer/Control/Label")
	if boss_text: boss_text.visible = true
	
	update_health()

func hide_boss_health():
	if ui_instance:
		var boss_bar = ui_instance.get_node_or_null("CanvasLayer/Control/TextureProgressBar")
		var boss_text = ui_instance.get_node_or_null("CanvasLayer/Control/Label")
		
		if boss_bar: boss_bar.visible = false
		if boss_text: boss_text.visible = false
		
		print("✅ ХП-бар босса скрыт")
	current_boss = null

func update_health():
	if not current_boss or not is_instance_valid(current_boss):
		return
		
	var boss_bar = ui_instance.get_node_or_null("CanvasLayer/Control/TextureProgressBar")
	if boss_bar and "current_health" in current_boss:
		# Устанавливаем текущее здоровье босса на полоску
		boss_bar.value = current_boss.current_health

# ====================== ЛОГИКА ИГРОКА (Новая, точно такая же!) ======================

func show_player_health(player_node: Node):
	_ensure_ui_loaded()
	current_player = player_node
	
	# Делаем видимым сам холст CanvasLayer, если он был выключен
	var canvas = ui_instance.get_node_or_null("CanvasLayer")
	if canvas: canvas.visible = true
	
	# Ищем наш новый созданный в Шаге 1 бар игрока
	var player_bar = ui_instance.get_node_or_null("CanvasLayer/Control/PlayerProgressBar")
	if player_bar:
		player_bar.visible = true
	else:
		print("❌ Ошибка: В BossUI.tscn не найден CanvasLayer/Control/PlayerProgressBar!")
		
	update_player_health()

func hide_player_health():
	if ui_instance:
		var player_bar = ui_instance.get_node_or_null("CanvasLayer/Control/PlayerProgressBar")
		if player_bar: player_bar.visible = false
	current_player = null

func update_player_health():
	if not ui_instance or not current_player: return
	
	var progress_bar = ui_instance.get_node_or_null("CanvasLayer/Control/PlayerProgressBar")
	if progress_bar == null:
		print("❌ Не найден PlayerProgressBar для обновления ХП игрока!")
		return
		
	# Вытаскиваем хп из игрока. 
	# (Подставь имена переменных здоровья твоего игрока, если они отличаются, например hp и max_hp)
	var max_hp = current_player.max_health if "max_health" in current_player else 100
	var cur_hp = current_player.health if "health" in current_player else 100
	
	progress_bar.max_value = max_hp
	progress_bar.value = cur_hp
	print("HP Игрока обновлён: ", cur_hp, " / ", max_hp)
