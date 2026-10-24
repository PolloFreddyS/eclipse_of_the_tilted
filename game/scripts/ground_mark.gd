extends Node2D
## Zona marcada en el suelo: primero avisa (parpadea en rojo), después explota y daña
## al Pollito si sigue dentro. Estilo "blast" para ¡POR AHÍ NO! y "roots" para las Raíces del Tilt.

const BLAST_TIME := 0.25

var radius := 26.0
var warn_time := 0.8
var damage := 25
var style := "blast"

var _t := 0.0
var _blasted := false


func _ready() -> void:
	add_to_group("ground_marks")


func is_warning() -> bool:
	return _t < warn_time


func _process(delta: float) -> void:
	_t += delta
	if _t >= warn_time and not _blasted:
		_blasted = true
		_blast()
	if _t >= warn_time + BLAST_TIME + 0.15:
		queue_free()
	queue_redraw()


func _blast() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and absf(player.global_position.x - global_position.x) <= radius \
			and player.global_position.y > global_position.y - 48.0:
		player.hurt(damage, global_position.x)


func _draw() -> void:
	if _t < warn_time:
		var pulse := 0.3 + 0.4 * absf(sin(_t * 14.0))
		var closing := 1.0 - 0.6 * (_t / warn_time)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, radius, Color(0.56, 0.1, 0.15, pulse * 0.6))
		draw_arc(Vector2.ZERO, radius * closing, 0.0, TAU, 32, Color(0.94, 0.84, 0.55, pulse), 2.0)
		draw_set_transform(Vector2.ZERO)
	elif style == "roots":
		# Espinas oscuras que salen del suelo.
		var p := clampf((_t - warn_time) / BLAST_TIME, 0.0, 1.0)
		var fade := 1.0 - maxf(_t - warn_time - BLAST_TIME, 0.0) / 0.15
		var h := 30.0 * minf(p * 2.0, 1.0)
		for i in 3:
			var x := -radius + radius * i
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x + 1, -h), Vector2(x + 5, 0)]), Color(0.3, 0.04, 0.09, fade))
			draw_line(Vector2(x + 1, -h), Vector2(x + 1, -h + 6), Color(1.0, 0.4, 0.4, fade), 1.0)
	else:
		var p := clampf((_t - warn_time) / BLAST_TIME, 0.0, 1.0)
		var fade := 1.0 - p
		draw_rect(Rect2(-radius, -48.0 * (0.4 + 0.6 * p), radius * 2.0, 48.0 * (0.4 + 0.6 * p)), Color(0.94, 0.84, 0.55, 0.5 * fade))
		draw_circle(Vector2(0, -6), radius * (0.6 + 0.6 * p), Color(0.56, 0.1, 0.15, 0.6 * fade))
