extends Room
## Sala de prueba: plataformas, un Santuario de Discord, espinas, un muñeco de práctica
## y, al final, la puerta a la arena de King Chiki.

const Dummy := preload("res://scripts/dummy.gd")
const Sanctuary := preload("res://scripts/sanctuary.gd")
const Spikes := preload("res://scripts/spikes.gd")
const Door := preload("res://scripts/door.gd")


func _ready() -> void:
	# En la web, ?sala=jefe abre directo la arena (útil para probar).
	if OS.has_feature("web") and "sala=jefe" in str(JavaScriptBridge.eval("location.search")):
		get_tree().change_scene_to_file.call_deferred("res://scenes/arena.tscn")
		return

	room_size = Vector2(1280, 360)
	blocks = [
		Rect2(0, 328, 1280, 32),
		Rect2(0, 0, 16, 360),
		Rect2(1264, 0, 16, 360),
		Rect2(180, 260, 120, 12),
		Rect2(360, 205, 120, 12),
		Rect2(560, 260, 160, 12),
		Rect2(900, 280, 80, 48),
	]
	build_blocks()

	var sanctuary := Sanctuary.new()
	sanctuary.position = Vector2(150, 328)
	add_child(sanctuary)

	var spikes := Spikes.new()
	spikes.position = Vector2(1040, 328)
	add_child(spikes)

	var dummy := Dummy.new()
	dummy.position = Vector2(760, 328)
	add_child(dummy)

	var door := Door.new()
	door.position = Vector2(1240, 328)
	door.target_scene = "res://scenes/arena.tscn"
	add_child(door)

	spawn_player(Vector2(80, 328))
	sanctuary.activated.connect(func() -> void: hud.notify("Santuario de Discord"))


func _process(_delta: float) -> void:
	var dummy := get_tree().get_first_node_in_group("dummy")
	if dummy:
		set_debug("Entrada: %s · Golpes al muñeco: %d" % [Controls.device_name(), dummy.hits])
