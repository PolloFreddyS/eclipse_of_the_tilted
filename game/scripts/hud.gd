extends Control
## Barra de vida del Pollito y avisos cortos ("Santuario de Discord").

const BAR := Rect2(10, 10, 110, 8)

var _hp := 1.0
var _shown := 1.0  # la parte roja baja despacio para que se note cuánto quitó el golpe
var _notice := ""
var _notice_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(player: Node) -> void:
	player.health_changed.connect(func(hp: int, max_hp: int) -> void: _hp = float(hp) / max_hp)
	player.died.connect(func() -> void: notify("Tilteado..."))
	player.respawned.connect(func() -> void: notify("Vuelves al Santuario"))


func notify(text: String) -> void:
	_notice = text
	_notice_time = 2.0


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _hp, delta * 0.6) if _shown > _hp else _hp
	_notice_time = maxf(_notice_time - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(BAR.grow(1), Color("#0b0708"))
	draw_rect(BAR, Color("#2e1f1c"))
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * _shown, BAR.size.y)), Color("#f0d58c"))
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * _hp, BAR.size.y)), Color("#8e1b26"))
	if _notice_time > 0.0:
		var font := get_theme_default_font()
		var size := get_viewport_rect().size
		var w := font.get_string_size(_notice, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		var color := Color(0.92, 0.88, 0.8, minf(_notice_time, 1.0))
		draw_string(font, Vector2((size.x - w) / 2.0, size.y * 0.3), _notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
