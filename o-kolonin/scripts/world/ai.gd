extends RefCounted
## AI för en ö-nation: bygger ekonomi, forskar, bygger skepp, koloniserar,
## försvarar sina öar och anfaller fiender.

const PRIORITY := {
	"skogshuggare": 10.0, "kokosodling": 9.0, "bosattning": 8.0, "fiskehydda": 6.0, "sandtakt": 6.0,
	"stenbrott": 8.0, "akademi": 7.0, "marknad": 6.0, "sockerplantage": 5.0, "romdestilleri": 4.0,
	"kryddgard": 5.0, "parldykare": 5.0, "kristallgruva": 6.0, "guldgruva": 8.0, "glasbruk": 4.0,
	"kanonbatteri": 5.0, "fyrtorn": 0.5, "skeppsvarv": 3.0,
}
## Personlighet per nation: militär satsning, expansion och favoritgren i forskningen.
const PERSONALITY := {
	"valdoria": {"military": 1.2, "expand": 1.0, "tree": "skepp", "focus": "balans"},
	"svartarevet": {"military": 1.4, "expand": 0.8, "tree": "perks", "focus": "forsvar"},
	"kaluma": {"military": 0.9, "expand": 1.2, "tree": "byggnader", "focus": "produktion"},
	"solmar": {"military": 0.8, "expand": 1.3, "tree": "byggnader", "focus": "handel"},
}
const Governor = preload("res://scripts/world/governor.gd")

var nation := ""
var world = null
var pers: Dictionary = {}
var _day := 0
var colonize_target = null
var attack_target = null


func setup(n: String, w) -> void:
	nation = n
	world = w
	pers = PERSONALITY.get(n, {"military": 1.0, "expand": 1.0, "tree": "perks"})
	_day = randi() % 4


func day_tick() -> void:
	_day += 1
	_research()
	if _day % 2 == 0:
		_economy()
	if _day % 3 == 0:
		_shipbuilding()
	if _day % 4 == 1:
		_military()


func _home():
	return world.island_by_id(Data.NATIONS[nation]["home"])


# ------------------------------------------------------------------ Forskning
func _research() -> void:
	var st: Dictionary = Game.nations[nation]
	if st["current_research"] != "":
		return
	var best := ""
	var best_score := INF
	for rid in Data.RESEARCH:
		if not Game.research_available(nation, rid):
			continue
		var r: Dictionary = Data.RESEARCH[rid]
		var score: float = r["cost"] * randf_range(0.8, 1.2)
		if r["tree"] == pers["tree"]:
			score *= 0.7
		if score < best_score:
			best_score = score
			best = rid
	if best != "":
		Game.queue_research(nation, best)


# ------------------------------------------------------------------ Ekonomi
## AI:n använder samma guvernörslogik som spelarens kolonier, ö för ö.
func _economy() -> void:
	var my: Array = world.islands_of(nation)
	if my.is_empty():
		return
	var built := 0
	var start := _day % my.size()
	for k in my.size():
		var isl = my[(start + k) % my.size()]
		var act: Dictionary = Governor.choose(nation, isl, world, pers.get("focus", "balans"), 30.0)
		if not act.is_empty() and world.do_action(nation, isl, act):
			built += 1
			if built >= 2:
				return


# ------------------------------------------------------------------ Skepp
func _shipbuilding() -> void:
	var yard = null
	for isl in world.islands_of(nation):
		if isl.has_shipyard() and isl.ship_queue.size() == 0:
			yard = isl
			break
	if yard == null:
		return
	var fleet: Array = world.ships_of(nation)
	var warships := 0
	var traders := 0
	var galeons := 0
	for s in fleet:
		if s.def.get("trade", false):
			traders += 1
		else:
			warships += 1
		if s.type == "galeon":
			galeons += 1
	var colonies: int = world.islands_of(nation).size() - 1
	if traders < mini(colonies, 3):
		_try_queue(yard, "handelsfartyg")
		return
	var cap := int((3.0 + Game.time / 90.0) * pers["military"] * Game.ai_aggro())
	cap = mini(cap, 18)
	if warships >= cap:
		return
	var at_war := _enemies().size() > 0
	if at_war and galeons == 0 and Game.ship_unlocked(nation, "galeon") and randf() < 0.5:
		if _try_queue(yard, "galeon"):
			return
	var order: Array = Data.SHIP_ORDER.duplicate()
	order.reverse()
	for t in order:
		if t == "handelsfartyg" or t == "galeon" or not Game.ship_unlocked(nation, t):
			continue
		if _try_queue(yard, t):
			return


func _try_queue(yard, t: String) -> bool:
	var cost := Game.ship_cost(nation, t)
	# Behåll en liten reserv för ekonomin.
	var with_reserve := cost.duplicate()
	with_reserve["tra"] = with_reserve.get("tra", 0.0) + 40.0
	if not Game.can_afford_at(nation, yard, with_reserve):
		return false
	return world.queue_ship(nation, yard, t)


func on_ship_built(s) -> void:
	if s.def.get("trade", false):
		var home = _home()
		for isl in world.islands_of(nation):
			if isl == home:
				continue
			var taken := false
			for o in world.ships_of(nation):
				if o != s and o.order == "trade" and o.trade_b == isl:
					taken = true
			if not taken and home != null and home.owner_id == nation:
				world.start_trade(s, home, isl)
				return


# ------------------------------------------------------------------ Militärt
func _enemies() -> Array:
	var out: Array = []
	for n in Game.nations:
		if n != nation and Game.nations[n]["alive"] and Game.at_war(nation, n):
			out.append(n)
	return out


func _military() -> void:
	var home = _home()
	var my_islands: Array = world.islands_of(nation)
	if my_islands.is_empty():
		return
	if home == null or home.owner_id != nation:
		home = my_islands[0]
	var fleet: Array = []
	var idle: Array = []
	for s in world.ships_of(nation):
		if s.def.get("trade", false):
			continue
		fleet.append(s)
		# Skadade skepp seglar hem och lagas.
		if s.hp < s.max_hp * 0.3 and s.order != "move":
			s.order_move(home.coast_point_towards(s.position, 80.0))
			continue
		if s.order == "idle":
			idle.append(s)
	# Amiraler och uppgraderingar
	_admirals_and_upgrades(fleet, home)
	# Försvar: öar under anfall eller med fiender i närheten.
	for isl in my_islands:
		var threat = world.nearest_hostile_ship(nation, isl.position, isl.radius + 700.0)
		if threat != null:
			for s in idle.duplicate():
				if s.position.distance_to(isl.position) < 2500.0:
					s.order_attack(threat)
					idle.erase(s)
	# Kolonisering
	if colonize_target == null or colonize_target.owner_id != "neutral":
		colonize_target = _pick_colony(home)
	if colonize_target != null and idle.size() > 0:
		var cost := Game.colonize_cost(nation)
		if Game.can_afford(nation, cost) and randf() < 0.5 * pers["expand"]:
			var going := false
			for s in world.ships_of(nation):
				if s.order == "colonize":
					going = true
			if not going:
				var best = idle[0]
				for s in idle:
					if s.def["speed"] > best.def["speed"]:
						best = s
				best.order_colonize(colonize_target)
				idle.erase(best)
	# Krig
	var enemies := _enemies()
	# Öar som pirater eller kriser tagit räknas också som mål.
	var hostile_held := false
	for isl in world.islands:
		if isl.owner_id in ["vildpirater", "spokflottan", "armadan", "djupkulten"]:
			hostile_held = true
	if (enemies.size() > 0 or hostile_held) and Game.time > 30.0:
		if attack_target == null or not Game.at_war(nation, attack_target.owner_id) or attack_target.owner_id == nation:
			attack_target = _pick_attack_target(home, enemies)
		var ready: Array = []
		for s in idle:
			if s.hp > s.max_hp * 0.6:
				ready.append(s)
		var needed := 3 if Game.ai_aggro() < 1.2 else 2
		if attack_target != null and ready.size() >= needed:
			for s in ready:
				s.order_attack_island(attack_target)
			if attack_target.owner_id == Game.player:
				Game.say("A fleet from %s is sailing towards %s!" % [Data.nation_short(nation), attack_target.display_name], Color(1, 0.55, 0.4))
			return
	# Lediga skepp långt hemifrån seglar hem.
	for s in idle:
		var near = world.nearest_own_island(nation, s.position, 700.0)
		if near == null:
			s.order_move(home.coast_point_towards(s.position, 150.0 + randf() * 100.0))


func _admirals_and_upgrades(fleet: Array, home) -> void:
	if fleet.size() >= 4 and Game.res(nation, "guld") > world.admiral_cost(nation) + 300.0:
		var with_adm := 0
		for s in fleet:
			if s.admiral != null:
				with_adm += 1
		if with_adm < fleet.size() / 4:
			var best = null
			for s in fleet:
				if s.admiral == null and (best == null or s.max_hp > best.max_hp):
					best = s
			if best != null:
				var free: Array = world.free_admirals(nation)
				if free.size() > 0:
					world.assign_admiral(best, free[0])
				else:
					world.recruit_admiral(best)
	if Game.res(nation, "guld") > 600.0:
		for s in fleet:
			if s.order != "idle":
				continue
			var yard = world.upgrade_island(s)
			if yard == null or yard.good("sten") < 150.0 or yard.good("tra") < 200.0:
				continue
			for key in ["koppar", "kanoner", "segel"]:
				if not s.upgrades.has(key):
					if world.upgrade_ship(s, key):
						return


func _pick_colony(home):
	var best = null
	var bd := INF
	var sol = world.island_by_id("solstenson")
	for isl in world.islands:
		if isl.owner_id != "neutral" or isl.guardians:
			continue
		if sol != null and sol.owner_id == "vaktarna" and isl.position.distance_to(sol.position) < 1000.0 and Game.ai_aggro() < 1.3:
			continue
		var d: float = isl.position.distance_to(home.position) * randf_range(0.85, 1.15)
		if d < bd:
			bd = d
			best = isl
	return best


func _pick_attack_target(home, enemies: Array):
	var best = null
	var bs := INF
	for isl in world.islands:
		if not isl.owner_id in enemies and not (isl.owner_id in ["vildpirater", "spokflottan", "armadan", "djupkulten"]):
			continue
		var forts := 0
		for b in isl.buildings:
			if b.is_active() and Data.BUILDINGS[b.type].has("fort"):
				forts += 1
		var score: float = isl.position.distance_to(home.position) + forts * 400.0 + isl.garrison * 10.0
		if isl.home_of == isl.owner_id:
			score += 800.0
		if score < bs:
			bs = score
			best = isl
	return best
