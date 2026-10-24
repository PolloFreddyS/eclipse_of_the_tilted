class_name KingChikiRigData
## Generado por scripts/art/rig_parts.py: no editar a mano.

## Punto de la cadera (de donde cuelgan torso, piernas y cola), con los pies en (0, 0).
const HIPS := Vector2(0.0, -30.6)

## Piezas en orden de dibujo: imagen, pieza padre, punto de giro y centro en reposo (pies en 0, 0).
const PARTS := [
	{"name": "cape", "parent": "torso", "pivot": Vector2(12.6, -55.8), "center": Vector2(21.6, -39.6)},
	{"name": "tail", "parent": "hips", "pivot": Vector2(43.2, -45.0), "center": Vector2(52.2, -46.8)},
	{"name": "thigh_back", "parent": "hips", "pivot": Vector2(19.8, -43.2), "center": Vector2(19.8, -34.2)},
	{"name": "shin_back", "parent": "thigh_back", "pivot": Vector2(20.7, -27.0), "center": Vector2(21.6, -16.2)},
	{"name": "arm_back", "parent": "torso", "pivot": Vector2(19.8, -64.8), "center": Vector2(28.8, -55.8)},
	{"name": "scepter", "parent": "arm_front", "pivot": Vector2(-37.8, -42.3), "center": Vector2(-35.1, -64.8)},
	{"name": "arm_front", "parent": "torso", "pivot": Vector2(-16.2, -62.1), "center": Vector2(-26.1, -52.2)},
	{"name": "torso", "parent": "hips", "pivot": Vector2(-2.7, -30.6), "center": Vector2(-4.5, -54.0)},
	{"name": "banner", "parent": "torso", "pivot": Vector2(-7.56, -47.7), "center": Vector2(-7.56, -33.3)},
	{"name": "leg_front", "parent": "hips", "pivot": Vector2(-18.9, -37.8), "center": Vector2(-20.7, -21.6)},
	{"name": "head", "parent": "torso", "pivot": Vector2(-4.5, -70.2), "center": Vector2(-5.4, -83.7)},
	{"name": "shield", "parent": "arm_back", "pivot": Vector2(28.8, -48.6), "center": Vector2(36.9, -42.3)},
]
