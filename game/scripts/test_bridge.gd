extends Node
## Solo en la versión web: publica el estado del juego en window.__eclipse para que
## las pruebas automáticas (Playwright) puedan verificar movimiento y controles.

const INTERVAL := 0.1

var _window: JavaScriptObject
var _elapsed := 0.0


func _ready() -> void:
	if OS.has_feature("web"):
		_window = JavaScriptBridge.get_interface("window")


func _process(delta: float) -> void:
	if _window == null:
		return
	_elapsed += delta
	if _elapsed < INTERVAL:
		return
	_elapsed = 0.0
	var data := {"device": Controls.device_name(), "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	var player := get_tree().get_first_node_in_group("player")
	if player:
		data["player"] = {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"on_floor": player.is_on_floor(),
			"state": player.state(),
			"jumps": player.jumps,
			"attacks": player.attacks,
			"dodges": player.dodges,
		}
	var dummy := get_tree().get_first_node_in_group("dummy")
	if dummy:
		data["dummy_hits"] = dummy.hits
	var touch := get_tree().get_first_node_in_group("touch_controls")
	if touch:
		data["touch_visible"] = touch.visible
		var centers := {}
		for spec: Dictionary in touch.BUTTONS:
			var c: Vector2 = touch.button_center(spec)
			centers[spec["action"]] = [c.x, c.y]
		data["touch_buttons"] = centers
	_window.__eclipse = JSON.stringify(data)
