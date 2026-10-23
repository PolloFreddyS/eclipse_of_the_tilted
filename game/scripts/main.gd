extends Node2D
## Prueba técnica: una sala con plataformas, un muñeco de práctica, la cámara
## siguiendo al pollito y los controles táctiles encima.

const Player := preload("res://scripts/player.gd")
const Dummy := preload("res://scripts/dummy.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")

const ROOM_SIZE := Vector2(1280, 360)
const BLOCKS := [
	Rect2(0, 328, 1280, 32),
	Rect2(0, 0, 16, 360),
	Rect2(1264, 0, 16, 360),
	Rect2(180, 260, 120, 12),
	Rect2(360, 205, 120, 12),
	Rect2(560, 260, 160, 12),
	Rect2(900, 280, 80, 48),
]

var _hud: Label


func _ready() -> void:
	for r: Rect2 in BLOCKS:
		_add_block(r)

	var dummy := Dummy.new()
	dummy.position = Vector2(760, 328)
	add_child(dummy)

	# El jugador se agrega después para que se dibuje encima de los enemigos.
	var player := Player.new()
	player.position = Vector2(80, 328)
	add_child(player)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(ROOM_SIZE.x)
	camera.limit_bottom = int(ROOM_SIZE.y)
	camera.position_smoothing_enabled = true
	player.add_child(camera)

	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_font_size_override("font_size", 10)
	ui.add_child(_hud)
	ui.add_child(TouchControls.new())


func _add_block(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size / 2.0
	body.add_child(shape)
	add_child(body)


func _process(_delta: float) -> void:
	var dummy := get_tree().get_first_node_in_group("dummy")
	_hud.text = "Entrada: %s   ·   Golpes al muñeco: %d" % [Controls.device_name(), dummy.hits]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#120c14"))
	for i in 8:
		draw_rect(Rect2(i * 170 + 40, 60, 14, 220), Color("#1c1420"))
	for r: Rect2 in BLOCKS:
		draw_rect(r, Color("#3c5a2e"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("#5f8a45"))
