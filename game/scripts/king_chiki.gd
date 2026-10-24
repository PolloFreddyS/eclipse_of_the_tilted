extends CharacterBody2D
## King Chiki, jefe del Santuario del Support.
##
## Fase I "El Último Protector" (100 %–50 %), defensiva:
## - Escudo del Santuario: de frente bloquea; hay que pegarle por detrás o en sus aperturas.
## - ¡POR AHÍ NO!: marca la zona donde está el Pollito y explota después del aviso.
## - Martillazo del Guardián: golpe de escudo con aviso y mucho retroceso; después queda abierto.
## - "¡Aprende a jugar!": si le pegas al escudo muchas veces seguidas, contraataca.
##
## Transición (50 %): intenta curarse, la magia falla y el Tilt lo consume.
##
## Fase II "El Chiquito Tilteado" (50 %–0 %), agresiva, sin escudo y dañina al tocarlo:
## - Democión Maldita: golpe al suelo que lanza ondas hacia ambos lados (hay que saltarlas).
## - Raíces del Tilt: espinas en fila hacia el Pollito, cada una con su aviso.
## - Furia del Chiquito: tres golpes seguidos y una apertura larga al final.

signal health_changed(hp: int, max_hp: int)
signal struck          # recibió un golpe del Pollito (para la pausa de impacto)
signal phase_changed(phase: int)
signal defeated

const GroundMark := preload("res://scripts/ground_mark.gd")
const Shockwave := preload("res://scripts/shockwave.gd")
const Vfx := preload("res://scripts/vfx.gd")

## Hoja de King Chiki (assets/king_chiki/king_chiki.png). Dibujado mirando a la izquierda.
const SHEET := preload("res://assets/king_chiki/king_chiki.png")
const FRAME := 96
const ANIMATIONS := {
	"idle": [0, 4, 5.0, true],
	"walk": [1, 4, 6.0, true],
	"block": [2, 2, 1.0, false],
	"bash": [3, 4, 1.0, false],
	"slam": [4, 4, 1.0, false],
	"cast": [5, 3, 6.0, false],
	"hurt": [6, 2, 8.0, false],
	"defeated": [7, 2, 3.0, false],
}

## Corrupción del Tilt: oscurece y lleva los tonos claros hacia el rojo.
const TILT_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 tilt = mix(vec3(l * 0.45), vec3(0.78, 0.08, 0.14), smoothstep(0.3, 0.85, l) * 0.75);
	COLOR = vec4(mix(c.rgb, tilt, amount), c.a);
}
"""

const MAX_HP := 260
const GRAVITY := 980.0
const NEAR := 80.0               # a esta distancia prefiere el golpe de escudo
const BASH_ACTIVE := 0.15
const BASH_REACH := Vector2(58, 44)
const BASH_DAMAGE := 30
const BASH_DAMAGE_TILTED := 35
const CONTACT_DAMAGE := 15        # en la fase II, tocarlo duele
const BASH_FORCE := 1.6
const BASH_LUNGE := 160.0
const CAST_TIME := 1.1
const BLOCK_TIME := 0.35
const COUNTER_WINDUP := 0.3
const COUNTER_HITS := 4
const COUNTER_WINDOW := 2.0
const TRANSITION_TIME := 2.4
const CORRUPTION := 0.75          # cuánto lo tiñe el Tilt en la fase II (1.0 lo vuelve una silueta)
const SLAM_WINDUP := 0.7
const SLAM_RECOVER := 0.9
const ROOTS := 9
const ROOT_STEP := 32.0
const ROOT_DELAY := 0.1
const ROOT_WARN := 0.5
const FURY_HITS := 3
const FURY_WINDUP := 0.24
const FURY_GAP := 0.12
const FURY_RECOVER := 0.9

## Ajustes por fase: la fase II es más rápida y ya no se cubre.
const PHASES := {
	1: {"walk": 45.0, "turn": 0.45, "windup": 0.5, "recover": 0.7, "rest": 0.7,
		"pattern": ["bash", "cast", "bash", "bash", "cast"]},
	2: {"walk": 95.0, "turn": 0.2, "windup": 0.35, "recover": 0.45, "rest": 0.25,
		"pattern": ["slam", "fury", "cast", "roots", "fury", "slam", "fury", "roots"]},
}

const LINES := {
	"intro": "¡YO LOS PROTEGÍ A TODOS! ¡Y USTEDES ME BAJARON DE DIAMANTE!",
	"por_ahi": "¡COÑO, YO TE DIJE QUE POR AHÍ NO FUERAS!",
	"aprende": "¡COÑO, PERO APRENDE A JUGAR!",
	"transition": "¡NOOOOO! ¡OTRA VEZ NO! ¡NO ME VAN A BAJAR OTRA VEZ!",
}

enum State { WAITING, IDLE, WALK, BLOCK, BASH_WINDUP, BASH_STRIKE, BASH_RECOVER, CAST,
	TRANSITION, SLAM_WINDUP, SLAM_RECOVER, ROOTS, DEFEATED }

var hp := MAX_HP
var phase := 1
var facing := -1
var blocked_hits := 0
var counters := 0
var fury_strikes := 0
var speech := ""
var state := State.WAITING
var home := Vector2.ZERO

var _t := 0.0
var _turn_t := 0.0
var _clock := 0.0
var _recent_blocks: Array[float] = []
var _counter_pending := false
var _combo_left := 0
var _roots_left := 0
var _roots_x := 0.0
var _roots_dir := 1
var _next := 0
var _flash := 0.0
var _spark := 0.0
var _speech_t := 0.0
var _corruption := 0.0
var _sprite: AnimatedSprite2D
var _tilt: ShaderMaterial


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
	var shader := Shader.new()
	shader.code = TILT_SHADER
	_tilt = ShaderMaterial.new()
	_tilt.shader = shader
	_sprite.material = _tilt
	_sprite.play("idle")
	add_child(_sprite)


func state_name() -> String:
	return State.keys()[state].to_lower()


func _cfg(key: String) -> Variant:
	return PHASES[phase][key]


func start() -> void:
	if state != State.WAITING:
		return
	say(LINES["intro"])
	_set_state(State.IDLE, 1.6)


## Vuelve al inicio de la pelea (cuando el Pollito muere y reaparece).
func reset() -> void:
	hp = MAX_HP
	phase = 1
	_corruption = 0.0
	position = home
	velocity = Vector2.ZERO
	facing = -1
	_next = 0
	_combo_left = 0
	_roots_left = 0
	_recent_blocks.clear()
	_counter_pending = false
	speech = ""
	_speech_t = 0.0
	_set_state(State.WAITING, 0.0)
	health_changed.emit(hp, MAX_HP)


func say(text: String, seconds := 2.6) -> void:
	speech = text
	_speech_t = seconds


## Golpe del Pollito. from_dir es hacia dónde mira el Pollito al pegar.
func hit(from_dir: int, damage: int) -> void:
	if state in [State.WAITING, State.DEFEATED, State.TRANSITION]:
		return
	var frontal := from_dir == -facing
	var guarding := phase == 1 and state in [State.IDLE, State.WALK, State.BLOCK, State.BASH_WINDUP]
	if frontal and guarding:
		_on_blocked()
		return
	hp = max(hp - damage, 0)
	_flash = 0.12
	health_changed.emit(hp, MAX_HP)
	struck.emit()
	if hp == 0:
		_set_state(State.DEFEATED, 0.0)
		speech = ""
		_speech_t = 0.0
		defeated.emit()
	elif phase == 1 and hp <= MAX_HP / 2:
		_start_transition()


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


func _start_transition() -> void:
	_counter_pending = false
	_combo_left = 0
	say(LINES["transition"], TRANSITION_TIME + 0.6)
	_set_state(State.TRANSITION, TRANSITION_TIME)


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
			velocity.x = facing * _cfg("walk")
			if absf(dx) <= NEAR:
				if phase == 2:
					_start_fury()
				else:
					_start_bash(_cfg("windup"))
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
				if _combo_left > 0:
					_combo_left -= 1
					_face(dx, 1.0)  # entre golpes de la furia se acomoda hacia el Pollito
					_set_state(State.BASH_WINDUP, FURY_WINDUP + FURY_GAP)
				else:
					_set_state(State.BASH_RECOVER, FURY_RECOVER if phase == 2 else _cfg("recover"))
		State.BASH_RECOVER:
			if _t <= 0.0:
				_set_state(State.IDLE, _cfg("rest"))
		State.CAST:
			velocity.x = 0.0
			if _t <= 0.0:
				_set_state(State.IDLE, 0.6)
		State.TRANSITION:
			velocity.x = 0.0
			_corruption = CORRUPTION * clampf(1.0 - _t / TRANSITION_TIME, 0.0, 1.0)
			if _t <= 0.0:
				phase = 2
				_corruption = CORRUPTION
				phase_changed.emit(phase)
				_set_state(State.IDLE, 0.6)
		State.SLAM_WINDUP:
			velocity.x = 0.0
			if _t <= 0.0:
				_slam()
				_set_state(State.SLAM_RECOVER, SLAM_RECOVER)
		State.SLAM_RECOVER:
			if _t <= 0.0:
				_set_state(State.IDLE, _cfg("rest"))
		State.ROOTS:
			velocity.x = 0.0
			if _roots_left > 0 and _t <= 0.0:
				_spawn_root()
			elif _roots_left == 0 and _t <= -0.6:
				_set_state(State.IDLE, _cfg("rest"))

	_tilt.set_shader_parameter("amount", _corruption)
	if phase == 2 and state != State.DEFEATED and player and absf(dx) < 22.0 \
			and absf(player.global_position.y - global_position.y) < 50.0:
		player.hurt(CONTACT_DAMAGE, global_position.x)
	move_and_slide()
	_animate()
	queue_redraw()


## Se voltea hacia el Pollito, pero con retraso: así se le puede pegar por detrás.
func _face(dx: float, delta: float) -> void:
	if dx == 0.0 or signf(dx) == facing:
		_turn_t = 0.0
		return
	_turn_t += delta
	if _turn_t >= _cfg("turn"):
		facing = -facing
		_turn_t = 0.0


func _choose(dist: float) -> void:
	var pattern: Array = _cfg("pattern")
	var kind: String = pattern[_next % pattern.size()]
	_next += 1
	match kind:
		"cast":
			_cast()
		"slam":
			_set_state(State.SLAM_WINDUP, SLAM_WINDUP)
		"roots":
			_start_roots()
		"fury":
			if dist <= NEAR * 1.5:
				_start_fury()
			else:
				_set_state(State.WALK, 2.0)
		_:
			if dist <= NEAR:
				_start_bash(_cfg("windup"))
			else:
				_set_state(State.WALK, 2.5)


func _start_fury() -> void:
	_combo_left = FURY_HITS - 1
	fury_strikes += 1
	_start_bash(FURY_WINDUP)


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


func _start_roots() -> void:
	var player := _player()
	_roots_dir = 1 if player and player.global_position.x > global_position.x else -1
	_roots_x = global_position.x + _roots_dir * 30.0
	_roots_left = ROOTS
	_set_state(State.ROOTS, 0.35)


func _spawn_root() -> void:
	var mark := GroundMark.new()
	mark.style = "roots"
	mark.radius = 14.0
	mark.warn_time = ROOT_WARN
	mark.damage = 20
	mark.position = Vector2(_roots_x, global_position.y)
	get_parent().add_child(mark)
	_roots_x += _roots_dir * ROOT_STEP
	_roots_left -= 1
	_t = ROOT_DELAY


func _slam() -> void:
	Vfx.spawn(get_parent(), global_position, "ring", Color(1.0, 0.3, 0.25), 1, 1.2, 0.4)
	Vfx.spawn(get_parent(), global_position, "dust", Color.WHITE, 1, 1.0, 0.5)
	_shake(6.0, 0.35)
	for dir in [-1, 1]:
		var wave := Shockwave.new()
		wave.direction = dir
		wave.position = global_position + Vector2(dir * 30, 0)
		get_parent().add_child(wave)


func _strike() -> void:
	var shape := RectangleShape2D.new()
	shape.size = BASH_REACH
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * 36, -22))
	query.collision_mask = 1 << 2  # capa 3: el jugador
	var slash := Color(0.95, 0.82, 0.45) if phase == 1 else Color(1.0, 0.25, 0.25)
	Vfx.spawn(get_parent(), global_position + Vector2(facing * 34, -26), "slash", slash, facing, 1.4, 0.2)
	_shake(2.0, 0.12)
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Object = hit["collider"]
		if target.has_method("hurt"):
			target.hurt(BASH_DAMAGE if phase == 1 else BASH_DAMAGE_TILTED, global_position.x, BASH_FORCE)


func _shake(strength: float, seconds: float) -> void:
	var room := get_parent()
	if room.has_method("shake"):
		room.shake(strength, seconds)


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
			_hold("bash", 0 if _t > 0.25 else 1)
		State.BASH_STRIKE:
			_hold("bash", 2)
		State.BASH_RECOVER:
			_hold("bash", 3)
		State.CAST, State.ROOTS:
			_play("cast")
		State.TRANSITION:
			# Primero levanta el cetro para curarse; cuando la magia falla, se dobla de dolor.
			if _t > TRANSITION_TIME * 0.55:
				_play("cast")
			else:
				_play("hurt")
		State.SLAM_WINDUP:
			_hold("slam", 0)
		State.SLAM_RECOVER:
			_hold("slam", 1 if _t > SLAM_RECOVER - 0.08 else (2 if _t > SLAM_RECOVER - 0.2 else 3))
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
	var pulse := absf(sin(_clock * 20.0))
	# Avisos: destello dorado en el escudo antes del golpe; rojo en fase II y antes del golpe al suelo.
	if state == State.BASH_WINDUP:
		var warn := Color(0.94, 0.84, 0.55) if phase == 1 else Color(1.0, 0.35, 0.3)
		warn.a = 0.35 + 0.35 * pulse
		draw_circle(Vector2(facing * 22, -34), 10.0, warn)
	if state == State.SLAM_WINDUP:
		draw_circle(Vector2(0, -78), 12.0, Color(1.0, 0.3, 0.25, 0.3 + 0.4 * pulse))
	if state == State.TRANSITION:
		_draw_transition()
	if phase == 2 and state != State.DEFEATED:
		# Energía del Tilt saliendo del cuerpo.
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 34.0 + 4.0 * sin(_clock * 4.0), Color(0.6, 0.05, 0.1, 0.35))
		draw_set_transform(Vector2.ZERO)
	if _spark > 0.0:
		var start := -PI / 2.0 if facing > 0 else PI / 2.0
		draw_arc(Vector2(facing * 24, -30), 14.0, start, start + PI, 12, Color(1, 0.95, 0.7, _spark / 0.15), 2.0)
	if speech != "":
		_draw_speech()


func _draw_transition() -> void:
	var p := 1.0 - _t / TRANSITION_TIME
	if p < 0.45:
		# Bendición del Chiquito: un círculo de curación que se forma...
		draw_arc(Vector2(0, -40), 30.0 + 10.0 * p, 0.0, TAU, 32, Color(0.6, 1.0, 0.6, 0.6), 2.0)
	else:
		# ...y se rompe: chispas rojas hacia afuera y raíces que salen del suelo.
		var q := (p - 0.45) / 0.55
		for i in 10:
			var ang := TAU * i / 10.0 + _clock
			var r := 20.0 + 40.0 * q
			draw_circle(Vector2(cos(ang) * r, -40.0 + sin(ang) * r * 0.6), 2.0, Color(0.9, 0.15, 0.2, 1.0 - q))
		for i in 5:
			var x := -40.0 + i * 20.0
			draw_line(Vector2(x, 0), Vector2(x + 4.0, -14.0 * q - 4.0), Color(0.25, 0.05, 0.08), 2.0)


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
