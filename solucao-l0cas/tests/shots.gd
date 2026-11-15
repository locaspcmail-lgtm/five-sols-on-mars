extends Node

var main


func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	await _shot("00_menu")
	main._start_tutorial()
	main._clear_overlay()
	Game.running = true
	await _shot("1_tut_step1")
	main.tut_step = 1
	await _shot("2_tut_janela")
	main.tut_step = 3
	main._set_panel(true)
	await get_tree().create_timer(0.5).timeout
	await _shot("3_tut_R")
	main.panel.open_screen("R")
	main.tut_step = 4
	await _shot("4_tut_comer")
	main._set_panel(false)
	await get_tree().create_timer(0.4).timeout
	main._set_panel(true)
	await get_tree().create_timer(0.5).timeout
	main._set_panel(false)
	main.tut_step = 8
	main._tut_next()
	main._tut_next()
	await get_tree().create_timer(0.6).timeout
	await _shot("4b_tut_diario")
	main._close_diary_example()
	await get_tree().create_timer(0.4).timeout
	main.tut_step = 12
	main.pan = 1100.0
	await _shot("5_tut_alavanca")
	main._launch()
	await get_tree().create_timer(4.5).timeout
	await _shot("0_viagem")
	main._clear_overlay()
	# avisos
	main._start_mission()
	await get_tree().create_timer(3.5).timeout
	await _shot("5b_intro_sol1")
	main._clear_overlay()
	Game.running = true
	Game.today_events = [{"type": "solar", "start": Game.hour, "end": Game.hour + 3.0, "warned": true}]
	main.pan = 640.0
	await get_tree().create_timer(0.7).timeout
	main.pan = 0.0
	await get_tree().create_timer(0.4).timeout
	await _shot("w_sala_esquerda")
	Game.today_events = []
	Game.today_event = ""
	for v in ["left", "center", "right"]:
		main._open_window(v)
		await get_tree().create_timer(0.4).timeout
		await _shot("w_" + v)
		main._close_window()
	Game.equip["gerador"] = 0.0
	main._open_window("center")
	await get_tree().create_timer(0.6).timeout
	await _shot("w_center_danificado")
	main._close_window()
	Game.equip["gerador"] = 100.0
	await _shot("6_alerta")
	main._pause()
	await get_tree().create_timer(0.3).timeout
	await _shot("6b_pausa")
	main._resume()
	await get_tree().create_timer(6.5).timeout
	Game.notify.emit("Pesquisa \"Procura por água\" concluída! 5 garrafas de água. (Os drops chegam no próximo sol.)", "good")
	await get_tree().create_timer(0.8).timeout
	await _shot("7_sucesso")
	main._set_panel(true)
	await get_tree().create_timer(0.5).timeout
	main.panel.open_screen("D")
	await _shot("8_diario")
	main.panel.open_screen("P")
	await _shot("9_pesquisas")
	main._set_panel(false)
	await get_tree().create_timer(0.4).timeout
	for k in ["paineis", "reciclador", "gerador", "robos"]:
		main._open_minigame(k)
		await get_tree().create_timer(0.3).timeout
		var mg = main.minigame
		if k == "paineis":
			for i in 14:
				mg._scrub(Vector2(260 + i * 40, 300 + (i % 3) * 60))
		elif k == "gerador":
			await get_tree().create_timer(1.2).timeout
		elif k == "robos":
			mg.connected[0] = mg.right_order.find(0)
			mg.selected = 1
		await _shot("m_" + k)
		main._on_minigame_done(0.5)
		await get_tree().create_timer(0.3).timeout
	# sala inteira (interior 3D) e telas de fim do sol
	main._set_panel(false)
	main.pan = 640.0
	await get_tree().create_timer(0.5).timeout
	await _shot("s_sala_centro")
	main.pan = 1280.0
	await get_tree().create_timer(0.5).timeout
	await _shot("s_sala_direita")
	Game.equip["robos"] = 0.0
	Game.research_done = 3
	Game.goals_done = {Game.page["goals"][0]: true} if not Game.page["goals"].is_empty() else {}
	Game._end_day()
	await get_tree().create_timer(2.5).timeout
	await _shot("e_fim_sol")
	main._clear_overlay()
	Game.won = false
	Game.day = Game.MAX_DAYS
	Game.start_day()
	Game.running = true
	Game.research_done = 11
	Game._end_day()
	await get_tree().create_timer(2.5).timeout
	await _shot("e_vitoria")
	main._clear_overlay()
	Game.game_over = false
	Game.running = true
	Game.cause = ""
	Game.res["oxigenio"] = 0.0
	Game._check_death()
	await get_tree().create_timer(2.5).timeout
	await _shot("e_derrota")
	get_tree().quit()
