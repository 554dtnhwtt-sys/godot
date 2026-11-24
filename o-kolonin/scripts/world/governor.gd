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


## Returnerar den byggnad som är bäst att bygga just nu (som nationen har råd med), eller "".
static func choose(nation: String, isl, world, focus: String, gold_reserve: float) -> String:
	if isl.owner_id != nation or isl.free_slot_count() == 0:
		return ""
	for b in isl.buildings:
		if not b.built:
			return ""  # vänta tills pågående bygge är klart
	var my_islands: Array = world.islands_of(nation)
	var eff: float = isl.work_efficiency()
	var pop_full: bool = isl.population >= isl.housing() - 2.0
	var cap: float = isl.capacity()
	var food_rate: float = isl.rates.get("mat", 0.0)
	var boost: Array = FOCUS.get(focus, FOCUS["balans"])["boost"]
	var best := ""
	var best_score := 2.0
	for type in Data.BUILD_ORDER:
		if not Game.building_unlocked(nation, type) or not isl.can_build_type(type):
			continue
		var on_isl := count_on(isl, type)
		var total: int = world.count_buildings(nation, type)
		var score: float = PRIORITY.get(type, 3.0) - on_isl * 3.0 - total * 0.4
		match type:
			"bosattning":
				if eff < 0.9 or pop_full:
					score += 8.0
				if isl.good("mat") < 20.0 and food_rate <= 0.0:
					score -= 8.0
			"lagerhus":
				var full := false
				for g in Data.GOODS:
					if isl.good(g) > cap * 0.85:
						full = true
				if not full:
					continue
				score += 6.0
			"skeppsvarv":
				if on_isl > 0 or (isl.home_of != nation and my_islands.size() < 4):
					continue
			"akademi":
				if total >= 1 + my_islands.size() / 2:
					score -= 6.0
			"kanonbatteri":
				if on_isl >= 2:
					continue
				score += 3.0 if Game.time > Game.ai_grace() * 0.5 else -3.0
			"romdestilleri":
				if count_on(isl, "sockerplantage") == 0 and isl.good("socker") < 10.0:
					continue
			"glasbruk":
				if count_on(isl, "sandtakt") == 0 and isl.good("sand") < 20.0:
					continue
			"marknad":
				if on_isl > 0:
					score -= 5.0
			"skogshuggare":
				if isl.good("tra") < 60.0:
					score += 5.0
			"kokosodling", "fiskehydda":
				if isl.good("mat") < 40.0 or food_rate < 0.0:
					score += 7.0
		var w: float = Data.BUILDINGS[type].get("workers", 0.0)
		if w > 0.0 and eff < 0.75:
			score -= 6.0
		if type in boost:
			score += 4.0
		score += randf() * 1.5
		if score <= best_score:
			continue
		var cost := Game.building_cost(nation, type)
		if not Game.can_afford_at(nation, isl, cost):
			continue
		if Game.res(nation, "guld") - cost.get("guld", 0.0) < gold_reserve:
			continue
		best_score = score
		best = type
	return best
