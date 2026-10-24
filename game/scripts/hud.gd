extends Control
## Barra de vida del Pollito, barra del jefe y avisos cortos ("Santuario de Discord").

const BAR := Rect2(10, 10, 110, 8)

var _hp := 1.0
var _shown := 1.0  # la parte roja baja despacio para que se note cuánto quitó el golpe
var _boss_hp := 1.0
var _boss_name := ""
var _boss_title := ""
var _boss_visible := false
var _notice := ""
var _notice_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(player: Node) -> void:
	player.health_changed.connect(func(hp: int, max_hp: int) -> void: _hp = float(hp) / max_hp)
	player.died.connect(func() -> void: notify("Tilteado..."))
	player.respawned.connect(func() -> void: notify("Vuelves al Santuario"))


func bind_boss(boss: Node, boss_name: String, title: String) -> void:
	_boss_name = boss_name
	_boss_title = title
	boss.health_changed.connect(func(hp: int, max_hp: int) -> void: _boss_hp = float(hp) / max_hp)


func show_boss(on: bool) -> void:
	_boss_visible = on
	if on:
		_boss_hp = 1.0


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
	var font := get_theme_default_font()
	var size := get_viewport_rect().size
	if _boss_visible:
		var bar := Rect2(size.x * 0.2, size.y - 18, size.x * 0.6, 6)
		draw_string(font, bar.position + Vector2(0, -4), _boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ebe1cd"))
		var title_w := font.get_string_size(_boss_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(font, bar.position + Vector2(bar.size.x - title_w, -4), _boss_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#c9a24a"))
		draw_rect(bar.grow(1), Color("#0b0708"))
		draw_rect(bar, Color("#2e1f1c"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_hp, bar.size.y)), Color("#c9a24a"))
	if _notice_time > 0.0:
		var w := font.get_string_size(_notice, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		var color := Color(0.92, 0.88, 0.8, minf(_notice_time, 1.0))
		draw_string(font, Vector2((size.x - w) / 2.0, size.y * 0.3), _notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
