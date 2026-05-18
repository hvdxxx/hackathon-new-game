# global_ui.gd
extends Node

var boss_health_bar: Node = null
var current_boss = null

func show_boss_health(boss_node: Node):
	if boss_health_bar == null:
		boss_health_bar = preload("res://BossUI.tscn").instantiate()
		add_child(boss_health_bar)  # добавляем на глобальный уровень
	
	current_boss = boss_node
	boss_health_bar.visible = true
	update_health()

func hide_boss_health():
	if boss_health_bar:
		# 1. Пробуем скрыть корень (на всякий случай)
		boss_health_bar.visible = false
		
		# 2. Ищем CanvasLayer внутри UI сцены и принудительно тушим его
		var canvas = boss_health_bar.get_node_or_null("CanvasLayer")
		if canvas:
			canvas.visible = false
			
		# 3. На всякий случай ищем сам Control
		var control = boss_health_bar.get_node_or_null("CanvasLayer/Control")
		if control:
			control.visible = false
			
		print("✅ Полноценное скрытие UI вызвано")
		
	current_boss = null

func update_health():
	if not boss_health_bar or not current_boss:
		return
	
	# ИЩЕМ TextureProgressBar
	var progress_bar = boss_health_bar.get_node_or_null("CanvasLayer/Control/TextureProgressBar")
	
	# Если не нашёл — попробуем другие популярные имена
	if progress_bar == null:
		progress_bar = boss_health_bar.get_node_or_null("CanvasLayer/Control/TextureProgressBar")
	if progress_bar == null:
		progress_bar = boss_health_bar.get_node_or_null("HealthBar")
	if progress_bar == null:
		progress_bar = boss_health_bar.get_node_or_null("ProgressBar")
	
	if progress_bar == null:
		print("❌ Не найден TextureProgressBar! Вот что есть в сцене:")
		for child in boss_health_bar.get_children():
			print("   → ", child.name, " (", child.get_class(), ")")
			# проверяем детей второго уровня
			for subchild in child.get_children():
				print("      └─ ", subchild.name, " (", subchild.get_class(), ")")
		return
	
	# Безопасное получение max_health
	var max_hp = current_boss.max_health if "max_health" in current_boss else current_boss.health
	var cur_hp = current_boss.health if "health" in current_boss else 100
	
	progress_bar.max_value = max_hp
	progress_bar.value = cur_hp
	
	print("HP обновлён: ", current_boss.health, " / ", current_boss.max_health)  # для отладки
