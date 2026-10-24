extends Node
## Solo en la versión web: publica el estado del juego en window.__eclipse para que
## las pruebas automáticas (Playwright) puedan verificar movimiento y controles.
## Con ?pruebas en la URL también acepta comandos para preparar cada prueba:
##   window.__eclipseCmd("teleport", x, y)   lleva al Pollito a esa posición
##   window.__eclipseCmd("player_hp", n)     fija la vida del Pollito
##   window.__eclipseCmd("boss_hp", n)       fija la vida del jefe
## Sin ?pruebas estos comandos no existen.

const INTERVAL := 0.1

var _window: JavaScriptObject
var _cmd_callback: JavaScriptObject  # se guarda para que no lo libere el recolector
var _elapsed := 0.0


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if "pruebas" in str(JavaScriptBridge.eval("location.search")):
		_cmd_callback = JavaScriptBridge.create_callback(_command)
		_window.__eclipseCmd = _cmd_callback


func _command(args: Array) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var boss := get_tree().get_first_node_in_group("boss")
	match str(args[0]):
		"teleport":
			if player:
				player.global_position = Vector2(float(args[1]), float(args[2]))
				player.velocity = Vector2.ZERO
		"player_hp":
			if player:
				player.hp = int(args[1])
				player.health_changed.emit(player.hp, player.MAX_HP)
		"boss_hp":
			if boss:
				boss.hp = int(args[1])
				boss.health_changed.emit(boss.hp, boss.MAX_HP)


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
			"anim": player.animation(),
			"jumps": player.jumps,
			"attacks": player.attacks,
			"dodges": player.dodges,
			"hp": player.hp,
			"deaths": player.deaths,
			"respawn_x": player.respawn_point.x,
		}
	var dummy := get_tree().get_first_node_in_group("dummy")
	if dummy:
		data["dummy_hits"] = dummy.hits
	var boss := get_tree().get_first_node_in_group("boss")
	if boss:
		data["boss"] = {
			"x": boss.global_position.x,
			"hp": boss.hp,
			"state": boss.state_name(),
			"facing": boss.facing,
			"blocked": boss.blocked_hits,
			"counters": boss.counters,
			"speech": boss.speech,
		}
		data["marks_warning"] = get_tree().get_nodes_in_group("ground_marks").filter(func(m: Node) -> bool: return m.is_warning()).size()
		data["sealed"] = get_tree().current_scene.get("sealed")
	var touch := get_tree().get_first_node_in_group("touch_controls")
	if touch:
		data["touch_visible"] = touch.visible
		var centers := {}
		for spec: Dictionary in touch.BUTTONS:
			var c: Vector2 = touch.button_center(spec)
			centers[spec["action"]] = [c.x, c.y]
		data["touch_buttons"] = centers
	_window.__eclipse = JSON.stringify(data)
