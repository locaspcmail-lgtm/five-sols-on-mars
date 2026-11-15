extends Control
## Minigames das manutenções. Cada um dura poucos segundos e devolve uma nota de 0 a 1.
##  paineis    -> esfregar a poeira dos painéis solares
##  reciclador -> acertar a válvula na zona verde (3 vezes)
##  gerador    -> repetir a sequência de luzes (memória)
##  robos      -> ligar os fios da mesma cor

signal finished(score: float)

const FRAME := Rect2(170, 90, 940, 560)
const AREA := Rect2(240, 230, 800, 340)
const TITLES := {
	"paineis": "CONSERTAR PAINÉIS SOLARES",
	"reciclador": "REPARAR RECICLADOR DE ÁGUA",
	"gerador": "REPARAR GERADOR DE OXIGÊNIO",
	"robos": "CONSERTAR ROBÔS",
}
const HELP := {
	"paineis": "Clique e arraste (ou passe o dedo) para tirar a areia e os detritos dos painéis!",
	"reciclador": "Clique (ou toque) quando a agulha estiver na ZONA VERDE. 3 tentativas.",
	"gerador": "Memorize a sequência de luzes e depois repita clicando nos botões.",
	"robos": "Clique num fio da esquerda e depois no conector da mesma cor à direita.",
}
const TIME := {"paineis": 9.0, "reciclador": 12.0, "gerador": 14.0, "robos": 12.0}
const COLORS := [Color("e8604c"), Color("5ec8f0"), Color("8be07f"), Color("f2d541")]

var kind := "paineis"
var t := 0.0
var time_left := 10.0
var done := false
var score := 0.0
var result_t := 0.0
var msg := ""
var msg_t := 0.0

# paineis
var dust: Array = []
const DCOLS := 32
const DROWS := 13

# reciclador
var needle := 0.0
var needle_dir := 1.0
var needle_speed := 0.9
var zone := Vector2(0.4, 0.55)
var tries := 0
var hits := 0

# gerador
var seq: Array = []
var seq_pos := 0
var show_i := -1
var show_t := 0.0
var phase := "show"
var lit := -1
var lit_t := 0.0

# robos
var right_order: Array = []
var connected := {}
var selected := -1
var mistakes := 0


func setup(k: String) -> void:
	kind = k
	time_left = TIME.get(k, 10.0)
	match kind:
		"paineis":
			dust = []
			for i in DCOLS * DROWS:
				dust.append(true)
		"reciclador":
			_new_zone()
		"gerador":
			seq = []
			for i in 5:
				seq.append(randi() % 4)
			phase = "show"
			show_i = -1
			show_t = 0.6
		"robos":
			right_order = [0, 1, 2, 3]
			right_order.shuffle()


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	msg_t = maxf(0.0, msg_t - delta)
	lit_t = maxf(0.0, lit_t - delta)
	if done:
		result_t -= delta
		if result_t <= 0.0:
			set_process(false)
			finished.emit(score)
		queue_redraw()
		return
	match kind:
		"reciclador":
			needle += needle_dir * needle_speed * delta
			if needle > 1.0:
				needle = 1.0
				needle_dir = -1.0
			elif needle < 0.0:
				needle = 0.0
				needle_dir = 1.0
		"gerador":
			if phase == "show":
				show_t -= delta
				if show_t <= 0.0:
					show_i += 1
					if show_i >= seq.size():
						phase = "input"
						lit = -1
					else:
						lit = seq[show_i]
						lit_t = 0.45
						show_t = 0.7
	if kind != "gerador" or phase == "input":
		time_left -= delta
	if time_left <= 0.0:
		_finish(_current_score())
	queue_redraw()


func _current_score() -> float:
	match kind:
		"paineis":
			var clean := 0
			for d in dust:
				if not d:
					clean += 1
			return clamp(float(clean) / dust.size() / 0.9, 0.0, 1.0)
		"reciclador":
			return float(hits) / 3.0
		"gerador":
			return float(seq_pos) / seq.size()
		"robos":
			return clampf((connected.size() - mistakes * 0.25) / 4.0, 0.0, 1.0)
	return 0.0


func _finish(s: float) -> void:
	if done:
		return
	done = true
	score = clampf(s, 0.0, 1.0)
	result_t = 1.6


func _flash(text: String) -> void:
	msg = text
	msg_t = 0.8


# ---------- Entrada ----------

func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if kind == "paineis":
			_scrub(event.position)
	elif event is InputEventScreenDrag and kind == "paineis":
		_scrub(event.position)


func _click(p: Vector2) -> void:
	match kind:
		"paineis":
			_scrub(p)
		"reciclador":
			tries += 1
			if needle >= zone.x and needle <= zone.y:
				hits += 1
				_flash("NA MOSCA!")
			else:
				_flash("ERROU!")
			if tries >= 3:
				_finish(float(hits) / 3.0)
			else:
				needle_speed += 0.35
				_new_zone()
		"gerador":
			if phase != "input":
				return
			for i in 4:
				if _simon_rect(i).has_point(p):
					lit = i
					lit_t = 0.25
					if seq[seq_pos] == i:
						seq_pos += 1
						if seq_pos >= seq.size():
							_flash("SEQUÊNCIA CERTA!")
							_finish(1.0)
					else:
						_flash("ERROU A SEQUÊNCIA")
						_finish(float(seq_pos) / seq.size())
		"robos":
			for i in 4:
				if _left_rect(i).has_point(p) and not connected.has(i):
					selected = i
					return
			if selected >= 0:
				for j in 4:
					if _right_rect(j).has_point(p):
						if right_order[j] == selected:
							connected[selected] = j
							_flash("CONECTADO!")
							if connected.size() >= 4:
								_finish(_current_score())
						else:
							mistakes += 1
							_flash("COR ERRADA!")
						selected = -1
						return


func _scrub(p: Vector2) -> void:
	var cw := AREA.size.x / DCOLS
	var ch := AREA.size.y / DROWS
	var cleaned_all := true
	for r in DROWS:
		for c in DCOLS:
			var idx := r * DCOLS + c
			if dust[idx]:
				var center := AREA.position + Vector2((c + 0.5) * cw, (r + 0.5) * ch)
				if center.distance_to(p) < 46.0:
					dust[idx] = false
				else:
					cleaned_all = false
	if cleaned_all:
		_finish(1.0)


func _new_zone() -> void:
	var w := randf_range(0.12, 0.18)
	var s := randf_range(0.05, 0.95 - w)
	zone = Vector2(s, s + w)


func _simon_rect(i: int) -> Rect2:
	return Rect2(AREA.position.x + 170 + (i % 2) * 240, AREA.position.y + 10 + (i / 2) * 165, 220, 150)


func _left_rect(i: int) -> Rect2:
	return Rect2(AREA.position.x + 60, AREA.position.y + 20 + i * 80, 70, 50)


func _right_rect(i: int) -> Rect2:
	return Rect2(AREA.end.x - 130, AREA.position.y + 20 + i * 80, 70, 50)


# ---------- Desenho ----------

func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.75))
	draw_rect(FRAME, Color("1f4f8f"))
	for x in range(int(FRAME.position.x), int(FRAME.end.x), 20):
		draw_line(Vector2(x, FRAME.position.y), Vector2(x, FRAME.end.y), Color(1, 1, 1, 0.05), 1.0)
	draw_rect(FRAME, Color("e8f1ff"), false, 4.0)
	draw_string(f, Vector2(FRAME.position.x, FRAME.position.y + 46), "MANUTENÇÃO: " + TITLES.get(kind, ""), HORIZONTAL_ALIGNMENT_CENTER, FRAME.size.x, 30, Color(1, 0.82, 0.2))
	draw_string(f, Vector2(FRAME.position.x, FRAME.position.y + 82), HELP.get(kind, ""), HORIZONTAL_ALIGNMENT_CENTER, FRAME.size.x, 18, Color.WHITE)
	# barra de tempo
	var tb := Rect2(FRAME.position.x + 60, FRAME.position.y + 100, FRAME.size.x - 120, 16)
	var frac := clampf(time_left / TIME.get(kind, 10.0), 0.0, 1.0)
	draw_rect(tb, Color(0, 0, 0, 0.4))
	draw_rect(Rect2(tb.position, Vector2(tb.size.x * frac, tb.size.y)), Color("8be07f") if frac > 0.3 else Color("e8604c"))
	draw_rect(tb, Color.WHITE, false, 2.0)
	match kind:
		"paineis":
			_draw_paineis()
		"reciclador":
			_draw_reciclador(f)
		"gerador":
			_draw_gerador(f)
		"robos":
			_draw_robos()
	draw_string(f, Vector2(FRAME.position.x, FRAME.end.y - 22), "Progresso: %d%%" % int(_current_score() * 100.0), HORIZONTAL_ALIGNMENT_CENTER, FRAME.size.x, 20, Color("9fc0ea"))
	if msg_t > 0.0:
		draw_string(f, Vector2(0, 380), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 48, Color(1, 1, 1, msg_t / 0.8))
	if done:
		draw_rect(Rect2(340, 300, 600, 140), Color(0.05, 0.1, 0.15, 0.95))
		draw_rect(Rect2(340, 300, 600, 140), Color(1, 0.82, 0.2), false, 4.0)
		var verdict := "PERFEITO!" if score >= 0.95 else ("BOM TRABALHO" if score >= 0.6 else ("REPARO PARCIAL" if score >= 0.25 else "QUASE NADA..."))
		draw_string(f, Vector2(340, 360), verdict, HORIZONTAL_ALIGNMENT_CENTER, 600, 40, Color(1, 0.82, 0.2))
		draw_string(f, Vector2(340, 410), "Eficiência do reparo: %d%%" % int(score * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 600, 24, Color.WHITE)


func _draw_paineis() -> void:
	var poly_col := Color("2c4f8a")
	draw_rect(AREA, poly_col)
	for i in 9:
		draw_line(Vector2(AREA.position.x + i * 100, AREA.position.y), Vector2(AREA.position.x + i * 100, AREA.end.y), Color("6f9be0"), 3.0)
	for i in 4:
		draw_line(Vector2(AREA.position.x, AREA.position.y + i * 113), Vector2(AREA.end.x, AREA.position.y + i * 113), Color("6f9be0"), 3.0)
	var cw := AREA.size.x / DCOLS
	var ch := AREA.size.y / DROWS
	for r in DROWS:
		for c in DCOLS:
			if dust[r * DCOLS + c]:
				var shade := 0.85 + 0.15 * sin(r * 1.7 + c * 2.3)
				draw_rect(Rect2(AREA.position + Vector2(c * cw, r * ch), Vector2(cw + 1, ch + 1)), Color(0.66 * shade, 0.42 * shade, 0.22 * shade, 0.95))
	draw_rect(AREA, Color.WHITE, false, 3.0)


func _draw_reciclador(f: Font) -> void:
	var g := Rect2(AREA.position.x + 40, AREA.position.y + 120, AREA.size.x - 80, 60)
	draw_rect(g, Color(0.1, 0.12, 0.15))
	draw_rect(Rect2(g.position.x + g.size.x * zone.x, g.position.y, g.size.x * (zone.y - zone.x), g.size.y), Color("8be07f"))
	draw_rect(g, Color.WHITE, false, 3.0)
	var nx := g.position.x + g.size.x * needle
	draw_colored_polygon(PackedVector2Array([Vector2(nx, g.position.y - 6), Vector2(nx - 14, g.position.y - 34), Vector2(nx + 14, g.position.y - 34)]), Color(1, 0.82, 0.2))
	draw_rect(Rect2(nx - 3, g.position.y - 6, 6, g.size.y + 12), Color(1, 0.82, 0.2))
	draw_string(f, Vector2(AREA.position.x, g.end.y + 70), "Acertos: %d / 3     Tentativas: %d / 3" % [hits, tries], HORIZONTAL_ALIGNMENT_CENTER, AREA.size.x, 26, Color.WHITE)


func _draw_gerador(f: Font) -> void:
	for i in 4:
		var r := _simon_rect(i)
		var on := lit == i and lit_t > 0.0
		var col: Color = COLORS[i]
		draw_rect(r, col if on else col.darkened(0.6))
		draw_rect(r, Color.WHITE if on else Color(1, 1, 1, 0.4), false, 5.0 if on else 2.0)
	var txt := "OBSERVE A SEQUÊNCIA..." if phase == "show" else "SUA VEZ: %d / %d" % [seq_pos, seq.size()]
	draw_string(f, Vector2(AREA.position.x, AREA.end.y + 6), txt, HORIZONTAL_ALIGNMENT_CENTER, AREA.size.x, 22, Color(1, 0.82, 0.2))


func _draw_robos() -> void:
	for i in 4:
		var l := _left_rect(i)
		draw_rect(l, COLORS[i])
		draw_rect(l, Color.WHITE if selected == i else Color(1, 1, 1, 0.4), false, 5.0 if selected == i else 2.0)
		var rr := _right_rect(i)
		draw_rect(rr, COLORS[right_order[i]].darkened(0.2))
		draw_rect(rr, Color(1, 1, 1, 0.4), false, 2.0)
	for k in connected:
		var a := _left_rect(k)
		var b := _right_rect(connected[k])
		draw_line(Vector2(a.end.x, a.get_center().y), Vector2(b.position.x, b.get_center().y), COLORS[k], 10.0)
	if selected >= 0:
		var a2 := _left_rect(selected)
		draw_line(Vector2(a2.end.x, a2.get_center().y), get_local_mouse_position(), COLORS[selected], 6.0)
