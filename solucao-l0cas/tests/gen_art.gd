extends Node
## Gera as imagens das janelas: cenas 3D low-poly de Marte renderizadas em baixa
## resolução, com paleta reduzida e contorno escuro (estilo pixel art 3D).
## Saída: res://art/gen/*.png e res://art/gen/marks.gd (posição dos equipamentos).

const W := 640
const H := 360
## Rode com: --rendering-method forward_plus (sombras suaves, SSAO, neblina, brilho).

var mats := {}
var marks := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/gen"))
	var only := OS.get_environment("GEN_ONLY")
	for scene in ["paineis", "rover", "perfuracao", "base", "vista", "vista_tarde"]:
		if only == "" or only.contains(scene):
			await _render(scene)
	if only == "" or only.contains("interior"):
		await _render_interior()
	if only == "":
		_save_marks()
	print("GERACAO OK")
	get_tree().quit()


# ---------- materiais e primitivas ----------

func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# sombreamento suave (Burley) com um pouco de brilho: aspecto 3D
	var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	m.roughness = 0.9 if lum < 0.5 else 0.7
	m.metallic = 0.25 if (c.s < 0.35 and lum < 0.45) else 0.0
	m.metallic_specular = 0.35
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mats[key] = m
	return m


func box(p: Node3D, sz: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	p.add_child(mi)
	return mi


func cyl(p: Node3D, r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, seg := 14, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	p.add_child(mi)
	return mi


## Viga/cabo entre dois pontos (coordenadas globais).
func beam(p: Node3D, a: Vector3, b: Vector3, t: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(t, t, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat(c)
	p.add_child(mi)
	var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.look_at_from_position((a + b) / 2.0, b, up)
	return mi


func blob(p: Node3D, r: float, pos: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = mat(c)
	mi.position = pos
	mi.scale = scl
	p.add_child(mi)
	return mi


# ---------- objetos ----------

func ground(p: Node3D, seed_v: int) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	g.mesh = pm
	g.material_override = mat(Color("6c3722"))
	p.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 90:
		var pos := Vector3(rng.randf_range(-40, 40), 0.01, rng.randf_range(-60, 15))
		var col := Color("7a4129") if rng.randf() < 0.5 else Color("5a2c1b")
		cyl(p, rng.randf_range(0.6, 3.5), 0.02, pos, col, Vector3(0, rng.randf() * 90, 0), 6)
	for i in 50:
		var pos2 := Vector3(rng.randf_range(-30, 30), 0.08, rng.randf_range(-40, 12))
		box(p, Vector3(0.25, 0.15, 0.2) * rng.randf_range(0.6, 1.6), pos2, Color("4a2216"), Vector3(0, rng.randf() * 90, 0))
	# dunas e ondulações do terreno (dão profundidade)
	for i in 14:
		var dpos := Vector3(rng.randf_range(-60, 60), -0.6, rng.randf_range(-90, -12))
		blob(p, 1.0, dpos, Color("744027") if i % 2 == 0 else Color("673521"), Vector3(rng.randf_range(8, 22), rng.randf_range(1.2, 2.6), rng.randf_range(5, 12)))
	# pedras maiores espalhadas
	for i in 18:
		var rp := Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-35, 8))
		blob(p, rng.randf_range(0.2, 0.55), rp, Color("5a2a1d"), Vector3(1.3, 0.7, 1.0))


func mountains(p: Node3D) -> void:
	# morro estratificado ao fundo (camadas de cores)
	var layers := [Color("c47a44"), Color("e2a05a"), Color("b8693a"), Color("e8b672"), Color("a95c34")]
	for i in layers.size():
		blob(p, 1.0, Vector3(-10, -2.0 + i * 0.1, -160), layers[i], Vector3(90.0 - i * 11.0, 26.0 - i * 4.0, 30.0))
	blob(p, 1.0, Vector3(120, -4, -190), Color("c98552"), Vector3(80, 14, 30))


func solar_panel(p: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	for lx in [-0.8, 0.8]:
		for lz in [-0.45, 0.45]:
			box(p, Vector3(0.07, 0.75, 0.07), pos + Vector3(lx, 0.37, lz), Color("2e3c42"))
	var panel := box(p, Vector3(2.05, 0.1, 1.45), pos + Vector3(0, 0.82, 0), Color("f0b860"), Vector3(-10, 0, 0))
	for i in 4:
		if rng.randf() < 0.6:
			box(panel, Vector3(rng.randf_range(0.3, 0.9), 0.02, rng.randf_range(0.2, 0.55)), Vector3(rng.randf_range(-0.6, 0.6), 0.06, rng.randf_range(-0.45, 0.45)), Color("6a8fa0"))
	box(panel, Vector3(2.07, 0.03, 0.04), Vector3(0, 0.06, 0), Color("b8782c"))
	box(panel, Vector3(0.04, 0.03, 1.47), Vector3(0, 0.06, 0), Color("b8782c"))


func panel_field(p: Node3D, origin: Vector3, cols: int, rows: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in rows:
		for c in cols:
			solar_panel(p, origin + Vector3(c * 2.15, 0, r * 1.55), rng)


func rover(p: Node3D, pos: Vector3, yaw: float, arm_out := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw, 0)
	p.add_child(root)
	box(root, Vector3(1.7, 0.5, 1.05), Vector3(0, 0.75, 0), Color("d7a07c"))
	box(root, Vector3(1.2, 0.18, 0.95), Vector3(-0.1, 1.08, 0), Color("3f5c64"))
	box(root, Vector3(0.5, 0.3, 0.5), Vector3(0.45, 1.25, 0), Color("4a6a72"))
	cyl(root, 0.05, 0.9, Vector3(0.65, 1.55, 0.3), Color("cfc6b6"))
	box(root, Vector3(0.28, 0.2, 0.22), Vector3(0.65, 2.02, 0.3), Color("d7a07c"))
	box(root, Vector3(0.1, 0.1, 0.06), Vector3(0.8, 2.02, 0.3), Color("2b3a3f"))
	for side in [-0.62, 0.62]:
		box(root, Vector3(1.6, 0.08, 0.08), Vector3(0, 0.5, side), Color("2e3c42"))
		for i in 3:
			cyl(root, 0.28, 0.24, Vector3(-0.62 + i * 0.62, 0.3, side * 1.05), Color("1d272b"), Vector3(90, 0, 0), 10)
			cyl(root, 0.12, 0.26, Vector3(-0.62 + i * 0.62, 0.3, side * 1.05), Color("6f7d82"), Vector3(90, 0, 0), 8)
	if arm_out:
		var a := root.to_global(Vector3(-0.7, 1.1, 0.3))
		var b := root.to_global(Vector3(-1.9, 1.55, 0.3))
		var c := root.to_global(Vector3(-2.6, 0.6, 0.3))
		beam(p, a, b, 0.08, Color("cfc6b6"))
		beam(p, b, c, 0.07, Color("cfc6b6"))
		box(p, Vector3(0.16, 0.16, 0.16), c, Color("2b3a3f"))
	return root


func rock(p: Node3D, pos: Vector3, s: float) -> void:
	blob(p, s, pos + Vector3(0, s * 0.55, 0), Color("6e2f2a"), Vector3(1.2, 0.85, 1.0))
	blob(p, s * 0.6, pos + Vector3(s * 0.5, s * 0.35, s * 0.3), Color("5a2522"), Vector3(1.0, 0.8, 1.1))


func cable(p: Node3D, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		beam(p, a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), 0.13, Color("1b2226"))


func base_building(p: Node3D, pos: Vector3, sz: Vector3) -> void:
	box(p, sz, pos + Vector3(0, sz.y / 2.0, 0), Color("d9c0a5"))
	box(p, Vector3(sz.x + 0.2, 0.18, sz.z + 0.2), pos + Vector3(0, sz.y + 0.05, 0), Color("c4a98d"))
	var beam := Color("4f7f86")
	var n := int(sz.x / 2.0)
	for i in n + 1:
		box(p, Vector3(0.18, sz.y, 0.18), pos + Vector3(-sz.x / 2.0 + i * sz.x / n, sz.y / 2.0, sz.z / 2.0 + 0.1), beam)
	box(p, Vector3(sz.x, 0.16, 0.16), pos + Vector3(0, sz.y * 0.68, sz.z / 2.0 + 0.12), beam)
	box(p, Vector3(sz.x + 0.3, 0.35, 0.4), pos + Vector3(0, 0.17, sz.z / 2.0 + 0.2), Color("3e5f66"))


func yellow_module(p: Node3D, pos: Vector3) -> void:
	box(p, Vector3(1.8, 0.2, 1.4), pos + Vector3(0, 0.1, 0), Color("4a7078"))
	box(p, Vector3(1.4, 1.1, 1.0), pos + Vector3(0, 0.75, 0), Color("f2aa34"))
	box(p, Vector3(1.45, 0.16, 1.05), pos + Vector3(0, 0.85, 0), Color("4a7078"))
	box(p, Vector3(0.4, 0.25, 0.02), pos + Vector3(-0.35, 0.55, 0.51), Color("1c2326"))
	box(p, Vector3(0.4, 0.25, 0.02), pos + Vector3(0.35, 0.55, 0.51), Color("1c2326"))
	box(p, Vector3(1.4, 0.3, 1.0), pos + Vector3(0, 1.45, 0), Color("f2aa34"))
	for i in 5:
		box(p, Vector3(0.08, 0.35, 0.8), pos + Vector3(-0.5 + i * 0.25, 1.75, 0), Color("4a7078"))
	cyl(p, 0.06, 0.8, pos + Vector3(-0.55, 1.9, -0.3), Color("d8cbb6"))


func tanks(p: Node3D, pos: Vector3) -> void:
	for i in 2:
		var tp := pos + Vector3(0, 0.55, i * 1.05)
		cyl(p, 0.48, 1.7, tp, Color("efe4cd"), Vector3(0, 0, 90), 14)
		cyl(p, 0.49, 0.06, tp + Vector3(0.55, 0, 0), Color("e8c87a"), Vector3(0, 0, 90), 14)
		for sx in [-0.55, 0.55]:
			box(p, Vector3(0.12, 0.7, 1.05), tp + Vector3(sx, -0.2, 0), Color("4a7078"))


func drill_pad(p: Node3D, pos: Vector3) -> void:
	cyl(p, 2.4, 0.3, pos + Vector3(0, 0.15, 0), Color("f0b040"), Vector3.ZERO, 6)
	cyl(p, 2.45, 0.1, pos + Vector3(0, 0.05, 0), Color("e7cfa0"), Vector3.ZERO, 6)
	cyl(p, 0.35, 0.05, pos + Vector3(0, 0.32, 0), Color("f6d98a"), Vector3.ZERO, 12)
	# braço robótico (base -> cotovelo -> punho -> ferramenta sobre o centro)
	var col_top := pos + Vector3(-3.0, 1.7, 1.3)
	var elbow := pos + Vector3(-1.6, 3.4, 0.5)
	var wrist := pos + Vector3(0, 2.6, 0)
	cyl(p, 0.4, 1.7, pos + Vector3(-3.0, 0.85, 1.3), Color("2b3a3f"), Vector3.ZERO, 10)
	beam(p, col_top, elbow, 0.22, Color("e8d4b0"))
	box(p, Vector3(0.32, 0.32, 0.32), elbow, Color("2b3a3f"))
	beam(p, elbow, wrist, 0.18, Color("e8d4b0"))
	box(p, Vector3(0.26, 0.4, 0.26), wrist, Color("2b3a3f"))
	beam(p, wrist, pos + Vector3(0, 1.3, 0), 0.08, Color("2b3a3f"))


func sample_table(p: Node3D, pos: Vector3) -> void:
	for lx in [-0.7, 0.7]:
		for lz in [-0.3, 0.3]:
			box(p, Vector3(0.07, 0.8, 0.07), pos + Vector3(lx, 0.4, lz), Color("2e3c42"))
	box(p, Vector3(1.6, 0.1, 0.8), pos + Vector3(0, 0.82, 0), Color("2e3c42"))
	box(p, Vector3(1.3, 0.12, 0.35), pos + Vector3(0, 0.93, 0), Color("1d272b"))
	for i in 8:
		var tp := pos + Vector3(-0.56 + i * 0.16, 1.15, 0)
		cyl(p, 0.045, 0.45, tp, Color("eee0c6"), Vector3.ZERO, 6)
		cyl(p, 0.05, 0.07, tp + Vector3(0, 0.25, 0), Color("d9553e"), Vector3.ZERO, 6)


func dish(p: Node3D, pos: Vector3) -> void:
	cyl(p, 0.08, 1.4, pos + Vector3(0, 0.7, 0), Color("6f7d82"))
	cyl(p, 0.9, 0.12, pos + Vector3(0, 1.75, 0), Color("d4b49a"), Vector3(55, 30, 0), 16, 0.95)


func light_pole(p: Node3D, pos: Vector3) -> void:
	cyl(p, 0.06, 3.0, pos + Vector3(0, 1.5, 0), Color("2e3c42"))
	box(p, Vector3(0.25, 0.3, 0.25), pos + Vector3(0, 3.1, 0), Color("1d272b"))


# ---------- cenas ----------

func _render(scene: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = 2048
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("e19a45")
	sm.sky_horizon_color = Color("f3d690")
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color("5e2c19")
	sm.ground_horizon_color = Color("c48352")
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.34
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	# oclusão de ambiente: cantos e encaixes mais escuros (volume)
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 2.5
	e.ssao_power = 1.6
	e.ssil_enabled = false
	# neblina de profundidade alaranjada
	e.fog_enabled = true
	e.fog_light_color = Color("e6b07a")
	e.fog_density = 0.0055
	e.fog_aerial_perspective = 0.35
	e.fog_sky_affect = 0.2
	# brilho leve nas partes claras
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.08
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.9
	e.adjustment_contrast = 1.14
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -40, 0)
	sun.light_color = Color("ffe0b0")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("9fb6d9")
	fill.light_energy = 0.18
	world.add_child(fill)
	if scene == "vista_tarde":
		# pôr do sol: sol baixo e avermelhado, céu mais escuro
		sm.sky_top_color = Color("6e3550")
		sm.sky_horizon_color = Color("f08a4a")
		sm.ground_horizon_color = Color("9a5236")
		sun.rotation_degrees = Vector3(-9, -70, 0)
		sun.light_color = Color("ff8a52")
		sun.light_energy = 1.6
		e.fog_light_color = Color("c4644a")
		e.ambient_light_energy = 0.22
	var cam := Camera3D.new()
	cam.fov = 48
	world.add_child(cam)
	ground(world, scene.length() * 13)
	mountains(world)
	var mk := {}
	match "vista" if scene == "vista_tarde" else scene:
		"paineis":
			panel_field(world, Vector3(-7, 0, -6), 7, 3)
			rover(world, Vector3(2.5, 0, -1.0), 15)
			rock(world, Vector3(-1.3, 0, 0.6), 0.85)
			cable(world, [Vector3(-4, 0, 2.5), Vector3(0.5, 0, 2.5), Vector3(4, 0, 4.5)])
			box(world, Vector3(1.6, 0.06, 1.0), Vector3(-0.6, 0.75, -1.6), Color("2e3c42"), Vector3(-15, 0, 0))
			cam.position = Vector3(-1.5, 4.6, 7.4)
			cam.look_at(Vector3(0.5, 0.8, -2.5))
			mk = {"paineis": [Vector3(-4, 0.9, -4), Vector3(3, 0.9, -4.5)], "robos": [Vector3(2.5, 1.2, -1.0)]}
		"rover":
			panel_field(world, Vector3(2, 0, -5), 5, 3)
			rover(world, Vector3(2.0, 0, 1.5), -35)
			rock(world, Vector3(-1.6, 0, 1.0), 0.95)
			cable(world, [Vector3(-5, 0, 3.8), Vector3(-1, 0, 3.8), Vector3(3, 0, 6)])
			drill_pad(world, Vector3(-6, 0, -9))
			cam.position = Vector3(-0.5, 2.6, 6.6)
			cam.look_at(Vector3(0.8, 0.9, 0.5))
			mk = {"paineis": [Vector3(6, 0.9, -3)], "robos": [Vector3(2.0, 1.3, 1.5)]}
		"perfuracao":
			drill_pad(world, Vector3(0, 0, 0))
			sample_table(world, Vector3(3.6, 0, 0.6))
			cam.position = Vector3(-0.2, 5.2, 6.4)
			cam.look_at(Vector3(0.4, 0.3, 0.1))
			mk = {"robos": [Vector3(-2.2, 2.6, 0.2)]}
		"base":
			base_building(world, Vector3(-3.5, 0, -1.5), Vector3(6, 3.2, 4))
			yellow_module(world, Vector3(1.2, 0, 1.2))
			tanks(world, Vector3(3.6, 0, 0.6))
			panel_field(world, Vector3(1, 0, -9), 6, 2)
			rover(world, Vector3(5, 0, -5.5), 10, false)
			rock(world, Vector3(1.2, 0, -5.2), 0.7)
			cam.position = Vector3(-1.0, 3.8, 7.0)
			cam.look_at(Vector3(2.0, 0.9, -1.0))
			mk = {"gerador": [Vector3(1.2, 1.3, 1.2)], "reciclador": [Vector3(3.6, 0.9, 1.1)], "robos": [Vector3(5, 1.2, -5.5)], "paineis": [Vector3(4, 0.9, -8.5)]}
		"vista":
			base_building(world, Vector3(-4, 0, -4), Vector3(6, 2.6, 4))
			box(world, Vector3(3, 1.4, 2.5), Vector3(-8.5, 0.7, -4.5), Color("d9c0a5"))
			yellow_module(world, Vector3(0.5, 0, -1.2))
			tanks(world, Vector3(2.4, 0, -1.6))
			dish(world, Vector3(-4, 2.6, -5))
			panel_field(world, Vector3(3, 0, -8), 8, 2)
			rover(world, Vector3(7, 0, -6), -5, false)
			rock(world, Vector3(4.2, 0, -5.4), 0.6)
			light_pole(world, Vector3(1.0, 0, 1.5))
			light_pole(world, Vector3(12, 0, -4))
			cam.position = Vector3(-2.0, 4.8, 11.0)
			cam.look_at(Vector3(1.5, 1.5, -3.5))
			mk = {"gerador": [Vector3(0.5, 1.3, -1.2)], "reciclador": [Vector3(2.4, 0.9, -1.1)], "paineis": [Vector3(8, 0.9, -7.5)], "robos": [Vector3(7, 1.2, -6)]}
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_stylize(img)
	img.save_png(ProjectSettings.globalize_path("res://art/gen/%s.png" % scene))
	var pts := {}
	for id in mk:
		var arr: Array = []
		for wp in mk[id]:
			var sp := cam.unproject_position(wp)
			arr.append(Vector2(snappedf(sp.x / W, 0.001), snappedf(sp.y / H, 0.001)))
		pts[id] = arr
	marks[scene] = pts
	print(scene, " ok")
	vp.queue_free()


## ---------- Interior da base ----------
## Câmera ortográfica: 1 unidade = 1 pixel da sala (2560x720). As janelas ficam
## vazadas (transparentes) nos mesmos retângulos usados pelo jogo (room.gd).
const ROOM_WINDOWS := [Rect2(130, 120, 540, 300), Rect2(880, 70, 800, 360), Rect2(1900, 120, 540, 300)]


func _wbox(p: Node3D, r: Rect2, z0: float, z1: float, c: Color) -> MeshInstance3D:
	# caixa definida por um retângulo da sala (pixels, y para baixo) e profundidade z0..z1
	return box(p, Vector3(r.size.x, r.size.y, z1 - z0), Vector3(r.position.x + r.size.x / 2.0, 720.0 - (r.position.y + r.size.y / 2.0), (z0 + z1) / 2.0), c)


func _wcyl(p: Node3D, cx: float, cy: float, r: float, h: float, z: float, c: Color, axis := "y") -> MeshInstance3D:
	var rot := Vector3.ZERO
	if axis == "x":
		rot = Vector3(0, 0, 90)
	elif axis == "z":
		rot = Vector3(90, 0, 0)
	return cyl(p, r, h, Vector3(cx, 720.0 - cy, z), c, rot, 16)


func _render_interior() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 360)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9a9fb0")
	e.ambient_light_energy = 0.38
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.1
	e.adjustment_saturation = 1.05
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 14.0
	e.ssao_intensity = 3.0
	e.ssao_power = 1.5
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 720.0
	cam.near = 1.0
	cam.far = 4000.0
	cam.position = Vector3(1280, 360, 1500)
	world.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_color = Color("ffe9c8")
	key.light_energy = 0.3
	key.shadow_enabled = true
	key.shadow_opacity = 0.6
	key.shadow_blur = 3.0
	key.directional_shadow_max_distance = 5000.0
	world.add_child(key)
	for lx in [300.0, 1000.0, 1560.0, 2280.0]:
		var o := OmniLight3D.new()
		o.position = Vector3(lx, 600, 300)
		# 1 unidade = 1 pixel: sem atenuação por distância, só o raio
		o.omni_range = 760.0
		o.omni_attenuation = 0.0
		o.light_color = Color("ffd29a")
		o.light_energy = 0.62
		o.shadow_enabled = true
		o.shadow_blur = 2.0
		world.add_child(o)
		# luminária no teto
		var lamp := box(world, Vector3(150, 10, 40), Vector3(lx, 720 - 64, 60), Color("fff1d2"))
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color("fff1d2")
		lm.emission_enabled = true
		lm.emission = Color("ffe2b0")
		lm.emission_energy_multiplier = 1.5
		lamp.material_override = lm
		box(world, Vector3(170, 8, 46), Vector3(lx, 720 - 57, 60), Color("3d4e54"))

	var wall := Color("8fa3ad")
	var dark := Color("55666e")
	var frame := Color("3d4e54")
	# parede com as janelas vazadas
	var pieces := [Rect2(0, 0, 130, 720), Rect2(670, 0, 210, 720), Rect2(1680, 0, 220, 720), Rect2(2440, 0, 120, 720)]
	for w in ROOM_WINDOWS:
		pieces.append(Rect2(w.position.x, 0, w.size.x, w.position.y))
		pieces.append(Rect2(w.position.x, w.end.y, w.size.x, 720 - w.end.y))
	for r in pieces:
		_wbox(world, r, -40, 0, wall)
	# emendas dos painéis e rebites (só onde há parede)
	for x in range(80, 2560, 160):
		var segs := [[58.0, 606.0]]
		for w in ROOM_WINDOWS:
			if x > w.position.x - 20 and x < w.end.x + 20:
				segs = [[58.0, w.position.y - 20.0], [w.end.y + 28.0, 606.0]]
		for s in segs:
			if s[1] - s[0] > 10:
				_wbox(world, Rect2(x - 2, s[0], 4, s[1] - s[0]), 0, 2, Color("6f828c"))
				_wcyl(world, x + 16, s[0] + 14, 4, 4, 2, Color("b8c6cd"), "z")
				_wcyl(world, x + 16, s[1] - 14, 4, 4, 2, Color("b8c6cd"), "z")
	# teto, canos e piso
	_wbox(world, Rect2(0, 0, 2560, 58), 0, 80, dark)
	_wbox(world, Rect2(0, 56, 2560, 6), 0, 84, Color("7a8b93"))
	_wcyl(world, 1280, 28, 8, 2560, 95, Color("9aa8ae"), "x")
	_wcyl(world, 1280, 44, 5, 2560, 110, Color("c79a4a"), "x")
	for bx in range(100, 2560, 300):
		_wbox(world, Rect2(bx, 20, 10, 34), 80, 115, Color("3d4e54"))
	_wbox(world, Rect2(0, 606, 2560, 114), 0, 220, Color("5b6a70"))
	_wbox(world, Rect2(0, 600, 2560, 10), 0, 225, Color("b5c4cb"))
	for fx in range(0, 2560, 80):
		_wbox(world, Rect2(fx, 610, 2, 110), 222, 224, Color("4d5b61"))
	# canos verticais nos cantos
	for vx in [760.0, 1790.0, 60.0]:
		_wcyl(world, vx, 330, 9, 560, 20, Color("9aa8ae"))
	# molduras das janelas
	for w in ROOM_WINDOWS:
		_wbox(world, Rect2(w.position.x - 18, w.position.y - 18, w.size.x + 36, 18), 0, 30, frame)
		_wbox(world, Rect2(w.position.x - 18, w.end.y, w.size.x + 36, 26), 0, 70, frame)
		_wbox(world, Rect2(w.position.x - 18, w.end.y, w.size.x + 36, 5), 0, 72, Color("5a7077"))
		_wbox(world, Rect2(w.position.x - 18, w.position.y, 18, w.size.y), 0, 30, frame)
		_wbox(world, Rect2(w.end.x, w.position.y, 18, w.size.y), 0, 30, frame)
		_wbox(world, Rect2(w.position.x + w.size.x / 2.0 - 6, w.position.y, 12, w.size.y), -10, 20, frame)
		for bx in [w.position.x - 9, w.end.x + 9]:
			for by in [w.position.y - 9, w.end.y + 13]:
				_wcyl(world, bx, by, 4, 4, 32, Color("8c9ca2"), "z")
	# prateleira com caixas e cilindro de O2
	_wbox(world, Rect2(40, 470, 360, 14), 0, 70, Color("4a5a60"))
	for i in 4:
		_wbox(world, Rect2(60 + i * 80, 410, 50, 60), 5, 60, Color("596b70") if i % 2 == 0 else Color("7a6440"))
	_wbox(world, Rect2(60, 484, 10, 30), 0, 20, Color("3d4e54"))
	_wbox(world, Rect2(370, 484, 10, 30), 0, 20, Color("3d4e54"))
	_wcyl(world, 535, 520, 36, 180, 60, Color("c9d2d2"))
	_wcyl(world, 535, 520 - 95, 30, 12, 60, Color("9aa8ae"))
	_wcyl(world, 535, 520 - 10, 37, 22, 60, Color("4a8cf0"))
	# painel de comunicação entre as janelas
	_wbox(world, Rect2(700, 450, 150, 110), 0, 18, Color("2b3a3f"))
	_wbox(world, Rect2(712, 462, 126, 60), 18, 20, Color("164a52"))
	for i in 4:
		_wbox(world, Rect2(716 + i * 30, 532, 16, 14), 18, 26, [Color("8be07f"), Color("f2d541"), Color("e8604c"), Color("5ec8f0")][i])
	# mesa central e objetos
	_wbox(world, Rect2(780, 500, 1000, 26), 0, 170, Color("4f6268"))
	_wbox(world, Rect2(800, 526, 960, 194), 0, 150, Color("2c383d"))
	for dx in [960.0, 1280.0, 1600.0]:
		_wbox(world, Rect2(dx - 120, 560, 240, 4), 150, 152, Color("1c2427"))
		_wbox(world, Rect2(dx - 20, 575, 40, 8), 150, 156, Color("8c9ca2"))
	_wcyl(world, 967, 484, 17, 36, 120, Color("c9483a"))
	_wbox(world, Rect2(985, 476, 8, 18), 110, 125, Color("c9483a"))
	_wbox(world, Rect2(1150, 462, 260, 40), 90, 96, Color("1f4f8f"))
	_wbox(world, Rect2(1160, 468, 240, 2), 96, 97, Color("e8f1ff"))
	_wbox(world, Rect2(1160, 484, 160, 2), 96, 97, Color("e8f1ff"))
	_wbox(world, Rect2(1430, 470, 110, 30), 60, 120, Color("2b3a3f"))
	for i in 5:
		_wbox(world, Rect2(1440 + i * 20, 478, 12, 10), 120, 124, Color("5ec8f0") if i % 2 == 0 else Color("f2a541"))
	_wcyl(world, 1564, 440, 5, 120, 110, Color("6b7a80"))
	cyl(world, 22, 30, Vector3(1564, 720 - 365, 110), Color("8a9aa0"), Vector3.ZERO, 16, 10)
	# caixa dos escudos (as alavancas são desenhadas pelo jogo)
	_wbox(world, Rect2(1712, 200, 168, 260), 0, 30, Color("39474c"))
	_wbox(world, Rect2(1712, 200, 168, 6), 0, 32, Color("5a7077"))
	_wbox(world, Rect2(1730, 250, 56, 170), 30, 32, Color("1c2427"))
	_wbox(world, Rect2(1806, 250, 56, 170), 30, 32, Color("1c2427"))
	# suporte da luz de alarme
	_wbox(world, Rect2(1250, 58, 60, 18), 0, 60, Color("2a3439"))
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	# janelas vazadas exatamente nos retângulos do jogo (imagem = sala / 2)
	for y in img.get_height():
		for x in img.get_width():
			var rp := Vector2(x * 2 + 1, y * 2 + 1)
			var inside := false
			for w in ROOM_WINDOWS:
				if (w as Rect2).has_point(rp):
					inside = true
			var c := img.get_pixel(x, y)
			c.a = 0.0 if inside else 1.0
			img.set_pixel(x, y, c)
	_stylize(img)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.save_png(ProjectSettings.globalize_path("res://art/gen/interior.png"))
	print("interior ok")
	vp.queue_free()


## Paleta reduzida + contorno escuro onde a cor muda muito (visual pixel art).
func _stylize(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for y in h:
		for x in w:
			var c0 := src.get_pixel(x, y)
			var gray := c0.r * 0.3 + c0.g * 0.59 + c0.b * 0.11
			var c := Color(lerpf(c0.r, gray, 0.06), lerpf(c0.g, gray, 0.06), lerpf(c0.b, gray, 0.06))
			var q := Color(snappedf(c.r, 1.0 / 40.0), snappedf(c.g, 1.0 / 40.0), snappedf(c.b, 1.0 / 40.0), c0.a)
			img.set_pixel(x, y, q)
			lum[y * w + x] = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var l := lum[y * w + x]
			var d := maxf(absf(l - lum[y * w + x + 1]), absf(l - lum[(y + 1) * w + x]))
			if d > 0.14:
				var c2 := img.get_pixel(x, y)
				img.set_pixel(x, y, c2.darkened(0.3))


func _save_marks() -> void:
	var txt := "## Gerado por tests/gen_art.gd: posição (0..1) dos equipamentos em cada imagem.\nconst MARKS := {\n"
	for scene in marks:
		txt += "\t\"%s\": {\n" % scene
		for id in marks[scene]:
			var arr := PackedStringArray()
			for v in marks[scene][id]:
				arr.append("Vector2(%s, %s)" % [v.x, v.y])
			txt += "\t\t\"%s\": [%s],\n" % [id, ", ".join(arr)]
		txt += "\t},\n"
	txt += "}\n"
	var f := FileAccess.open("res://art/gen/marks.gd", FileAccess.WRITE)
	f.store_string("extends RefCounted\n" + txt)
	f.close()
