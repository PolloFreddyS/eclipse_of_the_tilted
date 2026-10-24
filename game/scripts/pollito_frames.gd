class_name PollitoFrames
## Animaciones del Pollito a partir de assets/pollito/pollito.png (generada con
## scripts/art/sheet_to_frames.py). Cada fila de la hoja es una animación de cuadros de 48×48.

const SHEET := preload("res://assets/pollito/pollito.png")
const FRAME := 48

## nombre: [fila, cuadros, cuadros por segundo, se repite]
const ANIMATIONS := {
	"idle": [0, 4, 6.0, true],
	"run": [1, 6, 12.0, true],
	"jump": [2, 2, 8.0, false],
	"fall": [3, 2, 8.0, true],
	"attack": [4, 4, 18.0, false],
	"dodge": [5, 4, 22.0, false],
	"hurt": [6, 2, 8.0, false],
}


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[2])
		frames.set_animation_loop(anim, spec[3])
		for i in spec[1]:
			var tex := AtlasTexture.new()
			tex.atlas = SHEET
			tex.region = Rect2(i * FRAME, spec[0] * FRAME, FRAME, FRAME)
			frames.add_frame(anim, tex)
	return frames
