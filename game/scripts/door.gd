extends Area2D
## Puerta a otra sala: al entrar el Pollito, se carga la escena de destino.

var target_scene := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)  # el jugador
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 48)
	shape.shape = rect
	shape.position = Vector2(0, -24)
	add_child(shape)
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			get_tree().change_scene_to_file.call_deferred(target_scene))


func _draw() -> void:
	draw_rect(Rect2(-10, -52, 20, 52), Color("#1c1420"))
	draw_rect(Rect2(-10, -52, 20, 52), Color("#c9a24a"), false, 1.0)
	draw_rect(Rect2(-6, -46, 12, 46), Color("#3d0c13"))
