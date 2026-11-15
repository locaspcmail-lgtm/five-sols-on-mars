extends Node
## Teste automático: tutorial completo + bot jogando a missão (cuidadoso e descuidado).

var main
var finished_days := 0
var died := false
var pending_end := false
var t0 := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.day_finished.connect(_on_day_end)
	Game.died.connect(func(_c): died = true)
	await _frames(3)

	# ---- Tutorial ----
	main._start_tutorial()
	await _wait_running()
	main.pan = 1000.0
	await _frames(3)
	main._open_window("center")
	await _frames(3)
	main._close_window()
	main._set_panel(true)
	await _frames(3)
	main.panel.open_screen("R")
	await _frames(3)
	Game.eat()
	await _frames(3)
	Game.drink()
	await _frames(3)
	main.panel.open_screen("P")
	Game.start_research("agua")
	await _frames(3)
	main.panel.open_screen("M")
	Game.start_maint("paineis")
	main._on_minigame_done(1.0)
	await _frames(3)
	main.panel.open_screen("M")
	await _frames(2)
	main.panel.open_screen("D")
	await _frames(3)
	for i in 4:
		print("  passo do diário: ", main.tut_step)
		main._tut_next()
		await _frames(3)
	print("tutorial step antes do escudo: ", main.tut_step, " evento=", Game.today_event)
	main._set_panel(false)
	main._pull_lever("radiacao")
	await _frames(5)
	print("tutorial step com escudo: ", main.tut_step, " janela=", snappedf(Game.shutter, 0.1))
	main._pull_lever("radiacao")
	var g := 0
	while finished_days == 0 and g < 3000:
		g += 1
		await get_tree().process_frame
	print("tutorial terminou: ", finished_days == 1, " step=", main.tut_step)
	Engine.time_scale = 20.0
	main._launch()
	await _wait_running()
	print("tela de viagem ok, sol=", Game.day)

	# ---- Missão: bot cuidadoso ----
	finished_days = 0
	t0 = Time.get_ticks_msec()
	await _play(true)
	print("CUIDADOSO: sols=", finished_days, " morreu=", died, " sol=", Game.day, " venceu=", Game.won, " pesquisas=", Game.research_done, " causa=", Game.cause, " plano=", Game.event_plan.values().map(func(a): return a.size()))

	# ---- Missão: bot descuidado (sem escudos) ----
	finished_days = 0
	died = false
	main._start_mission()
	await _play(false)
	print("DESCUIDADO: sols=", finished_days, " morreu=", died, " sol=", Game.day, " pesquisas=", Game.research_done, " causa=", Game.cause)

	# ---- Blecaute: o painel precisa abrir para comer e beber ----
	main._start_mission()
	await _wait_running()
	Game._spend(9999)
	await _frames(3)
	main._set_panel(true)
	await _frames(10)
	var r0: int = Game.racoes
	Game.res["saciedade"] = 30.0
	Game.eat()
	print("BLECAUTE: blackout=", Game.blackout, " painel_aberto=", main.panel_shown, " comeu=", Game.racoes < r0, " pesquisa=", Game.can_research("agua"))
	Game.equip["gerador"] = 100.0
	Game.breakdowns = [{"id": "gerador", "at": Game.hour, "done": false}]
	Game._tick_breakdown()
	print("FALHA FORCADA: gerador quebrado=", Game.is_broken("gerador"))
	for k in Game.equip:
		Game.equip[k] = 100.0
	var dias_com_falha := 0
	var duplas := 0
	for d in 100:
		Game.day = 2
		Game._plan_breakdown()
		if not Game.breakdowns.is_empty():
			dias_com_falha += 1
		if Game.breakdowns.size() >= 2:
			duplas += 1
	print("SORTEIO (100 sols): com falha=", dias_com_falha, " com 2 falhas=", duplas)
	Engine.time_scale = 1.0
	main._show_title()
	await _frames(3)
	print("SMOKE OK")
	get_tree().quit()


func _on_day_end(_r: Dictionary) -> void:
	finished_days += 1
	pending_end = true


func _wait_running() -> void:
	var g := 0
	while not Game.running and g < 3000:
		g += 1
		await get_tree().process_frame


func _play(smart: bool) -> void:
	await _wait_running()
	var order := ["agua", "solo", "clima", "vida", "terremoto", "tempestade"]
	var guard := 0
	while guard < 80000:
		guard += 1
		if died or Game.day > Game.MAX_DAYS:
			return
		if not Game.running:
			if pending_end:
				pending_end = false
				print("  fim do sol %d: energia=%d racoes=%d garrafas=%d fome=%d sede=%d rad=%d o2=%d pesquisas=%d evento=%s" % [Game.day - 1, Game.energia, Game.racoes, Game.garrafas, Game.res["saciedade"], Game.res["hidratacao"], Game.res["radiacao"], Game.res["oxigenio"], Game.research_done, str(Game.events_for(Game.day - 1).size())])
				if Game.day > Game.MAX_DAYS:
					return
				main._next_day()
				await _wait_running()
			await get_tree().process_frame
			continue
		if Game.res["saciedade"] < 45.0:
			Game.eat()
		if Game.res["hidratacao"] < 45.0:
			Game.drink()
		if smart and Game.today_event == "" and Game.any_shield():
			for k in ["radiacao", "desastre"]:
				if Game.shields[k]:
					Game.toggle_shield(k)
		if smart and Game.today_event != "":
			var sh: String = Game.EVENTS[Game.today_event]["shield"]
			if not Game.shields[sh] and Game.energia >= Game.SHIELD_COST[sh]:
				Game.toggle_shield(sh)
		if not Game.sealed():
			if Game.maint_job.is_empty():
				if Game.equip["paineis"] < 60.0 and Game.can_maint("paineis") == "":
					Game.start_maint("paineis")
					main._on_minigame_done(0.8)
				elif smart:
					for k in ["gerador", "reciclador", "robos"]:
						if Game.equip[k] < 45.0 and Game.can_maint(k) == "":
							Game.start_maint(k)
							main._on_minigame_done(0.7)
							break
			var budget := 110.0 if smart else 0.0
			if Game.research_job.is_empty() and Game.energia > budget + 30.0:
				for id in order:
					if Game.can_research(id) == "":
						Game.start_research(id)
						break
		await get_tree().process_frame
