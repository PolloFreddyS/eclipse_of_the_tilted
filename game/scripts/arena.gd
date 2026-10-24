extends Room
## Arena de King Chiki: Santuario de Discord en la entrada. Al avanzar, King Chiki sella
## la entrada con una barrera mágica y empieza la pelea. Si el Pollito cae, reaparece en
## el Santuario y la pelea vuelve a empezar.

const KingChiki := preload("res://scripts/king_chiki.gd")
const Sanctuary := preload("res://scripts/sanctuary.gd")

const FLOOR_Y := 240.0
const SEAL_X := 110.0
const TRIGGER_X := 160.0

var boss: CharacterBody2D
var sealed := false
var _seal: CollisionShape2D


func _ready() -> void:
	room_size = Vector2(640, 270)
	blocks = [
		Rect2(0, FLOOR_Y, 640, 30),
		Rect2(0, 0, 8, 270),
		Rect2(632, 0, 8, 270),
	]
	build_blocks()

	var sanctuary := Sanctuary.new()
	sanctuary.position = Vector2(40, FLOOR_Y)
	add_child(sanctuary)

	var seal_body := StaticBody2D.new()
	_seal = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 120)
	_seal.shape = rect
	_seal.position = Vector2(SEAL_X, FLOOR_Y - 60)
	_seal.disabled = true
	seal_body.add_child(_seal)
	add_child(seal_body)

	boss = KingChiki.new()
	boss.position = Vector2(520, FLOOR_Y)
	add_child(boss)

	spawn_player(Vector2(60, FLOOR_Y))
	player.set_checkpoint(sanctuary.position)
	hud.bind_boss(boss, "King Chiki", "El Último Protector")
	player.respawned.connect(_reset_fight)
	boss.defeated.connect(_on_boss_defeated)


func _process(_delta: float) -> void:
	if not sealed and boss.state_name() == "waiting" and player.global_position.x > TRIGGER_X:
		_set_sealed(true)
		boss.start()
		hud.show_boss(true)
	set_debug("Entrada: %s · King Chiki: %d/%d" % [Controls.device_name(), boss.hp, boss.MAX_HP])
	queue_redraw()


func _set_sealed(on: bool) -> void:
	sealed = on
	_seal.set_deferred("disabled", not on)


func _reset_fight() -> void:
	_set_sealed(false)
	boss.reset()
	hud.show_boss(false)
	for mark in get_tree().get_nodes_in_group("ground_marks"):
		mark.queue_free()


func _on_boss_defeated() -> void:
	_set_sealed(false)
	hud.show_boss(false)
	hud.notify("El Tilt abandona a King Chiki")


func _draw() -> void:
	super._draw()
	if sealed:
		var a := 0.45 + 0.2 * sin(Time.get_ticks_msec() / 120.0)
		draw_rect(Rect2(SEAL_X - 4, FLOOR_Y - 120, 8, 120), Color(0.94, 0.84, 0.55, a * 0.5))
		draw_rect(Rect2(SEAL_X - 1, FLOOR_Y - 120, 2, 120), Color(1, 0.95, 0.75, a))
