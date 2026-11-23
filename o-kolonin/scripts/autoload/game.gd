extends Node
## Spelets tillstånd: valda inställningar, nationernas resurser, forskning,
## modifierare och diplomati. Världen (öar, skepp) ligger i World-noden.

signal resources_changed
signal research_changed
signal diplomacy_changed
signal notify(text: String, color: Color)
signal popup_requested(data: Dictionary)

const STATUS_NAMES := {"krig": "Krig", "fred": "Fred", "handel": "Handelsavtal", "allians": "Allians"}
const STATUS_COLORS := {"krig": Color(0.95, 0.35, 0.3), "fred": Color(0.85, 0.85, 0.8), "handel": Color(0.95, 0.8, 0.35), "allians": Color(0.45, 0.85, 0.5)}

var settings := {
	"nation": "valdoria",
	"ai_tempo": "normal",
	"crisis_timing": "normal",
	"crises": {"spokflottan": true, "armadan": true, "djupkulten": true, "vaktarna": true},
}
var player := "valdoria"
var nations := {}      # id -> state-dictionary (bara spelbara nationer)
var relations := {}    # "a|b" -> {"value", "status", "since"}
var vaktarna_awake := false
var vaktarna_angry := {}  # nation -> true om de provocerat Väktarna
var active_crises := {}   # crisis id -> true när krisen har startat
var time := 0.0
var wind_angle := 0.6     # riktningen vinden blåser MOT (radianer)
var wind_strength := 1.0
var storm := 0.0          # 0..1, stormens styrka
var world = null
var rates := {}           # nation -> resurs -> per dag (för HUD)
var speed_index := 0      # index i Data.SPEEDS
var paused := false


# ------------------------------------------------------------------ Tid
## time räknas i speldagar (flyttal). En dag går på Data.DAY_SECONDS sekunder i 1x.
func day() -> int:
	return int(time)


func date_text() -> String:
	return Data.date_text(time)


func set_speed(index: int) -> void:
	speed_index = clampi(index, 0, Data.SPEEDS.size() - 1)
	paused = false
	_apply_speed()


func toggle_pause() -> void:
	paused = not paused
	_apply_speed()


func _apply_speed() -> void:
	if world == null:
		Engine.time_scale = 1.0
		return
	world.get_tree().paused = paused
	Engine.time_scale = Data.SPEEDS[speed_index]


func new_game(new_settings: Dictionary) -> void:
	settings = new_settings.duplicate(true)
	player = settings["nation"]
	time = 0.0
	storm = 0.0
	wind_angle = randf() * TAU
	wind_strength = 1.0
	speed_index = 0
	paused = false
	vaktarna_awake = false
	vaktarna_angry = {}
	active_crises = {}
	nations = {}
	relations = {}
	rates = {}
	for id in Data.PLAYABLE:
		var def: Dictionary = Data.NATIONS[id]
		var st := {
			"id": id,
			"ai": id != player,
			"alive": true,
			"res": {},
			"research": {},
			"current_research": "",
			"research_progress": 0.0,
			"research_queue": [],
			"war_started": {},
		}
		for r in Data.RESOURCES:
			st["res"][r] = 0.0
		st["res"]["forskning"] = 0.0
		st["res"]["guld"] = 200.0
		st["res"]["tra"] = 150.0
		st["res"]["mat"] = 100.0
		st["res"]["sten"] = 20.0
		var bonus: Dictionary = def.get("start_bonus", {})
		for r in bonus:
			st["res"][r] += bonus[r]
		for rid in def["start_research"]:
			st["research"][rid] = true
		nations[id] = st
		rates[id] = {}
	for a in Data.PLAYABLE:
		for b in Data.PLAYABLE:
			if a < b:
				var va: float = Data.NATIONS[a]["start_relations"].get(b, 0)
				var vb: float = Data.NATIONS[b]["start_relations"].get(a, 0)
				var v := (va + vb) * 0.5
				if a == "solmar" or b == "solmar":
					v += 15.0
				relations[_key(a, b)] = {"value": v, "status": "fred", "since": 0.0}


# ------------------------------------------------------------------ Hjälp
func _key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func is_playable(id: String) -> bool:
	return nations.has(id)


func say(text: String, color: Color = Color(0.95, 0.93, 0.85)) -> void:
	notify.emit(text, color)


func ai_grace() -> float:
	return Data.AI_TEMPO[settings["ai_tempo"]]["grace"]


func ai_aggro() -> float:
	return Data.AI_TEMPO[settings["ai_tempo"]]["aggro"]


# ------------------------------------------------------------------ Modifierare
const ADDITIVE_MODS := ["plunder", "relations"]


func mod(nation: String, key: String) -> float:
	var additive := key in ADDITIVE_MODS
	var v := 0.0 if additive else 1.0
	if not nations.has(nation):
		# Fientliga fraktioner får lite bonus när krisen växer.
		return v
	var base: Dictionary = Data.NATIONS[nation]["mods"]
	if base.has(key):
		v = v + base[key] if additive else v * base[key]
	for rid in nations[nation]["research"]:
		var eff: Dictionary = Data.RESEARCH[rid].get("effect", {})
		if eff.has(key):
			v = v + eff[key] if additive else v * eff[key]
	return v


func prod_mod(nation: String, res: String) -> float:
	var m := mod(nation, "prod_all")
	if res == "forskning":
		return m * mod(nation, "research")
	return m * mod(nation, "prod_" + res)


# ------------------------------------------------------------------ Resurser
func res(nation: String, r: String) -> float:
	if not nations.has(nation):
		return 0.0
	return nations[nation]["res"].get(r, 0.0)


func add_res(nation: String, r: String, amount: float) -> void:
	if not nations.has(nation):
		return
	var d: Dictionary = nations[nation]["res"]
	d[r] = maxf(0.0, d.get(r, 0.0) + amount)


func can_afford(nation: String, cost: Dictionary) -> bool:
	if not nations.has(nation):
		return false
	for r in cost:
		if res(nation, r) + 0.001 < cost[r]:
			return false
	return true


func pay(nation: String, cost: Dictionary) -> bool:
	if not can_afford(nation, cost):
		return false
	for r in cost:
		add_res(nation, r, -cost[r])
	if nation == player:
		resources_changed.emit()
	return true


func building_cost(nation: String, type: String) -> Dictionary:
	var base: Dictionary = Data.BUILDINGS[type]["cost"]
	var count := 0
	if world:
		count = world.count_buildings(nation, type)
	var f := mod(nation, "build_cost") * pow(Data.COST_GROWTH, count)
	var out := {}
	for r in base:
		out[r] = ceilf(base[r] * f)
	return out


func ship_cost(nation: String, type: String) -> Dictionary:
	var base: Dictionary = Data.SHIPS[type]["cost"]
	var f := mod(nation, "ship_cost")
	var out := {}
	for r in base:
		out[r] = ceilf(base[r] * f)
	return out


func colonize_cost(nation: String) -> Dictionary:
	var n := 1
	if world:
		n = world.islands_of(nation).size()
	return {"guld": 80.0 + 60.0 * n, "tra": 40.0 + 30.0 * n, "mat": 30.0 + 20.0 * n}


# ------------------------------------------------------------------ Forskning
func has_research(nation: String, rid: String) -> bool:
	return nations.has(nation) and nations[nation]["research"].has(rid)


func research_available(nation: String, rid: String) -> bool:
	if has_research(nation, rid):
		return false
	for req in Data.RESEARCH[rid]["req"]:
		if not has_research(nation, req):
			return false
	return true


func building_unlocked(nation: String, type: String) -> bool:
	var def: Dictionary = Data.BUILDINGS[type]
	if not def.get("buildable", true):
		return false
	if def.has("research"):
		return has_research(nation, def["research"])
	return true


func ship_unlocked(nation: String, type: String) -> bool:
	if Data.SHIP_RESEARCH.has(type):
		return has_research(nation, Data.SHIP_RESEARCH[type])
	return Data.SHIP_ORDER.has(type)


func queue_research(nation: String, rid: String) -> void:
	var st: Dictionary = nations[nation]
	if has_research(nation, rid) or st["current_research"] == rid or rid in st["research_queue"]:
		return
	if st["current_research"] == "":
		st["current_research"] = rid
		st["research_progress"] = 0.0
	else:
		st["research_queue"].append(rid)
	research_changed.emit()


func cancel_research(nation: String, rid: String) -> void:
	var st: Dictionary = nations[nation]
	if st["current_research"] == rid:
		st["res"]["forskning"] += st["research_progress"]
		st["current_research"] = ""
		st["research_progress"] = 0.0
		_next_research(nation)
	else:
		st["research_queue"].erase(rid)
	research_changed.emit()


func _next_research(nation: String) -> void:
	var st: Dictionary = nations[nation]
	while st["research_queue"].size() > 0:
		var nxt: String = st["research_queue"].pop_front()
		if research_available(nation, nxt):
			st["current_research"] = nxt
			st["research_progress"] = 0.0
			return
	st["current_research"] = ""


func tick_research(nation: String) -> void:
	var st: Dictionary = nations[nation]
	var cur: String = st["current_research"]
	if cur == "":
		return
	if not research_available(nation, cur):
		_next_research(nation)
		return
	var cost: float = Data.research_cost(cur)
	var bank: float = st["res"]["forskning"]
	var take: float = minf(bank, cost - st["research_progress"])
	st["research_progress"] += take
	st["res"]["forskning"] = bank - take
	if st["research_progress"] >= cost - 0.001:
		st["research"][cur] = true
		st["current_research"] = ""
		st["research_progress"] = 0.0
		if nation == player:
			say("Forskning klar: %s" % Data.RESEARCH[cur]["name"], Data.RESOURCE_COLORS["forskning"])
		_next_research(nation)
		research_changed.emit()


# ------------------------------------------------------------------ Diplomati
func get_rel(a: String, b: String) -> Dictionary:
	return relations.get(_key(a, b), {"value": 0.0, "status": "fred", "since": 0.0})


func status(a: String, b: String) -> String:
	if a == b:
		return "allians"
	if not relations.has(_key(a, b)):
		return "krig" if at_war(a, b) else "fred"
	return relations[_key(a, b)]["status"]


func at_war(a: String, b: String) -> bool:
	if a == b or a == "" or b == "":
		return false
	if a == "neutral" or b == "neutral":
		return false
	if a == "vaktarna" or b == "vaktarna":
		var other := b if a == "vaktarna" else a
		return vaktarna_awake or vaktarna_angry.has(other)
	if not nations.has(a) or not nations.has(b):
		return true  # pirater och kriser är fiender till alla
	return relations[_key(a, b)]["status"] == "krig"


func change_relation(a: String, b: String, delta: float) -> void:
	var k := _key(a, b)
	if not relations.has(k):
		return
	relations[k]["value"] = clampf(relations[k]["value"] + delta, -100.0, 100.0)
	diplomacy_changed.emit()


func set_status(a: String, b: String, new_status: String) -> void:
	var k := _key(a, b)
	if not relations.has(k):
		return
	var old: String = relations[k]["status"]
	if old == new_status:
		return
	relations[k]["status"] = new_status
	relations[k]["since"] = time
	var col: Color = STATUS_COLORS[new_status]
	var na: String = Data.nation_short(a)
	var nb: String = Data.nation_short(b)
	match new_status:
		"krig":
			say("%s har förklarat krig mot %s!" % [na, nb], col)
			if world:
				world.on_war_declared(a, b)
		"fred":
			if old == "krig":
				say("%s och %s har slutit fred." % [na, nb], col)
			else:
				say("%s och %s har brutit sitt avtal." % [na, nb], col)
		"handel":
			say("%s och %s har ingått ett handelsavtal." % [na, nb], col)
		"allians":
			say("%s och %s har bildat en allians!" % [na, nb], col)
	diplomacy_changed.emit()


func declare_war(attacker: String, target: String) -> void:
	if at_war(attacker, target):
		return
	set_status(attacker, target, "krig")
	change_relation(attacker, target, -35.0)
	# Övriga nationer ogillar angripare, särskilt försvararens vänner.
	for n in nations:
		if n == attacker or n == target or not nations[n]["alive"]:
			continue
		change_relation(n, attacker, -8.0)
		if status(n, target) == "allians" and not at_war(n, attacker):
			if status(n, attacker) == "allians":
				set_status(n, attacker, "fred")
			set_status(n, attacker, "krig")


func nation_strength(nation: String) -> float:
	if world:
		return world.nation_strength(nation)
	return 1.0


## Spelarens diplomatiska förslag. Returnerar {"ok": bool, "text": String}.
func player_proposal(action: String, target: String, extra: String = "") -> Dictionary:
	var me := player
	var rel := get_rel(me, target)
	var v: float = rel["value"] + mod(me, "relations") * 15.0
	var st: String = rel["status"]
	var my_str := nation_strength(me)
	var their_str := nation_strength(target)
	var ratio := my_str / maxf(1.0, their_str)
	var tname: String = Data.nation_short(target)
	match action:
		"krig":
			if st == "krig":
				return {"ok": false, "text": "Ni är redan i krig."}
			declare_war(me, target)
			return {"ok": true, "text": "Krigsförklaringen är skickad till %s." % tname}
		"fred":
			if st != "krig":
				return {"ok": false, "text": "Ni är inte i krig."}
			var war_len := time - float(rel["since"])
			var willing := v + war_len / 12.0 + (ratio - 1.0) * 40.0
			if willing > -20.0:
				set_status(me, target, "fred")
				change_relation(me, target, 10.0)
				return {"ok": true, "text": "%s accepterar fred." % tname}
			change_relation(me, target, -2.0)
			return {"ok": false, "text": "%s vägrar. De tror att de kan vinna kriget." % tname}
		"handel":
			if st == "krig":
				return {"ok": false, "text": "Ni måste sluta fred först."}
			if st == "handel" or st == "allians":
				return {"ok": false, "text": "Ni har redan ett avtal."}
			if v >= 5.0:
				set_status(me, target, "handel")
				change_relation(me, target, 8.0)
				return {"ok": true, "text": "%s skriver under handelsavtalet." % tname}
			return {"ok": false, "text": "%s litar inte tillräckligt på er (relation minst 5 krävs)." % tname}
		"allians":
			if st != "handel":
				return {"ok": false, "text": "Ett handelsavtal krävs innan en allians."}
			if v >= 45.0:
				set_status(me, target, "allians")
				change_relation(me, target, 10.0)
				return {"ok": true, "text": "%s går med på en allians!" % tname}
			return {"ok": false, "text": "%s vill inte binda sig (relation minst 45 krävs)." % tname}
		"bryt":
			if st != "handel" and st != "allians":
				return {"ok": false, "text": "Det finns inget avtal att bryta."}
			set_status(me, target, "fred")
			change_relation(me, target, -20.0)
			return {"ok": true, "text": "Avtalet med %s är brutet." % tname}
		"gava":
			var amount := 100.0
			if res(me, "guld") < amount:
				return {"ok": false, "text": "Du har inte 100 guld."}
			add_res(me, "guld", -amount)
			add_res(target, "guld", amount)
			change_relation(me, target, 10.0 + mod(me, "relations") * 5.0)
			resources_changed.emit()
			return {"ok": true, "text": "%s tar tacksamt emot gåvan." % tname}
		"lyxgava":
			# Kryddor och pärlor är mer värda som gåvor.
			var cost := {"kryddor": 20.0, "parlor": 10.0}
			if not can_afford(me, cost):
				return {"ok": false, "text": "Kräver 20 kryddor och 10 pärlor."}
			pay(me, cost)
			change_relation(me, target, 22.0 + mod(me, "relations") * 8.0)
			return {"ok": true, "text": "%s blir mycket imponerade av de exotiska gåvorna." % tname}
		"tribut":
			if ratio >= 1.6:
				var amount: float = floorf(res(target, "guld") * 0.3)
				add_res(target, "guld", -amount)
				add_res(me, "guld", amount)
				change_relation(me, target, -25.0)
				resources_changed.emit()
				return {"ok": true, "text": "%s böjer sig och betalar %d guld i tribut." % [tname, int(amount)]}
			change_relation(me, target, -12.0)
			if v < -40.0 and time > ai_grace():
				declare_war(target, me)
				return {"ok": false, "text": "%s ser kravet som en förolämpning och förklarar krig!" % tname}
			return {"ok": false, "text": "%s skrattar åt kravet. (Du behöver vara mycket starkare.)" % tname}
		"gemensamt_krig":
			if st != "allians":
				return {"ok": false, "text": "Bara allierade kan dras in i krig."}
			if extra == "" or extra == target:
				return {"ok": false, "text": "Välj ett mål."}
			if at_war(target, extra):
				return {"ok": false, "text": "%s är redan i krig med %s." % [tname, Data.nation_short(extra)]}
			if get_rel(target, extra)["value"] < 25.0:
				if status(target, extra) == "handel" or status(target, extra) == "allians":
					set_status(target, extra, "fred")
				declare_war(target, extra)
				change_relation(me, target, 5.0)
				return {"ok": true, "text": "%s ansluter till kriget mot %s!" % [tname, Data.nation_short(extra)]}
			return {"ok": false, "text": "%s vill inte gå i krig mot %s." % [tname, Data.nation_short(extra)]}
	return {"ok": false, "text": "Okänt förslag."}


## Svar på ett AI-förslag som visats i en popup.
func answer_ai_proposal(data: Dictionary, accept: bool) -> void:
	var from: String = data["from"]
	var action: String = data["action"]
	if not accept:
		change_relation(player, from, -6.0)
		if action == "tribut_krav" and time > ai_grace():
			declare_war(from, player)
		return
	match action:
		"handel":
			set_status(player, from, "handel")
			change_relation(player, from, 8.0)
		"allians":
			set_status(player, from, "allians")
			change_relation(player, from, 10.0)
		"fred":
			set_status(player, from, "fred")
			change_relation(player, from, 10.0)
		"tribut_krav":
			var amount: float = data.get("amount", 100.0)
			add_res(player, "guld", -minf(amount, res(player, "guld")))
			add_res(from, "guld", amount)
			change_relation(player, from, 10.0)
			resources_changed.emit()
		"gemensamt_krig":
			var t: String = data.get("target", "")
			if t != "" and not at_war(player, t):
				if status(player, t) != "fred":
					set_status(player, t, "fred")
				declare_war(player, t)
			change_relation(player, from, 12.0)


## AI-nationernas diplomati. Körs med jämna mellanrum från World.
func diplomacy_tick() -> void:
	var alive: Array = []
	for n in nations:
		if nations[n]["alive"]:
			alive.append(n)
	for k in relations:
		var r: Dictionary = relations[k]
		var parts: PackedStringArray = k.split("|")
		var a := parts[0]
		var b := parts[1]
		if not (nations[a]["alive"] and nations[b]["alive"]):
			continue
		# Långsam drift: handel och allians förbättrar, krig försämrar.
		match r["status"]:
			"krig":
				r["value"] = maxf(-100.0, r["value"] - 1.0)
			"handel":
				r["value"] = minf(100.0, r["value"] + 1.5)
			"allians":
				r["value"] = minf(100.0, r["value"] + 1.0)
			"fred":
				r["value"] += (0.0 - r["value"]) * 0.02
		# Gemensamma fiender för samman.
		for c in alive:
			if c != a and c != b and at_war(a, c) and at_war(b, c):
				r["value"] = minf(100.0, r["value"] + 1.0)
	# AI-beslut
	for a in alive:
		if not nations[a]["ai"]:
			continue
		for b in alive:
			if a == b:
				continue
			_ai_decide(a, b)
	diplomacy_changed.emit()


func _ai_decide(a: String, b: String) -> void:
	var r := get_rel(a, b)
	var v: float = r["value"]
	var st: String = r["status"]
	var ratio := nation_strength(a) / maxf(1.0, nation_strength(b))
	var since: float = time - float(r["since"])
	var is_player := b == player
	if st == "krig":
		# Fred om kriget går dåligt eller pågått länge.
		if since > 120.0 and (ratio < 0.7 or since > 600.0 + v * 4.0) and randf() < 0.25:
			if is_player:
				_ask_player(a, "fred", "%s erbjuder fred." % Data.nation_short(a))
			elif nations[b]["ai"]:
				set_status(a, b, "fred")
		return
	if time < ai_grace():
		return
	# Krig om relationen är dålig och AI:n är stark.
	var war_threshold := -45.0 + (ai_aggro() - 1.0) * 30.0
	if st == "fred" and v < war_threshold and ratio > 1.15 and since > 90.0:
		if randf() < 0.15 * ai_aggro():
			declare_war(a, b)
			return
	# Tributkrav mot spelaren om AI:n är mycket starkare.
	if is_player and st == "fred" and ratio > 2.0 and v < 0.0 and randf() < 0.04 * ai_aggro():
		var amount: float = floorf(maxf(50.0, res(player, "guld") * 0.25))
		_ask_player(a, "tribut_krav", "%s kräver %d guld i tribut. Vägrar du kan det bli krig." % [Data.nation_short(a), int(amount)], {"amount": amount})
		return
	# Handel och allianser
	if st == "fred" and v > 15.0 and randf() < 0.12:
		if is_player:
			_ask_player(a, "handel", "%s föreslår ett handelsavtal (+guld för båda)." % Data.nation_short(a))
		elif nations[b]["ai"] and a < b:
			set_status(a, b, "handel")
	elif st == "handel" and v > 60.0 and randf() < 0.06:
		if is_player:
			_ask_player(a, "allians", "%s föreslår en allians." % Data.nation_short(a))
		elif nations[b]["ai"] and a < b:
			set_status(a, b, "allians")
	elif st == "allians" and is_player and randf() < 0.1:
		# Be spelaren om hjälp i ett krig.
		for c in nations:
			if c != a and c != player and nations[c]["alive"] and at_war(a, c) and not at_war(player, c):
				_ask_player(a, "gemensamt_krig", "Er allierade %s ber er gå med i kriget mot %s." % [Data.nation_short(a), Data.nation_short(c)], {"target": c})
				break


func _ask_player(from: String, action: String, text: String, extra: Dictionary = {}) -> void:
	var data := {"from": from, "action": action, "text": text}
	data.merge(extra)
	popup_requested.emit(data)
