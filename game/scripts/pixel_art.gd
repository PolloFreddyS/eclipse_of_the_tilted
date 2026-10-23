class_name PixelArt
## Arte provisional dibujado con texto. Se reemplaza cuando llegue el arte definitivo.

const CHICK := [
	"................",
	"......RR........",
	".....RRRR.......",
	"......YYYY......",
	".....YYYYYY.....",
	"....YYYYKYYY....",
	"....YYYYYYYOO...",
	"....YYYYYYYOO...",
	"...DYYYYYYYY....",
	"..DDYYYYYYYYY...",
	"..DYYYYYYYYYY...",
	"...YYYYYYYYYY...",
	"....YYYYYYYY....",
	".....L....L.....",
	".....L....L.....",
	"....LL...LL.....",
]

const CHICK_PALETTE := {
	"Y": Color("#f6c945"),
	"D": Color("#c99a1c"),
	"O": Color("#e8862a"),
	"K": Color("#10180f"),
	"R": Color("#d9402b"),
	"L": Color("#e8862a"),
}


static func texture_from(rows: Array, palette: Dictionary) -> ImageTexture:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			img.set_pixel(x, y, palette.get(row[x], Color.TRANSPARENT))
	return ImageTexture.create_from_image(img)


static func chick() -> ImageTexture:
	return texture_from(CHICK, CHICK_PALETTE)
