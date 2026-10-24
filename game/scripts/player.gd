extends CharacterBody2D
## El Pollito Sin Nombre: correr, saltar, atacar, esquivar, recibir daño y reaparecer.

signal health_changed(hp: int, max_hp: int)
signal died
signal respawned

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

const MAX_HP := 100
const HURT_TIME := 0.3         # sin control después de un golpe
const INVULN_TIME := 0.9       # invulnerable después de un golpe
const KNOCKBACK := Vector2(170, -220)
const RESPAWN_DELAY := 1.4

const LAYER_WORLD := 1
const LAYER_ENEMY := 2

var facing := 1
var jumps := 0
var attacks := 0
var dodges := 0
var deaths := 0
var hp := MAX_HP
var respawn_point := Vector2.ZERO

var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown := 0.0
var _attack_timer := 0.0
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _dead_timer := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = LAYER_WORLD
	respawn_point = position

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 26)
	shape.shape = rect
	shape.position = Vector2(0, -13)
	add_child(shape)

	# Los pies quedan en el origen del cuerpo; el cuerpo del pollito está algo a la derecha del centro del cuadro.
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = PollitoFrames.build()
	_sprite.offset = Vector2(-2, -PollitoFrames.FRAME / 2.0 + 1.0)
	_sprite.play("idle")
	add_child(_sprite)


func is_dead() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return is_dead() or _dodge_timer > 0.0 or _invuln_timer > 0.0


## Recibe un golpe. Devuelve false si no hizo efecto (esquivando o invulnerable).
func hurt(amount: int, from_x: float) -> bool:
	if is_invulnerable():
		return false
	hp = max(hp - amount, 0)
	health_changed.emit(hp, MAX_HP)
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(KNOCKBACK.x * away, KNOCKBACK.y)
	_hurt_timer = HURT_TIME
	_invuln_timer = INVULN_TIME
	_attack_timer = 0.0
	if is_dead():
		deaths += 1
		_dead_timer = RESPAWN_DELAY
		died.emit()
	return true


func heal_full() -> void:
	hp = MAX_HP
	health_changed.emit(hp, MAX_HP)


func set_checkpoint(point: Vector2) -> void:
	respawn_point = point


func state() -> String:
	if is_dead():
		return "dead"
	if _hurt_timer > 0.0:
		return "hurt"
	if _dodge_timer > 0.0:
		return "dodge"
	if _attack_timer > 0.0:
		return "attack"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	return "run" if absf(velocity.x) > 1.0 else "idle"


func _physics_process(delta: float) -> void:
	_coyote = COYOTE_TIME if is_on_floor() else maxf(_coyote - delta, 0.0)
	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else maxf(_jump_buffer - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)

	if is_dead():
		_dead_timer -= delta
		if _dead_timer <= 0.0:
			_respawn()
		else:
			_fall(delta)
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			move_and_slide()
		_update_sprite()
		return

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		_fall(delta)
		move_and_slide()
		_update_sprite()
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and _dodge_timer <= 0.0:
		facing = 1 if dir > 0.0 else -1

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown <= 0.0 and _dodge_timer <= 0.0:
		_dodge_timer = DODGE_TIME
		_dodge_cooldown = DODGE_TIME + DODGE_COOLDOWN
		dodges += 1

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity = Vector2(DODGE_SPEED * facing, 0.0)
	else:
		_fall(delta)
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
	_update_sprite()


func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)


func _respawn() -> void:
	position = respawn_point
	velocity = Vector2.ZERO
	_hurt_timer = 0.0
	_dodge_timer = 0.0
	_invuln_timer = INVULN_TIME
	heal_full()
	respawned.emit()


func animation() -> String:
	return _sprite.animation


func _update_sprite() -> void:
	var anim := state()
	if anim == "dead":
		anim = "hurt"
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.flip_h = facing < 0
	if is_dead():
		_sprite.modulate.a = clampf(_dead_timer / RESPAWN_DELAY, 0.0, 1.0)
	elif _dodge_timer > 0.0:
		_sprite.modulate.a = 0.5
	elif _invuln_timer > 0.0:
		# Parpadeo mientras es invulnerable después de un golpe.
		_sprite.modulate.a = 0.35 if int(_invuln_timer * 20.0) % 2 == 0 else 1.0
	else:
		_sprite.modulate.a = 1.0


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
