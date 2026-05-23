extends Area2D

@export var speed: float = 320.0
@export var lifetime: float = 1.2
@export var damage: int = 45
@export var spin_speed: float = 14.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var time_alive: float = 0.0
var has_hit: bool = false

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
		return

	position += direction * speed * delta
	rotation += spin_speed * delta

func setup(new_direction: Vector2, new_damage: int = -1, shooter_node: Node2D = null) -> void:
	if new_direction != Vector2.ZERO:
		direction = new_direction.normalized()
	if new_damage > 0:
		damage = new_damage
	shooter = shooter_node
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return
	if area.get_parent() == shooter:
		return
	if area.is_in_group("enemy") or area.is_in_group("boss"):
		_hit_target(area.get_parent())

func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == shooter:
		return
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		_hit_target(body)

func _hit_target(target: Node) -> void:
	if has_hit:
		return
	if target and target.has_method("take_damage"):
		target.take_damage(damage, direction, false)
	has_hit = true
	queue_free()
