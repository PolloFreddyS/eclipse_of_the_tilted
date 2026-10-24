class_name SheetFrames
## Arma las animaciones de un personaje a partir de una hoja generada con
## scripts/art/sheet_to_frames.py: cada fila es una animación de cuadros cuadrados.


## animations: nombre -> [fila, cuadros, cuadros por segundo, se repite]
static func build(sheet: Texture2D, frame: int, animations: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in animations:
		var spec: Array = animations[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[2])
		frames.set_animation_loop(anim, spec[3])
		for i in spec[1]:
			var tex := AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(i * frame, spec[0] * frame, frame, frame)
			frames.add_frame(anim, tex)
	return frames
