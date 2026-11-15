extends Control
## Interior do módulo. mode = "back" desenha as paredes (atrás das janelas);
## mode = "front" desenha molduras, mesa, alavancas dos escudos e iluminação.

const W := 2560.0
const IMG_INTERIOR := preload("res://art/gen/interior.png")
const WINDOWS := {
	"left": Rect2(130, 120, 540, 300),
	"center": Rect2(880, 70, 800, 360),
	"right": Rect2(1900, 120, 540, 300),
}
const LEVERS := {
	"radiacao": Rect2(1730, 250, 56, 170),
	"desastre": Rect2(1806, 250, 56, 170),
}

var mode := "back"
var hover := ""
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, 720)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if mode == "back":
		_draw_back()
	else:
		_draw_front()


func _draw_back() -> void:
	for i in 18:
		draw_rect(Rect2(0, i * 40, W, 41), Color("8fa3ad").lerp(Color("6c808a"), i / 17.0))
	draw_rect(Rect2(0, 0, W, 58), Color("55666e"))
	for x in range(0, int(W), 160):
		draw_rect(Rect2(x, 58, 3, 560), Color("7a8e98"))
		draw_circle(Vector2(x + 20, 80), 4, Color("b5c4cb"))
		draw_circle(Vector2(x + 20, 590), 4, Color("b5c4cb"))
	draw_rect(Rect2(0, 610, W, 110), Color("5b6a70"))
	for x in range(0, int(W), 80):
		draw_rect(Rect2(x, 610, 2, 110), Color("4d5b61"))
	draw_rect(Rect2(0, 606, W, 6), Color("b5c4cb"))


func _font() -> Font:
	return ThemeDB.fallback_font


func _draw_front() -> void:
	var font := _font()
	# interior renderizado em 3D (tests/gen_art.gd), com as janelas vazadas
	draw_texture_rect(IMG_INTERIOR, Rect2(0, 0, W, 720), false)
	for k in WINDOWS:
		var r: Rect2 = WINDOWS[k]
		# reflexo no vidro
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(40, 0), r.position + Vector2(110, 0), r.position + Vector2(30, r.size.y), r.position + Vector2(-40, r.size.y)]), Color(1, 1, 1, 0.05))
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(130, 0), r.position + Vector2(150, 0), r.position + Vector2(70, r.size.y), r.position + Vector2(50, r.size.y)]), Color(1, 1, 1, 0.035))
		# divisória central do vidro
		draw_rect(Rect2(r.position.x + r.size.x / 2.0 - 6, r.position.y, 12, r.size.y), Color("3d4e54"))
		draw_rect(Rect2(r.position.x + r.size.x / 2.0 - 6, r.position.y, 3, r.size.y), Color("5a7077"))
		if Game.shutter > 0.9:
			draw_string(font, r.position + Vector2(0, r.size.y / 2.0 + 10), "ESCUDO ATIVO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color("2b2f33"))
		if hover == k:
			draw_rect(Rect2(r.position - Vector2(22, 22), r.size + Vector2(44, 52)), Color("f2a541"), false, 3.0)
			draw_string(font, r.position + Vector2(r.size.x / 2.0 - 70, r.size.y + 20), "CLIQUE PARA OLHAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2a541"))
	draw_string(font, Vector2(516, 545), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3a474d"))
	# tela do comunicador e luz da luminária
	var lamp_on := not Game.blackout
	if lamp_on:
		var blink := 0.5 + 0.5 * sin(t * 2.0)
		draw_rect(Rect2(724, 464, 102, 2), Color(0.55, 1, 0.9, 0.35 + 0.3 * blink))
		draw_rect(Rect2(724, 476 + fmod(t * 20.0, 40.0), 102, 2), Color(0.55, 1, 0.9, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(1534, 382), Vector2(1594, 382), Vector2(1660, 500), Vector2(1470, 500)]), Color(1, 0.9, 0.6, 0.08))
	# Caixa dos escudos (alavancas)
	draw_string(font, Vector2(1724, 228), "ESCUDOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f2d541"))
	for k in LEVERS:
		var r: Rect2 = LEVERS[k]
		var on: bool = Game.shields[k]
		var knob_y := r.position.y + (20.0 if on else r.size.y - 50.0)
		draw_rect(Rect2(r.position.x + 22, r.position.y + 10, 12, r.size.y - 20), Color("0f1416"))
		draw_rect(Rect2(r.position.x + 6, knob_y + 4, r.size.x - 12, 30), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(r.position.x + 6, knob_y, r.size.x - 12, 30), Color("c9d2d2"))
		draw_rect(Rect2(r.position.x + 6, knob_y, r.size.x - 12, 6), Color("eef3f3"))
		draw_rect(Rect2(r.position.x + 6, knob_y + 24, r.size.x - 12, 6), Color("8c9a9c"))
		var lc := Color("8be07f") if on else Color("e8604c")
		if Game.blackout:
			lc = Color("333333")
		draw_circle(Vector2(r.position.x + r.size.x / 2.0, r.end.y + 16), 9, lc)
		var lbl := "RAD" if k == "radiacao" else "DES"
		draw_string(font, Vector2(r.position.x + 8, r.end.y + 44), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c8f7ea"))
		if hover == k:
			draw_rect(r.grow(5), Color("f2a541"), false, 3.0)

	# Luz de aviso no teto (pisca em âmbar quando há alerta)
	var alert := Game.any_alert() and Game.running
	var on_blink := alert and fmod(t, 0.8) < 0.45
	if on_blink:
		draw_circle(Vector2(1280, 78), 70, Color(1, 0.7, 0.15, 0.12))
	draw_circle(Vector2(1280, 78), 18, Color("ffb627") if on_blink else Color("c9d2d2"))
	draw_circle(Vector2(1274, 72), 6, Color(1, 1, 1, 0.5))

	# Blecaute: só escurece um pouco a sala
	if Game.blackout:
		draw_rect(Rect2(0, 0, W, 720), Color(0.05, 0.08, 0.15, 0.35))
