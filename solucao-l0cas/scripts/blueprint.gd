extends Control
## Painel de controle em estilo blueprint (papel azul de arquiteto).
## Layout do caderno: [R] [PESQUISAS] em cima, [M] [E] [D] embaixo.

signal screen_opened(id: String)

const BG := Color("1f4f8f")
const LINE := Color("e8f1ff")
const DIM := Color("9fc0ea")
const WARN := Color("ffd166")
const BAD := Color("ff7b7b")
const GOOD := Color("9ef0b0")
const PANEL_SIZE := Vector2(1060, 584)

const TITLES := {
	"home": "PAINEL — ONDE VOCÊ CONTROLA SUAS AÇÕES",
	"R": "R · RECURSOS — COMER E BEBER",
	"P": "PESQUISAS",
	"M": "M · MANUTENÇÕES",
	"E": "E · EVENTOS E ALERTAS",
	"D": "D · DIÁRIO",
}


class SegBar extends Control:
	var value := 0.0
	var color := Color.WHITE
	var segments := 12

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, c: Color) -> void:
		value = v
		color = c
		queue_redraw()

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (segments - 1)) / segments
		var filled := int(ceil(value / 100.0 * segments - 0.001))
		for i in segments:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			if i < filled:
				draw_rect(r, color)
			else:
				draw_rect(r, Color(1, 1, 1, 0.35), false, 1.0)


class IconView extends Control:
	var kind := ""

	func _init(k: String, s: float = 56.0) -> void:
		kind = k
		custom_minimum_size = Vector2(s, s)
		size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x
		var c := size / 2.0
		var L := Color("e8f1ff")
		var w := 2.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 1.0)
		match kind:
			"agua", "beber":
				draw_arc(c + Vector2(0, s * 0.1), s * 0.22, -0.3, PI + 0.3, 16, L, w)
				draw_line(c + Vector2(0, -s * 0.36), c + Vector2(-s * 0.21, s * 0.04), L, w)
				draw_line(c + Vector2(0, -s * 0.36), c + Vector2(s * 0.21, s * 0.04), L, w)
			"comer":
				draw_rect(Rect2(s * 0.2, s * 0.35, s * 0.6, s * 0.4), L, false, w)
				draw_line(Vector2(s * 0.2, s * 0.5), Vector2(s * 0.8, s * 0.5), L, w)
				draw_rect(Rect2(s * 0.3, s * 0.22, s * 0.4, s * 0.13), L, false, w)
			"solo":
				draw_line(Vector2(s * 0.1, s * 0.72), Vector2(s * 0.9, s * 0.72), L, w)
				draw_line(Vector2(c.x, s * 0.72), Vector2(c.x, s * 0.3), L, w)
				draw_arc(Vector2(c.x - s * 0.12, s * 0.38), s * 0.12, 0, TAU, 14, L, w)
				draw_arc(Vector2(c.x + s * 0.12, s * 0.3), s * 0.12, 0, TAU, 14, L, w)
			"vida":
				draw_arc(c - Vector2(s * 0.06, s * 0.06), s * 0.22, 0, TAU, 20, L, w)
				draw_line(c + Vector2(s * 0.1, s * 0.1), c + Vector2(s * 0.34, s * 0.34), L, w + 1.5)
				draw_arc(c - Vector2(s * 0.06, s * 0.06), s * 0.07, 0, TAU, 10, L, w)
			"terremoto":
				var pts := PackedVector2Array()
				for i in 9:
					var amp := s * 0.25 * (0.3 if i == 0 or i == 8 else 1.0)
					pts.append(Vector2(s * 0.08 + i * s * 0.105, c.y + (amp if i % 2 == 0 else -amp)))
				draw_polyline(pts, L, w)
			"tempestade":
				for i in 3:
					var y := s * 0.3 + i * s * 0.2
					draw_line(Vector2(s * 0.12 + i * 4, y), Vector2(s * 0.78, y), L, w)
					draw_arc(Vector2(s * 0.78, y - s * 0.07), s * 0.07, -PI / 2, PI / 2, 8, L, w)
			"clima":
				draw_rect(Rect2(c.x - s * 0.07, s * 0.15, s * 0.14, s * 0.48), L, false, w)
				draw_arc(Vector2(c.x, s * 0.72), s * 0.13, 0, TAU, 14, L, w)
			"paineis":
				var poly := PackedVector2Array([Vector2(s * 0.1, s * 0.75), Vector2(s * 0.8, s * 0.75), Vector2(s * 0.9, s * 0.3), Vector2(s * 0.2, s * 0.3), Vector2(s * 0.1, s * 0.75)])
				draw_polyline(poly, L, w)
				for j in 3:
					draw_line(Vector2(s * (0.3 + j * 0.2), s * 0.75), Vector2(s * (0.4 + j * 0.2), s * 0.3), L, 1.5)
			"reciclador":
				draw_arc(c, s * 0.34, 0.4, PI - 0.4, 14, L, w)
				draw_arc(c, s * 0.34, PI + 0.4, TAU - 0.4, 14, L, w)
				draw_arc(c + Vector2(0, s * 0.06), s * 0.12, -0.3, PI + 0.3, 12, L, w)
				draw_line(c + Vector2(0, -s * 0.2), c + Vector2(-s * 0.115, s * 0.03), L, w)
				draw_line(c + Vector2(0, -s * 0.2), c + Vector2(s * 0.115, s * 0.03), L, w)
			"gerador":
				draw_rect(Rect2(s * 0.3, s * 0.25, s * 0.4, s * 0.55), L, false, w)
				draw_arc(Vector2(c.x, s * 0.25), s * 0.2, PI, TAU, 12, L, w)
				draw_string(ThemeDB.fallback_font, Vector2(s * 0.33, s * 0.62), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.26), L)
			"robos":
				draw_rect(Rect2(s * 0.15, s * 0.4, s * 0.7, s * 0.28), L, false, w)
				draw_rect(Rect2(s * 0.25, s * 0.24, s * 0.25, s * 0.16), L, false, w)
				for i in 3:
					draw_arc(Vector2(s * (0.27 + i * 0.23), s * 0.76), s * 0.08, 0, TAU, 10, L, w)


var current := "home"
var content: Control
var live: Array = []
var sec := {}                       # blocos da página do diário (story, goals, hints)
var _sig := ""
var _sig_t := 0.0


func _ready() -> void:
	size = PANEL_SIZE
	theme = _make_theme()
	content = Control.new()
	content.size = PANEL_SIZE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	Game.changed.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for f in live:
		f.call()
	_sig_t += delta
	if _sig_t > 0.3:
		_sig_t = 0.0
		if _signature() != _sig:
			_rebuild()


func open_screen(id: String) -> void:
	current = id
	_rebuild()
	screen_opened.emit(id)


# ---------- Visual ----------

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.03)
	n.border_color = LINE
	n.set_border_width_all(2)
	n.set_content_margin_all(6)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1, 1, 1, 0.14)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(1, 1, 1, 0.3)
	var d := n.duplicate() as StyleBoxFlat
	d.border_color = Color(1, 1, 1, 0.3)
	d.bg_color = Color(0, 0, 0, 0.06)
	th.set_stylebox("normal", "Button", n)
	th.set_stylebox("hover", "Button", h)
	th.set_stylebox("pressed", "Button", p)
	th.set_stylebox("disabled", "Button", d)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", LINE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))
	th.set_color("font_color", "Label", LINE)
	th.set_color("default_color", "RichTextLabel", LINE)
	return th


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for x in range(0, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.12 if x % 100 == 0 else 0.05), 1.0)
	for y in range(0, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.12 if y % 100 == 0 else 0.05), 1.0)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), LINE, false, 2.0)
	draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color(1, 1, 1, 0.5), false, 1.0)
	draw_line(Vector2(12, 58), Vector2(size.x - 12, 58), Color(1, 1, 1, 0.5), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(26, 44), TITLES[current], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, LINE)
	var block := Rect2(size.x - 330, 18, 312, 34)
	draw_rect(block, Color(1, 1, 1, 0.6), false, 1.0)
	var day_txt := "TESTE (TERRA)" if Game.is_earth() else "SOL %d" % Game.day
	draw_string(font, block.position + Vector2(10, 23), "PRANCHA 01 · BASE AURORA · %s" % day_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)


# ---------- Construção ----------

func _signature() -> String:
	var parts: Array = [current, Game.blackout, Game.research_job.get("id", ""), Game.maint_job.get("id", ""),
		Game.shields["radiacao"], Game.shields["desastre"], Game.notes.size(), Game.today_log.size(), Game.diary.size(),
		Game.day, Game.today_event, Game.racoes, Game.garrafas, str(Game.pending_drops), Game.forecast_until, Game.goals_done.size(), str(Game.equip)]
	match current:
		"P":
			for r in Game.RESEARCH:
				parts.append(Game.can_research(r["id"]))
		"D":
			for e in Game.today_events:
				parts.append(int(Game.hour >= e["start"]) + int(Game.hour >= e["end"]))
			parts.append(Game.goals_done.size())
			parts.append(str(Game.page.get("hints", [])).length())
		"M":
			for m in Game.MAINT:
				parts.append(Game.can_maint(m["id"]))
	return str(parts)


func _rebuild() -> void:
	for c in content.get_children():
		c.queue_free()
	live.clear()
	sec.clear()
	_sig = _signature()
	queue_redraw()
	if current == "home":
		_build_home()
		return
	var back := Button.new()
	back.text = "< VOLTAR"
	back.position = Vector2(24, 70)
	back.size = Vector2(140, 40)
	back.pressed.connect(open_screen.bind("home"))
	content.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 122)
	scroll.size = Vector2(1012, 444)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(990, 0)
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	match current:
		"R":
			_build_r(box)
		"P":
			_build_p(box)
		"M":
			_build_m(box)
		"E":
			_build_e(box)
		"D":
			_build_d(box)


func _lbl(parent: Control, text: String, fs: int = 18, col: Color = LINE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _wrap(parent: Control, text: String, fs: int = 14, col: Color = DIM) -> Label:
	var l := _lbl(parent, text, fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(980, 0)
	return l


func _rich(parent: Control, bb: String, fs: int = 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(980, 0)
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.text = bb
	parent.add_child(r)
	return r


func _tile(rect: Rect2, letter: String, title: String, sub: String, id: String) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(open_screen.bind(id))
	content.add_child(b)
	var big := _lbl(b, letter, 64 if letter.length() == 1 else 40)
	big.position = Vector2(22, 10)
	var tl := _lbl(b, title, 22)
	tl.position = Vector2(24, rect.size.y - 74)
	var sl := _lbl(b, sub, 14, DIM)
	sl.position = Vector2(24, rect.size.y - 42)
	sl.size = Vector2(rect.size.x - 40, 0)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _drops_text() -> String:
	var d: Dictionary = Game.pending_drops
	if d.is_empty():
		return ""
	var parts := PackedStringArray()
	if d.has("garrafas"):
		parts.append("%d garrafas" % d["garrafas"])
	if d.has("racoes"):
		parts.append("%d rações" % d["racoes"])
	if d.has("energia"):
		parts.append("%d energia" % d["energia"])
	return ", ".join(parts)


func _build_home() -> void:
	var r := _tile(Rect2(30, 76, 300, 230), "R", "Recursos", "Comer e beber água", "R")
	var rl := _lbl(r, "", 16, WARN)
	rl.position = Vector2(110, 30)
	live.append(func() -> void:
		var need: bool = Game.res["saciedade"] < 40.0 or Game.res["hidratacao"] < 40.0
		rl.text = "! FOME/SEDE" if need else ""
		rl.visible = need and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.4)
	var p := _tile(Rect2(350, 76, 680, 230), "PESQUISAS", "Envie o robô a campo", "Os drops das pesquisas chegam no próximo sol", "P")
	var status := _lbl(p, "", 16, WARN)
	status.position = Vector2(24, 76)
	live.append(func() -> void:
		if Game.sealed():
			status.text = "Base selada pelo escudo — o robô não pode sair."
			status.add_theme_color_override("font_color", BAD)
		elif Game.research_job.is_empty():
			status.text = "Robô na garagem — pronto para sair."
			status.add_theme_color_override("font_color", GOOD)
		else:
			status.text = "Em campo: %s — %d%%" % [Game.research_def(Game.research_job["id"])["name"], int(Game.research_progress() * 100)]
			status.add_theme_color_override("font_color", WARN))
	var mt := _tile(Rect2(30, 326, 1000, 230), "M", "Manutenções", "Conserte equipamentos danificados — cada conserto é um minigame", "M")
	var bk := _lbl(mt, "", 20, BAD)
	bk.position = Vector2(110, 30)
	live.append(func() -> void:
		var n: int = Game.broken_count()
		bk.text = ("! %d EQUIPAMENTO(S) DANIFICADO(S)" % n) if n > 0 else "Tudo funcionando"
		bk.add_theme_color_override("font_color", BAD if n > 0 else GOOD)
		bk.visible = n == 0 or fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.4)
	var al := _lbl(mt, "", 18, BAD)
	al.position = Vector2(560, 24)
	var nx := _lbl(p, "", 16, Color(1.0, 0.82, 0.2))
	nx.position = Vector2(24, 106)
	live.append(func() -> void:
		var on := Game.any_alert()
		al.text = "! BASE DESPROTEGIDA" if on else ""
		al.visible = on and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.4
		var goals: Array = Game.page.get("goals", [])
		nx.text = "Pesquisas do diário: %d de %d feitas" % [Game.goals_done.size(), goals.size()] if goals.size() > 0 else "")


# ---------- R: comer e beber ----------

func _food_card(parent: Control, kind: String) -> void:
	var is_food := kind == "comer"
	var card := Button.new()
	card.custom_minimum_size = Vector2(484, 300)
	card.pressed.connect(Game.eat if is_food else Game.drink)
	parent.add_child(card)
	var icon := IconView.new(kind, 90)
	icon.position = Vector2(20, 20)
	card.add_child(icon)
	var t := _lbl(card, "COMER" if is_food else "BEBER ÁGUA", 30)
	t.position = Vector2(130, 22)
	var stock := _lbl(card, "", 22, WARN)
	stock.position = Vector2(130, 64)
	var meter_name := _lbl(card, "SACIEDADE" if is_food else "HIDRATAÇÃO", 15, DIM)
	meter_name.position = Vector2(20, 140)
	var bar := SegBar.new()
	bar.position = Vector2(20, 166)
	bar.size = Vector2(444, 24)
	card.add_child(bar)
	var pct := _lbl(card, "", 18)
	pct.position = Vector2(20, 198)
	var hint := _lbl(card, ("Clique para comer 1 ração (+%d)" % int(Game.EAT_GAIN)) if is_food else ("Clique para beber 1 garrafa (+%d)" % int(Game.DRINK_GAIN)), 15, DIM)
	hint.position = Vector2(20, 250)
	live.append(func() -> void:
		var v: float = Game.res["saciedade" if is_food else "hidratacao"]
		var n: int = Game.racoes if is_food else Game.garrafas
		stock.text = ("%d rações no estoque" if is_food else "%d garrafas no estoque") % n
		stock.add_theme_color_override("font_color", BAD if n <= 1 else WARN)
		bar.set_value(v, BAD if v < 30.0 else LINE)
		pct.text = "%d%%%s" % [int(v), "  — PRECISA %s!" % ("COMER" if is_food else "BEBER") if v < 30.0 else ""]
		pct.add_theme_color_override("font_color", BAD if v < 30.0 else LINE))


func _build_r(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_food_card(row, "comer")
	_food_card(row, "beber")
	_wrap(box, "Consumo: a saciedade cai %d por hora e a hidratação %d por hora. À noite caem mais (-12 e -16). Se chegar a 0, a missão acaba." % [int(Game.HUNGER_PER_HOUR), int(Game.THIRST_PER_HOUR)])
	_wrap(box, "Reposição: pesquisas de água e solo trazem garrafas e rações (chegam no próximo sol). O reciclador de água recupera garrafas toda noite.")
	var dt := _drops_text()
	if dt != "":
		_wrap(box, "Chegam no próximo sol: %s." % dt, 16, GOOD)


# ---------- P: pesquisas ----------

func _build_p(box: VBoxContainer) -> void:
	var st := _lbl(box, "", 17, WARN)
	var bar := SegBar.new()
	bar.custom_minimum_size = Vector2(980, 14)
	box.add_child(bar)
	live.append(func() -> void:
		if Game.sealed():
			st.text = "BASE SELADA: com um escudo ativo o robô não pode sair. Desligue a alavanca na sala."
			st.add_theme_color_override("font_color", BAD)
			bar.set_value(0, LINE)
		elif Game.research_job.is_empty():
			st.text = "Robô na garagem. Chance de sucesso: %d%% (depende do estado dos robôs)." % int(Game.success_chance() * 100)
			st.add_theme_color_override("font_color", WARN)
			bar.set_value(0, LINE)
		else:
			var dmg := " — DANIFICADO, chance reduzida!" if Game.research_job["damaged"] else ""
			st.text = "Em campo: %s — %d%%%s" % [Game.research_def(Game.research_job["id"])["name"], int(Game.research_progress() * 100), dmg]
			st.add_theme_color_override("font_color", WARN)
			bar.set_value(Game.research_progress() * 100.0, WARN))
	var dt := _drops_text()
	_lbl(box, ("Drops chegando no próximo sol: %s" % dt) if dt != "" else "Os drops das pesquisas chegam no próximo sol. Pesquisas com borda dourada são as sugeridas pelo Diário.", 15, GOOD if dt != "" else DIM)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for r in Game.RESEARCH:
		var id: String = r["id"]
		var why := Game.can_research(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(320, 160)
		b.disabled = why != ""
		b.pressed.connect(Game.start_research.bind(id))
		grid.add_child(b)
		var icon := IconView.new(id, 56)
		icon.position = Vector2(14, 14)
		b.add_child(icon)
		var n := _lbl(b, r["name"], 19)
		n.position = Vector2(84, 14)
		var info := _lbl(b, "%.1fh · %d energia" % [r["hours"], r["energy"]], 14, WARN)
		info.position = Vector2(84, 42)
		if (Game.page.get("goals", []) as Array).has(id):
			var done: bool = Game.goals_done.has(id)
			var tag := _lbl(b, "DIÁRIO: FEITA" if done else "DO DIÁRIO", 13, GOOD if done else Color(1.0, 0.82, 0.2))
			tag.position = Vector2(226, 44)
			if not done:
				var gsb := StyleBoxFlat.new()
				gsb.bg_color = Color(1.0, 0.82, 0.2, 0.12)
				gsb.border_color = Color(1.0, 0.82, 0.2)
				gsb.set_border_width_all(4)
				b.add_theme_stylebox_override("normal", gsb)
		var d := _lbl(b, r["desc"], 14, DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(292, 0)
		d.position = Vector2(14, 76)
		d.size = Vector2(292, 50)
		if why != "":
			var w := _lbl(b, why.to_upper(), 14, BAD)
			w.position = Vector2(14, 132)


# ---------- M: manutenções ----------

func _build_m(box: VBoxContainer) -> void:
	for m in Game.MAINT:
		var id: String = m["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		row.add_child(IconView.new(id, 64))
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(580, 0)
		row.add_child(col)
		var broken: bool = Game.is_broken(id)
		_lbl(col, m["name"], 19)
		_lbl(col, m["desc"], 13, DIM)
		var st := _lbl(col, ("DANIFICADO — precisa de conserto (custa %d de energia)" % m["energy"]) if broken else "FUNCIONANDO", 16, BAD if broken else GOOD)
		if broken:
			live.append(func() -> void: st.visible = fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.5)
		var why := Game.can_maint(id)
		var b := Button.new()
		b.text = "CONSERTAR" if why == "" else why.to_upper()
		b.disabled = why != ""
		b.custom_minimum_size = Vector2(240, 60)
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(Game.start_maint.bind(id))
		if broken and why == "":
			var rb := StyleBoxFlat.new()
			rb.bg_color = Color(0.8, 0.15, 0.1, 0.35)
			rb.border_color = BAD
			rb.set_border_width_all(3)
			b.add_theme_stylebox_override("normal", rb)
		row.add_child(b)
	_wrap(box, "Os equipamentos só precisam de manutenção quando são DANIFICADOS (por tempestades de areia ou terremotos sem escudo). Cada conserto é um minigame: com %d%% de eficiência ou mais, o equipamento volta a funcionar. Consertar os painéis é trabalho externo: não dá com a base selada." % int(Game.REPAIR_MIN * 100))


# ---------- E: eventos ----------

func _build_e(box: VBoxContainer) -> void:
	_lbl(box, "EVENTO DO SOL", 15, DIM)
	if Game.today_event == "":
		_rich(box, "[color=#9ef0b0][b]Sol calmo.[/b] Nenhum evento hoje: aproveite para pesquisar e limpar os painéis.[/color]", 20)
	else:
		var info: Dictionary = Game.EVENTS[Game.today_event]
		_rich(box, "[color=#ffd166][b]%s — o dia inteiro[/b][/color]\n%s" % [info["name"].to_upper(), info["hint"]], 20)
		var st := _lbl(box, "", 20)
		live.append(func() -> void:
			if Game.any_alert():
				st.text = "!!! BASE DESPROTEGIDA — puxe a alavanca na parede direita da sala !!!"
				st.add_theme_color_override("font_color", BAD)
				st.visible = fmod(Time.get_ticks_msec() / 350.0, 2.0) < 1.5
			else:
				st.text = "Base protegida pelo escudo."
				st.add_theme_color_override("font_color", GOOD)
				st.visible = true)
	_lbl(box, "ESCUDOS", 15, DIM)
	var sh := PackedStringArray()
	for id in ["radiacao", "desastre"]:
		var nm := "Escudo de radiação (alavanca RAD)" if id == "radiacao" else "Escudo de desastres (alavanca DES)"
		var on: bool = Game.shields[id]
		sh.append("[color=%s]%s %s[/color] — ativar custa %d de energia" % ["#9ef0b0" if on else "#e8f1ff", "● ATIVO" if on else "○ desligado", nm, Game.SHIELD_COST[id]])
	_rich(box, "\n".join(sh) + "\n[color=#9fc0ea]Os escudos ficam na parede direita da sala (fora do painel). Com escudo ativo as janelas fecham e a base fica selada.[/color]", 16)
	_lbl(box, "NOTIFICAÇÕES", 15, DIM)
	var ntxt := ""
	var colors := {"good": "#9ef0b0", "bad": "#ff7b7b", "alert": "#ffd166", "info": "#e8f1ff", "drop": "#9ef0b0"}
	for i in range(Game.notes.size() - 1, maxi(-1, Game.notes.size() - 13), -1):
		var n: Dictionary = Game.notes[i]
		ntxt += "[color=#9fc0ea]%s[/color]  [color=%s]%s[/color]\n" % [n["time"], colors.get(n["kind"], "#e8f1ff"), n["text"]]
	_rich(box, ntxt if ntxt != "" else "Sem notificações.", 15)


# ---------- D: diário ----------

func _event_line(d: int) -> String:
	var evs: Array = Game.events_for(d)
	if evs.is_empty():
		return "sol calmo, sem eventos."
	var parts := PackedStringArray()
	for e in evs:
		parts.append(Game.event_text(e))
	return "; ".join(parts) + "."


func _build_d(box: VBoxContainer) -> void:
	# Situação agora (antes ficava na aba E)
	var st := _lbl(box, "", 19)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(980, 0)
	live.append(func() -> void:
		if Game.today_event != "":
			var nm: String = Game.EVENTS[Game.today_event]["name"]
			if Game.any_alert():
				st.text = "!!! %s ACONTECENDO — BASE DESPROTEGIDA: puxe a alavanca %s na parede direita da sala !!!" % [nm.to_upper(), "RAD" if Game.EVENTS[Game.today_event]["shield"] == "radiacao" else "DES"]
				st.add_theme_color_override("font_color", BAD)
			else:
				st.text = "%s acontecendo — base protegida pelo escudo." % nm
				st.add_theme_color_override("font_color", GOOD)
		else:
			var e: Dictionary = Game.next_event()
			if not e.is_empty() and e.get("warned", false):
				st.text = "Atenção: %s chega às %s!" % [Game.EVENTS[e["type"]]["name"], Game.fmt_hour(e["start"])]
				st.add_theme_color_override("font_color", WARN)
			else:
				st.text = "Agora: tudo calmo lá fora."
				st.add_theme_color_override("font_color", GOOD))
	# Página do diário: história, pesquisas do dia e pistas
	# Cada parte da página é um bloco separado (o tutorial destaca cada um).
	var pg: Dictionary = Game.page
	var title := "Teste na Terra" if Game.is_earth() else "Sol %d" % Game.day
	sec["story"] = _rich(box, "[color=#ffd166][b]1. HISTÓRIA DO SOL — %s[/b][/color]\n[i]\"%s\"[/i]" % [title.to_upper(), pg.get("story", "")], 16)
	var goals: Array = pg.get("goals", [])
	if goals.size() > 0:
		var gt := "[color=#ffd166][b]2. PESQUISAS DE HOJE[/b][/color]  [color=#9fc0ea](cumpra todas: +%d de energia no próximo sol)[/color]\n" % Game.GOAL_BONUS
		for g in goals:
			var done: bool = Game.goals_done.has(g)
			var nm: String = Game.research_def(g)["name"]
			gt += ("[color=#9ef0b0][lb]X[rb] [s]%s[/s] — feita[/color]\n" % nm) if done else ("[lb]  [rb] %s\n" % nm)
		sec["goals"] = _rich(box, gt.strip_edges(), 16)
	var hints: PackedStringArray = pg.get("hints", PackedStringArray()).duplicate()
	if Game.is_earth() and Game.today_event == "":
		hints.append("Os instrutores avisaram que vão simular uma tempestade solar daqui a pouco, durante o treino.")
	if hints.size() > 0:
		var ht := "[color=#ffd166][b]3. PISTAS — o que pode acontecer[/b][/color]\n"
		for h in hints:
			ht += "[color=#ffd166][i]\"%s\"[/i][/color]\n" % h
		sec["hints"] = _rich(box, ht.strip_edges(), 16)
	var t := ""
	for d in range(Game.day + 1, Game.forecast_until + 1):
		var evs: Array = Game.events_for(d)
		var guess := "parece que vai ser um sol calmo"
		if not evs.is_empty():
			var names := PackedStringArray()
			for e in evs:
				names.append(Game.EVENTS[e["type"]]["name"].to_lower())
			guess = "os dados do clima indicam " + " e ".join(names)
		t += "[color=#9fc0ea][i]\"Sol %d: %s.\"[/i][/color]\n" % [d, guess]
	var dt := _drops_text()
	if dt != "":
		t += "[color=#9ef0b0]• Drops chegando no próximo sol: %s.[/color]\n" % dt
	t += "\n"
	if Game.today_log.size() > 0 and Game.running:
		t += "[color=#ffd166][b]Hoje[/b][/color]\n"
		for line in Game.today_log:
			t += "• %s\n" % line
		t += "\n"
	var colors := {"good": "#9ef0b0", "bad": "#ff7b7b", "alert": "#ffd166", "info": "#e8f1ff", "drop": "#9ef0b0"}
	if Game.notes.size() > 0:
		t += "[color=#ffd166][b]Notificações[/b][/color]\n"
		for i in range(Game.notes.size() - 1, maxi(-1, Game.notes.size() - 9), -1):
			var n: Dictionary = Game.notes[i]
			t += "[color=#9fc0ea]%s[/color]  [color=%s]%s[/color]\n" % [n["time"], colors.get(n["kind"], "#e8f1ff"), n["text"]]
		t += "\n"
	for i in range(Game.diary.size() - 1, -1, -1):
		var e: Dictionary = Game.diary[i]
		t += "[color=#ffd166][b]%s[/b][/color]  [color=#9fc0ea](pesquisas do diário: %s)[/color]\n" % [("Teste na Terra" if e["day"] == 0 else "Sol %d" % e["day"]), e.get("goals", "-")]
		if e.get("story", "") != "":
			t += "[color=#9fc0ea][i]\"%s\"[/i][/color]\n" % e["story"]
		for line in e["lines"]:
			t += "• %s\n" % line
		t += "\n"
	_rich(box, t, 16)
