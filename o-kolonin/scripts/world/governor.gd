extends RefCounted
## Väljer vad som ska byggas på en ö. Används av AI-nationerna och av
## guvernörerna på spelarens öar (som bygger efter vald inriktning).

const PRIORITY := {
	"skogshuggare": 10.0, "kokosodling": 9.0, "bosattning": 8.0, "fiskehydda": 6.0, "sandtakt": 6.0,
	"stenbrott": 8.0, "akademi": 7.0, "marknad": 6.0, "sockerplantage": 5.0, "romdestilleri": 4.0,
	"kryddgard": 5.0, "parldykare": 5.0, "kristallgruva": 6.0, "guldgruva": 8.0, "glasbruk": 4.0,
	"kanonbatteri": 5.0, "fyrtorn": 0.5, "skeppsvarv": 3.0, "lagerhus": 2.0,
}

const FOCUS := {
	"balans": {"name": "Balanced", "desc": "Builds a bit of everything, based on what the island needs.", "boost": []},
	"produktion": {"name": "Raw materials", "desc": "Focuses on wood, food, stone and other raw materials.", "boost": ["skogshuggare", "kokosodling", "fiskehydda", "stenbrott", "sandtakt", "sockerplantage", "kristallgruva", "guldgruva"]},
	"handel": {"name": "Trade", "desc": "Focuses on markets, rum, spices, pearls and glass.", "boost": ["marknad", "romdestilleri", "kryddgard", "parldykare", "glasbruk", "sockerplantage"]},
	"forsvar": {"name": "Defense", "desc": "Focuses on cannon batteries, lighthouses and more inhabitants.", "boost": ["kanonbatteri", "fyrtorn", "bosattning"]},
}


static func count_on(isl, type: String) -> int:
	var c := 0
	for b in isl.buildings:
		if b.type == type:
			c += 1
	return c


## Väljer bästa åtgärden på ön just nu: uppgradera staden, bygga en stadsbyggnad,
## bygga på en resursplats eller uppgradera en resursbyggnad. Tom = inget.
static func choose(nation: String, isl, world, focus: String, gold_reserve: float) -> Dictionary:
	if isl.owner_id != nation or isl.town_level <= 0:
		return {}
	for b in isl.buildings:
		if b.type != "hus" and b.type != "dekor" and (not b.built or b.upgrading):
			return {}  # vänta tills pågående bygge är klart
	var my_islands: Array = world.islands_of(nation)
	var eff: float = isl.work_efficiency()
	var pop_full: bool = isl.population >= isl.housing() - 2.0
	var food_rate: float = isl.rates.get("mat", 0.0)
	var boost: Array = FOCUS.get(focus, FOCUS["balans"])["boost"]
	var cands: Array = []
	# 1. Stadens nivå
	if isl.town_level < Data.TOWN_LEVELS.size() and isl.town_upgrade_left <= 0.0:
		var sc := 5.0
		if pop_full:
			sc += 8.0
		if eff < 0.9:
			sc += 4.0
		if isl.good("mat") < 25.0 and food_rate <= 0.0:
			sc -= 10.0
		if focus == "forsvar":
			sc += 2.0
		cands.append([sc, {"kind": "town"}, isl.upgrade_cost(nation)])
	# 2. Stadsbyggnader på sina platser
	for type in Data.TOWN_REQ:
		if not Game.building_unlocked(nation, type) or not isl.can_build_type(type):
			continue
		var sc: float = PRIORITY.get(type, 3.0) - world.count_buildings(nation, type) * 0.4
		match type:
			"skeppsvarv":
				if isl.home_of != nation and my_islands.size() < 4:
					continue
			"akademi":
				if world.count_buildings(nation, type) >= 1 + my_islands.size() / 2:
					sc -= 6.0
			"kanonbatteri":
				sc += 3.0 if Game.time > Game.ai_grace() * 0.5 else -3.0
			"romdestilleri":
				if isl.good("socker") < 10.0 and isl.free_site("socker") < 0 and count_on(isl, "sockerplantage") == 0:
					continue
			"glasbruk":
				if isl.good("sand") < 20.0 and count_on(isl, "sandtakt") == 0:
					continue
			"lagerhus":
				var full := false
				for g in Data.GOODS:
					if isl.good(g) > isl.capacity() * 0.8:
						full = true
				sc += 6.0 if full else -4.0
		if type in boost:
			sc += 4.0
		cands.append([sc, {"kind": "build", "type": type}, Game.building_cost(nation, type)])
	# 3. Resursplatser: bygga nytt eller uppgradera
	for i in isl.sites.size():
		var st: Dictionary = isl.sites[i]
		var type: String = Data.SITES[st["res"]]["building"]
		var b = st["b"]
		var sc: float = PRIORITY.get(type, 3.0)
		if type == "skogshuggare" and isl.good("tra") < 60.0:
			sc += 5.0
		if (type == "kokosodling" or type == "fiskehydda") and (isl.good("mat") < 40.0 or food_rate < 0.0):
			sc += 7.0
		if type in boost:
			sc += 4.0
		if b == null:
			if not Game.building_unlocked(nation, type):
				continue
			if eff < 0.75:
				sc -= 6.0
			sc -= count_on(isl, type) * 2.0
			cands.append([sc, {"kind": "site", "index": i}, Game.building_cost(nation, type)])
		elif b.built and not b.upgrading and b.level < 3 and isl.town_level >= b.level + 1:
			sc -= 3.0 + b.level * 2.0
			if eff < 0.85:
				sc -= 6.0
			cands.append([sc, {"kind": "site_up", "index": i}, world.site_upgrade_cost(nation, b)])
	# Spara till stadens uppgradering när folket inte räcker till
	var saving := false
	if pop_full and eff < 0.95 and isl.town_level < Data.TOWN_LEVELS.size() and isl.town_upgrade_left <= 0.0:
		if not Game.can_afford_at(nation, isl, isl.upgrade_cost(nation)):
			saving = true
	var best: Dictionary = {}
	var best_score := 2.0
	for c in cands:
		if saving and c[1]["kind"] != "town":
			var act: Dictionary = c[1]
			var food := false
			if act["kind"] == "site":
				var t: String = Data.SITES[isl.sites[act["index"]]["res"]]["building"]
				food = t == "kokosodling" or t == "fiskehydda" or t == "stenbrott" or t == "skogshuggare"
			if not food:
				continue
		var sc: float = c[0] + randf() * 1.5
		if sc <= best_score:
			continue
		var cost: Dictionary = c[2]
		if not Game.can_afford_at(nation, isl, cost):
			continue
		if Game.res(nation, "guld") - cost.get("guld", 0.0) < gold_reserve:
			continue
		best_score = sc
		best = c[1]
	return best


static func describe(isl, act: Dictionary) -> String:
	match act.get("kind", ""):
		"town":
			return "upgrading the town"
		"build":
			return "building a %s" % Data.BUILDINGS[act["type"]]["name"]
		"site":
			var st: Dictionary = isl.sites[act["index"]]
			return "building a %s (%s)" % [Data.BUILDINGS[Data.SITES[st["res"]]["building"]]["name"], Data.SITES[st["res"]]["name"].to_lower()]
		"site_up":
			var b = isl.sites[act["index"]]["b"]
			return "upgrading the %s" % b.display_name()
	return ""
