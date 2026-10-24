extends Node2D
## Onda de la Democión Maldita: recorre el suelo hasta la pared. Si toca al Pollito
## mientras está en el suelo, le hace daño; hay que saltarla.

const SPEED := 190.0
const HEIGHT := 16.0
const DAMAGE := 25
const LIFE := 3.0

var direction := 1
var _t := 0.0


func _ready() -> void:
	add_to_group("shockwaves")


func _physics_process(delta: float) -> void:
	_t += delta
	position.x += direction * SPEED * delta
	var player := get_tree().get_first_node_in_group("player")
	if player and absf(player.global_position.x - global_position.x) < 10.0 \
			and player.global_position.y > global_position.y - HEIGHT:
		player.hurt(DAMAGE, global_position.x - direction * 20.0)
	if _t > LIFE or position.x < 0.0 or position.x > get_parent().room_size.x:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Llama roja con núcleo claro y estela: tiene que verse bien sobre el fondo oscuro.
	var flicker := 0.75 + 0.25 * sin(_t * 30.0)
	for i in 3:
		var back := -direction * (14.0 + i * 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(back - 6.0, 0), Vector2(back, -HEIGHT * (0.6 - i * 0.15)), Vector2(back + 6.0, 0)]), Color(0.8, 0.1, 0.15, 0.35 - i * 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-direction * 12.0, 0), Vector2(direction * 4.0, -HEIGHT - 4.0), Vector2(direction * 12.0, 0)]), Color(0.9, 0.12, 0.18, flicker))
	draw_colored_polygon(PackedVector2Array([Vector2(-direction * 5.0, 0), Vector2(direction * 2.0, -HEIGHT + 4.0), Vector2(direction * 6.0, 0)]), Color(1.0, 0.75, 0.55, flicker))
