extends CharacterBody2D
## El Pollito Sin Nombre: correr, saltar, atacar y esquivar.

const SPEED := 150.0
const ACCEL := 1400.0
const FRICTION := 1800.0
const GRAVITY := 980.0
const JUMP_VELOCITY := -360.0
const JUMP_CUT := 0.45
const MAX_FALL := 520.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const DODGE_SPEED := 320.0
const DODGE_TIME := 0.18
const DODGE_COOLDOWN := 0.35
const ATTACK_TIME := 0.22
const ATTACK_REACH := Vector2(26, 22)

const LAYER_WORLD := 1
const LAYER_ENEMY := 2

var facing := 1
var jumps := 0
var attacks := 0
var dodges := 0
var invulnerable := false

var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown := 0.0
var _attack_timer := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = LAYER_WORLD

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 24)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.chick()
	_sprite.scale = Vector2(2, 2)
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)


func state() -> String:
	if _dodge_timer > 0.0:
		return "dodge"
	if _attack_timer > 0.0:
		return "attack"
	if not is_on_floor():
		return "air"
	return "run" if absf(velocity.x) > 1.0 else "idle"


func _physics_process(delta: float) -> void:
	_coyote = COYOTE_TIME if is_on_floor() else maxf(_coyote - delta, 0.0)
	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else maxf(_jump_buffer - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and _dodge_timer <= 0.0:
		facing = 1 if dir > 0.0 else -1

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown <= 0.0 and _dodge_timer <= 0.0:
		_dodge_timer = DODGE_TIME
		_dodge_cooldown = DODGE_TIME + DODGE_COOLDOWN
		dodges += 1

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		invulnerable = true
		velocity = Vector2(DODGE_SPEED * facing, 0.0)
	else:
		invulnerable = false
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		var target := dir * SPEED
		var rate := ACCEL if dir != 0.0 else FRICTION
		velocity.x = move_toward(velocity.x, target, rate * delta)

		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			jumps += 1
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= JUMP_CUT

	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_attack_timer = ATTACK_TIME
		attacks += 1
		_strike()

	move_and_slide()
	_sprite.flip_h = facing < 0
	_sprite.modulate.a = 0.5 if invulnerable else 1.0
	queue_redraw()


func _strike() -> void:
	var shape := RectangleShape2D.new()
	shape.size = ATTACK_REACH
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(facing * 20, -12))
	query.collision_mask = LAYER_ENEMY
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target: Object = hit["collider"]
		if target.has_method("hit"):
			target.hit(facing)


func _draw() -> void:
	if _attack_timer > 0.0:
		var r := Rect2(Vector2(facing * 20, -12) - ATTACK_REACH / 2.0, ATTACK_REACH)
		draw_rect(r, Color(1, 0.9, 0.6, 0.55))
