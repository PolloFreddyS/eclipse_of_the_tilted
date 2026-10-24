extends Node2D
## Comparación: King Chiki actual (cuadros dibujados) al lado del King Chiki por piezas,
## haciendo lo mismo al mismo tiempo. Se abre en la web con ?sala=rig.

const KingChikiRig := preload("res://scripts/king_chiki_rig.gd")
const KingChiki := preload("res://scripts/king_chiki.gd")

## Qué hacen los dos y por cuánto tiempo.
const SEQUENCE := [["idle", 2.5], ["walk", 2.5], ["bash", 1.6], ["idle", 0.6], ["slam", 1.9], ["idle", 0.6]]

var _old: AnimatedSprite2D
var _rig: Node2D
var _step := -1
var _t := 0.0


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(240, 135)
	add_child(camera)

	_old = AnimatedSprite2D.new()
	_old.sprite_frames = SheetFrames.build(KingChiki.SHEET, KingChiki.FRAME, KingChiki.ANIMATIONS)
	_old.offset = Vector2(0, -KingChiki.FRAME / 2.0 + 1.0)
	_old.position = Vector2(140, 220)
	add_child(_old)

	_rig = KingChikiRig.new()
	_rig.position = Vector2(340, 220)
	add_child(_rig)
	_next()


func _next() -> void:
	_step = (_step + 1) % SEQUENCE.size()
	_t = 0.0
	var anim: String = SEQUENCE[_step][0]
	_rig.play(anim)
	_old.play(anim)


func _process(delta: float) -> void:
	_t += delta
	var anim: String = SEQUENCE[_step][0]
	# La hoja actual no tiene tiempos propios para los ataques: se reparten sus cuadros en la duración.
	if anim in ["bash", "slam"]:
		_old.stop()
		_old.frame = mini(int(_t / SEQUENCE[_step][1] * 4.0), 3)
	if _t >= SEQUENCE[_step][1]:
		_next()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("#120c14"))
	draw_rect(Rect2(0, 220, 480, 50), Color("#3c5a2e"))
	draw_rect(Rect2(0, 220, 480, 3), Color("#5f8a45"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(110, 40), "Actual (cuadros)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c9a24a"))
	draw_string(font, Vector2(300, 40), "Por piezas", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c9a24a"))
	draw_string(font, Vector2(200, 60), SEQUENCE[_step][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ebe1cd"))
