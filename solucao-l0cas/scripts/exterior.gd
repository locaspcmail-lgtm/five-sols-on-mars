extends Control
## Paisagem vista por uma janela, desenhada num espaço virtual de 1280x720.
## É renderizada num SubViewport pequeno e ampliada sem filtro (pixel art).
## Quando um escudo está ativo, uma persiana de metal desce sobre a vista.

var view := "center"   # left, center, right
var t := 0.0
var dust: Array[Vector2] = []
var rocks: Array[Vector3] = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in SCENE_OF:
		MARKS[k] = GenMarks.MARKS.get(SCENE_OF[k], {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 140:
		dust.append(Vector2(rng.randf() * 1280.0, 60.0 + rng.randf() * 640.0))
	for i in 22:
		rocks.append(Vector3(rng.randf() * 1280.0, 440.0 + rng.randf() * 270.0, 8.0 + rng.randf() * 22.0))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Imagens das janelas: cenas 3D low-poly geradas por tests/gen_art.gd (pixel art).
## Na Terra (tutorial) a paisagem é desenhada.
const PHOTOS := {
	"left": preload("res://art/gen/paineis.png"),
	"rover": preload("res://art/gen/rover.png"),
	"center": preload("res://art/gen/base.png"),
	"right": preload("res://art/gen/perfuracao.png"),
}
const SCENE_OF := {"left": "paineis", "rover": "rover", "center": "base", "right": "perfuracao"}
## Onde cada equipamento aparece em cada imagem (0..1), calculado na geração.
const GenMarks := preload("res://art/gen/marks.gd")
var MARKS := {}


func _photo_key() -> String:
	if view == "left" and not Game.research_job.is_empty():
		return "rover"   # robô em campo: a janela mostra o rover trabalhando
	return view


## Desenha a imagem cobrindo o controle (corta as sobras) e devolve o recorte usado.
func _draw_cover(tex: Texture2D, offset: Vector2, grow: float) -> Rect2:
	var tsz := tex.get_size()
	var aspect := size.x / size.y
	var src := Rect2(Vector2.ZERO, tsz)
	if tsz.x / tsz.y > aspect:
		var w := tsz.y * aspect
		src = Rect2((tsz.x - w) / 2.0, 0, w, tsz.y)
	else:
		var h := tsz.x / aspect
		src = Rect2(0, (tsz.y - h) / 2.0, tsz.x, h)
	var dst := Rect2(-size * (grow - 1.0) / 2.0 + offset, size * grow)
	draw_texture_rect_region(tex, dst, src)
	return src


func _draw_photo() -> void:
	var key := _photo_key()
	var tex: Texture2D = PHOTOS[key]
	var shaking := Game.is_shaking()
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * size.y * 0.025 if shaking else Vector2.ZERO
	var src := _draw_cover(tex, shake, 1.06 if shaking else 1.0)
	# fim de tarde escurece um pouco
	var dayf := clampf((Game.hour - Game.START_HOUR) / (Game.END_HOUR - Game.START_HOUR), 0.0, 1.0)
	if dayf > 0.75:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.08, 0.15, (dayf - 0.75) * 1.2))
	# equipamentos danificados: fumaça, faíscas e luz vermelha
	var tsz := tex.get_size()
	var marks: Dictionary = MARKS.get(key, {})
	for id in marks:
		if Game.is_broken(id):
			for p in marks[id]:
				var pt: Vector2 = (p * tsz - src.position) / src.size * size
				_draw_damage(pt)
	# efeitos dos eventos (espaço virtual 1280x720)
	var sc := size / Vector2(1280, 720)
	draw_set_transform(Vector2.ZERO, 0.0, sc)
	_draw_radiation_sky()
	var storm := Game.threat("areia")
	if storm > 0.0:
		var a := 0.42 + 0.08 * sin(t * 3.0) if storm >= 2.0 else storm * 0.3
		draw_rect(Rect2(-20, -20, 1320, 760), Color(0.7, 0.4, 0.18, a))
	var n := 140 if storm >= 2.0 else int(16 + storm * 60)
	var spd := 700.0 if storm >= 2.0 else 40.0 + storm * 200.0
	for i in n:
		var d: Vector2 = dust[i]
		var x := fmod(d.x + t * spd * (0.5 + float(i % 7) / 7.0), 1320.0) - 20.0
		draw_rect(Rect2(x, d.y + sin(t * 2.0 + i) * 6.0, 8, 8), Color(1, 0.85, 0.6, 0.6))
	if Game.threat("terremoto") > 0.0 and shaking:
		for i in 6:
			draw_rect(Rect2(200 + i * 160, fmod(t * 300.0 + i * 120.0, 700.0), 16, 14), Color("6b3a22"))
	_draw_shutter()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_damage(pt: Vector2) -> void:
	var k := size.y / 300.0
	for i in 4:
		var rise := fmod(t * 22.0 + i * 15.0, 60.0)
		draw_circle(pt + Vector2(sin(t + i) * 4.0, -rise) * k, (6.0 + rise * 0.25) * k, Color(0.15, 0.15, 0.15, 0.55 - rise / 120.0))
	if fmod(t * 6.0 + pt.x, 2.0) < 0.5:
		for i in 4:
			draw_rect(Rect2(pt + Vector2(randf_range(-10, 10), randf_range(-8, 6)) * k, Vector2(3, 3) * k), Color(1, 0.9, 0.3))
	var on := fmod(t, 0.8) < 0.4
	draw_arc(pt, 14.0 * k, 0, TAU, 20, Color(1, 0.2, 0.15, 0.9 if on else 0.3), 3.0 * k)


func _draw() -> void:
	if not Game.is_earth():
		_draw_photo()
		return
	var sc := size / Vector2(1280, 720)
	var shake := Vector2.ZERO
	if Game.is_shaking():
		shake = Vector2(randf_range(-12, 12), randf_range(-8, 8))
	draw_set_transform(shake * sc, 0.0, sc)
	var earth := Game.is_earth()

	# Céu em faixas (como no vídeo: laranja em cima, creme no horizonte)
	var dayf := clampf((Game.hour - Game.START_HOUR) / (Game.END_HOUR - Game.START_HOUR), 0.0, 1.0)
	var top := Color("3f74b8") if earth else Color("c77a3a").lerp(Color("8a4a3a"), smoothstep(0.7, 1.0, dayf))
	var bot := Color("bfe3f5") if earth else Color("f3d49a").lerp(Color("d9905a"), smoothstep(0.7, 1.0, dayf))
	for i in 12:
		draw_rect(Rect2(-20, i * 36, 1320, 37), top.lerp(bot, i / 11.0))
	draw_circle(Vector2(240.0 + dayf * 800.0, 250.0 - sin(dayf * PI) * 170.0), 36, Color(1, 0.96, 0.85))

	_draw_radiation_sky()

	var far := Color("8fa7b8") if earth else Color("c98a5a")
	var near := Color("5a7a44") if earth else Color("a65a35")
	var ground := Color("6f9a4a") if earth else Color("9c4a2c")
	var off: float = {"left": 0.0, "center": 300.0, "right": 600.0}.get(view, 0.0)
	var far_pts := PackedVector2Array()
	for i in 15:
		var x := -40.0 + i * 100.0
		far_pts.append(Vector2(x, 360.0 - absf(sin((x + off) * 0.009)) * 60.0 - absf(sin((x + off) * 0.023)) * 22.0))
	far_pts.append(Vector2(1320, 420))
	far_pts.append(Vector2(-40, 420))
	draw_colored_polygon(far_pts, far)
	_draw_storm_wall()
	var near_pts := PackedVector2Array()
	for i in 15:
		var x := -40.0 + i * 100.0
		near_pts.append(Vector2(x, 400.0 - absf(sin((x + off) * 0.007 + 1.0)) * 26.0))
	near_pts.append(Vector2(1320, 420))
	near_pts.append(Vector2(-40, 420))
	draw_colored_polygon(near_pts, near)
	draw_rect(Rect2(-20, 410, 1320, 330), ground)
	for i in 6:
		draw_rect(Rect2(-20, 430 + i * 48, 1320, 8), ground.darkened(0.05 + i * 0.02))
	for r in rocks:
		draw_rect(Rect2(r.x, r.y, r.z * 1.8, r.z * 0.8), ground.darkened(0.3))

	_draw_quake_dust()

	match view:
		"left":
			_draw_left(earth)
		"center":
			_draw_center(earth)
		"right":
			_draw_right(earth)
	_draw_rover(earth)

	var storm := Game.threat("areia")
	if storm >= 2.0:
		draw_rect(Rect2(-20, -20, 1320, 760), Color(0.7, 0.4, 0.18, 0.4 + 0.08 * sin(t * 3.0)))
	var n := 140 if storm >= 2.0 else int(16 + storm * 60)
	var spd := 700.0 if storm >= 2.0 else 40.0 + storm * 200.0
	for i in n:
		var p: Vector2 = dust[i]
		var x := fmod(p.x + t * spd * (0.5 + float(i % 7) / 7.0), 1320.0) - 20.0
		draw_rect(Rect2(x, p.y + sin(t * 2.0 + i) * 6.0, 8, 8), Color(1, 0.85, 0.6, 0.6))

	draw_set_transform(Vector2.ZERO, 0.0, sc)
	_draw_shutter()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shutter() -> void:
	var s := Game.shutter
	if s <= 0.0:
		return
	var h := 720.0 * s
	draw_rect(Rect2(0, 0, 1280, h), Color("8e9aa1"))
	var y := h - 40.0
	while y > -40.0:
		draw_rect(Rect2(0, y, 1280, 8), Color("b4bfc5"))
		draw_rect(Rect2(0, y + 28, 1280, 8), Color("6b777d"))
		y -= 48.0
	# barra inferior com faixas de aviso
	draw_rect(Rect2(0, h - 36, 1280, 36), Color("2b2f33"))
	var x := -40.0
	while x < 1320.0:
		draw_colored_polygon(PackedVector2Array([Vector2(x, h - 32), Vector2(x + 40, h - 32), Vector2(x + 20, h - 4), Vector2(x - 20, h - 4)]), Color("f2c230"))
		x += 80.0


func _draw_radiation_sky() -> void:
	# Tempestade solar: céu ofuscante e raios de luz
	var r := Game.threat("solar")
	if r <= 0.0:
		return
	var strength := 1.0 if r >= 2.0 else r * 0.6
	var flick := (0.6 + 0.4 * sin(t * 4.0)) * strength
	draw_rect(Rect2(-20, -20, 1320, 440), Color(1.0, 0.9, 0.45, (0.25 + 0.2 * flick) * strength))
	var sun := Vector2(640, 120)
	for i in 12:
		var a := t * 0.3 + i * TAU / 12.0
		draw_line(sun, sun + Vector2(cos(a), sin(a)) * (500.0 + 80.0 * sin(t * 3.0 + i)), Color(1, 0.95, 0.6, 0.25 * flick), 18.0)
	draw_circle(sun, (70 + 8 * flick) * strength, Color(1, 0.97, 0.75))
	for band in 3:
		var pts := PackedVector2Array()
		for i in 34:
			var x := -40.0 + i * 40.0
			pts.append(Vector2(x, 220.0 + band * 40.0 + sin(x * 0.01 + t * 1.5 + band) * 20.0))
		draw_polyline(pts, Color(1.0, 0.75, 0.3, 0.3 * flick + 0.1), 12.0 - band * 3.0)


func _draw_storm_wall() -> void:
	var s := Game.threat("areia")
	if s <= 0.0 or s >= 2.0:
		return
	var h := 60.0 + s * 380.0
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	for i in 34:
		var x := -40.0 + i * 40.0
		var bump := sin(x * 0.02 + t * 0.8) * 25.0 + sin(x * 0.051 + t * 1.3) * 12.0
		pts.append(Vector2(x, 415.0 - h + bump))
		rim.append(Vector2(x, 415.0 - h + bump))
	pts.append(Vector2(1320, 420))
	pts.append(Vector2(-40, 420))
	draw_colored_polygon(pts, Color(0.45, 0.25, 0.13, 0.65 + 0.3 * s))
	draw_polyline(rim, Color(0.88, 0.66, 0.42, 0.9), 10.0)


func _draw_quake_dust() -> void:
	var q := Game.threat("terremoto")
	if q <= 0.0:
		return
	var k := 1.0 if q >= 2.0 else q
	for i in 7:
		draw_circle(Vector2(120.0 + i * 170.0, 395.0), 16.0 + k * 42.0 + sin(t * 2.0 + i) * 6.0, Color(0.85, 0.65, 0.48, 0.3 + 0.35 * k))
	if Game.is_shaking():
		for i in 6:
			draw_rect(Rect2(200 + i * 160, fmod(t * 300.0 + i * 120.0, 460.0), 16, 14), Color("6b3a22"))


func _half_dome(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _lights_on() -> bool:
	return not Game.blackout


func _tank(pos: Vector2, length: float, h: float) -> void:
	var white := Color("f1ebdc")
	draw_rect(Rect2(pos, Vector2(length, h)), white)
	draw_rect(Rect2(pos + Vector2(0, h * 0.65), Vector2(length, h * 0.35)), Color("d4cdbb"))
	draw_circle(pos + Vector2(0, h / 2.0), h / 2.0, white)
	draw_circle(pos + Vector2(length, h / 2.0), h / 2.0, Color("d4cdbb"))
	draw_rect(Rect2(pos + Vector2(length * 0.3, -4), Vector2(10, h + 8)), Color("9aa3a8"))
	draw_rect(Rect2(pos + Vector2(length * 0.7, -4), Vector2(10, h + 8)), Color("9aa3a8"))


func _distant_rover(x: float, y: float, col: Color) -> void:
	draw_rect(Rect2(x, y - 26, 70, 20), Color("4a4f55"))
	draw_rect(Rect2(x + 8, y - 38, 30, 14), col)
	for w in 3:
		draw_rect(Rect2(x + 4 + w * 24, y - 8, 14, 12), Color("1f1f22"))


func _draw_center(earth: bool) -> void:
	# Muro da base (lado esquerdo, como no vídeo)
	var wall := PackedVector2Array([Vector2(-20, 150), Vector2(400, 330), Vector2(400, 560), Vector2(-20, 740)])
	draw_colored_polygon(wall, Color("b9a097"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 150), Vector2(400, 330), Vector2(400, 350), Vector2(-20, 185)]), Color("8f7770"))
	for i in 5:
		var fx := 40.0 + i * 80.0
		var fy0 := 150.0 + (fx + 20.0) * 0.43
		draw_line(Vector2(fx, fy0 + 10), Vector2(fx, fy0 + 190 - i * 20), Color("9d857d"), 6.0)
	for i in 4:
		var y0 := 250.0 + i * 70.0
		draw_line(Vector2(-20, y0), Vector2(400, y0 + 120 - i * 25), Color("a68d85"), 4.0)
	# Rovers estacionados no horizonte
	_distant_rover(820, 412, Color("e3a33b"))
	_distant_rover(920, 410, Color("c9d2d2"))
	_distant_rover(1030, 412, Color("e3a33b"))
	_distant_rover(1140, 410, Color("9aa3a8"))
	# Módulo amarelo com topo escuro e luzes verdes
	draw_rect(Rect2(470, 440, 190, 130), Color("e9a93a"))
	draw_rect(Rect2(660, 450, 40, 120), Color("b9772a"))
	draw_rect(Rect2(470, 400, 190, 48), Color("3a3f44"))
	draw_colored_polygon(PackedVector2Array([Vector2(660, 400), Vector2(700, 412), Vector2(700, 452), Vector2(660, 448)]), Color("2a2e32"))
	var lit := _lights_on()
	for r in 2:
		for c in 6:
			var col := Color("9be07f") if lit and (c + r + int(t * 2.0)) % 5 != 0 else Color("355a35")
			draw_rect(Rect2(484 + c * 28, 410 + r * 18, 16, 10), col)
	draw_rect(Rect2(470, 500, 190, 14), Color("2f3338"))
	draw_rect(Rect2(540, 520, 50, 50), Color("c78a2e"))
	# Tanques brancos deitados
	_tank(Vector2(740, 500), 190, 58)
	_tank(Vector2(770, 450), 150, 46)
	# Antena
	draw_rect(Rect2(560, 300, 8, 100), Color("8a8f90"))
	draw_circle(Vector2(564, 296), 12, Color("e8604c") if fmod(t, 1.2) < 0.6 else Color("7a2f25"))


func _draw_left(earth: bool) -> void:
	var white := Color("e6e2d6")
	_half_dome(Vector2(480, 470), 170, white)
	for i in 3:
		draw_rect(Rect2(370 + i * 80, 380, 44, 26), Color("5ec8f0") if _lights_on() else Color("2b2b2b"))
	draw_rect(Rect2(650, 410, 260, 64), white)
	draw_rect(Rect2(650, 436, 260, 12), Color("e9a93a"))
	draw_rect(Rect2(470, 230, 10, 70), Color("8a8f90"))
	draw_circle(Vector2(475, 226), 14, Color("e8604c") if fmod(t, 1.2) < 0.6 else Color("7a2f25"))
	# Garagem do robô
	draw_rect(Rect2(960, 360, 300, 116), Color("b9a097"))
	draw_rect(Rect2(990, 396, 180, 80), Color("2b3a3f"))
	draw_rect(Rect2(960, 360, 300, 14), Color("e9a93a"))
	# Painéis solares em primeiro plano (ficam sujos de poeira)
	var dirt := clampf(1.0 - Game.equip["paineis"] / 100.0, 0.0, 1.0)
	for i in 3:
		var x := 40.0 + i * 300.0
		draw_rect(Rect2(x + 120, 640, 16, 80), Color("5b6266"))
		var poly := PackedVector2Array([Vector2(x, 660), Vector2(x + 260, 660), Vector2(x + 290, 560), Vector2(x + 30, 560)])
		draw_colored_polygon(poly, Color("2c4f8a"))
		for j in 6:
			draw_line(Vector2(x + 10 + j * 44, 660), Vector2(x + 40 + j * 44, 560), Color("6f9be0"), 6.0)
		draw_line(Vector2(x + 15, 610), Vector2(x + 275, 610), Color("6f9be0"), 6.0)
		draw_colored_polygon(poly, Color(0.66, 0.4, 0.2, dirt * 0.95))


func _draw_right(earth: bool) -> void:
	# Estufa
	_half_dome(Vector2(300, 480), 160, Color(0.75, 0.95, 0.85, 0.6))
	for i in 8:
		draw_rect(Rect2(180 + i * 30, 440 - (i % 3) * 10, 16, 40 + (i % 3) * 10), Color("6cc35f"))
	# Reciclador de água (luz azul = ok, vermelha = gasto)
	draw_rect(Rect2(560, 390, 150, 100), Color("596b70"))
	draw_rect(Rect2(575, 405, 120, 26), Color("2b3a3f"))
	var rok: bool = Game.equip["reciclador"] >= 40.0 and not Game.blackout
	draw_rect(Rect2(615, 444, 36, 30), (Color("5ec8f0") if rok else Color("e8604c")) * Color(1, 1, 1, 0.6 + 0.4 * sin(t * (2.0 if rok else 9.0))))
	# Gerador de O2
	draw_rect(Rect2(770, 370, 150, 120), Color("596b70"))
	draw_rect(Rect2(785, 385, 120, 26), Color("2b3a3f"))
	var ok: bool = Game.equip["gerador"] >= 40.0 and not Game.blackout
	draw_rect(Rect2(825, 430, 36, 36), (Color("8be07f") if ok else Color("e8604c")) * Color(1, 1, 1, 0.6 + 0.4 * sin(t * (2.0 if ok else 9.0))))
	_tank(Vector2(990, 440), 200, 60)


func _draw_rover(earth: bool) -> void:
	var p := Game.research_progress()
	var out := not Game.research_job.is_empty()
	var x := 0.0
	var y := 600.0
	if view == "left" and not out:
		x = 1020.0
		y = 470.0
	elif view == "center" and out:
		x = 1100.0 - sin(p * PI) * 700.0
		y = 640.0
	else:
		return
	var body := Color("e0e0e0") if earth else Color("e9c74a")
	draw_rect(Rect2(x, y - 44, 130, 44), body)
	draw_rect(Rect2(x + 12, y - 68, 52, 26), Color("2b3a3f"))
	draw_rect(Rect2(x + 98, y - 92, 6, 48), Color("8a8f90"))
	draw_rect(Rect2(x + 92, y - 104, 18, 14), Color("5ec8f0"))
	for w in 3:
		draw_rect(Rect2(x + 6 + w * 44, y - 8, 30, 22), Color("1f1f1f"))
	if Game.equip["robos"] < 35.0:
		for i in 3:
			var sy := fmod(t * 40.0 + i * 20.0, 60.0)
			draw_circle(Vector2(x + 40 + i * 6, y - 74 - sy), 10 + sy * 0.2, Color(0.2, 0.2, 0.2, 0.5 - sy / 140.0))
