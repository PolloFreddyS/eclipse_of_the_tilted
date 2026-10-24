extends Area2D
## Santuario de Discord: al tocarlo cura al Pollito y guarda este punto para reaparecer.

signal activated

var active := false
var _glow := 0.0


func _ready() -> void:
	add_to_group("sanctuary")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)  # el jugador
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 40)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("set_checkpoint"):
		return
	body.set_checkpoint(global_position)
	body.heal_full()
	_glow = 1.0
	if not active:
		active = true
		activated.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	# Piedra con un cristal: apagado en gris, encendido en el azul de Discord.
	draw_rect(Rect2(-14, -6, 28, 6), Color("#3a3036"))
	draw_rect(Rect2(-8, -30, 16, 24), Color("#2a2228"))
	var crystal := Color("#5865f2") if active else Color("#5a5560")
	if _glow > 0.0:
		draw_circle(Vector2(0, -38), 14.0 + 10.0 * _glow, Color(0.35, 0.4, 0.95, 0.25 * _glow))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -48), Vector2(7, -38), Vector2(0, -28), Vector2(-7, -38)]), crystal)
