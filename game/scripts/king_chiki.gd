extends CharacterBody2D
## King Chiki, fase I "El Último Protector". Pelea a la defensiva:
## - Escudo del Santuario: de frente bloquea los golpes; hay que pegarle por detrás o en sus aperturas.
## - ¡POR AHÍ NO!: marca la zona donde está el Pollito y explota después del aviso.
## - Martillazo del Guardián: golpe con el escudo, con aviso y mucho retroceso; después queda abierto.
## - "¡Aprende a jugar!": si le pegas al escudo muchas veces seguidas, contraataca.

signal health_changed(hp: int, max_hp: int)
signal defeated

const GroundMark := preload("res://scripts/ground_mark.gd")

## Hoja de King Chiki (assets/king_chiki/king_chiki.png). Dibujado mirando a la izquierda.
const SHEET := preload("res://assets/king_chiki/king_chiki.png")
const FRAME := 96
const ANIMATIONS := {
	"idle": [0, 4, 5.0, true],
	"walk": [1, 4, 6.0, true],
	"block": [2, 2, 1.0, false],
	"bash": [3, 4, 1.0, false],
	"slam": [4, 4, 8.0, false],
	"cast": [5, 3, 6.0, false],
	"hurt": [6, 2, 8.0, false],
	"defeated": [7, 2, 3.0, false],
}

const MAX_HP := 200
const GRAVITY := 980.0
const WALK_SPEED := 40.0
const NEAR := 80.0             # a esta distancia prefiere el golpe de escudo
const TURN_DELAY := 0.5        # tarda en voltearse: la ventana para pegarle por detrás
const BASH_WINDUP := 0.55
const COUNTER_WINDUP := 0.3
const BASH_ACTIVE := 0.15
const BASH_RECOVER := 0.8
const BASH_REACH := Vector2(58, 44)
const BASH_DAMAGE := 30
const BASH_FORCE := 1.6
const BASH_LUNGE := 160.0
const CAST_TIME := 1.1
const BLOCK_TIME := 0.35
const COUNTER_HITS := 4
const COUNTER_WINDOW := 2.0
const PATTERN := ["bash", "cast", "bash", "bash", "cast"]

const LINES := {
	"intro": "¡YO LOS PROTEGÍ A TODOS! ¡Y USTEDES ME BAJARON DE DIAMANTE!",
	"por_ahi": "¡COÑO, YO TE DIJE QUE POR AHÍ NO FUERAS!",
	"aprende": "¡COÑO, PERO APRENDE A JUGAR!",
}

enum State { WAITING, IDLE, WALK, BLOCK, BASH_WINDUP, BASH_STRIKE, BASH_RECOVER, CAST, DEFEATED }

var hp := MAX_HP
var facing := -1
var blocked_hits := 0
var counters := 0
var speech := ""
var state := State.WAITING
var home := Vector2.ZERO

var _t := 0.0
var _turn_t := 0.0
var _clock := 0.0
var _recent_blocks: Array[float] = []
var _counter_pending := false
var _next := 0
var _flash := 0.0
var _spark := 0.0
var _speech_t := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("boss")
	collision_layer = 0
	set_collision_layer_value(2, true)  # enemigo: recibe los golpes del Pollito
	collision_mask = 1                  # el mundo
	home = position

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 60)
	shape.shape = rect
	shape.position = Vector2(0, -30)
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SheetFrames.build(SHEET, FRAME, ANIMATIONS)
	_sprite.offset = Vector2(0, -FRAME / 2.0 + 1.0)
	_sprite.play("idle")
	add_child(_sprite)


func state_name() -> String:
	return State.keys()[state].to_lower()


func start() -> void:
	if state != State.WAITING:
		return
	say(LINES["intro"])
	_set_state(State.IDLE, 1.6)


## Vuelve al inicio de la pelea (cuando el Pollito muere y reaparece).
func reset() -> void:
	hp = MAX_HP
	position = home
	velocity = Vector2.ZERO
	facing = -1
	_next = 0
	_recent_blocks.clear()
	_counter_pending = false
	speech = ""
	_speech_t = 0.0
	_set_state(State.WAITING, 0.0)
	health_changed.emit(hp, MAX_HP)


func say(text: String) -> void:
	speech = text
	_speech_t = 2.6


## Golpe del Pollito. from_dir es hacia dónde mira el Pollito al pegar.
func hit(from_dir: int, damage: int) -> void:
	if state == State.WAITING or state == State.DEFEATED:
		return
	var frontal := from_dir == -facing
	var guarding := state in [State.IDLE, State.WALK, State.BLOCK, State.BASH_WINDUP]
	if frontal and guarding:
		_on_blocked()
		return
	hp = max(hp - damage, 0)
	_flash = 0.12
	health_changed.emit(hp, MAX_HP)
	if hp == 0:
		_set_state(State.DEFEATED, 0.0)
		speech = ""
		_speech_t = 0.0
		defeated.emit()


func _on_blocked() -> void:
	blocked_hits += 1
	_spark = 0.15
	_recent_blocks.append(_clock)
	_recent_blocks = _recent_blocks.filter(func(t: float) -> bool: return _clock - t <= COUNTER_WINDOW)
	if _recent_blocks.size() >= COUNTER_HITS and not _counter_pending:
		_recent_blocks.clear()
		_counter_pending = true
		counters += 1
		say(LINES["aprende"])
	_set_state(State.BLOCK, BLOCK_TIME)


func _set_state(s: State, t: float) -> void:
	state = s
	_t = t


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_clock += delta
	_t -= delta
	_flash = maxf(_flash - delta, 0.0)
	_spark = maxf(_spark - delta, 0.0)
	_speech_t = maxf(_speech_t - delta, 0.0)
	if _speech_t == 0.0:
		speech = ""
	velocity.y = minf(velocity.y + GRAVITY * delta, 520.0)

	var player := _player()
	var dx := player.global_position.x - global_position.x if player else 0.0

	match state:
		State.WAITING, State.DEFEATED:
			velocity.x = 0.0
		State.IDLE:
			velocity.x = 0.0
			_face(dx, delta)
			if _t <= 0.0:
				_choose(absf(dx))
		State.WALK:
			_face(dx, delta)
			velocity.x = facing * WALK_SPEED
			if absf(dx) <= NEAR:
				_start_bash(BASH_WINDUP)
			elif _t <= 0.0:
				_set_state(State.IDLE, 0.4)
		State.BLOCK:
			velocity.x = 0.0
			if _t <= 0.0:
				if _counter_pending:
					_counter_pending = false
					_start_bash(COUNTER_WINDUP)
				else:
					_set_state(State.IDLE, 0.5)
		State.BASH_WINDUP:
			velocity.x = 0.0
			if _t <= 0.0:
				_set_state(State.BASH_STRIKE, BASH_ACTIVE)
				velocity.x = facing * BASH_LUNGE
				_strike()
		State.BASH_STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _t <= 0.0:
				velocity.x = 0.0
				_set_state(State.BASH_RECOVER, BASH_RECOVER)
		State.BASH_RECOVER:
			if _t <= 0.0:
				_set_state(State.IDLE, 0.9)
		State.CAST:
			velocity.x = 0.0
			if _t <= 0.0:
				_set_state(State.IDLE, 0.6)

	move_and_slide()
	_animate()
	queue_redraw()


## Se voltea hacia el Pollito, pero con retraso: así se le puede pegar por detrás.
func _face(dx: float, delta: float) -> void:
	if dx == 0.0 or signf(dx) == facing:
		_turn_t = 0.0
		return
	_turn_t += delta
	if _turn_t >= TURN_DELAY:
		facing = -facing
		_turn_t = 0.0


func _choose(dist: float) -> void:
	var kind: String = PATTERN[_next % PATTERN.size()]
	_next += 1
	if kind == "cast":
		_cast()
	elif dist <= NEAR:
		_start_bash(BASH_WINDUP)
	else:
		_set_state(State.WALK, 2.5)


func _start_bash(windup: float) -> void:
	_set_state(State.BASH_WINDUP, windup)


func _cast() -> void:
	_set_state(State.CAST, CAST_TIME)
	say(LINES["por_ahi"])
	var player := _player()
	if player:
		var mark := GroundMark.new()
		mark.position = Vector2(player.global_position.x, global_position.y)
		get_parent().add_child(mark)


func _strike() -> void:
	var shape := RectangleShape2D.new()
	shape.size = BASH_REACH
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * 36, -22))
	query.collision_mask = 1 << 2  # capa 3: el jugador
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Object = hit["collider"]
		if target.has_method("hurt"):
			target.hurt(BASH_DAMAGE, global_position.x, BASH_FORCE)


func _animate() -> void:
	_sprite.flip_h = facing > 0
	_sprite.modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	match state:
		State.WAITING, State.IDLE:
			_play("idle")
		State.WALK:
			_play("walk")
		State.BLOCK:
			_hold("block", 0)
		State.BASH_WINDUP:
			_hold("bash", 0 if _t > BASH_WINDUP / 2.0 else 1)
		State.BASH_STRIKE:
			_hold("bash", 2)
		State.BASH_RECOVER:
			_hold("bash", 3)
		State.CAST:
			_play("cast")
		State.DEFEATED:
			_play("defeated")


func _play(anim: String) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _hold(anim: String, frame: int) -> void:
	if _sprite.animation != anim:
		_sprite.animation = anim
	_sprite.stop()
	_sprite.frame = frame


func _draw() -> void:
	# Aviso del golpe de escudo: destello dorado en el escudo mientras carga.
	if state == State.BASH_WINDUP:
		var a := 0.35 + 0.35 * absf(sin(_clock * 20.0))
		draw_circle(Vector2(facing * 22, -34), 10.0, Color(0.94, 0.84, 0.55, a))
	if _spark > 0.0:
		var start := -PI / 2.0 if facing > 0 else PI / 2.0
		draw_arc(Vector2(facing * 24, -30), 14.0, start, start + PI, 12, Color(1, 0.95, 0.7, _spark / 0.15), 2.0)
	if speech != "":
		_draw_speech()


func _draw_speech() -> void:
	var font := ThemeDB.fallback_font
	var width := 190.0
	var size := 9
	var text_h := font.get_multiline_string_size(speech, HORIZONTAL_ALIGNMENT_CENTER, width, size).y
	var box := Rect2(-width / 2.0 - 4.0, -104.0 - text_h, width + 8.0, text_h + 8.0)
	# El globo no se sale de la pantalla aunque King Chiki esté en el borde.
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	var left := global_position.x + box.position.x
	var shift := clampf(left, view.position.x + 2.0, view.end.x - box.size.x - 2.0) - left
	box.position.x += shift
	draw_rect(box, Color(0.04, 0.03, 0.03, 0.85))
	draw_rect(box, Color(0.79, 0.64, 0.29, 0.9), false, 1.0)
	draw_multiline_string(font, box.position + Vector2(4, 4 + size), speech, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, Color(0.92, 0.88, 0.8))
