extends Node
## Estado global e simulação em tempo real de "Five Sols in Mars".
## 5 sols de 2 minutos reais cada (jogo completo ~10 min).

signal changed                       # mudança estrutural (job, escudo, evento...)
signal notify(text: String, kind: String)  # kind: info, good, bad, alert, drop
signal day_finished(report: Dictionary)
signal died(cause: String)
signal maint_minigame(id: String)    # a interface abre o minigame da manutenção

var paused := false                  # simulação parada durante os minigames

const MAX_DAYS := 5
const START_HOUR := 6.0
const END_HOUR := 18.0
const SEC_PER_HOUR := 10.0           # 12h de jogo = 2 minutos reais

const APPROACH := 1.0                # aviso (e visual na janela) 1h antes do evento

const START_ENERGY := 400.0
const MAX_ENERGY := 400.0
const SHIELD_COST := {"radiacao": 90, "desastre": 100}
const PANEL_ENERGY := 100.0          # painéis funcionando geram isto às 06:00 de cada sol
const RECYCLER_BOTTLES := 2          # garrafas recuperadas por noite com o reciclador funcionando
var stress := {}
const BREAK_CHANCE := 0.7            # chance por sol de algo quebrar sozinho (a partir do sol 2)
const BREAK_CHANCE_FREE := 0.85
const SECOND_BREAK := 0.25           # chance de quebrar um segundo equipamento no mesmo sol
const EVENT_DAMAGE := 1.4            # multiplicador do dano de eventos sem escudo
const BREAK_HINTS := {
	"paineis": "Um dos painéis solares está rangendo com o vento desde ontem... acho que algo pode quebrar %s.",
	"reciclador": "O reciclador de água está fazendo um barulho estranho. Pode ser que ele quebre %s.",
	"gerador": "O gerador de oxigênio está esquentando mais que o normal. Talvez ele pare %s.",
	"robos": "Um dos robôs está com a roda travando. Acho que ele pode quebrar %s.",
}
var breakdowns: Array = []           # falhas aleatórias planejadas para hoje

const EAT_GAIN := 35.0
const DRINK_GAIN := 30.0
const HUNGER_PER_HOUR := 4.0
const THIRST_PER_HOUR := 6.0

const RESEARCH := [
	{"id": "agua", "name": "Procura por água", "hours": 1.5, "energy": 40, "desc": "Robôs perfuram o solo atrás de gelo. Drop: garrafas de água.", "reward": "Água"},
	{"id": "solo", "name": "Fertilidade do solo", "hours": 1.5, "energy": 40, "desc": "Testa o solo para cultivo. Drop: rações de comida.", "reward": "Comida"},
	{"id": "vida", "name": "Vestígios de vida", "hours": 2.0, "energy": 60, "desc": "Busca microfósseis. Vale 2 pesquisas.", "reward": "+2 pesquisas"},
	{"id": "terremoto", "name": "Teste de terremotos", "hours": 1.5, "energy": 35, "desc": "Reforça a base: terremotos causam menos dano até o fim da missão.", "reward": "Reforço"},
	{"id": "tempestade", "name": "Teste de tempestade", "hours": 1.5, "energy": 35, "desc": "Reforça a base: tempestades de areia causam menos dano.", "reward": "Reforço"},
	{"id": "clima", "name": "Monitorar clima", "hours": 1.0, "energy": 30, "desc": "Prevê os eventos dos próximos 2 sols no Diário.", "reward": "Previsão"},
]

const MAINT := [
	{"id": "paineis", "name": "Consertar painéis solares", "energy": 20, "gain": 100, "external": true, "desc": "Funcionando: +100 de energia às 06:00 de cada sol. Danificados: nada."},
	{"id": "reciclador", "name": "Reparar reciclador de água", "energy": 45, "gain": 100, "external": false, "desc": "Funcionando: +2 garrafas de água por noite. Danificado: nada."},
	{"id": "gerador", "name": "Reparar gerador de oxigênio", "energy": 55, "gain": 100, "external": false, "desc": "Funcionando: oxigênio estável. Danificado: o oxigênio cai."},
	{"id": "robos", "name": "Consertar robôs", "energy": 45, "gain": 100, "external": false, "desc": "Funcionando: 90% de sucesso nas pesquisas. Danificados: 30%."},
]
const MAINT_HOURS := 0.75

const EVENTS := {
	"solar": {"name": "Tempestade solar", "shield": "radiacao", "hint": "A radiação solar sobe rápido. Puxe a alavanca RAD (escudo de radiação)."},
	"areia": {"name": "Tempestade de areia", "shield": "desastre", "hint": "Suja os painéis e estraga o reciclador. Puxe a alavanca DES (escudo de desastres)."},
	"terremoto": {"name": "Terremotos", "shield": "desastre", "hint": "Danificam o gerador e os robôs. Puxe a alavanca DES (escudo de desastres)."},
}

var running := false
var day := 1
var tutorial := false
var free_play := false
var won := false
var hour := START_HOUR
var energia := START_ENERGY
var res := {}                        # oxigenio, radiacao (solar), saciedade, hidratacao
var racoes := 0
var garrafas := 0
var equip := {}
var shields := {"radiacao": false, "desastre": false}
var shutter := 0.0
var panel_open := false
var blackout := false
var research_done := 0
var research_job := {}
var maint_job := {}
var done_today := {}
var reinforced := {}
var event_plan := {}                 # sol -> Array de {type, start, end}
var today_events: Array = []
var today_event := ""                # evento acontecendo agora ("" = nenhum)
var page := {}                       # página do diário: story, hints, goals
var goals_done := {}
var research_day0 := 0   # pesquisas concluídas antes do sol atual (para o relatório)
const GOAL_BONUS := 50

const STORIES := {
	0: "Teste na Terra. Antes de partir para Marte, a agência quer ver se eu sei operar a base. Hoje é só treino: aprender os controles, comer, beber e mandar o robô a campo uma vez.",
	1: "Sol 1. Pousamos ontem à noite na Base Aurora. O silêncio aqui é enorme e o céu tem cor de ferrugem. Antes de qualquer descoberta, preciso garantir o básico: achar água no subsolo e descobrir se este solo vermelho consegue alimentar alguma planta.",
	2: "Sol 2. Dormi mal; o vento arranhou as paredes do módulo a noite inteira. A Terra quer resultados científicos: as rochas perto da cratera podem guardar vestígios de vida antiga. Vale a pena procurar.",
	3: "Sol 3. Metade da missão. Os equipamentos começam a reclamar da poeira e eu também. Se eu entender melhor o clima daqui, consigo me proteger antes que algo dê errado.",
	4: "Sol 4. Chegou mensagem da Terra: a nave de resgate está a caminho! Faltam dois sols. Preciso juntar o máximo de dados possível e não posso deixar a base desabar agora.",
	5: "Sol 5. Último sol. No radar já aparece o pontinho da nave se aproximando. Só mais um esforço: vou fechar esta missão com as pesquisas mais importantes.",
}
const STORY_FREE := "Sol %d. A nave de resgate atrasou por causa de uma tempestade em órbita. Sigo sozinho na Base Aurora, coletando dados e tentando não pensar no silêncio."
const DAY_GOALS := {0: ["agua"], 1: ["agua", "solo"], 2: ["vida", "clima"], 3: ["clima", "solo"], 4: ["vida", "agua"], 5: ["vida", "solo", "clima"]}
const HINTS := {
	"terremoto": "Senti um leve tremor no café da manhã e os copos tilintaram na mesa. Acho que pode acontecer um terremoto %s.",
	"areia": "O horizonte está ficando marrom e o vento não para de aumentar. Acho que uma tempestade de areia pode chegar %s.",
	"solar": "Os sensores captaram manchas enormes no Sol. Pode ser que venha uma tempestade solar %s.",
}
var forecast_until := 0              # Diário mostra previsão até este sol
var pending_drops := {}              # entregue no próximo sol
var today_log: Array = []
var diary: Array = []
var game_over := false
var cause := ""
var notes: Array = []
var anim_t := 0.0


func _ready() -> void:
	randomize()
	notify.connect(_store_note)
	new_game(false)


func _store_note(text: String, kind: String) -> void:
	notes.append({"time": clock_text(), "text": text, "kind": kind})
	if notes.size() > 30:
		notes.pop_front()


func new_game(with_tutorial: bool) -> void:
	tutorial = with_tutorial
	day = 0 if with_tutorial else 1
	free_play = false
	won = false
	energia = START_ENERGY
	res = {"oxigenio": 80.0, "radiacao": 5.0, "saciedade": 80.0, "hidratacao": 80.0}
	racoes = 6
	garrafas = 8
	# 100 = funcionando, 0 = danificado. No início só os painéis solares estão danificados.
	equip = {"paineis": 0.0, "reciclador": 100.0, "gerador": 100.0, "robos": 100.0}
	stress = {}
	research_done = 0
	reinforced = {}
	pending_drops = {}
	diary = []
	notes = []
	game_over = false
	cause = ""
	forecast_until = 0
	_plan_events()
	start_day()


func _plan_events() -> void:
	event_plan = {}
	var count := 0
	for d in range(1, MAX_DAYS + 1):
		var evs := _roll_day(d, 0)
		if evs.size() > 0:
			count += 1
		event_plan[d] = evs
	# garante pelo menos 2 sols com evento, mas nunca todos
	while count < 2:
		var d := randi_range(2, MAX_DAYS)
		if event_plan[d].is_empty():
			event_plan[d] = _roll_day(d, 1)
			count += 1
	if count == MAX_DAYS:
		event_plan[1] = []


## Sorteia os eventos de um sol: cada um tem horário de início e dura de 2 a 4 horas.
func _roll_day(d: int, force: int) -> Array:
	var n := force
	if n == 0:
		var r := randf()
		if d == 1:
			n = 1 if r < 0.3 else 0
		elif d > MAX_DAYS:
			n = 2 if r < 0.5 else 1
		else:
			n = 2 if r < 0.25 else (1 if r < 0.8 else 0)
	var out: Array = []
	var types := EVENTS.keys()
	var t := randf_range(7.5, 11.0) if n == 1 else randf_range(7.5, 9.0)
	for i in n:
		var dur := randf_range(2.0, 4.0)
		if t + dur > 17.5:
			break
		out.append({"type": types[randi() % types.size()], "start": t, "end": t + dur})
		t += dur + randf_range(1.0, 3.0)
	return out


func events_for(d: int) -> Array:
	if d <= 0:
		return []
	if not event_plan.has(d):
		event_plan[d] = _roll_day(d, 0)
	return event_plan[d]


func event_text(e: Dictionary) -> String:
	return "%s das %s às %s" % [EVENTS[e["type"]]["name"], fmt_hour(e["start"]), fmt_hour(e["end"])]


## Próximo evento (ativo ou futuro) de hoje, ou {} se não houver.
func next_event() -> Dictionary:
	for e in today_events:
		if hour < e["end"]:
			return e
	return {}


func start_day() -> void:
	running = false
	paused = false
	hour = START_HOUR
	shields = {"radiacao": false, "desastre": false}
	blackout = energia <= 0.0
	research_job = {}
	maint_job = {}
	done_today = {}
	today_log = []
	today_event = ""
	today_events = events_for(day).duplicate(true)
	research_day0 = research_done
	# Painéis solares: às 06:00 de cada sol geram energia, se estiverem funcionando.
	if not is_broken("paineis"):
		energia = minf(MAX_ENERGY, energia + PANEL_ENERGY)
		blackout = false
		_log("Painéis solares geraram +%d de energia às 06:00." % int(PANEL_ENERGY))
		notify.emit("06:00 — Painéis solares geraram +%d de energia!" % int(PANEL_ENERGY), "drop")
	elif day >= 1 or is_earth():
		_log("Painéis solares danificados: nenhuma energia gerada às 06:00.")
	if not pending_drops.is_empty():
		var parts := PackedStringArray()
		if pending_drops.has("garrafas"):
			garrafas += pending_drops["garrafas"]
			parts.append("+%d garrafas de água" % pending_drops["garrafas"])
		if pending_drops.has("racoes"):
			racoes += pending_drops["racoes"]
			parts.append("+%d rações" % pending_drops["racoes"])
		if pending_drops.has("energia"):
			energia = minf(MAX_ENERGY, energia + pending_drops["energia"])
			parts.append("+%d energia" % pending_drops["energia"])
			blackout = false
		var msg := "Suprimentos das pesquisas chegaram: %s." % ", ".join(parts)
		_log(msg)
		notify.emit(msg, "drop")
		pending_drops = {}
	_plan_breakdown()
	_make_page()
	changed.emit()


## Sorteia se algum equipamento que está funcionando vai quebrar sozinho hoje (e a que horas).
func _plan_breakdown() -> void:
	breakdowns = []
	if is_earth() or day < 2:
		return
	var chance := BREAK_CHANCE if day <= MAX_DAYS else BREAK_CHANCE_FREE
	if randf() >= chance:
		return
	var working: Array = []
	for k in equip:
		if not is_broken(k):
			working.append(k)
	if working.is_empty():
		return
	working.shuffle()
	var n := 2 if (randf() < SECOND_BREAK and working.size() >= 2) else 1
	for i in n:
		breakdowns.append({"id": working[i], "at": randf_range(8.0, 16.0), "done": false})


func _tick_breakdown() -> void:
	for b in breakdowns:
		if b["done"] or hour < b["at"]:
			continue
		b["done"] = true
		var id: String = b["id"]
		if is_broken(id):
			continue
		equip[id] = 0.0
		stress[id] = 0.0
		var nm: String = {"paineis": "OS PAINÉIS SOLARES QUEBRARAM", "reciclador": "O RECICLADOR DE ÁGUA QUEBROU", "gerador": "O GERADOR DE OXIGÊNIO QUEBROU", "robos": "OS ROBÔS QUEBRARAM"}[id]
		_log("Falha inesperada: %s." % nm.to_lower())
		notify.emit("FALHA INESPERADA: %s sozinho(s)! Abra o painel > M para consertar." % nm, "alert")
		changed.emit()


func _period(h: float) -> String:
	if h < 10.0:
		return "logo de manhã"
	elif h < 13.0:
		return "por volta do meio-dia"
	elif h < 15.5:
		return "no começo da tarde"
	return "no fim da tarde"


## Monta a página do diário do sol: história, pistas do que pode acontecer e pesquisas sugeridas.
func _make_page() -> void:
	goals_done = {}
	var story: String = STORIES.get(day, STORY_FREE % day) if day <= MAX_DAYS else STORY_FREE % day
	var hints := PackedStringArray()
	var goals: Array = (DAY_GOALS.get(day, []) as Array).duplicate()
	if day > MAX_DAYS:
		var ids := ["agua", "solo", "vida", "clima"]
		ids.shuffle()
		goals = ids.slice(0, 2)
	for e in today_events:
		hints.append(HINTS[e["type"]] % _period(e["start"]))
		var test := "terremoto" if e["type"] == "terremoto" else ("tempestade" if e["type"] == "areia" else "clima")
		if not goals.has(test) and goals.size() < 3:
			goals.append(test)
	if today_events.is_empty() and not is_earth():
		hints.append("O céu está limpo e o vento, calmo. Parece que hoje vai ser um sol tranquilo — bom dia para trabalhar lá fora.")
	for b in breakdowns:
		hints.append(BREAK_HINTS[b["id"]] % ("hoje " + _period(b["at"])))
	if racoes <= 2 and not is_earth():
		hints.append("Restam só %d rações. Preciso pesquisar a fertilidade do solo logo." % racoes)
		if not goals.has("solo"):
			goals.push_front("solo")
	if garrafas <= 2 and not is_earth():
		hints.append("A água está acabando (%d garrafas). Uma busca por gelo no subsolo é urgente." % garrafas)
		if not goals.has("agua"):
			goals.push_front("agua")
	if is_broken("paineis"):
		hints.append("Os painéis solares estão danificados. Sem conserto, não terei os 100 de energia de cada manhã.")
	for k in ["reciclador", "gerador", "robos"]:
		if is_broken(k) and not is_earth():
			hints.append({"reciclador": "O reciclador de água está quebrado: nada de garrafas recuperadas à noite.", "gerador": "O gerador de oxigênio está danificado e o ar está ficando rarefeito. Preciso consertá-lo logo!", "robos": "Os robôs voltaram avariados; com eles assim, as pesquisas quase sempre falham."}[k])
	if goals.size() > 3:
		goals = goals.slice(0, 3)
	page = {"story": story, "hints": hints, "goals": goals}


## Pesquisas do diário de hoje: [[nome, concluída], ...]
func goal_status() -> Array:
	var out: Array = []
	for g in page.get("goals", []):
		out.append([research_def(g)["name"], goals_done.has(g)])
	return out


func goal_names() -> PackedStringArray:
	var out := PackedStringArray()
	for g in page.get("goals", []):
		out.append(research_def(g)["name"])
	return out


func _check_goal(id: String) -> void:
	var goals: Array = page.get("goals", [])
	if not goals.has(id) or goals_done.has(id):
		return
	goals_done[id] = true
	if goals_done.size() >= goals.size():
		_add_drop("energia", GOAL_BONUS)
		var msg := "Pesquisas do diário cumpridas! Bônus: +%d de energia no próximo sol." % GOAL_BONUS
		_log(msg)
		notify.emit(msg, "drop")
	else:
		notify.emit("Pesquisa do diário concluída (%d de %d)." % [goals_done.size(), goals.size()], "good")


func is_earth() -> bool:
	return tutorial and day == 0


# ---------- Eventos ----------

func start_tutorial_event(type: String) -> void:
	today_events = [{"type": type, "start": hour, "end": hour + 100.0, "warned": true}]
	_tick_events()


func end_tutorial_event() -> void:
	today_events = []
	today_event = ""
	changed.emit()


## Avisa 1h antes, marca início e fim de cada evento e define o evento ativo agora.
func _tick_events() -> void:
	var active := ""
	for e in today_events:
		var info: Dictionary = EVENTS[e["type"]]
		if not e.get("warned", false) and hour >= e["start"] - APPROACH:
			e["warned"] = true
			notify.emit("Em 1 hora: %s (dura %dh). %s" % [event_text(e), roundi(e["end"] - e["start"]), info["hint"]], "alert")
		if hour >= e["start"] and hour < e["end"]:
			active = e["type"]
			if not e.get("started", false):
				e["started"] = true
				_log("%s começou." % info["name"])
				notify.emit("%s COMEÇOU! %s" % [info["name"], info["hint"]], "alert")
		elif hour >= e["end"] and e.get("started", false) and not e.get("ended", false):
			e["ended"] = true
			_log("%s terminou." % info["name"])
			notify.emit("%s terminou. Desligue o escudo para abrir as janelas e liberar o robô." % info["name"], "good")
	if active != today_event:
		today_event = active
		changed.emit()


## 2.0 = evento acontecendo agora; 0..1 = chegando (até 1h antes); 0 = nada.
func threat(type: String) -> float:
	if today_event == type:
		return 2.0
	for e in today_events:
		if e["type"] == type and hour < e["start"] and hour >= e["start"] - APPROACH:
			return clampf(1.0 - (e["start"] - hour) / APPROACH, 0.01, 1.0)
	return 0.0


func is_active(type: String) -> bool:
	return today_event == type


func any_alert() -> bool:
	if today_event == "" or not running:
		return false
	return not shields[EVENTS[today_event]["shield"]]


func is_shaking() -> bool:
	return today_event == "terremoto" and fmod(anim_t, 7.0) < 1.4


func any_shield() -> bool:
	return shields["radiacao"] or shields["desastre"]


func sealed() -> bool:
	return any_shield()


# ---------- Energia ----------

func _spend(amount: float) -> void:
	energia = maxf(0.0, energia - amount)
	if energia <= 0.0 and not blackout:
		blackout = true
		shields = {"radiacao": false, "desastre": false}
		notify.emit("BLECAUTE! A energia acabou: escudos, gerador, pesquisas e consertos desligados. O painel ainda abre para COMER e BEBER.", "alert")
	changed.emit()


func toggle_shield(id: String) -> void:
	if shields[id]:
		shields[id] = false
		notify.emit("Escudo desligado. As janelas abriram.", "info")
		changed.emit()
		return
	if blackout:
		notify.emit("Sem energia! Os escudos não ligam.", "bad")
		return
	var cost: int = SHIELD_COST[id]
	if energia < cost:
		notify.emit("Energia insuficiente: este escudo custa %d." % cost, "bad")
		return
	shields[id] = true
	notify.emit("Escudo ativado (-%d de energia). Janelas fechadas: a base está selada." % cost, "info")
	_spend(cost)


# ---------- Comer e beber ----------

func eat() -> void:
	if racoes <= 0:
		notify.emit("Sem rações! Pesquise a fertilidade do solo.", "bad")
		return
	if res["saciedade"] >= 95.0:
		notify.emit("Você está satisfeito. Guarde a ração.", "info")
		return
	racoes -= 1
	res["saciedade"] = minf(100.0, res["saciedade"] + EAT_GAIN)
	notify.emit("Você comeu uma ração (+%d saciedade). Restam %d." % [int(EAT_GAIN), racoes], "good")
	changed.emit()


func drink() -> void:
	if garrafas <= 0:
		notify.emit("Sem água! Pesquise água ou repare o reciclador.", "bad")
		return
	if res["hidratacao"] >= 95.0:
		notify.emit("Você não está com sede. Guarde a água.", "info")
		return
	garrafas -= 1
	res["hidratacao"] = minf(100.0, res["hidratacao"] + DRINK_GAIN)
	notify.emit("Você bebeu uma garrafa (+%d hidratação). Restam %d." % [int(DRINK_GAIN), garrafas], "good")
	changed.emit()


# ---------- Loop em tempo real ----------

func _process(delta: float) -> void:
	anim_t += delta
	shutter = move_toward(shutter, 1.0 if any_shield() else 0.0, delta * 2.2)
	if not running or game_over or paused:
		return
	var dh := delta / SEC_PER_HOUR
	hour += dh
	if is_earth():
		hour = minf(hour, END_HOUR - 0.1)
	_tick_events()
	_tick_breakdown()
	_tick_resources(dh)
	_tick_jobs()
	if _check_death():
		return
	if hour >= END_HOUR:
		_end_day()


func _tick_resources(dh: float) -> void:
	# Gerador funcionando mantém o oxigênio estável; danificado (ou sem energia) ele cai.
	var o_net := -2.5 if (blackout or is_broken("gerador")) else 0.0
	res["oxigenio"] += o_net * dh
	res["saciedade"] -= HUNGER_PER_HOUR * dh
	res["hidratacao"] -= THIRST_PER_HOUR * dh
	var rad := 0.3
	if shields["radiacao"]:
		rad = -0.5
	elif today_event == "solar":
		rad = 24.0
	res["radiacao"] += rad * dh
	# Equipamentos não se desgastam sozinhos: só eventos sem escudo os danificam.
	var out := not research_job.is_empty()
	match today_event:
		"areia":
			var k := 0.6 if reinforced.has("tempestade") else 1.0
			var sh := 0.08 if shields["desastre"] else 1.0
			_stress("paineis", 0.8 * k * sh * dh)
			_stress("reciclador", 0.6 * k * sh * dh)
		"terremoto":
			var k2 := 0.6 if reinforced.has("terremoto") else 1.0
			var sh2 := 0.08 if shields["desastre"] else 1.0
			_stress("gerador", 0.7 * k2 * sh2 * dh)
			_stress("robos", 0.5 * k2 * sh2 * dh)
	if out and (today_event == "areia" or today_event == "terremoto"):
		_stress("robos", 1.0 * dh)
		research_job["damaged"] = true
	_clamp_all()


func is_broken(id: String) -> bool:
	return equip[id] < 50.0


func broken_count() -> int:
	var n := 0
	for k in equip:
		if is_broken(k):
			n += 1
	return n


## Acumula "estresse" de um evento; ao chegar em 1, o equipamento é danificado.
func _stress(id: String, amount: float) -> void:
	if is_broken(id):
		return
	stress[id] = stress.get(id, 0.0) + amount * EVENT_DAMAGE
	if stress[id] >= 1.0:
		stress[id] = 0.0
		equip[id] = 0.0
		var nm: String = {"paineis": "PAINÉIS SOLARES", "reciclador": "RECICLADOR DE ÁGUA", "gerador": "GERADOR DE OXIGÊNIO", "robos": "ROBÔS"}[id]
		_log("%s danificado(s)." % nm.capitalize())
		notify.emit("%s DANIFICADO(S)! Abra o painel > M para consertar." % nm, "alert")
		changed.emit()


func _clamp_all() -> void:
	for k in res:
		res[k] = clampf(res[k], 0.0, 100.0)
	for k in equip:
		equip[k] = clampf(equip[k], 0.0, 100.0)


func _tick_jobs() -> void:
	if not research_job.is_empty() and hour >= research_job["end"]:
		_finish_research()
	pass


# ---------- Pesquisas ----------

func research_def(id: String) -> Dictionary:
	for r in RESEARCH:
		if r["id"] == id:
			return r
	return {}


func maint_def(id: String) -> Dictionary:
	for m in MAINT:
		if m["id"] == id:
			return m
	return {}


func success_chance() -> float:
	return 0.3 if is_broken("robos") else 0.9


func can_research(id: String) -> String:
	var r := research_def(id)
	if blackout:
		return "Sem energia"
	if sealed():
		return "Base selada (escudo)"
	if not research_job.is_empty():
		return "Robô em campo"
	if maint_job.get("id", "") == "robos":
		return "Robôs em reparo"
	if done_today.has(id):
		return "Feita hoje"
	if energia < r["energy"]:
		return "Pouca energia"
	if hour + r["hours"] > END_HOUR and not is_earth():
		return "Sem tempo hoje"
	return ""


func start_research(id: String) -> void:
	var why := can_research(id)
	if why != "":
		notify.emit(why, "bad")
		return
	var r := research_def(id)
	done_today[id] = true
	research_job = {"id": id, "start": hour, "end": hour + r["hours"], "damaged": false}
	notify.emit("Robô saiu para: %s (-%d de energia)." % [r["name"], r["energy"]], "info")
	_spend(r["energy"])


func research_progress() -> float:
	if research_job.is_empty():
		return 0.0
	return clampf((hour - research_job["start"]) / (research_job["end"] - research_job["start"]), 0.0, 1.0)


func _add_drop(key: String, v: int) -> void:
	pending_drops[key] = pending_drops.get(key, 0) + v


func _finish_research() -> void:
	var id: String = research_job["id"]
	var r := research_def(id)
	var chance := success_chance()
	if research_job["damaged"]:
		chance *= 0.5
	research_job = {}
	res["radiacao"] += 2.0
	var success := is_earth() or randf() < chance
	if not success:
		var fail := "Pesquisa \"%s\" falhou.%s" % [r["name"], " (Os robôs estão danificados: conserte-os no painel > M.)" if is_broken("robos") else ""]
		_log(fail)
		notify.emit(fail, "bad")
		changed.emit()
		return
	var gains := PackedStringArray()
	match id:
		"agua":
			var v := randi_range(4, 7)
			_add_drop("garrafas", v)
			gains.append("%d garrafas de água" % v)
		"solo":
			var v := randi_range(3, 5)
			_add_drop("racoes", v)
			gains.append("%d rações" % v)
		"vida":
			gains.append("microfósseis (+2 pesquisas)")
		"terremoto", "tempestade":
			reinforced[id] = true
			gains.append("base reforçada contra %s" % ("terremotos" if id == "terremoto" else "tempestades de areia"))
		"clima":
			forecast_until = maxi(forecast_until, day + 2)
			gains.append("previsão dos próximos 2 sols no Diário")
	research_done += 2 if id == "vida" else 1
	if randf() < 0.6:
		var roll := randi() % 3
		if roll == 0:
			var e := randi_range(40, 80)
			_add_drop("energia", e)
			gains.append("bônus %d de energia" % e)
		elif roll == 1:
			var g := randi_range(1, 3)
			_add_drop("garrafas", g)
			gains.append("bônus %d garrafas" % g)
		else:
			var c := randi_range(1, 2)
			_add_drop("racoes", c)
			gains.append("bônus %d rações" % c)
	_clamp_all()
	var msg := "Pesquisa \"%s\" concluída! %s. (Os drops chegam no próximo sol.)" % [r["name"], ", ".join(gains)]
	_log(msg)
	notify.emit(msg, "good")
	_check_goal(id)
	changed.emit()


# ---------- Manutenção ----------

func can_maint(id: String) -> String:
	var m := maint_def(id)
	if blackout:
		return "Sem energia"
	if m["external"] and sealed():
		return "Base selada (escudo)"
	if not maint_job.is_empty():
		return "Em andamento"
	if not is_broken(id):
		return "Funcionando"
	if id == "robos" and not research_job.is_empty():
		return "Robô em campo"
	if energia < m["energy"]:
		return "Pouca energia"
	return ""


func start_maint(id: String) -> void:
	var why := can_maint(id)
	if why != "":
		notify.emit(why, "bad")
		return
	var m := maint_def(id)
	maint_job = {"id": id, "start": hour, "end": hour + MAINT_HOURS}
	_spend(m["energy"])
	paused = true
	maint_minigame.emit(id)


const REPAIR_MIN := 0.4               # nota mínima no minigame para o conserto dar certo

## Chamado quando o minigame termina: com nota suficiente o equipamento volta a funcionar.
func finish_maint(score: float) -> void:
	paused = false
	if maint_job.is_empty():
		return
	var id: String = maint_job["id"]
	var m := maint_def(id)
	maint_job = {}
	var msg := ""
	if score >= REPAIR_MIN:
		equip[id] = 100.0
		stress[id] = 0.0
		msg = "%s: CONSERTADO! Está funcionando de novo (eficiência %d%%)." % [m["name"], int(score * 100.0)]
		notify.emit(msg, "good")
	else:
		msg = "%s: o conserto FALHOU (eficiência %d%%, mínimo %d%%). Tente de novo." % [m["name"], int(score * 100.0), int(REPAIR_MIN * 100.0)]
		notify.emit(msg, "bad")
	_log(msg)
	changed.emit()


func maint_progress() -> float:
	return 0.0


# ---------- Fim do dia / morte ----------

func _log(text: String) -> void:
	today_log.append("%s  %s" % [clock_text(), text])


func clock_text() -> String:
	return fmt_hour(hour)


func fmt_hour(h: float) -> String:
	return "%02d:%02d" % [int(h), int((h - int(h)) * 60.0)]


func _check_death() -> bool:
	if is_earth():
		for k in ["oxigenio", "saciedade", "hidratacao"]:
			res[k] = maxf(res[k], 15.0)
		res["radiacao"] = minf(res["radiacao"], 80.0)
		return false
	var c := ""
	if res["oxigenio"] <= 0.0:
		c = "O oxigênio acabou."
	elif res["hidratacao"] <= 0.0:
		c = "Você ficou desidratado. Beba água na aba R!"
	elif res["saciedade"] <= 0.0:
		c = "Você morreu de fome. Coma rações na aba R!"
	elif res["radiacao"] >= 100.0:
		c = "Exposição fatal à radiação solar."
	if c == "":
		return false
	game_over = true
	running = false
	cause = c
	_log("Missão encerrada. " + c)
	diary.append({"day": day, "lines": today_log.duplicate(), "story": page.get("story", ""), "goals": "%d/%d" % [goals_done.size(), page.get("goals", []).size()]})
	died.emit(c)
	return true


func _end_day() -> void:
	running = false
	hour = END_HOUR
	shields = {"radiacao": false, "desastre": false}
	today_event = ""
	if not research_job.is_empty():
		_log("O robô voltou antes de terminar a pesquisa.")
		research_job = {}
	maint_job = {}
	var lines := PackedStringArray()
	if is_broken("reciclador"):
		lines.append("Reciclador DANIFICADO: nenhuma garrafa recuperada esta noite.")
	else:
		garrafas += RECYCLER_BOTTLES
		lines.append("Reciclador recuperou +%d garrafas de água." % RECYCLER_BOTTLES)
	lines.append("Painéis solares: %s" % ("DANIFICADOS — amanhã às 06:00 não vão gerar energia." if is_broken("paineis") else "funcionando — amanhã às 06:00 geram +%d de energia." % int(PANEL_ENERGY)))
	res["saciedade"] -= 12.0
	res["hidratacao"] -= 16.0
	res["radiacao"] -= 15.0
	lines.append("Noite: fome e sede aumentaram enquanto você dormia.")
	if blackout:
		res["oxigenio"] -= 12.0
		lines.append("Sem energia à noite: o oxigênio caiu.")
	_clamp_all()
	_log("Fim do sol.")
	var entry: Array = today_log.duplicate()
	entry.append_array(Array(lines))
	diary.append({"day": day, "lines": entry, "story": page.get("story", ""), "goals": "%d/%d" % [goals_done.size(), page.get("goals", []).size()]})
	var report := {"day": day, "log": today_log.duplicate(), "night": lines, "tutorial_done": is_earth(), "victory": false,
		"research_today": research_done - research_day0, "goals": goal_status()}
	if not is_earth():
		if res["oxigenio"] <= 0.0 or res["saciedade"] <= 0.0 or res["hidratacao"] <= 0.0:
			_check_death()
			return
		day += 1
		if day > MAX_DAYS and not won:
			won = true
			report["victory"] = true
	changed.emit()
	day_finished.emit(report)


func finish_tutorial_now() -> void:
	if is_earth() and running:
		_end_day()


func res_name(k: String) -> String:
	return {"oxigenio": "Oxigênio", "radiacao": "Radiação solar", "saciedade": "Saciedade", "hidratacao": "Hidratação"}.get(k, k)


func rating() -> String:
	if research_done >= 14:
		return "Lenda de Marte"
	elif research_done >= 10:
		return "Cientista exemplar"
	elif research_done >= 5:
		return "Pesquisador dedicado"
	return "Sobrevivente"
