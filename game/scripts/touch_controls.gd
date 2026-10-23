extends Control
## Botones en pantalla para celular. Presionan las mismas acciones que el teclado
## y el control. Soporta varios dedos a la vez y deslizar entre botones.

const RADIUS := 26.0
const MARGIN := 18.0

## Cada botón: acción, flecha o etiqueta, y posición relativa a una esquina inferior.
## "side" -1 = izquierda (cruceta), 1 = derecha (acciones).
const BUTTONS := [
	{"action": "move_left", "arrow": Vector2.LEFT, "side": -1, "pos": Vector2(0, 1)},
	{"action": "move_right", "arrow": Vector2.RIGHT, "side": -1, "pos": Vector2(2, 1)},
	{"action": "move_up", "arrow": Vector2.UP, "side": -1, "pos": Vector2(1, 0)},
	{"action": "move_down", "arrow": Vector2.DOWN, "side": -1, "pos": Vector2(1, 2)},
	{"action": "jump", "label": "Saltar", "side": 1, "pos": Vector2(0, 1.4)},
	{"action": "attack", "label": "Golpe", "side": 1, "pos": Vector2(1.1, 0.7)},
	{"action": "dodge", "label": "Esquivar", "side": 1, "pos": Vector2(2.2, 1.4)},
	{"action": "soul", "label": "Alma", "side": 1, "pos": Vector2(1.1, -0.4)},
]

var _touches := {}  # índice del dedo -> acción
var _held := {}  # acción -> cuántos dedos la presionan


func _ready() -> void:
	add_to_group("touch_controls")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _starts_visible()
	Controls.device_changed.connect(_on_device_changed)


func _starts_visible() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _on_device_changed(device: Controls.Device) -> void:
	visible = device == Controls.Device.TOUCH
	if not visible:
		_release_all()


func button_center(spec: Dictionary) -> Vector2:
	var size := get_viewport_rect().size
	var step := RADIUS * 2.0 + 6.0
	var grid: Vector2 = spec["pos"] * step
	var base_y := size.y - MARGIN - RADIUS - step * 2.0
	if spec["side"] < 0:
		return Vector2(MARGIN + RADIUS, base_y) + grid
	return Vector2(size.x - MARGIN - RADIUS - grid.x, base_y + grid.y)


func _action_at(pos: Vector2) -> String:
	for spec: Dictionary in BUTTONS:
		if pos.distance_to(button_center(spec)) <= RADIUS * 1.15:
			return spec["action"]
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_assign(event.index, event.position)
		else:
			_assign(event.index, Vector2(-1000, -1000))
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_assign(event.index, event.position)


func _assign(index: int, pos: Vector2) -> void:
	var action := _action_at(pos)
	var previous: String = _touches.get(index, "")
	if action == previous:
		return
	if previous != "":
		_held[previous] -= 1
		if _held[previous] <= 0:
			_held.erase(previous)
			Input.action_release(previous)
	if action != "":
		if not _held.has(action):
			Input.action_press(action)
		_held[action] = _held.get(action, 0) + 1
	_touches[index] = action
	queue_redraw()


func _release_all() -> void:
	for action: String in _held:
		Input.action_release(action)
	_held.clear()
	_touches.clear()
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	for spec: Dictionary in BUTTONS:
		var center := button_center(spec)
		var pressed := _held.has(spec["action"])
		draw_circle(center, RADIUS, Color(1, 1, 1, 0.32 if pressed else 0.14))
		draw_arc(center, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.45), 1.5)
		var ink := Color(1, 1, 1, 0.85)
		if spec.has("arrow"):
			var d: Vector2 = spec["arrow"]
			var side := d.orthogonal()
			draw_colored_polygon(PackedVector2Array([center + d * 9.0, center - d * 6.0 + side * 8.0, center - d * 6.0 - side * 8.0]), ink)
		else:
			var label: String = spec["label"]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10).x
			draw_string(font, center + Vector2(-w / 2.0, 3.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
