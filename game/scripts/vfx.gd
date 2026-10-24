extends Node2D
## Efecto visual corto que se borra solo:
## "slash" arco de un golpe, "ring" anillo de impacto en el suelo, "dust" polvo que sale a los lados.

var kind := "slash"
var color := Color(1.0, 0.9, 0.6)
var direction := 1
var size := 1.0
var life := 0.18

var _t := 0.0


static func spawn(parent: Node, at: Vector2, kind: String, color: Color, direction := 1, size := 1.0, life := 0.18) -> void:
	var fx: Node2D = load("res://scripts/vfx.gd").new()
	fx.position = at
	fx.kind = kind
	fx.color = color
	fx.direction = direction
	fx.size = size
	fx.life = life
	fx.z_index = 30  # los efectos siempre encima de los personajes
	parent.add_child(fx)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := _t / life
	var c := color
	c.a = 1.0 - p
	match kind:
		"slash":
			# Arco grueso delante, que se abre y se desvanece.
			var r := 26.0 * size * (0.7 + 0.3 * p)
			var start := -PI * 0.45 if direction > 0 else PI * 0.55
			for i in 3:
				draw_arc(Vector2.ZERO, r - i * 4.0, start, start + PI * 0.9, 16, Color(c, c.a * (1.0 - i * 0.3)), 3.0 - i)
		"ring":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
			draw_arc(Vector2.ZERO, 20.0 + 60.0 * size * p, 0.0, TAU, 32, c, 3.0)
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(0, -6), 18.0 * size * (1.0 - p), Color(1.0, 0.95, 0.85, c.a * 0.7))
		"dust":
			for i in 8:
				var side := -1.0 if i % 2 == 0 else 1.0
				var x := side * (10.0 + 50.0 * size * p) * (0.5 + 0.5 * float(i) / 8.0)
				var y := -4.0 - 14.0 * p * (float(i % 3) / 2.0)
				draw_circle(Vector2(x, y), 3.0 * (1.0 - p) + 1.0, Color(0.55, 0.45, 0.4, c.a * 0.8))
