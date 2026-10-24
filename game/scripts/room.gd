class_name Room
extends Node2D
## Base de las salas: bloques sólidos, el Pollito con su cámara, la barra de vida,
## los controles táctiles y una línea de depuración.

const Player := preload("res://scripts/player.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Hud := preload("res://scripts/hud.gd")

var room_size := Vector2(480, 270)
var blocks: Array[Rect2] = []
var player: CharacterBody2D
var hud: Control
var _debug: Label


func build_blocks() -> void:
	for r in blocks:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.position + r.size / 2.0
		body.add_child(shape)
		add_child(body)


## Agrega el Pollito (al final, para que se dibuje encima de los enemigos), su cámara y la interfaz.
func spawn_player(at: Vector2) -> void:
	player = Player.new()
	player.position = at
	add_child(player)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room_size.x)
	camera.limit_bottom = int(room_size.y)
	camera.position_smoothing_enabled = true
	player.add_child(camera)

	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.bind(player)
	_debug = Label.new()
	_debug.position = Vector2(10, 22)
	_debug.add_theme_font_size_override("font_size", 8)
	_debug.modulate.a = 0.6
	ui.add_child(_debug)
	ui.add_child(TouchControls.new())


func set_debug(text: String) -> void:
	_debug.text = text


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("#120c14"))
	for i in int(room_size.x / 170.0) + 1:
		draw_rect(Rect2(i * 170 + 40, 60, 14, room_size.y - 140), Color("#1c1420"))
	for r in blocks:
		draw_rect(r, Color("#3c5a2e"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("#5f8a45"))
