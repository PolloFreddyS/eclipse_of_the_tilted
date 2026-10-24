extends Area2D
## Espinas: dañan al Pollito al tocarlas. El golpe lo empuja hacia afuera.

const DAMAGE := 25

var width := 64.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)  # el jugador
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	shape.shape = rect
	shape.position = Vector2(width / 2.0, -4)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(DAMAGE, global_position.x + width / 2.0)


func _draw() -> void:
	var step := 8.0
	var x := 0.0
	while x < width:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + step / 2.0, -10), Vector2(x + step, 0)]), Color("#8e1b26"))
		draw_line(Vector2(x + step / 2.0, -10), Vector2(x + step / 2.0, -6), Color("#f0d58c"), 1.0)
		x += step
