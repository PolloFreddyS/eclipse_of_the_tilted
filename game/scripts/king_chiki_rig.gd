extends Node2D
## King Chiki animado por piezas (prueba). Cada pieza cuelga de un punto de giro
## (cadera, cuello, hombros, rodilla) y las animaciones mueven esos puntos con código,
## así el movimiento es continuo en vez de saltar entre pocos cuadros dibujados.
## Dibujado mirando a la izquierda; los pies quedan en (0, 0).

const DIR := "res://assets/king_chiki_rig/"
## Piezas que no se dibujan: la cola se veía como una segunda capa cuando el escudo se mueve.
const HIDDEN := ["tail"]

## Cuánto dura cada parte de los ataques (en segundos).
const BASH := {"windup": 0.5, "strike": 0.15, "recover": 0.6}
const SLAM := {"windup": 0.7, "impact": 0.12, "recover": 0.8}

var animation := "idle"
var _t := 0.0
var _joints := {}   # nombre -> Node2D en el punto de giro
var _rest := {}     # nombre -> posición de reposo del punto de giro (relativa a su padre)


func _ready() -> void:
	var hips := Node2D.new()
	hips.position = KingChikiRigData.HIPS
	add_child(hips)
	_joints["hips"] = hips
	_rest["hips"] = hips.position

	# Primero los puntos de giro (un padre siempre antes que sus hijos)...
	var pending: Array = KingChikiRigData.PARTS.duplicate()
	var pivots := {"hips": KingChikiRigData.HIPS}
	while not pending.is_empty():
		for part: Dictionary in pending.duplicate():
			if not _joints.has(part["parent"]):
				continue
			var joint := Node2D.new()
			joint.position = part["pivot"] - pivots[part["parent"]]
			_joints[part["parent"]].add_child(joint)
			_joints[part["name"]] = joint
			_rest[part["name"]] = joint.position
			pivots[part["name"]] = part["pivot"]
			pending.erase(part)

	# ...después cada imagen en su punto, con el orden de dibujo de la pose de reposo.
	for i in KingChikiRigData.PARTS.size():
		var part: Dictionary = KingChikiRigData.PARTS[i]
		var sprite := Sprite2D.new()
		sprite.texture = load(DIR + part["name"] + ".png")
		sprite.position = part["center"] - part["pivot"]
		sprite.z_index = i  # orden de dibujo dentro de King Chiki (el Pollito y los efectos van más arriba)
		sprite.visible = not part["name"] in HIDDEN
		_joints[part["name"]].add_child(sprite)


func play(anim: String) -> void:
	if anim != animation:
		animation = anim
		_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var pose := {}
	match animation:
		"idle":
			pose = _idle(_t)
		"walk":
			pose = _walk(_t)
		"bash":
			pose = _bash(_t)
		"slam":
			pose = _slam(_t)
	_apply(pose)


func _apply(pose: Dictionary) -> void:
	for name: String in _joints:
		var joint: Node2D = _joints[name]
		var p: Dictionary = pose.get(name, {})
		joint.rotation = p.get("rot", 0.0)
		joint.position = _rest[name] + p.get("pos", Vector2.ZERO)
		joint.scale = p.get("scale", Vector2.ONE)


func _idle(t: float) -> Dictionary:
	var b := sin(t * 2.4)
	return {
		"hips": {"pos": Vector2(0, b * 0.8)},
		"torso": {"rot": b * 0.02},
		"head": {"rot": sin(t * 2.4 + 0.6) * 0.05},
		"cape": {"rot": sin(t * 1.6) * 0.05},
		"arm_front": {"rot": sin(t * 2.4 + 0.3) * 0.04},
		"scepter": {"rot": sin(t * 2.4 + 1.0) * 0.05},
		"shield": {"rot": b * 0.02},
	}


func _walk(t: float) -> Dictionary:
	var ph := t * 7.0
	return {
		"hips": {"pos": Vector2(0, -absf(sin(ph)) * 2.5)},
		"torso": {"rot": sin(ph * 2.0) * 0.03},
		"head": {"rot": sin(ph * 2.0 + 0.5) * 0.04},
		"leg_front": {"rot": sin(ph) * 0.35},
		"thigh_back": {"rot": -sin(ph) * 0.35},
		"shin_back": {"rot": maxf(0.0, cos(ph)) * 0.3},
		"cape": {"rot": sin(ph) * 0.08},
		"arm_front": {"rot": sin(ph) * 0.12},
		"scepter": {"rot": -sin(ph) * 0.06},
		"arm_back": {"rot": -sin(ph) * 0.06},
	}


## Golpe con escudo: se echa atrás cargando, empuja el escudo hacia adelante y se recupera.
func _bash(t: float) -> Dictionary:
	var w: float = BASH["windup"]
	var s: float = BASH["strike"]
	var r: float = BASH["recover"]
	var lean := 0.0
	var shield := Vector2.ZERO
	var lunge := 0.0
	if t < w:
		var p := _ease(t / w)
		lean = 0.18 * p
		shield = Vector2(10, -4) * p
	elif t < w + s:
		var p := _ease((t - w) / s)
		lean = lerpf(0.18, -0.22, p)
		shield = Vector2(10, -4).lerp(Vector2(-58, 6), p)
		lunge = -10.0 * p
	elif t < w + s + r:
		var p := _ease((t - w - s) / r)
		lean = lerpf(-0.22, 0.0, p)
		shield = Vector2(-58, 6).lerp(Vector2.ZERO, p)
		lunge = lerpf(-10.0, 0.0, p)
	else:
		return _idle(t)
	return {
		"hips": {"pos": Vector2(lunge, 0)},
		"torso": {"rot": lean},
		"head": {"rot": -lean * 0.5},
		"arm_back": {"pos": shield},
		"shield": {"rot": -lean * 0.6},
		"arm_front": {"rot": lean * 0.8},
		"cape": {"rot": clampf(lean * 0.5, -0.06, 0.1)},
		"leg_front": {"rot": -lean * 0.6},
		"thigh_back": {"rot": lean * 0.6},
	}


## Golpe al suelo: levanta el escudo sobre la cabeza y lo estrella delante, agachándose.
func _slam(t: float) -> Dictionary:
	var w: float = SLAM["windup"]
	var i: float = SLAM["impact"]
	var r: float = SLAM["recover"]
	var raise := 0.0
	var crouch := 0.0
	if t < w:
		raise = _ease(t / w)
	elif t < w + i:
		var p := _ease((t - w) / i)
		raise = 1.0 - 2.0 * p
		crouch = p
	elif t < w + i + r:
		var p := _ease((t - w - i) / r)
		raise = lerpf(-1.0, 0.0, p)
		crouch = 1.0 - p
	else:
		return _idle(t)
	# raise 1 = escudo arriba; -1 = escudo estrellado en el suelo delante.
	var up := Vector2(-18, -46) * maxf(raise, 0.0)
	var down := Vector2(-40, 14) * maxf(-raise, 0.0)
	return {
		"hips": {"pos": Vector2(0, 4.0 * crouch), "scale": Vector2(1.0 + 0.04 * crouch, 1.0 - 0.06 * crouch)},
		"torso": {"rot": 0.12 * maxf(raise, 0.0) - 0.18 * crouch},
		"head": {"rot": -0.08 * maxf(raise, 0.0)},
		"arm_back": {"pos": up + down, "rot": -0.5 * maxf(raise, 0.0)},
		"shield": {"rot": -0.9 * maxf(raise, 0.0) + 0.15 * crouch},
		"arm_front": {"rot": 0.3 * maxf(raise, 0.0)},
		"cape": {"rot": 0.06 * maxf(raise, 0.0) - 0.05 * crouch},
		"leg_front": {"rot": -0.15 * crouch},
		"thigh_back": {"rot": 0.15 * crouch},
	}


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
