extends Control
## Cena principal: sala com janelas (olhar para os lados), HUD com barras,
## painel blueprint que sobe ao passar o mouse embaixo, notificações, sons e fluxo dos sols.

const RoomScript := preload("res://scripts/room.gd")
const ExteriorScript := preload("res://scripts/exterior.gd")
const BlueprintScript := preload("res://scripts/blueprint.gd")
const MinigameScript := preload("res://scripts/minigames.gd")
const IMG_BASE := preload("res://art/gen/base.png")
const IMG_VISTA := preload("res://art/gen/vista.png")
const IMG_TARDE := preload("res://art/gen/vista_tarde.png")

const C_TEXT := Color("c8f7ea")
const C_DIM := Color("7fa8a0")
const C_ACCENT := Color("f2a541")
const C_BAD := Color("e8604c")
const C_GOOD := Color("8be07f")

const PAN_MAX := 1280.0
const PANEL_SHOWN_Y := 76.0
const PANEL_HIDDEN_Y := 740.0
const STRIP := Rect2(440, 680, 400, 36)

const TUT := [
	"Bem-vindo ao treinamento na Terra! Esta é a sala de controle da base. Leve o mouse até as BORDAS da tela (no celular: arraste o dedo ou segure as setas < >) para olhar ao redor.",
	"Ótimo! Agora CLIQUE (ou toque) EM UMA JANELA. Pelas janelas você vê o tempo lá fora e os eventos (tempestades, terremotos, radiação). Elas servem só para observar.",
	"Clique para voltar. Embaixo da tela fica a barra PAINEL: passe o mouse nela (no celular: toque nela) para abrir o painel de controle.",
	"Este é o painel: R = comer e beber · PESQUISAS · M = manutenções. Clique em R.",
	"Suas barras COM (fome) e ÁGUA (sede) ficam à esquerda e caem com o tempo. Comida e água são contadas em unidades. Clique em COMER.",
	"Agora clique em BEBER ÁGUA. Se a fome ou a sede chegarem a 0, a missão acaba. Coma e beba sempre que as barras ficarem baixas!",
	"Clique em < VOLTAR e abra PESQUISAS. Mande o robô a campo. Pesquisas custam energia e o que o robô encontrar (drops) chega só no PRÓXIMO SOL.",
	"Energia (no topo) é limitada: começa com 400. Os PAINÉIS SOLARES geram +100 às 06:00 de cada sol, mas eles chegaram DANIFICADOS! Manutenção só existe para equipamento danificado. Volte, abra M e CONSERTE OS PAINÉIS SOLARES (é um minigame).",
	"Agora vamos aprender a ler o DIÁRIO, a parte mais importante do jogo. Toda manhã, na TELA DE CARREGAMENTO do sol, aparece a página do diário. Clique em ENTENDI para ver um exemplo.",
	"DIÁRIO — 1. HISTÓRIA: o astronauta conta como foi a noite e qual é o objetivo do sol. Leia para entender o que a missão precisa. Clique em ENTENDI.",
	"DIÁRIO — 2. PESQUISAS DE HOJE: as pesquisas que o diário recomenda. Durante o sol elas aparecem com BORDA DOURADA na tela de Pesquisas. Faça TODAS e ganhe +50 de energia no sol seguinte. Clique em ENTENDI.",
	"DIÁRIO — 3. PISTAS: frases como 'acho que pode acontecer um terremoto à tarde' avisam O QUE pode vir e MAIS OU MENOS QUANDO. Guarde energia para o escudo certo! Clique em ENTENDI.",
	"Uma TEMPESTADE SOLAR simulada começou! A radiação solar está subindo. Feche o painel, olhe para a DIREITA da sala e clique na alavanca RAD (escudo de radiação).",
	"Escudo ativo! As janelas fecharam e a radiação parou de subir. Mas a base fica SELADA: sem pesquisas nem conserto dos painéis, e cada ativação custa muita energia. Quando o evento acabar, desligue. Clique na alavanca RAD de novo para desligar.",
	"Treinamento concluído! Prepare-se para o lançamento rumo a Marte...",
]

const TIPS := [
	"Dica: leia o diário na abertura de cada sol — ele sugere as pesquisas e dá pistas dos eventos.",
	"Dica: ative o escudo quando o evento começar e desligue quando ele acabar.",
	"Dica: os drops das pesquisas chegam só no sol seguinte.",
	"Dica: painéis solares funcionando geram +100 de energia às 06:00 de cada sol.",
	"Dica: com o escudo ativo a base fica selada — o robô não pode sair.",
	"Dica: coma e beba antes que as barras COM e ÁGUA fiquem vazias.",
	"Dica: tempestades de areia sujam os painéis solares.",
]


class HudView extends Control:
	var m: Control
	var strip_rect := Rect2()
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _box(r: Rect2) -> void:
		draw_rect(r, Color(0.03, 0.06, 0.07, 0.85))
		draw_rect(r, Color("3d4e54"), false, 2.0)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var alert := Game.any_alert()

		# Energia (topo)
		_box(Rect2(16, 8, 330, 58))
		draw_string(f, Vector2(28, 30), "ENERGIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7fa8a0"))
		var e := Game.energia
		var frac := e / Game.MAX_ENERGY
		var ec := Color("8be07f") if frac > 0.4 else (Color("f2d541") if frac > 0.15 else Color("e8604c"))
		if Game.blackout:
			if fmod(t, 1.0) < 0.6:
				draw_string(f, Vector2(28, 58), "SEM ENERGIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("e8604c"))
		else:
			draw_string(f, Vector2(28, 58), "%d" % int(e), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ec)
		draw_string(f, Vector2(130, 30), "de %d · painéis: +100 às 06:00" % int(Game.MAX_ENERGY), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("7fa8a0"))
		var bar := Rect2(130, 38, 200, 18)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(frac, 0.0, 1.0), bar.size.y)), ec)
		for i in range(1, 8):
			draw_line(Vector2(bar.position.x + i * 25, bar.position.y), Vector2(bar.position.x + i * 25, bar.end.y), Color(0, 0, 0, 0.5), 1.0)
		draw_rect(bar, Color("3d4e54"), false, 1.0)

		# Relógio + evento do sol (topo direito)
		_box(Rect2(1064, 8, 200, 58))
		draw_string(f, Vector2(1078, 52), Game.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("c8f7ea"))
		var dtxt := "TESTE" if Game.is_earth() else ("SOL %d/%d" % [Game.day, Game.MAX_DAYS] if Game.day <= Game.MAX_DAYS else "SOL %d" % Game.day)
		draw_string(f, Vector2(1180, 30), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2a541"))
		draw_string(f, Vector2(1180, 52), "até 18:00", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("7fa8a0"))
		var ev_txt := "SEM EVENTOS"
		var ev_col := Color("8be07f")
		var nxt: Dictionary = Game.next_event()
		if Game.today_event != "":
			ev_txt = "%s ATÉ %s" % [Game.EVENTS[Game.today_event]["name"].to_upper(), Game.fmt_hour(nxt.get("end", Game.hour))]
			ev_col = Color("e8604c") if alert and fmod(t, 0.8) < 0.5 else Color("f2a541")
		elif not nxt.is_empty() and not Game.is_earth() and nxt.get("warned", false):
			ev_txt = "%s ÀS %s" % [Game.EVENTS[nxt["type"]]["name"].to_upper(), Game.fmt_hour(nxt["start"])]
			ev_col = Color("f2d541")
		elif not Game.is_earth():
			ev_txt = "SEM ALERTAS"
			ev_col = Color("8be07f")
		_box(Rect2(1004, 70, 260, 28))
		draw_string(f, Vector2(1004, 90), ev_txt, HORIZONTAL_ALIGNMENT_CENTER, 260, 13, ev_col)

		# Barras de suporte de vida (fora do painel)
		_box(Rect2(10, 380, 178, 330))
		var bars := [["COM", "saciedade", Color("8be07f")], ["ÁGUA", "hidratacao", Color("4a8cf0")], ["RAD SOL", "radiacao", Color("f2c230")], ["O2", "oxigenio", Color("5ec8f0")]]
		for i in bars.size():
			var key: String = bars[i][1]
			var v: float = Game.res[key]
			var col: Color = bars[i][2]
			var danger := v >= 70.0 if key == "radiacao" else v <= 25.0
			if danger:
				col = Color("e8604c") if fmod(t, 0.8) < 0.5 else col
			var x := 24.0 + i * 41.0
			var r := Rect2(x, 430, 30, 222)
			draw_rect(r, Color(0, 0, 0, 0.5))
			var hgt := 222.0 * v / 100.0
			draw_rect(Rect2(x, 652 - hgt, 30, hgt), col)
			for s in range(1, 10):
				draw_line(Vector2(x, 430 + s * 22.2), Vector2(x + 30, 430 + s * 22.2), Color(0, 0, 0, 0.5), 1.0)
			draw_rect(r, Color("3d4e54"), false, 1.0)
			var top_txt := "%d" % int(v)
			if key == "saciedade":
				top_txt = "x%d" % Game.racoes
			elif key == "hidratacao":
				top_txt = "x%d" % Game.garrafas
			var tcol := Color("c8f7ea")
			if (key == "saciedade" and Game.racoes <= 1) or (key == "hidratacao" and Game.garrafas <= 1):
				tcol = Color("e8604c")
			draw_string(f, Vector2(x - 6, 422), top_txt, HORIZONTAL_ALIGNMENT_CENTER, 42, 15, tcol)
			draw_string(f, Vector2(x - 8, 672), bars[i][0], HORIZONTAL_ALIGNMENT_CENTER, 46, 11, Color("c8f7ea"))
		draw_string(f, Vector2(18, 400), "rações / garrafas", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7fa8a0"))
		draw_string(f, Vector2(18, 698), "fome · sede · radiação · ar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7fa8a0"))

		# Barra do painel (passe o mouse)
		var sr := strip_rect
		var blink: bool = alert and not m.panel_shown and fmod(t, 0.7) < 0.4
		draw_rect(sr, Color(0.85, 0.55, 0.1, 0.95) if blink else Color(0.12, 0.31, 0.56, 0.85))
		draw_rect(sr, Color("e8f1ff"), false, 2.0)
		var label := "PAINEL"
		if Game.blackout:
			label = "PAINEL (MODO RESERVA)"
		draw_string(f, Vector2(sr.position.x, sr.position.y + 25), label, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 18, Color("e8f1ff"))
		var up: bool = not m.panel_shown
		for side in [sr.position.x + 40, sr.end.x - 40]:
			var cy := sr.position.y + 18
			if up:
				draw_colored_polygon(PackedVector2Array([Vector2(side - 10, cy + 6), Vector2(side + 10, cy + 6), Vector2(side, cy - 6)]), Color("e8f1ff"))
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(side - 10, cy - 6), Vector2(side + 10, cy - 6), Vector2(side, cy + 6)]), Color("e8f1ff"))


class LoadingView extends Control:
	## Tela de viagem Terra -> Marte entre o tutorial e o jogo.
	signal finished
	const DURATION := 7.0
	var t := 0.0
	var stars: Array[Vector3] = []
	var tips: Array = []
	var done := false

	func _ready() -> void:
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 220:
			stars.append(Vector3(rng.randf() * 1280.0, rng.randf() * 720.0, rng.randf()))

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= DURATION + 1.0 and not done:
			done = true
			finished.emit()

	const LOG := [
		[0.00, "Ignição dos motores"],
		[0.10, "Separação de estágios"],
		[0.25, "Órbita de transferência para Marte"],
		[0.50, "Correção de rota no meio do caminho"],
		[0.75, "Aproximação de Marte"],
		[0.88, "Entrada na atmosfera — escudo térmico"],
		[0.96, "Paraquedas abertos"],
	]
	var trail: Array[Vector2] = []

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and t > 1.5 and not done:
			done = true
			finished.emit()

	func _bez(p: float) -> Vector2:
		var a := Vector2(250, 470)
		var c := Vector2(640, 110)
		var b := Vector2(1030, 440)
		return a.lerp(c, p).lerp(c.lerp(b, p), p)

	func _planet(c: Vector2, r: float, base: Color, spots: Array, rot: float, glow: Color) -> void:
		for i in 6:
			draw_circle(c, r + 8 + i * 6, Color(glow.r, glow.g, glow.b, 0.06 - i * 0.008))
		draw_circle(c, r, base)
		for s in spots:
			var ang: float = s[0] + rot
			var x := cos(ang) * r * 0.75
			if cos(ang) > -0.2:
				draw_circle(c + Vector2(x * 0.0 + sin(ang) * r * 0.6, s[1] * r), s[2] * r * (0.6 + 0.4 * absf(cos(ang))), base.darkened(0.3) if base.b < 0.5 else Color("4f9a4a"))
		# sombra (lado noturno)
		for i in 10:
			draw_circle(c + Vector2(r * 0.25 + i * 1.5, 0), r - i * 1.2, Color(0, 0, 0.05, 0.05))
		draw_arc(c, r + 3, 0, TAU, 64, Color(glow.r, glow.g, glow.b, 0.5), 4.0)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var p := clampf(t / DURATION, 0.0, 1.0)
		var ease_p := p * p * (3.0 - 2.0 * p)
		for i in 12:
			draw_rect(Rect2(0, i * 60, 1280, 61), Color("04070f").lerp(Color("141f3d"), i / 11.0))
		# nebulosa
		draw_circle(Vector2(640, 300), 420, Color(0.35, 0.2, 0.55, 0.06))
		draw_circle(Vector2(820, 220), 260, Color(0.2, 0.35, 0.6, 0.05))
		for s in stars:
			var a := 0.35 + 0.65 * absf(sin(t * (1.0 + s.z * 3.0) + s.x))
			var sx := fmod(s.x - t * 40.0 * (0.2 + s.z), 1280.0)
			if sx < 0.0:
				sx += 1280.0
			draw_rect(Rect2(sx, s.y, 1.5 + s.z * 2.5, 1.5 + s.z * 2.5), Color(1, 1, 1, a))
		_planet(Vector2(250, 470), 95, Color("2f6fc0"), [[0.0, -0.3, 0.35], [2.0, 0.25, 0.3], [4.0, 0.0, 0.25]], t * 0.6, Color(0.5, 0.75, 1))
		_planet(Vector2(1030, 440), 75 + ease_p * 25, Color("c1552d"), [[0.5, -0.2, 0.22], [2.5, 0.3, 0.16], [4.5, 0.05, 0.2]], t * 0.4, Color(1, 0.55, 0.3))
		# luas de Marte
		var moon := Vector2(1030, 440) + Vector2(cos(t * 1.3), sin(t * 1.3) * 0.35) * 140
		draw_circle(moon, 7, Color("9a8f86"))
		for i in 40:
			if i % 2 == 0:
				draw_line(_bez(i / 40.0), _bez((i + 1) / 40.0), Color(1, 1, 1, 0.25), 2.0)
		# foguete e rastro
		var pos := _bez(ease_p)
		if trail.is_empty() or trail[trail.size() - 1].distance_to(pos) > 4.0:
			trail.append(pos)
			if trail.size() > 60:
				trail.pop_front()
		for i in trail.size():
			var k := float(i) / maxf(trail.size(), 1)
			draw_circle(trail[i], 2.0 + k * 5.0, Color(1, 0.6 + 0.3 * k, 0.2, k * 0.5))
		var dir := (_bez(minf(ease_p + 0.01, 1.0)) - _bez(maxf(ease_p - 0.01, 0.0))).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var flame := 22.0 + sin(t * 35.0) * 8.0
		draw_colored_polygon(PackedVector2Array([pos - dir * 16 + nrm * 8, pos - dir * (16 + flame), pos - dir * 16 - nrm * 8]), Color("ffb627"))
		draw_colored_polygon(PackedVector2Array([pos - dir * 16 + nrm * 4, pos - dir * (16 + flame * 0.6), pos - dir * 16 - nrm * 4]), Color("fff1c0"))
		draw_colored_polygon(PackedVector2Array([pos + dir * 30, pos - dir * 16 + nrm * 11, pos - dir * 16 - nrm * 11]), Color("f1ebdc"))
		draw_circle(pos + dir * 5, 4, Color("5ec8f0"))
		# título e contador
		var title := "VIAGEM PARA MARTE" if p < 1.0 else "POUSO CONFIRMADO!"
		draw_string(f, Vector2(0, 74), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 44, Color("f2a541"))
		draw_string(f, Vector2(0, 112), "Dia %d de 210 de viagem  ·  %d milhões de km" % [int(ease_p * 210.0), int(ease_p * 225.0)], HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("9fc0ea"))
		# registro da missão
		draw_rect(Rect2(30, 140, 380, 222), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(30, 140, 380, 222), Color("3d4e54"), false, 2.0)
		draw_string(f, Vector2(46, 164), "REGISTRO DA MISSÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2a541"))
		var row := 0
		for e in LOG:
			if p >= e[0]:
				var ok: bool = p >= e[0] + 0.06
				draw_string(f, Vector2(46, 192 + row * 24), ("[OK] " if ok else "[..] ") + e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8be07f") if ok else Color("f2d541"))
				row += 1
		# barra de progresso
		var bar := Rect2(290, 610, 700, 22)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("f2a541"))
		for i in range(1, 10):
			draw_line(Vector2(bar.position.x + i * 70, bar.position.y), Vector2(bar.position.x + i * 70, bar.end.y), Color(0, 0, 0, 0.35), 1.0)
		draw_rect(bar, Color("e8f1ff"), false, 2.0)
		draw_string(f, Vector2(0, 602), "TERRA → MARTE   %d%%" % int(p * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color("e8f1ff"))
		if tips.size() > 0:
			var tip: String = tips[int(t / 2.6) % tips.size()]
			draw_string(f, Vector2(0, 668), tip, HORIZONTAL_ALIGNMENT_CENTER, 1280, 19, Color("c8f7ea"))
		if t > 1.5:
			draw_string(f, Vector2(0, 704), "clique para pular", HORIZONTAL_ALIGNMENT_CENTER, 1280, 13, Color(1, 1, 1, 0.35))
		# flash do pouso
		if p >= 1.0:
			var k2 := clampf(1.0 - (t - DURATION) / 0.8, 0.0, 1.0)
			draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.85, 0.6, 0.6 * k2))


class IntroView extends Control:
	## Abertura de cada sol: amanhecer animado, relógio, checklist e a página do diário.
	signal finished
	const CHECKS := ["Pressurização do módulo", "Gerador de oxigênio", "Reciclador de água", "Contato com a Terra"]
	var title := ""
	var subtitle := ""
	var earth := false
	var story := ""
	var goals: Array = []
	var hints: PackedStringArray = PackedStringArray()
	var duration := 12.0
	var touch := false
	var reader := false                 # modo "exemplo do diário" usado no tutorial
	var bg: Texture2D = null
	var highlight := -1
	var card_pos := Vector2(660, 66)
	var t := 0.0
	var done := false
	var dust: Array[Vector3] = []
	var stars: Array[Vector2] = []

	func _ready() -> void:
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 70:
			dust.append(Vector3(rng.randf() * 1280.0, 400.0 + rng.randf() * 320.0, rng.randf()))
		for i in 90:
			stars.append(Vector2(rng.randf() * 1280.0, rng.randf() * 360.0))

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= duration and not reader:
			_end()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and t > 1.0 and not reader:
			_end()

	func _end() -> void:
		if done:
			return
		done = true
		finished.emit()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		if reader:
			draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))
			_draw_card(f)
			return
		var rise := clampf(t / 3.5, 0.0, 1.0)
		var e := rise * rise * (3.0 - 2.0 * rise)
		var top_d := Color("3f74b8") if earth else Color("b8652a")
		var bot_d := Color("bfe3f5") if earth else Color("f4c27c")
		for i in 18:
			var k := i / 17.0
			draw_rect(Rect2(0, i * 24, 1280, 25), Color("0b1026").lerp(Color("2a1f3d"), k).lerp(top_d.lerp(bot_d, k), e * 0.85))
		for s in stars:
			draw_rect(Rect2(s, Vector2(2, 2)), Color(1, 1, 1, (1.0 - e) * 0.8))
		var sun := Vector2(980, lerpf(560.0, 290.0, e))
		draw_circle(sun, 150, Color(1, 0.85, 0.5, 0.10 * e))
		draw_circle(sun, 85, Color(1, 0.9, 0.6, 0.22 * e))
		draw_circle(sun, 44, Color(1, 0.97, 0.85))
		var dark := 0.65 * (1.0 - e)
		var far := (Color("7f9db5") if earth else Color("c77a45")).darkened(dark)
		var near := (Color("4d6d3c") if earth else Color("8a3f22")).darkened(dark)
		var ground := (Color("6f9a4a") if earth else Color("a9532c")).darkened(dark)
		var pts := PackedVector2Array()
		for i in 15:
			var x := -40.0 + i * 100.0
			pts.append(Vector2(x, 400.0 - absf(sin(x * 0.009)) * 70.0 - absf(sin(x * 0.023)) * 25.0))
		pts.append(Vector2(1320, 460))
		pts.append(Vector2(-40, 460))
		draw_colored_polygon(pts, far)
		draw_rect(Rect2(-20, 450, 1320, 280), ground)
		var near_pts := PackedVector2Array([Vector2(-40, 470), Vector2(200, 440), Vector2(420, 465), Vector2(700, 445), Vector2(1000, 470), Vector2(1320, 450), Vector2(1320, 480), Vector2(-40, 480)])
		draw_colored_polygon(near_pts, near)
		# silhueta da base
		var sil := Color(0.08, 0.06, 0.08, 0.9)
		var dome := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			dome.append(Vector2(330, 520) + Vector2(cos(a), sin(a)) * 90)
		draw_colored_polygon(dome, sil)
		draw_rect(Rect2(420, 480, 160, 40), sil)
		draw_rect(Rect2(600, 490, 90, 30), sil)
		draw_rect(Rect2(328, 390, 5, 40), sil)
		if fmod(t, 1.2) < 0.6:
			draw_circle(Vector2(330, 388), 5, Color("e8604c"))
		for d in dust:
			var x2 := fmod(d.x + t * 30.0 * (0.4 + d.z), 1300.0) - 10.0
			draw_rect(Rect2(x2, d.y, 3, 3), Color(1, 0.85, 0.6, 0.35))
		if bg != null and not earth:
			# vista geral da base, com a câmera passeando devagar e o céu clareando
			var tsz := bg.get_size()
			var src := Rect2(0, 0, tsz.y * 1280.0 / 720.0, tsz.y)
			src.position.x = (tsz.x - src.size.x) * clampf(t / 20.0, 0.0, 1.0)
			draw_texture_rect_region(bg, Rect2(0, 0, 1280, 720), src)
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.03, 0.14, 0.75 * (1.0 - e)))
			for d in dust:
				var x4 := fmod(d.x + t * 30.0 * (0.4 + d.z), 1300.0) - 10.0
				draw_rect(Rect2(x4, d.y, 3, 3), Color(1, 0.85, 0.6, 0.35))
		# faixa escura para leitura
		for i in 16:
			draw_rect(Rect2(i * 40, 0, 40, 720), Color(0, 0, 0, 0.5 * (1.0 - i / 16.0)))
		# relógio e título
		var mins := int(lerpf(54.0, 60.0, clampf(t / 1.6, 0.0, 1.0)))
		var clock := "05:%02d" % mins if mins < 60 else "06:00"
		draw_string(f, Vector2(70, 140), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("c8f7ea"))
		var a2 := clampf((t - 0.5) / 0.6, 0.0, 1.0)
		draw_string(f, Vector2(70 - (1.0 - a2) * 60.0, 250), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color(1, 0.82, 0.2, a2))
		draw_string(f, Vector2(74, 296), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.9, 1, a2))
		for i in CHECKS.size():
			var ti := 1.2 + i * 0.5
			if t < ti:
				continue
			var ok := t > ti + 0.35
			draw_string(f, Vector2(74, 370 + i * 34), CHECKS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			draw_string(f, Vector2(480, 370 + i * 34), "OK" if ok else "...", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8be07f") if ok else Color("f2d541"))
		var p := clampf(t / 3.4, 0.0, 1.0)
		var bar := Rect2(74, 530, 460, 18)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("8be07f") if p >= 1.0 else Color("f2a541"))
		draw_rect(bar, Color.WHITE, false, 2.0)
		draw_string(f, Vector2(74, 578), "SISTEMAS PRONTOS" if p >= 1.0 else "Preparando a base... %d%%" % int(p * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8be07f") if p >= 1.0 else Color("f2d541"))
		_draw_card(f)
		if t > 1.0 and fmod(t, 1.0) < 0.7:
			draw_string(f, Vector2(0, 704), ("toque" if touch else "clique") + " para começar o sol", HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color(1, 1, 1, 0.65))

	## Retângulos (na tela) das 3 partes da página: 0 história, 1 pesquisas, 2 pistas.
	func section_rect(i: int) -> Rect2:
		var c := card_pos
		match i:
			0:
				return Rect2(c + Vector2(14, 66), Vector2(552, 196))
			1:
				return Rect2(c + Vector2(14, 270), Vector2(552, 128))
		return Rect2(c + Vector2(14, 406), Vector2(552, 160))

	## Página do diário em papel pautado: história, pesquisas de hoje e pistas.
	func _draw_card(f: Font) -> void:
		if story == "":
			return
		var ca := clampf((t - 0.6) / 0.7, 0.0, 1.0) if not reader else 1.0
		var c := card_pos + Vector2(0, (1.0 - ca) * 40.0)
		var ink := Color(0.18, 0.13, 0.08, ca)
		var brown := Color(0.45, 0.22, 0.06, ca)
		draw_rect(Rect2(c + Vector2(10, 12), Vector2(580, 580)), Color(0, 0, 0, 0.35 * ca))
		draw_rect(Rect2(c, Vector2(580, 580)), Color(0.95, 0.9, 0.79, ca))
		for i in 21:
			draw_line(c + Vector2(12, 62 + i * 25), c + Vector2(568, 62 + i * 25), Color(0.5, 0.62, 0.8, 0.3 * ca), 1.0)
		draw_line(c + Vector2(46, 0), c + Vector2(46, 580), Color(0.85, 0.3, 0.3, 0.5 * ca), 2.0)
		draw_string(f, c + Vector2(60, 44), "Diário — " + title.to_lower().capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, brown)
		# 1. história
		draw_string(f, c + Vector2(60, 88), "1. HISTÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, brown)
		draw_multiline_string(f, c + Vector2(60, 112), story, HORIZONTAL_ALIGNMENT_LEFT, 500, 15, 7, ink)
		# 2. pesquisas de hoje
		draw_string(f, c + Vector2(60, 292), "2. PESQUISAS DE HOJE  (faça todas: +%d de energia)" % Game.GOAL_BONUS, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, brown)
		var gy := 320.0
		for g in goals:
			draw_rect(Rect2(c + Vector2(62, gy - 15), Vector2(16, 16)), ink, false, 2.0)
			draw_string(f, c + Vector2(90, gy), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
			gy += 26.0
		# 3. pistas
		draw_string(f, c + Vector2(60, 428), "3. PISTAS — o que pode acontecer", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, brown)
		var hy := 452.0
		for h in hints:
			if hy > 560.0:
				break
			draw_multiline_string(f, c + Vector2(60, hy), "\"" + h + "\"", HORIZONTAL_ALIGNMENT_LEFT, 500, 14, 3, Color(0.62, 0.16, 0.1, ca))
			hy += 20.0 * mini(3, int(ceil(h.length() / 62.0))) + 8.0
		# destaque do tutorial
		if highlight >= 0:
			for i in 3:
				if i != highlight:
					draw_rect(section_rect(i), Color(0.1, 0.1, 0.12, 0.55))
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			draw_rect(section_rect(highlight).grow(4.0 + pulse * 5.0), Color(1.0, 0.82, 0.2), false, 6.0)


class MenuView extends Control:
	## Menu inicial: paisagem de Marte animada, título e botões.
	var t := 0.0
	var stars: Array[Vector3] = []
	var dust: Array[Vector3] = []
	var buttons: Array = []   # [texto, Callable, destaque]
	var bg: Texture2D = null

	func _ready() -> void:
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 160:
			stars.append(Vector3(rng.randf() * 1280.0, rng.randf() * 380.0, rng.randf()))
		for i in 80:
			dust.append(Vector3(rng.randf() * 1280.0, 470.0 + rng.randf() * 250.0, rng.randf()))
		var y := 300.0
		for b in buttons:
			_make_button(b[0], y, b[1], b[2])
			y += 82.0

	func _make_button(text: String, y: float, cb: Callable, primary: bool) -> void:
		var b := Button.new()
		b.text = text
		b.position = Vector2(450, y)
		b.size = Vector2(380, 66)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.85, 0.45, 0.15, 0.95) if primary else Color(0.05, 0.08, 0.12, 0.8)
		n.border_color = Color(1.0, 0.82, 0.2) if primary else Color("e8f1ff")
		n.set_border_width_all(3)
		n.shadow_color = Color(0, 0, 0, 0.5)
		n.shadow_size = 8
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = Color(1.0, 0.6, 0.2) if primary else Color(0.2, 0.32, 0.5, 0.95)
		h.border_color = Color.WHITE
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(cb)
		add_child(b)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		for i in 20:
			draw_rect(Rect2(0, i * 24, 1280, 25), Color("120c22").lerp(Color("c46a3a"), pow(i / 19.0, 1.6)))
		for s in stars:
			draw_rect(Rect2(s.x, s.y, 1.5 + s.z * 2.0, 1.5 + s.z * 2.0), Color(1, 1, 1, (0.3 + 0.7 * absf(sin(t * (0.8 + s.z * 2.0) + s.x))) * (1.0 - s.y / 420.0)))
		# a Terra, um pontinho azul no céu
		draw_circle(Vector2(1150, 260), 7, Color("5ec8f0"))
		draw_circle(Vector2(1150, 260), 14, Color(0.4, 0.7, 1, 0.15))
		# Fobos passando
		draw_circle(Vector2(fmod(200.0 + t * 12.0, 1400.0) - 60.0, 230), 5, Color("9a8f86"))
		draw_circle(Vector2(240, 470), 60, Color(1, 0.85, 0.6, 0.18))
		draw_circle(Vector2(240, 470), 30, Color(1, 0.93, 0.8))
		var far := PackedVector2Array()
		for i in 15:
			var x := -40.0 + i * 100.0
			far.append(Vector2(x, 455.0 - absf(sin(x * 0.008)) * 70.0 - absf(sin(x * 0.021)) * 20.0))
		far.append(Vector2(1320, 500))
		far.append(Vector2(-40, 500))
		draw_colored_polygon(far, Color("7a3a24"))
		draw_rect(Rect2(-20, 490, 1320, 240), Color("8f4126"))
		for i in 6:
			draw_rect(Rect2(-20, 505 + i * 36, 1320, 5), Color("7d3820"))
		# base Aurora
		var dome := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			dome.append(Vector2(1000, 560) + Vector2(cos(a), sin(a)) * 90)
		draw_colored_polygon(dome, Color("d8d2c4"))
		draw_rect(Rect2(1080, 520, 170, 40), Color("d8d2c4"))
		draw_rect(Rect2(1080, 536, 170, 8), Color("e9a93a"))
		for i in 3:
			draw_rect(Rect2(950 + i * 36, 505, 22, 14), Color("5ec8f0"))
		draw_rect(Rect2(998, 430, 5, 45), Color("8a8f90"))
		if fmod(t, 1.2) < 0.6:
			draw_circle(Vector2(1000, 428), 6, Color("e8604c"))
		# rover passeando
		var rx := 80.0 + fmod(t * 25.0, 520.0)
		draw_rect(Rect2(rx, 600, 70, 24), Color("e9c74a"))
		draw_rect(Rect2(rx + 8, 588, 26, 14), Color("2b3a3f"))
		for w in 3:
			draw_circle(Vector2(rx + 10 + w * 25, 628), 8, Color("1f1f1f"))
		for d in dust:
			var x2 := fmod(d.x + t * 25.0 * (0.4 + d.z), 1300.0) - 10.0
			draw_rect(Rect2(x2, d.y, 3, 3), Color(1, 0.85, 0.6, 0.4))
		if bg != null:
			# imagem da base cobrindo a tela, com leve movimento de câmera
			var tsz := bg.get_size()
			var src := Rect2(0, 0, tsz.y * 1280.0 / 720.0, tsz.y)
			src.position.x = (tsz.x - src.size.x) * (0.5 + 0.5 * sin(t * 0.08))
			draw_texture_rect_region(bg, Rect2(0, 0, 1280, 720), src)
			for i in 12:
				draw_rect(Rect2(0, i * 22, 1280, 22), Color(0.05, 0.03, 0.08, 0.6 * (1.0 - i / 12.0)))
			draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.2))
			for d in dust:
				var x3 := fmod(d.x + t * 40.0 * (0.4 + d.z), 1300.0) - 10.0
				draw_rect(Rect2(x3, d.y - 200.0, 4, 4), Color(1, 0.85, 0.6, 0.45))
		# título
		var pulse := 0.5 + 0.5 * sin(t * 2.0)
		draw_string(f, Vector2(4, 156), "FIVE SOLS IN MARS", HORIZONTAL_ALIGNMENT_CENTER, 1280, 86, Color(0, 0, 0, 0.5))
		draw_string(f, Vector2(0, 150), "FIVE SOLS IN MARS", HORIZONTAL_ALIGNMENT_CENTER, 1280, 86, Color(1.0, 0.82 + 0.1 * pulse, 0.3))
		draw_string(f, Vector2(0, 205), "Sobreviva a cinco sols em Marte", HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("f1e3cc"))
		draw_line(Vector2(440, 230), Vector2(840, 230), Color(1, 0.82, 0.2, 0.6), 2.0)
		draw_string(f, Vector2(0, 708), "v1.0 · feito em Godot 4.7", HORIZONTAL_ALIGNMENT_CENTER, 1280, 13, Color(1, 1, 1, 0.4))


class EndDayView extends Control:
	## Tela de fim do sol / vitória / derrota: pôr do sol em Marte, estado do
	## astronauta (barras animadas), equipamentos e o relatório do dia.
	var t := 0.0
	var bg: Texture2D = null
	var kind := "day"          # day | win | dead | tutorial
	var title := ""
	var subtitle := ""
	var left_title := "ESTADO DO ASTRONAUTA"
	var right_title := "RELATÓRIO DO SOL"
	var goals: Array = []      # [[nome, concluída], ...]
	var research_today := -1
	var badge := ""
	var body := ""
	var buttons: Array = []    # [texto, Callable, destaque]
	var stars: Array[Vector3] = []
	var dust: Array[Vector3] = []
	var rich: RichTextLabel
	const L := Rect2(56, 168, 560, 450)
	const R := Rect2(664, 168, 560, 450)

	func _ready() -> void:
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 120:
			stars.append(Vector3(rng.randf() * 1280.0, rng.randf() * 260.0, rng.randf()))
		for i in 60:
			dust.append(Vector3(rng.randf() * 1280.0, 380.0 + rng.randf() * 340.0, rng.randf()))
		var top := R.position.y + 62.0
		if not goals.is_empty():
			top += 34.0 + goals.size() * 30.0
		if research_today >= 0:
			top += 34.0
		if badge != "":
			top += 56.0
		rich = RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.scroll_active = true
		rich.position = Vector2(R.position.x + 26, top)
		rich.size = Vector2(R.size.x - 52, R.end.y - top - 18)
		rich.add_theme_font_size_override("normal_font_size", 15)
		rich.add_theme_font_size_override("bold_font_size", 15)
		rich.add_theme_color_override("default_color", Color("dfe9ea"))
		rich.text = body
		rich.modulate.a = 0.0
		add_child(rich)
		var bw := 300.0
		var total := buttons.size() * bw + (buttons.size() - 1) * 24.0
		var x := 640.0 - total / 2.0
		for b in buttons:
			_make_button(b[0], Vector2(x, 638), bw, b[1], b[2])
			x += bw + 24.0

	func _make_button(text: String, pos: Vector2, w: float, cb: Callable, primary: bool) -> void:
		var b := Button.new()
		b.text = text
		b.position = pos
		b.size = Vector2(w, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.85, 0.45, 0.15, 0.95) if primary else Color(0.05, 0.08, 0.12, 0.85)
		n.border_color = Color(1.0, 0.82, 0.2) if primary else Color("e8f1ff")
		n.set_border_width_all(3)
		n.shadow_color = Color(0, 0, 0, 0.5)
		n.shadow_size = 8
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = Color(1.0, 0.6, 0.2) if primary else Color(0.2, 0.32, 0.5, 0.95)
		h.border_color = Color.WHITE
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(cb)
		b.modulate.a = 0.0
		add_child(b)
		create_tween().tween_property(b, "modulate:a", 1.0, 0.4).set_delay(1.2)

	func _process(delta: float) -> void:
		t += delta
		if rich != null:
			rich.modulate.a = clampf((t - 0.6) / 0.5, 0.0, 1.0)
		queue_redraw()

	func _ease(delay: float, dur := 0.6) -> float:
		var k := clampf((t - delay) / dur, 0.0, 1.0)
		return 1.0 - pow(1.0 - k, 3.0)

	func _card(r: Rect2, head: String, a: float, accent: Color) -> Rect2:
		var off := Vector2(0, 30.0 * (1.0 - a))
		var rr := Rect2(r.position + off, r.size)
		draw_rect(Rect2(rr.position + Vector2(6, 8), rr.size), Color(0, 0, 0, 0.35 * a))
		draw_rect(rr, Color(0.03, 0.05, 0.07, 0.86 * a))
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, 46)), Color(accent.r, accent.g, accent.b, 0.22 * a))
		draw_rect(Rect2(rr.position, Vector2(6, rr.size.y)), Color(accent.r, accent.g, accent.b, a))
		draw_rect(rr, Color(1, 1, 1, 0.18 * a), false, 2.0)
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(24, 32), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(accent.r, accent.g, accent.b, a))
		return rr

	func _bar(pos: Vector2, label: String, v: float, maxv: float, col: Color, k: float, a: float, txt := "") -> void:
		var f := ThemeDB.fallback_font
		draw_string(f, pos + Vector2(0, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.93, 0.93, a))
		var br := Rect2(pos + Vector2(150, 2), Vector2(280, 18))
		draw_rect(br, Color(1, 1, 1, 0.08 * a))
		var fill := clampf(v / maxv, 0.0, 1.0) * k
		draw_rect(Rect2(br.position, Vector2(br.size.x * fill, br.size.y)), Color(col.r, col.g, col.b, a))
		draw_rect(Rect2(br.position, Vector2(br.size.x * fill, 5)), Color(1, 1, 1, 0.25 * a))
		for i in range(1, 10):
			draw_rect(Rect2(br.position.x + br.size.x * i / 10.0, br.position.y, 1, br.size.y), Color(0, 0, 0, 0.35 * a))
		draw_rect(br, Color(1, 1, 1, 0.25 * a), false, 1.0)
		var s := txt if txt != "" else "%d%%" % int(round(v * k))
		draw_string(f, pos + Vector2(446, 17), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.r, col.g, col.b, a).lightened(0.2))

	func _check(c: Vector2, ok: bool, a: float) -> void:
		draw_circle(c, 11, Color(0.55, 0.88, 0.5, a) if ok else Color(1, 1, 1, 0.12 * a))
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 5), c + Vector2(6, -5)]), Color(0.05, 0.15, 0.05, a), 3.0)
		else:
			draw_arc(c, 11, 0, TAU, 20, Color(0.95, 0.75, 0.3, a), 2.0)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var dead := kind == "dead"
		var accent := Color("e8604c") if dead else (Color("ffd23f") if kind == "win" else Color("f2a541"))
		# fundo: pôr do sol renderizado em 3D, com câmera descendo devagar
		if bg != null:
			var tsz := bg.get_size()
			var zoom := 1.08 - 0.05 * clampf(t / 12.0, 0.0, 1.0)
			var sw := tsz.x / zoom
			var sh := tsz.y / zoom
			var src := Rect2((tsz.x - sw) / 2.0 + sin(t * 0.1) * 8.0, (tsz.y - sh) / 2.0, sw, sh)
			draw_texture_rect_region(bg, Rect2(0, 0, 1280, 720), src)
		# a noite chegando: céu escurece e estrelas aparecem
		var night := clampf(t / 6.0, 0.0, 1.0)
		for i in 14:
			draw_rect(Rect2(0, i * 20, 1280, 20), Color(0.06, 0.03, 0.12, (0.55 + 0.25 * night) * (1.0 - i / 14.0)))
		for s in stars:
			var sa := night * (0.3 + 0.7 * absf(sin(t * (0.6 + s.z) + s.x))) * (1.0 - s.y / 280.0)
			draw_rect(Rect2(s.x, s.y, 1.5 + s.z * 1.5, 1.5 + s.z * 1.5), Color(1, 1, 1, sa * 0.8))
		for d in dust:
			var dx := fmod(d.x + t * 30.0 * (0.4 + d.z), 1300.0) - 10.0
			draw_rect(Rect2(dx, d.y, 3, 3), Color(1, 0.8, 0.55, 0.35))
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.25, 0.0, 0.0, 0.45) if dead else Color(0, 0, 0, 0.18))
		for i in 10:
			draw_rect(Rect2(0, 560 + i * 16, 1280, 16), Color(0, 0, 0, 0.05 * i))
		# título
		var ta := _ease(0.0, 0.5)
		var ty := 84.0 - 20.0 * (1.0 - ta)
		draw_string(f, Vector2(4, ty + 4), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 58, Color(0, 0, 0, 0.55 * ta))
		draw_string(f, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 58, Color(accent.r, accent.g, accent.b, ta))
		draw_string(f, Vector2(0, ty + 42), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(0.95, 0.9, 0.82, ta))
		var lw := 380.0 * ta
		draw_rect(Rect2(640 - lw / 2.0, ty + 58, lw, 2), Color(accent.r, accent.g, accent.b, 0.7 * ta))
		# cartão esquerdo: astronauta, suprimentos e equipamentos
		var a1 := _ease(0.2)
		var lr := _card(L, left_title, a1, Color("5ec8f0"))
		var k := _ease(0.5, 1.2)
		var y := lr.position.y + 66.0
		var bars := [["Comida", Game.res["saciedade"], Color("8be07f")], ["Água", Game.res["hidratacao"], Color("4a8cf0")],
			["Oxigênio", Game.res["oxigenio"], Color("5ec8f0")], ["Radiação solar", Game.res["radiacao"], Color("f2c230") if Game.res["radiacao"] < 70.0 else Color("e8604c")]]
		for b in bars:
			_bar(Vector2(lr.position.x + 26, y), b[0], b[1], 100.0, b[2], k, a1)
			y += 36.0
		_bar(Vector2(lr.position.x + 26, y), "Energia", Game.energia, Game.MAX_ENERGY, Color("f2d541"), k, a1, "%d/%d" % [int(Game.energia * k), int(Game.MAX_ENERGY)])
		y += 50.0
		# suprimentos
		var sx := lr.position.x + 26.0
		draw_rect(Rect2(sx, y, 24, 18), Color(0.8, 0.6, 0.3, a1))
		draw_rect(Rect2(sx, y, 24, 5), Color(0.95, 0.8, 0.5, a1))
		draw_string(f, Vector2(sx + 34, y + 16), "%d rações" % Game.racoes, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, a1))
		sx += 200.0
		draw_rect(Rect2(sx + 6, y - 4, 12, 24), Color(0.3, 0.55, 0.95, a1))
		draw_rect(Rect2(sx + 9, y - 9, 6, 6), Color(0.85, 0.9, 1, a1))
		draw_string(f, Vector2(sx + 34, y + 16), "%d garrafas" % Game.garrafas, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, a1))
		y += 44.0
		draw_string(f, Vector2(lr.position.x + 26, y + 14), "EQUIPAMENTOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.75, 0.75, a1))
		y += 26.0
		var names := {"paineis": "Painéis solares", "reciclador": "Reciclador", "gerador": "Gerador de O2", "robos": "Robôs"}
		var i := 0
		for id in ["paineis", "reciclador", "gerador", "robos"]:
			var ok := not Game.is_broken(id)
			var cr := Rect2(lr.position.x + 26 + (i % 2) * 258, y + floorf(i / 2.0) * 42, 248, 34)
			draw_rect(cr, Color(0.2, 0.45, 0.25, 0.55 * a1) if ok else Color(0.55, 0.12, 0.08, 0.7 * a1))
			draw_rect(cr, Color(0.55, 0.88, 0.5, a1) if ok else Color(1, 0.4, 0.3, a1), false, 2.0)
			draw_circle(cr.position + Vector2(16, 17), 6, Color(0.55, 0.88, 0.5, a1) if ok else Color(1, 0.4, 0.3, a1 * (0.5 + 0.5 * sin(t * 6.0))))
			draw_string(f, cr.position + Vector2(30, 23), "%s · %s" % [names[id], "OK" if ok else "DANIFICADO"], HORIZONTAL_ALIGNMENT_LEFT, 214, 14, Color(1, 1, 1, a1))
			i += 1
		# cartão direito: pesquisas do diário + relatório
		var a2 := _ease(0.4)
		var rr := _card(R, right_title, a2, accent)
		var ry := rr.position.y + 62.0
		if badge != "":
			draw_rect(Rect2(rr.position.x + 26, ry, rr.size.x - 52, 44), Color(1, 0.82, 0.2, 0.18 * a2))
			draw_rect(Rect2(rr.position.x + 26, ry, rr.size.x - 52, 44), Color(1, 0.82, 0.2, a2), false, 2.0)
			draw_string(f, Vector2(rr.position.x + 26, ry + 31), "AVALIAÇÃO: " + badge.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x - 52, 22, Color(1, 0.88, 0.4, a2))
			ry += 56.0
		if not goals.is_empty():
			draw_string(f, Vector2(rr.position.x + 26, ry + 16), "PESQUISAS DO DIÁRIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.8, 0.4, a2))
			ry += 34.0
			for gi in goals.size():
				var g: Array = goals[gi]
				var ga := a2 * _ease(0.7 + gi * 0.25, 0.3)
				_check(Vector2(rr.position.x + 40, ry + 10), g[1], ga)
				draw_string(f, Vector2(rr.position.x + 62, ry + 16), g[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, ga) if g[1] else Color(0.75, 0.75, 0.75, ga))
				ry += 30.0
		if research_today >= 0:
			draw_string(f, Vector2(rr.position.x + 26, ry + 20), "Pesquisas hoje: %d   ·   Total da missão: %d" % [research_today, Game.research_done], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.55, 0.88, 0.5, a2))
		draw_rect(Rect2(rr.position.x + 26, rich.position.y - 8, rr.size.x - 52, 1), Color(1, 1, 1, 0.15 * a2))


class TutPointer extends Control:
	## Indicador do tutorial: holofote, moldura pulsante e seta "CLIQUE AQUI".
	var mode := ""          # "", "rect", "sides", "right"
	var target := Rect2()
	var label := ""
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _tag(f: Font, text: String, center: Vector2) -> void:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 30
		var r := Rect2(center.x - w / 2.0, center.y - 22, w, 40)
		r.position.x = clampf(r.position.x, 6, 1274 - w)
		draw_rect(r, Color(1.0, 0.82, 0.2))
		draw_rect(r, Color(0.2, 0.1, 0), false, 3.0)
		draw_string(f, Vector2(r.position.x, r.position.y + 29), text, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0.15, 0.08, 0))

	func _arrow_h(x: float, y: float, dir: float, gold: Color) -> void:
		var bob := sin(t * 7.0) * 12.0 * dir
		var tip := Vector2(x + bob, y)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-40 * dir, -34), tip + Vector2(-40 * dir, 34)]), gold)
		draw_rect(Rect2(tip.x - (90 if dir > 0 else -40) * 1.0, y - 12, 50, 24), gold)

	func _draw() -> void:
		if mode == "":
			return
		var f := ThemeDB.fallback_font
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		var gold := Color(1.0, 0.82, 0.2)
		match mode:
			"rect":
				var r := target
				var dim := Color(0, 0, 0, 0.5)
				draw_rect(Rect2(0, 0, 1280, r.position.y), dim)
				draw_rect(Rect2(0, r.end.y, 1280, 720.0 - r.end.y), dim)
				draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
				draw_rect(Rect2(r.end.x, r.position.y, 1280.0 - r.end.x, r.size.y), dim)
				var g := r.grow(4.0 + pulse * 8.0)
				draw_rect(g, gold, false, 7.0)
				draw_rect(g.grow(8), Color(1.0, 0.82, 0.2, 0.4 * pulse), false, 5.0)
				var ax := r.position.x + r.size.x / 2.0
				var bob := sin(t * 7.0) * 12.0
				if r.position.y > 170.0:
					var tip := Vector2(ax, r.position.y - 16 + bob)
					draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-32, -42), tip + Vector2(32, -42)]), gold)
					draw_rect(Rect2(ax - 11, tip.y - 92, 22, 52), gold)
					_tag(f, label, Vector2(ax, tip.y - 118))
				else:
					var tip2 := Vector2(ax, r.end.y + 16 - bob)
					draw_colored_polygon(PackedVector2Array([tip2, tip2 + Vector2(-32, 42), tip2 + Vector2(32, 42)]), gold)
					draw_rect(Rect2(ax - 11, tip2.y + 40, 22, 52), gold)
					_tag(f, label, Vector2(ax, tip2.y + 118))
			"sides":
				_arrow_h(70, 360, -1.0, gold)
				_arrow_h(1210, 360, 1.0, gold)
				_tag(f, label, Vector2(640, 300))
			"right":
				_arrow_h(1210, 360, 1.0, gold)
				_tag(f, label, Vector2(980, 300))


class FlashView extends Control:
	## Flash de tela e borda vermelha pulsante para avisos muito chamativos.
	var flash := 0.0
	var flash_col := Color(1, 0.1, 0.05)
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(delta: float) -> void:
		t += delta
		flash = maxf(0.0, flash - delta * 0.9)
		queue_redraw()

	func _draw() -> void:
		if flash > 0.0:
			var blink := 1.0 if fmod(t, 0.25) < 0.125 else 0.55
			draw_rect(Rect2(0, 0, 1280, 720), Color(flash_col.r, flash_col.g, flash_col.b, flash * 0.33 * blink))
		var unprot := Game.any_alert()
		var a := 0.0
		if unprot:
			a = 0.55 + 0.45 * sin(t * 9.0)
		elif flash > 0.0:
			a = flash
		if a > 0.0:
			var col := Color(1, 0.12, 0.05) if unprot else flash_col
			for i in 12:
				draw_rect(Rect2(i * 5, i * 5, 1280 - i * 10, 720 - i * 10), Color(col.r, col.g, col.b, a * (12 - i) / 12.0 * 0.7), false, 5.0)
		if unprot and Game.running:
			var f := ThemeDB.fallback_font
			var lever := "RAD" if Game.EVENTS[Game.today_event]["shield"] == "radiacao" else "DES"
			var on := fmod(t, 0.6) < 0.4
			var r := Rect2(300, 612, 680, 56)
			draw_rect(r, Color("c62020") if on else Color("7a1010"))
			draw_rect(r, Color.WHITE, false, 4.0)
			draw_string(f, Vector2(r.position.x, r.position.y + 36), "BASE DESPROTEGIDA — PUXE A ALAVANCA %s!" % lever, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color.WHITE)


var pan := 640.0
var room_root: Control
var front: Control
var window_view: Control
var window_back: Button
var hud: HudView
var pointer: TutPointer
var flash_view: FlashView
var banner_sb: StyleBoxFlat
var banner_icon: Polygon2D
var banner_mark: Label
var warned := {}
var minigame: Control = null
var pause_btn: Button
var diary_reader: IntroView = null
var panel: Control
var panel_shown := false
var panel_tween: Tween
var tut_panel: Panel
var tut_label: Label
var tut_step_label: Label
var tut_sb: StyleBoxFlat
var tut_next_btn: Button
var banner: Panel
var banner_stripe: ColorRect
var banner_title: Label
var banner_text: Label
var banner_queue: Array = []
var banner_t := 0.0
var banner_kind := ""
var banner_gap := 0.0
var overlay: Control = null
var tut_step := -1
var tut_wait := 0.0
var tut_food0 := 0
var tut_water0 := 0
var intro_tween: Tween = null
var last_shield := false
var window_hint: Label

var touch := DisplayServer.is_touchscreen_available()
var touch_pan_dir := 0.0
var touch_arrows: Array = []

var snd := {}
var hum_player: AudioStreamPlayer
var sfx_players: Array = []


func _ready() -> void:
	theme = _make_theme()
	_build_audio()
	_build_room()
	_build_window_view()
	_build_panel()
	hud = HudView.new()
	hud.m = self
	hud.strip_rect = STRIP
	add_child(hud)
	var strip_btn := Button.new()
	strip_btn.flat = true
	strip_btn.position = STRIP.position
	strip_btn.size = STRIP.size
	strip_btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		strip_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	strip_btn.mouse_entered.connect(_on_strip_hover)
	strip_btn.pressed.connect(_on_strip_tap)
	add_child(strip_btn)
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.tooltip_text = "Pausa (ESC)"
	pause_btn.position = Vector2(1004, 10)
	pause_btn.size = Vector2(54, 54)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.pressed.connect(_pause)
	add_child(pause_btn)
	if touch:
		_build_touch_arrows()
	flash_view = FlashView.new()
	add_child(flash_view)
	pointer = TutPointer.new()
	add_child(pointer)
	_build_tutorial_box()
	_build_banner()
	Game.notify.connect(_on_notify)
	Game.maint_minigame.connect(_open_minigame)
	Game.day_finished.connect(_on_day_finished)
	Game.died.connect(_on_died)
	_show_title()


# ---------- Construção ----------

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("24343a")
	sb.border_color = Color("5a7077")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color("34505a")
	sbh.border_color = C_ACCENT
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = C_ACCENT
	th.set_stylebox("normal", "Button", sb)
	th.set_stylebox("hover", "Button", sbh)
	th.set_stylebox("pressed", "Button", sbp)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color("142024"))
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("default_color", "RichTextLabel", C_TEXT)
	return th


func _hit_button(parent: Control, rect: Rect2, hover_id: String, cb: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: front.hover = hover_id)
	b.mouse_exited.connect(func() -> void:
		if front.hover == hover_id:
			front.hover = "")
	parent.add_child(b)


func _build_room() -> void:
	room_root = Control.new()
	room_root.size = Vector2(RoomScript.W, 720)
	room_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_root)
	var back: Control = RoomScript.new()
	back.mode = "back"
	room_root.add_child(back)
	for k in RoomScript.WINDOWS:
		_pixel_view(room_root, k, RoomScript.WINDOWS[k], 1.0)
	front = RoomScript.new()
	front.mode = "front"
	room_root.add_child(front)
	for k in RoomScript.WINDOWS:
		_hit_button(room_root, RoomScript.WINDOWS[k], k, _open_window.bind(k))
	for k in RoomScript.LEVERS:
		_hit_button(room_root, RoomScript.LEVERS[k], k, _pull_lever.bind(k))


## Cria uma vista da janela em baixa resolução (SubViewport) ampliada sem filtro.
func _pixel_view(parent: Control, view: String, rect: Rect2, factor: float) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(rect.size.x / factor), int(rect.size.y / factor))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var ext: Control = ExteriorScript.new()
	ext.view = view
	ext.size = Vector2(vp.size)
	vp.add_child(ext)
	var tr := TextureRect.new()
	tr.position = rect.position
	tr.size = rect.size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(vp)
	tr.texture = vp.get_texture()
	tr.set_meta("ext", ext)
	parent.add_child(tr)
	return tr


func _build_window_view() -> void:
	window_view = _pixel_view(self, "center", Rect2(0, 0, 1280, 720), 1.0)
	window_view.visible = false
	window_back = Button.new()
	window_back.flat = true
	window_back.position = Vector2.ZERO
	window_back.size = Vector2(1280, 720)
	for st in ["normal", "hover", "pressed", "focus"]:
		window_back.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	window_back.pressed.connect(_close_window)
	window_back.visible = false
	add_child(window_back)
	var hint := Label.new()
	window_hint = hint
	hint.text = "CLIQUE PARA VOLTAR"
	hint.position = Vector2(0, 110)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	window_back.add_child(hint)


func _build_panel() -> void:
	panel = BlueprintScript.new()
	panel.position = Vector2(200, PANEL_HIDDEN_Y)
	panel.visible = false
	add_child(panel)
	panel.screen_opened.connect(_on_screen_opened)


## Celular: setas para olhar ao redor (segurar) — no PC o mouse nas bordas faz isso.
func _build_touch_arrows() -> void:
	for side in [-1.0, 1.0]:
		var b := Button.new()
		b.text = "<" if side < 0.0 else ">"
		b.add_theme_font_size_override("font_size", 40)
		b.size = Vector2(80, 120)
		b.position = Vector2(200 if side < 0.0 else 1000, 250)
		b.focus_mode = Control.FOCUS_NONE
		b.modulate.a = 0.75
		b.button_down.connect(func() -> void: touch_pan_dir = side)
		b.button_up.connect(func() -> void: touch_pan_dir = 0.0)
		add_child(b)
		touch_arrows.append(b)


func _on_strip_hover() -> void:
	if not touch:
		_toggle_panel()


func _on_strip_tap() -> void:
	if touch:
		_toggle_panel()


func _build_tutorial_box() -> void:
	tut_panel = Panel.new()
	tut_sb = StyleBoxFlat.new()
	tut_sb.bg_color = Color(0.06, 0.09, 0.12, 0.97)
	tut_sb.border_color = Color(1.0, 0.82, 0.2)
	tut_sb.set_border_width_all(5)
	tut_panel.add_theme_stylebox_override("panel", tut_sb)
	tut_panel.position = Vector2(352, 2)
	tut_panel.size = Vector2(646, 96)
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tut_panel)
	tut_step_label = Label.new()
	tut_step_label.position = Vector2(12, 4)
	tut_step_label.add_theme_font_size_override("font_size", 14)
	tut_step_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	tut_panel.add_child(tut_step_label)
	tut_label = Label.new()
	tut_label.position = Vector2(12, 22)
	tut_label.size = Vector2(622, 72)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tut_label.add_theme_font_size_override("font_size", 15)
	tut_label.add_theme_color_override("font_color", Color.WHITE)
	tut_panel.add_child(tut_label)
	tut_next_btn = Button.new()
	tut_next_btn.text = "ENTENDI  >"
	tut_next_btn.position = Vector2(500, 92)
	tut_next_btn.size = Vector2(134, 34)
	tut_next_btn.add_theme_font_size_override("font_size", 16)
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(1.0, 0.82, 0.2)
	nb.set_border_width_all(2)
	nb.border_color = Color.WHITE
	tut_next_btn.add_theme_stylebox_override("normal", nb)
	tut_next_btn.add_theme_stylebox_override("hover", nb)
	tut_next_btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0))
	tut_next_btn.add_theme_color_override("font_hover_color", Color(0.15, 0.08, 0))
	tut_next_btn.focus_mode = Control.FOCUS_NONE
	tut_next_btn.pressed.connect(_tut_next)
	tut_panel.add_child(tut_next_btn)
	tut_panel.visible = false


func _build_banner() -> void:
	banner = Panel.new()
	banner.position = Vector2(190, -200)
	banner.size = Vector2(900, 110)
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			banner_t = minf(banner_t, 0.01))
	add_child(banner)
	banner_sb = StyleBoxFlat.new()
	banner_sb.set_border_width_all(5)
	banner_sb.border_color = Color.WHITE
	banner_sb.shadow_color = Color(0, 0, 0, 0.6)
	banner_sb.shadow_size = 14
	banner.add_theme_stylebox_override("panel", banner_sb)
	banner_stripe = ColorRect.new()
	banner_stripe.visible = false
	banner.add_child(banner_stripe)
	banner_icon = Polygon2D.new()
	banner_icon.polygon = PackedVector2Array([Vector2(50, 14), Vector2(88, 84), Vector2(12, 84)])
	banner_icon.color = Color.WHITE
	banner.add_child(banner_icon)
	banner_mark = Label.new()
	banner_mark.text = "!"
	banner_mark.position = Vector2(38, 30)
	banner_mark.size = Vector2(24, 50)
	banner_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_mark.add_theme_font_size_override("font_size", 40)
	banner_mark.add_theme_color_override("font_color", Color("b3261e"))
	banner.add_child(banner_mark)
	banner_title = Label.new()
	banner_title.position = Vector2(110, 6)
	banner_title.add_theme_font_size_override("font_size", 30)
	banner_title.add_theme_color_override("font_color", Color.WHITE)
	banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	banner_title.add_theme_constant_override("outline_size", 6)
	banner.add_child(banner_title)
	banner_text = Label.new()
	banner_text.position = Vector2(110, 48)
	banner_text.size = Vector2(770, 56)
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_text.add_theme_font_size_override("font_size", 18)
	banner_text.add_theme_color_override("font_color", Color.WHITE)
	banner.add_child(banner_text)
	banner.visible = false


# ---------- Áudio procedural ----------

func _wav(dur: float, gen: Callable, loop: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = gen.call(float(i) / rate)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _build_audio() -> void:
	snd["hum"] = _wav(2.0, _g_hum, true)
	snd["alarm"] = _wav(1.0, _g_alarm)
	snd["beep"] = _wav(0.14, _g_beep)
	snd["click"] = _wav(0.06, _g_click)
	snd["flip"] = _wav(0.2, _g_flip)
	snd["chime"] = _wav(1.2, _g_chime)
	snd["rumble"] = _wav(1.0, _g_rumble)
	snd["fail"] = _wav(1.5, _g_fail)
	hum_player = AudioStreamPlayer.new()
	hum_player.stream = snd["hum"]
	hum_player.volume_db = -10.0
	add_child(hum_player)
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _g_hum(t: float) -> float:
	return 0.10 * sin(TAU * 55.0 * t) + 0.05 * sin(TAU * 110.0 * t) + 0.015 * _noise()


func _g_alarm(t: float) -> float:
	var fq := 880.0 if t < 0.5 else 660.0
	return 0.14 * sin(TAU * fq * t) * (1.0 - fmod(t, 0.5) / 0.5)


func _g_beep(t: float) -> float:
	return 0.3 * sin(TAU * 1200.0 * t) * (1.0 - t / 0.14)


func _g_click(t: float) -> float:
	return 0.5 * _noise() * (1.0 - t / 0.06)


func _g_flip(t: float) -> float:
	return 0.25 * _noise() * (1.0 - t / 0.2) + 0.15 * sin(TAU * (300.0 + t * 1500.0) * t)


func _g_chime(t: float) -> float:
	var idx := mini(int(t / 0.4), 2)
	var fq: float = [523.25, 659.25, 783.99][idx]
	var lt := t - idx * 0.4
	return 0.3 * sin(TAU * fq * t) * exp(-lt * 4.0)


func _g_rumble(t: float) -> float:
	return 0.5 * sin(TAU * 38.0 * t) * (randf() * 0.6 + 0.4) * (1.0 - t)


func _g_fail(t: float) -> float:
	return 0.25 * sin(TAU * (520.0 - 160.0 * t) * t) * (1.0 - t / 1.5)


func _play(id: String, vol: float = 0.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = snd[id]
			p.volume_db = vol
			p.play()
			return


# ---------- Loop ----------

func _process(delta: float) -> void:
	var can_look := overlay == null and minigame == null and diary_reader == null and not panel_shown and not window_view.visible
	for b in touch_arrows:
		b.visible = can_look
	if can_look:
		var mx := get_local_mouse_position().x
		var my := get_local_mouse_position().y
		pan += touch_pan_dir * 900.0 * delta
		if touch:
			pass
		elif my < 670:
			if mx < 200.0:
				pan -= 1100.0 * delta * (1.0 - mx / 200.0)
			elif mx > 1080.0:
				pan += 1100.0 * delta * ((mx - 1080.0) / 200.0)
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			pan -= 900.0 * delta
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			pan += 900.0 * delta
		pan = clampf(pan, 0.0, PAN_MAX)
	room_root.position.x = -pan
	room_root.position.y = randf_range(-6.0, 6.0) if Game.is_shaking() else 0.0

	var shield_now := Game.any_shield()
	if shield_now != last_shield:
		last_shield = shield_now
		_play("rumble", -6.0)
	window_hint.text = "ESCUDO ATIVO — JANELAS FECHADAS · CLIQUE PARA VOLTAR" if Game.shutter > 0.5 else "CLIQUE PARA VOLTAR"

	if Game.running and not hum_player.playing and not Game.blackout:
		hum_player.play()
	elif (Game.blackout or not Game.running) and hum_player.playing:
		hum_player.stop()

	pause_btn.visible = Game.running and overlay == null and minigame == null and diary_reader == null
	_check_warnings()
	_tick_banner(delta)
	_tick_tutorial(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif overlay != null:
			return
		elif k == KEY_ESCAPE:
			if window_view.visible:
				_close_window()
			elif panel_shown:
				_set_panel(false)
			else:
				_pause()
		elif k == KEY_SPACE or k == KEY_S:
			_toggle_panel()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and window_view.visible:
		_close_window()
	elif event is InputEventScreenDrag and overlay == null and not panel_shown and not window_view.visible:
		# Celular: arrastar o dedo para olhar ao redor
		pan = clampf(pan - event.relative.x * 1.5, 0.0, PAN_MAX)


# ---------- Notificações (banner) ----------

func _on_notify(text: String, kind: String) -> void:
	banner_queue.append([text, kind])
	if banner_queue.size() > 4:
		banner_queue.pop_front()


func _tick_banner(delta: float) -> void:
	if banner_t > 0.0:
		banner_t -= delta
		if banner_kind == "alert" or banner_kind == "bad":
			var on := fmod(Time.get_ticks_msec() / 1000.0, 0.3) < 0.15
			var base: Color = banner_sb.get_meta("base", Color.RED)
			banner_sb.bg_color = base if on else base.darkened(0.45)
			banner_sb.border_color = Color.WHITE if on else Color(1, 0.85, 0.2)
		if banner_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(banner, "position:y", -220.0, 0.25)
			tw.tween_callback(func() -> void: banner.visible = false)
			banner_gap = 0.35
		return
	if banner_gap > 0.0:
		banner_gap -= delta
		return
	if banner_queue.is_empty() or overlay != null or minigame != null:
		return
	var item: Array = banner_queue.pop_front()
	_show_banner(item[0], item[1])


func _show_banner(text: String, kind: String) -> void:
	var titles := {"alert": "!!! ALERTA !!!", "bad": "ATENÇÃO!", "good": "SUCESSO!", "drop": "SUPRIMENTOS CHEGARAM!", "info": "AVISO"}
	var colors := {"alert": Color("c62020"), "bad": Color("d9622b"), "good": Color("2e8b3e"), "drop": Color("1f7fb8"), "info": Color("b8860b")}
	var col: Color = colors.get(kind, Color("b8860b"))
	var big := kind == "alert"
	# Alertas: banner gigante no meio da tela; outros: banner grande no topo.
	banner.size = Vector2(1040, 160) if big else Vector2(900, 112)
	banner.position.x = (1280.0 - banner.size.x) / 2.0
	banner.pivot_offset = banner.size / 2.0
	banner_title.add_theme_font_size_override("font_size", 44 if big else 30)
	banner_text.add_theme_font_size_override("font_size", 22 if big else 18)
	banner_text.position = Vector2(118, 66 if big else 48)
	banner_text.size = Vector2(banner.size.x - 136, banner.size.y - banner_text.position.y - 6)
	banner_icon.position = Vector2(4, 24 if big else 6)
	banner_mark.position = Vector2(42, 54 if big else 36)
	banner_icon.visible = kind in ["alert", "bad"]
	banner_mark.visible = banner_icon.visible
	banner_title.position.x = 118 if banner_icon.visible else 24
	if not banner_icon.visible:
		banner_text.position.x = 24
		banner_text.size.x = banner.size.x - 44
	banner_sb.bg_color = col
	banner_sb.border_color = Color.WHITE
	banner_sb.set_meta("base", col)
	banner_mark.add_theme_color_override("font_color", col)
	banner_title.text = titles.get(kind, "AVISO")
	banner_text.text = text
	banner_kind = kind
	banner.visible = true
	var target_y := 190.0 if big else 104.0
	banner.position.y = -220.0
	banner.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "position:y", target_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if big:
		var shake := create_tween()
		shake.tween_interval(0.3)
		for i in 6:
			shake.tween_property(banner, "position:x", banner.position.x + (14.0 if i % 2 == 0 else -14.0), 0.05)
		shake.tween_property(banner, "position:x", banner.position.x, 0.05)
	banner_t = 6.0 if big else (4.5 if kind == "drop" else 3.5)
	# Flash de tela e sons
	match kind:
		"alert":
			flash_view.flash_col = Color(1, 0.1, 0.05)
			flash_view.flash = 1.0
			_play("alarm", 0.0)
			var rep := create_tween()
			rep.tween_interval(1.05)
			rep.tween_callback(_play.bind("alarm", 0.0))
			rep.tween_interval(1.05)
			rep.tween_callback(_play.bind("alarm", -3.0))
		"bad":
			flash_view.flash_col = Color(1, 0.45, 0.1)
			flash_view.flash = 0.6
			_play("beep", 0.0)
			var rep2 := create_tween()
			rep2.tween_interval(0.2)
			rep2.tween_callback(_play.bind("beep", 0.0))
		"drop", "good":
			flash_view.flash_col = Color(0.3, 1, 0.5) if kind == "good" else Color(0.3, 0.7, 1)
			flash_view.flash = 0.35
			_play("chime", -3.0)
		_:
			_play("beep", -6.0)


## Alertas automáticos quando um recurso fica perigoso (avisa uma vez até recuperar).
func _check_warnings() -> void:
	if not Game.running:
		return
	_warn("fome", Game.res["saciedade"] < 25.0, Game.res["saciedade"] > 40.0, "FOME! Sua saciedade está em %d%%. Abra o painel > R e clique em COMER." % int(Game.res["saciedade"]))
	_warn("sede", Game.res["hidratacao"] < 25.0, Game.res["hidratacao"] > 40.0, "SEDE! Sua hidratação está em %d%%. Abra o painel > R e clique em BEBER ÁGUA." % int(Game.res["hidratacao"]))
	_warn("o2", Game.res["oxigenio"] < 25.0, Game.res["oxigenio"] > 35.0, "OXIGÊNIO BAIXO (%d%%)! Repare o gerador de oxigênio no painel > M." % int(Game.res["oxigenio"]))
	_warn("rad", Game.res["radiacao"] > 70.0, Game.res["radiacao"] < 55.0, "RADIAÇÃO SOLAR ALTA (%d%%)! Ative o escudo RAD. Em 100%% a missão acaba." % int(Game.res["radiacao"]))
	_warn("energia", Game.energia < 60.0, Game.energia > 90.0, "ENERGIA BAIXA (%d)! Conserte os painéis solares (se danificados) e evite gastos." % int(Game.energia))
	_warn("racao", Game.racoes == 0, Game.racoes > 0, "ACABARAM AS RAÇÕES! Pesquise a fertilidade do solo.")
	_warn("garrafa", Game.garrafas == 0, Game.garrafas > 0, "ACABOU A ÁGUA! Pesquise água ou repare o reciclador.")


func _warn(key: String, bad: bool, ok: bool, text: String) -> void:
	if bad and not warned.get(key, false):
		warned[key] = true
		_on_notify(text, "alert" if key in ["fome", "sede", "o2", "rad"] else "bad")
	elif ok:
		warned[key] = false


# ---------- Interações ----------

func _toggle_panel() -> void:
	_set_panel(not panel_shown)


# ---------- Minigames de manutenção ----------

func _open_minigame(id: String) -> void:
	if minigame != null:
		minigame.queue_free()
	_set_panel(false)
	minigame = MinigameScript.new()
	minigame.setup(id)
	add_child(minigame)
	minigame.finished.connect(_on_minigame_done)
	_play("flip", -2.0)


func _on_minigame_done(score: float) -> void:
	if minigame != null:
		minigame.queue_free()
		minigame = null
	Game.finish_maint(score)
	if tut_step == 7:
		tut_step = 8
	_play("chime" if score >= 0.6 else "beep", -4.0)
	if Game.running and overlay == null:
		_set_panel(true)


func _set_panel(want: bool) -> void:
	if want and (overlay != null or minigame != null or diary_reader != null or window_view.visible or not Game.running):
		return
	if want == panel_shown:
		return
	panel_shown = want
	Game.panel_open = want
	_play("flip", -4.0)
	if panel_tween:
		panel_tween.kill()
	panel_tween = create_tween()
	if want:
		panel.visible = true
		panel_tween.tween_property(panel, "position:y", PANEL_SHOWN_Y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		panel_tween.tween_property(panel, "position:y", PANEL_HIDDEN_Y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		panel_tween.tween_callback(func() -> void: panel.visible = false)


func _open_window(id: String) -> void:
	if overlay != null or panel_shown:
		return
	window_view.get_meta("ext").view = id
	window_view.visible = true
	window_back.visible = true
	front.hover = ""
	_play("click", -6.0)
	if tut_step == 1:
		tut_step = 2


func _close_window() -> void:
	window_view.visible = false
	window_back.visible = false


func _pull_lever(id: String) -> void:
	if overlay != null or minigame != null or not Game.running:
		return
	Game.toggle_shield(id)
	_play("click")


func _on_screen_opened(id: String) -> void:
	_play("click", -8.0)
	if tut_step == 3 and id == "R":
		tut_step = 4


## Botão ENTENDI dos passos explicativos do Diário.
func _tut_next() -> void:
	if tut_step < 8 or tut_step > 11:
		return
	tut_step += 1
	_play("click", -6.0)
	if tut_step == 9:
		_open_diary_example()
	if tut_step == 12:
		_close_diary_example()
		Game.start_tutorial_event("solar")
	elif diary_reader != null:
		diary_reader.highlight = tut_step - 9


# ---------- Tutorial ----------

## Retângulo na tela de algo dentro do painel (coordenadas do painel).
func _pr(r: Rect2) -> Rect2:
	return Rect2(panel.position + r.position, r.size)


func _pt(rect: Rect2, text: String) -> void:
	pointer.mode = "rect"
	pointer.target = rect
	pointer.label = text


## Decide o que o indicador do tutorial deve destacar neste passo.
func _update_pointer() -> void:
	var click := "TOQUE" if touch else "CLIQUE"
	var back := _pr(Rect2(24, 70, 140, 40))
	var strip_txt := "TOQUE AQUI" if touch else "PASSE O MOUSE AQUI"
	pointer.mode = ""
	if not Game.is_earth() or overlay != null or minigame != null or tut_step < 0 or tut_step >= TUT.size():
		return
	var cur: String = panel.current
	var need_panel := tut_step >= 3 and tut_step <= 7
	if need_panel and not panel_shown:
		_pt(STRIP, strip_txt)
		return
	match tut_step:
		0:
			pointer.mode = "sides"
			pointer.label = "ARRASTE OU SEGURE AS SETAS" if touch else "LEVE O MOUSE ATÉ A BORDA"
		1:
			if not window_view.visible:
				var best := Rect2()
				for k in RoomScript.WINDOWS:
					var r: Rect2 = RoomScript.WINDOWS[k]
					var vis := Rect2(r.position.x - pan, r.position.y, r.size.x, r.size.y).intersection(Rect2(0, 0, 1280, 720))
					if vis.size.x > best.size.x:
						best = vis
				_pt(best, "%s NA JANELA" % click)
		2:
			if window_view.visible:
				_pt(Rect2(340, 100, 600, 50), "%s EM QUALQUER LUGAR PARA VOLTAR" % click)
			else:
				_pt(STRIP, strip_txt)
		3:
			_pt(back if cur != "home" else _pr(Rect2(30, 76, 300, 230)), "%s EM R" % click if cur == "home" else "VOLTAR")
		4, 5:
			if cur == "R":
				if tut_step == 4:
					_pt(_pr(Rect2(24, 122, 484, 300)), "%s EM COMER" % click)
				else:
					_pt(_pr(Rect2(528, 122, 484, 300)), "%s EM BEBER ÁGUA" % click)
			elif cur == "home":
				_pt(_pr(Rect2(30, 76, 300, 230)), "%s EM R" % click)
			else:
				_pt(back, "VOLTAR")
		6:
			if cur == "P":
				_pt(_pr(Rect2(24, 211, 320, 160)), "%s NUMA PESQUISA" % click)
			elif cur == "home":
				_pt(_pr(Rect2(350, 76, 680, 230)), "%s EM PESQUISAS" % click)
			else:
				_pt(back, "VOLTAR")
		7:
			if cur == "M":
				_pt(_pr(Rect2(700, 136, 240, 60)), "%s EM INICIAR" % click)
			elif cur == "home":
				_pt(_pr(Rect2(30, 326, 1000, 230)), "%s EM M" % click)
			else:
				_pt(back, "VOLTAR")
		8, 9, 10, 11:
			pass   # a página de exemplo do diário destaca cada parte sozinha
		12, 13:
			if panel_shown:
				_pt(STRIP, ("TOQUE AQUI PARA FECHAR" if touch else "PASSE O MOUSE PARA FECHAR"))
			else:
				var r: Rect2 = RoomScript.LEVERS["radiacao"]
				var lx := r.position.x - pan
				if lx < 0.0 or lx + r.size.x > 1280.0:
					pointer.mode = "right"
					pointer.label = "OLHE PARA A DIREITA"
				else:
					_pt(Rect2(lx, r.position.y, r.size.x, r.size.y + 50), "%s NA ALAVANCA RAD" % click if tut_step == 12 else "%s DE NOVO PARA DESLIGAR" % click)


func _tick_tutorial(delta: float) -> void:
	tut_panel.visible = Game.is_earth() and tut_step >= 0 and tut_step < TUT.size() and overlay == null and minigame == null
	_update_pointer()
	if not tut_panel.visible:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	tut_sb.border_color = Color(1.0, 0.82, 0.2).lerp(Color.WHITE, pulse * 0.6)
	tut_step_label.text = "TREINAMENTO — PASSO %d DE %d" % [tut_step + 1, TUT.size()]
	tut_label.text = TUT[tut_step]
	var info_step := tut_step >= 8 and tut_step <= 11
	tut_next_btn.visible = info_step
	tut_panel.size.y = 132 if info_step else 96
	tut_label.size.x = 622
	match tut_step:
		0:
			if absf(pan - 640.0) > 250.0:
				tut_step = 1
		2:
			if panel_shown:
				tut_step = 3
		4:
			if Game.racoes < tut_food0:
				tut_step = 5
		5:
			if Game.garrafas < tut_water0:
				tut_step = 6
		6:
			if not Game.research_job.is_empty():
				tut_step = 7
		7:
			if Game.maint_job.get("id", "") == "paineis":
				tut_step = 8
		12:
			if Game.shields["radiacao"]:
				tut_step = 13
		13:
			if not Game.shields["radiacao"]:
				Game.end_tutorial_event()
				tut_step = 14
				tut_wait = 4.0
		14:
			tut_wait -= delta
			if tut_wait <= 0.0:
				tut_step = 15
				Game.finish_tutorial_now()


# ---------- Telas / diálogos ----------

func _clear_overlay() -> void:
	if intro_tween != null:
		intro_tween.kill()
		intro_tween = null
	if overlay != null:
		overlay.queue_free()
		overlay = null


func _dialog(title: String, body: String, buttons: Array, big: bool = false, compact: bool = false) -> void:
	_clear_overlay()
	overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var rect := Rect2(170, 50, 940, 620) if big else Rect2(250, 70, 780, 580)
	if compact:
		rect = Rect2(270, 210, 740, 300)
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1215")
	sb.border_color = Color("3d4e54")
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	overlay.add_child(p)
	var t := Label.new()
	t.text = title
	t.position = Vector2(30, 20)
	t.add_theme_font_size_override("font_size", 40 if big else 30)
	t.add_theme_color_override("font_color", C_ACCENT)
	p.add_child(t)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.position = Vector2(30, 84 if big else 72)
	r.size = Vector2(rect.size.x - 60, rect.size.y - 176)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	r.add_theme_font_size_override("italics_font_size", 16)
	r.text = body
	p.add_child(r)
	var hb := HBoxContainer.new()
	hb.position = Vector2(30, rect.size.y - 84)
	hb.size = Vector2(rect.size.x - 60, 60)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 14)
	p.add_child(hb)
	for bdef in buttons:
		var b := Button.new()
		b.text = bdef[0]
		b.custom_minimum_size = Vector2(210, 56)
		b.pressed.connect(bdef[1])
		hb.add_child(b)


func _reset_view() -> void:
	_set_panel(false)
	panel.visible = false
	panel.position.y = PANEL_HIDDEN_Y
	panel_shown = false
	Game.panel_open = false
	panel.open_screen("home")
	_close_window()
	pan = 640.0


func _intro(title: String, subtitle: String) -> void:
	## Tela de abertura do sol (amanhecer + página do diário).
	_reset_view()
	_clear_overlay()
	var iv := IntroView.new()
	iv.title = title
	iv.subtitle = subtitle
	iv.earth = Game.is_earth()
	iv.bg = IMG_VISTA
	iv.touch = touch
	_fill_page(iv)
	iv.duration = 8.0 if Game.is_earth() else 40.0
	overlay = iv
	add_child(iv)
	iv.finished.connect(_intro_done)
	_play("chime", -10.0)


func _fill_page(iv: IntroView) -> void:
	iv.story = Game.page.get("story", "")
	iv.goals = Array(Game.goal_names())
	var hints: PackedStringArray = (Game.page.get("hints", PackedStringArray()) as PackedStringArray).duplicate()
	if Game.is_earth():
		hints.append("Os instrutores avisaram que vão simular uma tempestade solar durante o treino.")
	iv.hints = hints


## Tutorial: abre um exemplo da página do diário (igual à da tela de carregamento).
func _open_diary_example() -> void:
	_set_panel(false)
	diary_reader = IntroView.new()
	diary_reader.reader = true
	diary_reader.title = "Treino"
	diary_reader.card_pos = Vector2(350, 140)
	_fill_page(diary_reader)
	add_child(diary_reader)
	move_child(tut_panel, get_child_count() - 1)
	move_child(banner, get_child_count() - 1)


func _close_diary_example() -> void:
	if diary_reader != null:
		diary_reader.queue_free()
		diary_reader = null


func _intro_done() -> void:
	intro_tween = null
	_clear_overlay()
	Game.running = true
	if not Game.is_earth():
		_on_notify("Pesquisas do diário hoje: %s. Elas estão com borda dourada em PESQUISAS." % ", ".join(Game.goal_names()), "info")


func _launch() -> void:
	## Tela de carregamento: viagem da Terra até Marte.
	_reset_view()
	_clear_overlay()
	var lv := LoadingView.new()
	lv.tips = TIPS
	overlay = lv
	add_child(lv)
	_play("rumble", 0.0)
	lv.finished.connect(_start_mission)


func _show_title() -> void:
	## Menu inicial.
	Game.new_game(false)
	Game.paused = false
	tut_step = -1
	_close_diary_example()
	if minigame != null:
		minigame.queue_free()
		minigame = null
	_reset_view()
	_clear_overlay()
	var mv := MenuView.new()
	mv.bg = IMG_BASE
	mv.buttons = [
		["INICIAR MISSÃO", _launch, true],
		["TUTORIAL", _start_tutorial, false],
		["COMO JOGAR", _how_to_play, false],
		["SAIR", _quit, false],
	]
	overlay = mv
	add_child(mv)


func _how_to_play() -> void:
	_dialog("COMO JOGAR",
		"[color=#7fa8a0]Sobreviva a cinco sols (dias) em Marte — cerca de 10 minutos de jogo.[/color]\n\n" +
		"Você é um astronauta numa base em Marte. Cuide da sua [color=#8be07f]fome[/color] e [color=#4a8cf0]sede[/color] (rações e garrafas contadas em unidades), do [color=#5ec8f0]oxigênio[/color], da [color=#f2c230]radiação solar[/color] e da [color=#f2d541]energia[/color] (400 no início; os painéis solares funcionando geram +100 às 06:00 de cada sol).\n\n" +
		"[b]Olhe pelas janelas[/b] (mouse nas bordas). [b]Passe o mouse na barra de baixo[/b] para abrir o painel: comer e beber, pesquisas, manutenções, eventos e diário. Os [b]escudos[/b] ficam nas alavancas da sala: fecham as janelas e selam a base.\n\n" +
		"Na tela de carregamento de cada sol aparece o [b]Diário[/b]: ele conta a história do sol, sugere as pesquisas do dia e dá pistas do que pode acontecer. Eventos duram algumas horas e um alerta avisa 1 hora antes. Os drops das pesquisas chegam no sol seguinte.\n\n" +
		"[b]Objetivo:[/b] concluir os 5 sols fazendo o máximo de pesquisas.\n" +
		"[color=#7fa8a0]Controles: mouse · A/D olhar · ESPAÇO painel · ESC pausa · F11 tela cheia · no celular: arraste e toque[/color]",
		[["Voltar ao menu", _show_title]], true)


func _start_tutorial() -> void:
	Game.new_game(true)
	warned = {}
	tut_step = 0
	tut_food0 = Game.racoes
	tut_water0 = Game.garrafas
	_intro("TREINO", "TERRA — BASE DE TESTES")


func _start_mission() -> void:
	Game.new_game(false)
	warned = {}
	tut_step = -1
	_intro("SOL 1", "MARTE — BASE AURORA")


func _next_day() -> void:
	Game.start_day()
	_intro("SOL %d" % Game.day, "MARTE — BASE AURORA" if Game.day <= Game.MAX_DAYS else "JOGO LIVRE — MARTE")


func _continue_free() -> void:
	Game.free_play = true
	_next_day()


func _stats() -> String:
	return "\n[color=#7fa8a0]Energia %d · Rações %d · Garrafas %d · Fome %d%% · Sede %d%% · Radiação solar %d%% · O2 %d%% · Pesquisas: %d[/color]" % [
		Game.energia, Game.racoes, Game.garrafas, Game.res["saciedade"], Game.res["hidratacao"], Game.res["radiacao"], Game.res["oxigenio"], Game.research_done]


func _on_day_finished(report: Dictionary) -> void:
	_reset_view()
	_play("chime")
	var log_txt := ""
	for line in report["log"]:
		log_txt += "• %s\n" % line
	var night := ""
	for line in report["night"]:
		night += "[color=#9fc0ea]• %s[/color]\n" % line
	var ev := EndDayView.new()
	ev.bg = IMG_TARDE
	if report["tutorial_done"]:
		ev.kind = "tutorial"
		ev.title = "TREINO CONCLUÍDO"
		ev.subtitle = "18:00 · O sol se pôs sobre a base de testes na Terra"
		ev.right_title = "O QUE VOCÊ APRENDEU"
		ev.body = "• [b]Janelas[/b]: observe o tempo e os eventos lá fora.\n• [b]R[/b]: coma e beba (rações e garrafas são limitadas).\n• [b]Pesquisas[/b]: custam energia; os drops chegam no sol seguinte.\n• [b]M[/b]: conserte equipamentos DANIFICADOS (minigame). Painéis funcionando geram +100 às 06:00.\n• [b]Diário[/b] (tela de carregamento): história, pesquisas sugeridas e pistas.\n• [b]Alavancas RAD/DES[/b]: escudos que fecham as janelas e selam a base.\n\n[color=#f2a541]Agora é pra valer: [b]5 sols em Marte[/b]![/color]"
		ev.buttons = [["LANÇAR PARA MARTE", _launch, true]]
	elif report["victory"]:
		ev.kind = "win"
		ev.title = "MISSÃO CUMPRIDA!"
		ev.subtitle = "Você sobreviveu aos 5 sols em Marte · %d pesquisas concluídas" % Game.research_done
		ev.badge = Game.rating()
		ev.goals = report.get("goals", [])
		ev.research_today = report.get("research_today", 0)
		ev.body = "%s\n[color=#9fc0ea][b]Noite[/b][/color]\n%s\n[color=#f2a541]Continue no [b]jogo livre[/b] para bater seu recorde.[/color]" % [log_txt, night]
		ev.buttons = [["MENU", _show_title, false], ["JOGO LIVRE", _continue_free, true]]
	else:
		var prev := "\n[color=#9fc0ea]Próximo sol: leia o diário na tela de carregamento.[/color]"
		if Game.forecast_until >= Game.day:
			var parts := PackedStringArray()
			for e in Game.events_for(Game.day):
				parts.append(Game.event_text(e))
			prev = "\n[color=#f2a541]Previsão do próximo sol: %s.[/color]" % ("calmo" if parts.is_empty() else "; ".join(parts))
		ev.title = "FIM DO SOL %d" % report["day"]
		ev.subtitle = "18:00 · O sol se põe sobre a Base Aurora" + ("" if report["day"] >= Game.MAX_DAYS else " · faltam %d sols" % (Game.MAX_DAYS - report["day"]))
		ev.goals = report.get("goals", [])
		ev.research_today = report.get("research_today", 0)
		ev.body = "%s\n[color=#9fc0ea][b]Noite[/b][/color]\n%s%s" % [log_txt, night, prev]
		ev.buttons = [["COMEÇAR SOL %d" % Game.day, _next_day, true]]
	_clear_overlay()
	overlay = ev
	add_child(ev)


func _on_died(c: String) -> void:
	_reset_view()
	hum_player.stop()
	_play("fail")
	var ev := EndDayView.new()
	ev.bg = IMG_TARDE
	ev.kind = "dead"
	ev.title = "MISSÃO ENCERRADA"
	ev.subtitle = c
	ev.right_title = "O QUE ACONTECEU"
	ev.goals = Game.goal_status()
	ev.research_today = Game.research_done - Game.research_day0
	var log_txt := ""
	for line in Game.today_log:
		log_txt += "• %s\n" % line
	ev.body = "Você resistiu até [b]%s[/b] do sol %d.\n\n%s\n[color=#f2a541][b]Dicas[/b][/color]\n• Coma e beba na aba R.\n• Leia as pistas do diário na tela de carregamento.\n• Puxe as alavancas dos escudos nos eventos.\n• Conserte os equipamentos danificados (principalmente os painéis)." % [Game.clock_text(), Game.day, log_txt]
	ev.buttons = [["MENU", _show_title, false], ["TENTAR NOVAMENTE", _launch, true]]
	_clear_overlay()
	overlay = ev
	add_child(ev)


func _quit() -> void:
	get_tree().quit()


# ---------- Pausa ----------

func _pause() -> void:
	if overlay != null or minigame != null or not Game.running or Game.game_over:
		return
	Game.paused = true
	_set_panel(false)
	_play("click", -4.0)
	_dialog("PAUSA", "O jogo está pausado.\n\n[color=#7fa8a0]Sol %d · %s · %d pesquisas concluídas[/color]" % [Game.day, Game.clock_text(), Game.research_done] if not Game.is_earth() else "O treinamento está pausado.",
		[["Sair do jogo", _quit], ["Menu inicial", _show_title], ["Continuar", _resume]], false, true)


func _resume() -> void:
	_clear_overlay()
	Game.paused = false
