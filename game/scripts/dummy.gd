extends StaticBody2D
## Muñeco de práctica: cuenta los golpes que recibe.

var hits := 0
var _flash := 0.0


func _ready() -> void:
	add_to_group("dummy")
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 36)
	shape.shape = rect
	shape.position = Vector2(0, -18)
	add_child(shape)


func hit(_from_dir: int) -> void:
	hits += 1
	_flash = 0.15


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var body := Color("#f2ead2") if _flash > 0.0 else Color("#8a6a4a")
	draw_rect(Rect2(-10, -36, 20, 36), body)
	draw_rect(Rect2(-14, -28, 28, 6), body.darkened(0.25))
	draw_rect(Rect2(-3, -32, 2, 2), Color("#10180f"))
	draw_rect(Rect2(3, -32, 2, 2), Color("#10180f"))
