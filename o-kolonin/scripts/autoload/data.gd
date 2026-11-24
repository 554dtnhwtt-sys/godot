extends Node
## Statisk speldata för Ö-kolonin: nationer, karta, resurser, byggnader,
## forskning, skepp och endgame-kriser. Inget här ändras under spelets gång.

const WORLD_SIZE := Vector2(7200, 4800)
const SEA_NAME := "the Emerald Sea"

# ---------------------------------------------------------------- Resurser
const RESOURCES := ["guld", "tra", "mat", "sten", "sand", "kristaller", "socker", "rom", "kryddor", "parlor"]
const RESOURCE_NAMES := {
	"guld": "Gold", "tra": "Wood", "mat": "Food", "sten": "Stone", "sand": "Sand",
	"kristaller": "Crystals", "socker": "Sugar", "rom": "Rum", "kryddor": "Spices",
	"parlor": "Pearls", "forskning": "Research", "befolkning": "Population",
}
const RESOURCE_COLORS := {
	"guld": Color(1.0, 0.82, 0.25), "tra": Color(0.62, 0.42, 0.24), "mat": Color(0.55, 0.85, 0.35),
	"sten": Color(0.66, 0.68, 0.72), "sand": Color(0.98, 0.88, 0.6), "kristaller": Color(0.55, 0.9, 1.0),
	"socker": Color(0.96, 0.96, 0.92), "rom": Color(0.78, 0.42, 0.18), "kryddor": Color(0.9, 0.36, 0.2),
	"parlor": Color(0.95, 0.9, 1.0), "forskning": Color(0.72, 0.6, 1.0), "befolkning": Color(0.95, 0.75, 0.6),
}
## Lyxvaror som marknader säljer automatiskt (pris i guld per enhet).
const LUXURY_PRICES := {"rom": 3.0, "kryddor": 5.0, "parlor": 9.0}
const LUXURY_RESERVE := 40.0

# ---------------------------------------------------------------- Nationer
const NATIONS := {
	"valdoria": {
		"name": "The Valdorian Crown", "short": "Valdoria", "type": "Colonial Empire",
		"color": Color(0.17, 0.3, 0.62), "accent": Color(0.93, 0.78, 0.3),
		"leader": "Governor Isabela de Valdor", "home": "kronholmen", "emblem": "krona",
		"lore": "Two hundred years ago the first Valdorian galleons sailed into the Emerald Sea in search of gold and spices. Now the Crown has sent Governor Isabela de Valdor with a clear command: make these islands the jewel of the Crown before the rivals get there first.\n\nValdoria has the heaviest ships and the most disciplined sailors on the sea, but every nail and every plank must be approved by bureaucrats far away. From the fortress on Crownholm, the governor looks out over a sea she intends to own.",
		"strengths": ["+20% hull strength on all ships", "Cannon batteries hit 25% harder", "Starts with a frigate and can build brigs right away"],
		"weaknesses": ["Buildings cost 20% more", "Research is 10% slower"],
		"difficulty": 1,
		"mods": {"ship_hp": 1.2, "fort": 1.25, "build_cost": 1.2, "research": 0.9},
		"start_ships": ["fregatt", "slup"],
		"start_research": ["skonare", "brigg"],
		"start_relations": {"svartarevet": -40, "kaluma": -20, "solmar": 10},
	},
	"svartarevet": {
		"name": "Brotherhood of the Black Reef", "short": "Black Reef", "type": "Pirates",
		"color": Color(0.16, 0.14, 0.16), "accent": Color(0.85, 0.18, 0.18),
		"leader": "Captain Mara \"Redbeard\" Kell", "home": "svartarevet", "emblem": "dodskalle",
		"lore": "The Black Reef is on no map – a reef of black volcanic rock where the wrecks of a hundred shipwrecks bleach in the sun. Here come runaways, mutineers and everyone who refuses to bend the knee to a crown.\n\nCaptain Mara Kell united the quarrelling crews with a single law: all plunder is shared equally, and whoever betrays the Brotherhood walks the plank. Their ships are light and fast, and they live off what they take from others.",
		"strengths": ["+15% speed on all ships", "Ships cost 15% less", "Plunder: sinking enemy ships gives gold"],
		"weaknesses": ["Every nation distrusts you from the start", "Buildings produce 15% less"],
		"difficulty": 2,
		"mods": {"ship_speed": 1.15, "ship_cost": 0.85, "plunder": 1.0, "prod_all": 0.85},
		"start_ships": ["skonare", "slup", "slup"],
		"start_research": ["skonare", "battre_segel"],
		"start_relations": {"valdoria": -40, "kaluma": -10, "solmar": -30},
	},
	"kaluma": {
		"name": "The Kaluma People", "short": "Kaluma", "type": "Island Natives",
		"color": Color(0.16, 0.55, 0.36), "accent": Color(0.98, 0.6, 0.2),
		"leader": "Ixara, Voice of the Volcano", "home": "kaluma", "emblem": "vulkan",
		"lore": "Long before the first sails appeared on the horizon, the Kaluma people lived on these islands. They read the sea currents the way others read books, and their canoes find paths through reefs where heavy ships run aground.\n\nThe fire in Mount Kaluma gives them strength, say the elders. Now that strangers arrive with cannons and flags, Ixara, Voice of the Volcano, has called all the clans together. The islands are their home – and every beach will be defended.",
		"strengths": ["+25% food and wood production", "+50% island defense (garrison)", "Sees 30% further through the fog"],
		"weaknesses": ["Starts with simpler ship technology", "Ships have 10% less hull strength"],
		"difficulty": 1,
		"mods": {"prod_mat": 1.25, "prod_tra": 1.25, "garrison": 1.5, "vision": 1.3, "ship_hp": 0.9},
		"start_ships": ["slup", "slup"],
		"start_research": ["fiske", "jordbruk"],
		"start_relations": {"valdoria": -20, "svartarevet": -10, "solmar": 0},
	},
	"solmar": {
		"name": "The Republic of Solmar", "short": "Solmar", "type": "Merchant Republic",
		"color": Color(0.88, 0.5, 0.15), "accent": Color(0.98, 0.95, 0.85),
		"leader": "Councillor Cassia Moravel", "home": "portosolmar", "emblem": "sol",
		"lore": "The Republic of Solmar is ruled not by kings but by a council of merchants, and in Solmar anything can be bought – even peace. When rumours of the crystals in the Emerald Sea reached the council, it took only a week before the first merchant ships set sail.\n\nCouncillor Cassia Moravel leads the colony with a slide rule in one hand and a contract in the other. The Republic prefers treaties to cannons, but whoever breaks a deal with Solmar pays – with interest.",
		"strengths": ["+30% income from trade and markets", "Every nation starts with better relations to you", "Starts with 300 extra gold"],
		"weaknesses": ["Ships have 10% less hull strength", "Landing troops are 20% weaker"],
		"difficulty": 0,
		"mods": {"trade": 1.3, "relations": 1.0, "ship_hp": 0.9, "troops": 0.8},
		"start_ships": ["handelsfartyg", "slup"],
		"start_research": ["marknad", "handelsvana"],
		"start_relations": {"valdoria": 10, "svartarevet": -30, "kaluma": 0},
		"start_bonus": {"guld": 300},
	},
}
const PLAYABLE := ["valdoria", "svartarevet", "kaluma", "solmar"]

## Fientliga fraktioner som inte är spelbara (pirater från händelser och kriser).
const HOSTILE_FACTIONS := {
	"vildpirater": {"name": "Free Pirates", "short": "Pirates", "color": Color(0.3, 0.27, 0.25), "accent": Color(0.9, 0.9, 0.85)},
	"spokflottan": {"name": "The Ghost Fleet", "short": "Ghost Fleet", "color": Color(0.35, 0.95, 0.7), "accent": Color(0.75, 1.0, 0.9)},
	"armadan": {"name": "The Golden Armada", "short": "Armada", "color": Color(0.85, 0.68, 0.18), "accent": Color(0.55, 0.08, 0.1)},
	"djupkulten": {"name": "Cult of the Deep", "short": "Deep Cult", "color": Color(0.42, 0.2, 0.55), "accent": Color(0.3, 0.9, 0.8)},
	"vaktarna": {"name": "The Sleeping Wardens", "short": "Wardens", "color": Color(0.45, 0.75, 0.95), "accent": Color(1.0, 0.95, 0.7)},
}

# ---------------------------------------------------------------- Kriser
## Endgame-kriser (Stellaris-stil). Flera kan vara igång samtidigt.
## "from_start": fraktionen finns på kartan från början och vaknar senare.
const CRISES := {
	"spokflottan": {
		"name": "The Ghost Fleet",
		"desc": "The ships that sank in the Emerald Sea do not rest. When the fog thickens, a fleet of dead crews rises from the deep and attacks everything that lives.",
		"from_start": false,
		"pilot": true,
	},
	"armadan": {
		"name": "The Golden Armada",
		"desc": "A vast empire beyond the horizon has set its eyes on the riches of the islands. Ships of the line by the hundred sail in from the open sea to conquer everything.",
		"from_start": false,
		"pilot": false,
	},
	"djupkulten": {
		"name": "Cult of the Deep",
		"desc": "A secret sect worships what sleeps beneath the reefs. When the cult has gathered enough sacrifices, they will wake the Kraken – a beast that drags whole ships into the depths.",
		"from_start": false,
		"pilot": false,
	},
	"vaktarna": {
		"name": "The Sleeping Wardens",
		"desc": "On Sunstone Isle live the remnants of an ancient civilization with ships of crystal. They want to be left alone – whoever comes too close, or waits too long, will awaken their wrath.",
		"from_start": true,
		"pilot": true,
	},
}

# ---------------------------------------------------------------- Karta
## Handgjord karta. r = ungefärlig radie i pixlar.
const ISLANDS := [
	{"id": "kronholmen", "name": "Crownholm", "pos": Vector2(1050, 950), "r": 330, "deposits": ["tra", "mat", "sten"], "home": "valdoria"},
	{"id": "svartarevet", "name": "Black Reef", "pos": Vector2(6150, 900), "r": 300, "deposits": ["tra", "mat", "sten"], "home": "svartarevet", "dark": true},
	{"id": "kaluma", "name": "Kaluma", "pos": Vector2(1150, 3850), "r": 370, "deposits": ["tra", "mat", "kryddor"], "home": "kaluma", "volcano": true},
	{"id": "portosolmar", "name": "Porto Solmar", "pos": Vector2(6050, 3850), "r": 320, "deposits": ["tra", "mat", "sand"], "home": "solmar"},
	{"id": "kokoson", "name": "Coconut Isle", "pos": Vector2(2200, 1500), "r": 200, "deposits": ["tra", "mat"]},
	{"id": "sandbanken", "name": "The Sandbank", "pos": Vector2(2950, 650), "r": 170, "deposits": ["sand", "parlor"]},
	{"id": "fyrskaret", "name": "Beacon Skerry", "pos": Vector2(3800, 1150), "r": 150, "deposits": ["sten", "parlor"]},
	{"id": "stenkummel", "name": "Stone Cairn", "pos": Vector2(4800, 1500), "r": 210, "deposits": ["sten", "tra"]},
	{"id": "skoldpaddson", "name": "Turtle Isle", "pos": Vector2(5100, 550), "r": 170, "deposits": ["mat", "socker"]},
	{"id": "mangroveholmen", "name": "Mangrove Holm", "pos": Vector2(1500, 2350), "r": 210, "deposits": ["tra", "kryddor"]},
	{"id": "smaragdon", "name": "Emerald Isle", "pos": Vector2(2700, 2150), "r": 190, "deposits": ["kristaller", "tra"]},
	{"id": "kristallrevet", "name": "Crystal Reef", "pos": Vector2(3650, 2450), "r": 250, "deposits": ["kristaller", "sand", "parlor"]},
	{"id": "papegojon", "name": "Parrot Isle", "pos": Vector2(2350, 3150), "r": 220, "deposits": ["tra", "socker", "kryddor"]},
	{"id": "solnedgangson", "name": "Sunset Isle", "pos": Vector2(3000, 4100), "r": 180, "deposits": ["mat", "socker"]},
	{"id": "dodmanskistan", "name": "Dead Man's Chest", "pos": Vector2(4250, 3600), "r": 190, "deposits": ["guld", "sten"]},
	{"id": "parlbukten", "name": "Pearl Bay", "pos": Vector2(5150, 2750), "r": 210, "deposits": ["parlor", "sand", "mat"]},
	{"id": "spokskaret", "name": "Ghost Skerry", "pos": Vector2(6150, 2150), "r": 150, "deposits": ["kristaller", "sten"]},
	{"id": "hajtanden", "name": "Shark's Tooth", "pos": Vector2(4950, 4300), "r": 150, "deposits": ["sten", "guld"]},
	{"id": "solstenson", "name": "Sunstone Isle", "pos": Vector2(4450, 2500), "r": 200, "deposits": ["kristaller", "guld"], "guardians": true},
]

# ---------------------------------------------------------------- Byggnader
## prod = per sekund. consumes = förbrukas per sekund (krävs för produktion).
## deposit = kräver att ön har den resursen. research = kräver forskningen.
const BUILDINGS := {
	"radhus": {"name": "Town Hall", "desc": "The heart of the town. Gives gold and some research. Upgrade the town to make it grow.", "cost": {}, "prod": {"guld": 1.5, "forskning": 0.4}, "buildable": false, "garrison": 0, "fort": {"range": 360.0, "damage": 6.0, "reload": 3.6}, "time": 1.0, "workers": 0},
	"hus": {"name": "House", "desc": "Homes for the townspeople.", "cost": {}, "prod": {}, "buildable": false, "time": 4.0, "workers": 0},
	"dekor": {"name": "Town decoration", "desc": "", "cost": {}, "prod": {}, "buildable": false, "time": 4.0, "workers": 0},
	"bosattning": {"name": "Settlement", "desc": "Homes for 20 settlers. The inhabitants work in your buildings and pay taxes.", "cost": {"tra": 30}, "prod": {}, "housing": 20, "time": 6.0, "workers": 0},
	"skogshuggare": {"name": "Woodcutter", "desc": "Fells palms and hardwood.", "cost": {"guld": 20}, "prod": {"tra": 1.2}, "deposit": "tra", "time": 6.0, "workers": 4},
	"kokosodling": {"name": "Coconut Grove", "desc": "Coconuts and fruit to feed the people.", "cost": {"tra": 25}, "prod": {"mat": 1.2}, "deposit": "mat", "time": 6.0, "workers": 4},
	"fiskehydda": {"name": "Fishing Hut", "desc": "Fishermen on the beach. Works on every island.", "cost": {"tra": 20, "guld": 10}, "prod": {"mat": 0.9}, "research": "fiske", "coastal": true, "time": 6.0, "workers": 3},
	"stenbrott": {"name": "Quarry", "desc": "Cuts stone from the cliffs.", "cost": {"tra": 40, "guld": 30}, "prod": {"sten": 0.8}, "deposit": "sten", "research": "stenbrott", "time": 9.0, "workers": 6},
	"sandtakt": {"name": "Sand Pit", "desc": "Digs up white coral sand.", "cost": {"tra": 30}, "prod": {"sand": 1.0}, "deposit": "sand", "time": 6.0, "workers": 4},
	"sockerplantage": {"name": "Sugar Plantation", "desc": "Grows sugar cane.", "cost": {"tra": 35, "guld": 20}, "prod": {"socker": 0.9}, "deposit": "socker", "research": "sockerodling", "time": 8.0, "workers": 5},
	"romdestilleri": {"name": "Rum Distillery", "desc": "Distills sugar into rum. Rum raises the morale of your crews and sells for a good price.", "cost": {"tra": 60, "sten": 30}, "prod": {"rom": 0.5}, "consumes": {"socker": 1.0}, "research": "romdestilleri", "time": 10.0, "workers": 6},
	"kryddgard": {"name": "Spice Garden", "desc": "Grows nutmeg, vanilla and cinnamon.", "cost": {"tra": 40, "guld": 40}, "prod": {"kryddor": 0.4}, "deposit": "kryddor", "research": "kryddhandel", "time": 9.0, "workers": 5},
	"parldykare": {"name": "Pearl Divers", "desc": "Divers who bring up pearls from the reefs.", "cost": {"tra": 40, "guld": 50}, "prod": {"parlor": 0.25}, "deposit": "parlor", "research": "parldykning", "coastal": true, "time": 9.0, "workers": 4},
	"kristallgruva": {"name": "Crystal Mine", "desc": "Mines the glowing crystals.", "cost": {"tra": 80, "sten": 60}, "prod": {"kristaller": 0.3}, "deposit": "kristaller", "research": "kristallgruva", "time": 14.0, "workers": 8},
	"guldgruva": {"name": "Gold Mine", "desc": "Digs gold out of the mountain.", "cost": {"tra": 70, "sten": 50}, "prod": {"guld": 2.5}, "deposit": "guld", "research": "guldgruva", "time": 12.0, "workers": 8},
	"marknad": {"name": "Market", "desc": "Gives gold and automatically sells rum, spices and pearls (above a reserve of 40).", "cost": {"tra": 60, "sten": 20}, "prod": {"guld": 1.5}, "research": "marknad", "market": true, "time": 10.0, "workers": 4},
	"akademi": {"name": "Academy", "desc": "Learned men and women research new ideas.", "cost": {"tra": 60, "sten": 30, "sand": 20}, "prod": {"forskning": 1.2}, "time": 12.0, "workers": 6},
	"skeppsvarv": {"name": "Shipyard", "desc": "Builds ships. Required to grow your fleet.", "cost": {"tra": 80, "guld": 50}, "prod": {}, "shipyard": true, "coastal": true, "time": 12.0, "workers": 8},
	"kanonbatteri": {"name": "Cannon Battery", "desc": "Fires on enemy ships near the island and strengthens the garrison.", "cost": {"sten": 60, "guld": 40}, "prod": {}, "fort": {"range": 420.0, "damage": 12.0, "reload": 3.2}, "garrison": 15, "research": "kanonbatteri", "coastal": true, "time": 12.0, "workers": 4},
	"fyrtorn": {"name": "Lighthouse", "desc": "Clears the fog far out over the sea.", "cost": {"sten": 40, "sand": 40}, "prod": {}, "vision": 1100.0, "research": "fyrtorn", "coastal": true, "time": 10.0, "workers": 2},
	"lagerhus": {"name": "Warehouse", "desc": "Increases the island's storage by 300 for every good.", "cost": {"tra": 40, "sten": 10}, "prod": {}, "storage": 300, "time": 7.0, "workers": 2},
	"glasbruk": {"name": "Glassworks", "desc": "Melts sand into glass that sells for gold.", "cost": {"tra": 50, "sten": 30}, "prod": {"guld": 2.2}, "consumes": {"sand": 0.8}, "research": "glasbruk", "time": 10.0, "workers": 6},
}
const BUILD_ORDER := ["lagerhus", "skogshuggare", "kokosodling", "fiskehydda", "sandtakt", "stenbrott", "sockerplantage", "romdestilleri", "kryddgard", "parldykare", "kristallgruva", "guldgruva", "marknad", "glasbruk", "akademi", "skeppsvarv", "kanonbatteri", "fyrtorn"]
const COST_GROWTH := 1.05

# ---------------------------------------------------------------- Städer och resursplatser
## Varje ö har en färdigplanerad stad. Uppgraderas staden växer den av sig själv:
## fler hus, ett större rådhus och (på högre nivåer) torg och vakttorn.
const TOWN_LEVELS := [
	{"name": "Outpost", "hall": "hall1", "housing": 20, "houses": 2, "tier": 0, "cost": {}, "time": 0.0, "garrison": 10, "storage": 0},
	{"name": "Village", "hall": "hall2", "housing": 50, "houses": 5, "tier": 0, "cost": {"tra": 80, "mat": 40, "guld": 100}, "time": 15.0, "garrison": 20, "storage": 100},
	{"name": "Town", "hall": "hall3", "housing": 100, "houses": 9, "tier": 1, "cost": {"tra": 160, "sten": 60, "guld": 250}, "time": 25.0, "garrison": 35, "storage": 250},
	{"name": "City", "hall": "hall4", "housing": 170, "houses": 14, "tier": 2, "cost": {"tra": 300, "sten": 160, "sand": 60, "guld": 600}, "time": 35.0, "garrison": 55, "storage": 450},
	{"name": "Capital", "hall": "hall5", "housing": 260, "houses": 20, "tier": 3, "cost": {"tra": 500, "sten": 300, "sand": 120, "kristaller": 15, "guld": 1200}, "time": 50.0, "garrison": 80, "storage": 700},
]
## Husbilder per nivå (hyddor -> hus -> stenhus -> herrgårdar).
const HOUSE_TIERS := [["hut1", "hut2", "hut3"], ["hut2", "house1", "house2", "house3"], ["house1", "house2", "house3", "townhouse"], ["townhouse", "mansion", "house3", "chapel"]]
## Stadsbyggnader placeras automatiskt på sin plats i staden. Kräver en viss stadsnivå.
const TOWN_REQ := {"skeppsvarv": 1, "lagerhus": 1, "marknad": 2, "akademi": 2, "kanonbatteri": 2, "romdestilleri": 2, "glasbruk": 3, "fyrtorn": 3}
## Resursplatser på öarna och vilken byggnad som byggs där.
const SITES := {
	"tra": {"name": "Forest", "building": "skogshuggare"},
	"mat": {"name": "Coconut palms", "building": "kokosodling"},
	"fisk": {"name": "Fishing waters", "building": "fiskehydda"},
	"sten": {"name": "Stone deposit", "building": "stenbrott"},
	"sand": {"name": "Sand dunes", "building": "sandtakt"},
	"socker": {"name": "Wild sugar cane", "building": "sockerplantage"},
	"kryddor": {"name": "Wild spices", "building": "kryddgard"},
	"parlor": {"name": "Pearl reef", "building": "parldykare"},
	"kristaller": {"name": "Crystal vein", "building": "kristallgruva"},
	"guld": {"name": "Gold vein", "building": "guldgruva"},
}
## Resursbyggnader kan uppgraderas till nivå 3.
const RES_LEVEL_PROD := [1.0, 1.7, 2.5]
const RES_LEVEL_WORKERS := [1.0, 1.5, 2.0]
const RES_LEVEL_COST := [1.0, 2.0, 4.0]
const RES_LEVEL_STONE := [0.0, 20.0, 60.0]

# ---------------------------------------------------------------- Ekonomi per ö
## Guld och forskning är gemensamma för nationen. Alla andra varor ligger i varje ös lager.
const NATIONAL := ["guld", "forskning"]
const GOODS := ["tra", "mat", "sten", "sand", "kristaller", "socker", "rom", "kryddor", "parlor"]
const STORAGE_BASE := 300.0
const STORAGE_HOME := 600.0
## Befolkning: mat per invånare och dag, skatt i guld per invånare och dag.
const FOOD_PER_POP := 0.045
const TAX_PER_POP := 0.05

# ---------------------------------------------------------------- Skepp
const SHIPS := {
	"handelsfartyg": {"name": "Merchant Ship", "desc": "Unarmed. Runs trade routes between your islands.", "hp": 110, "speed": 120.0, "cannons": 0, "range": 0.0, "reload": 99.0, "damage": 0.0, "troops": 5, "cost": {"tra": 50, "guld": 30}, "time": 10.0, "size": 1.1, "masts": 1, "trade": true, "cargo": 150},
	"slup": {"name": "Sloop", "desc": "Small and nimble. Good for scouting and colonizing.", "hp": 100, "speed": 140.0, "cannons": 2, "range": 260.0, "reload": 2.6, "damage": 7.0, "troops": 10, "cost": {"tra": 60, "guld": 40}, "time": 12.0, "size": 1.0, "masts": 1, "cargo": 40},
	"skonare": {"name": "Schooner", "desc": "Fast two-master with more cannons.", "hp": 150, "speed": 150.0, "cannons": 3, "range": 270.0, "reload": 2.4, "damage": 7.0, "troops": 15, "cost": {"tra": 90, "guld": 60}, "time": 15.0, "size": 1.15, "masts": 2, "cargo": 60},
	"brigg": {"name": "Brig", "desc": "Sturdy warship, the workhorse of the fleet.", "hp": 240, "speed": 125.0, "cannons": 5, "range": 290.0, "reload": 2.6, "damage": 8.0, "troops": 20, "cost": {"tra": 140, "guld": 100, "sten": 20}, "time": 20.0, "size": 1.35, "masts": 2, "cargo": 80},
	"galeon": {"name": "Galleon", "desc": "Heavy transport. Carries many soldiers for landings.", "hp": 320, "speed": 95.0, "cannons": 4, "range": 280.0, "reload": 3.0, "damage": 8.0, "troops": 60, "cost": {"tra": 180, "guld": 120}, "time": 24.0, "size": 1.6, "masts": 3, "cargo": 220},
	"fregatt": {"name": "Frigate", "desc": "Fast and heavily armed. The hunter of the seas.", "hp": 380, "speed": 120.0, "cannons": 8, "range": 320.0, "reload": 2.6, "damage": 9.0, "troops": 25, "cost": {"tra": 220, "guld": 180, "sten": 40}, "time": 28.0, "size": 1.6, "masts": 3, "cargo": 80},
	"linjeskepp": {"name": "Ship of the Line", "desc": "A floating fortress with three gun decks.", "hp": 720, "speed": 88.0, "cannons": 14, "range": 340.0, "reload": 3.0, "damage": 10.0, "troops": 40, "cost": {"tra": 400, "guld": 320, "sten": 120, "kristaller": 20}, "time": 40.0, "size": 2.0, "masts": 3, "cargo": 120},
	# Specialskepp för kriser
	"spokskepp": {"name": "Ghost Ship", "desc": "A dead crew sailing against the wind.", "hp": 300, "speed": 115.0, "cannons": 7, "range": 300.0, "reload": 2.6, "damage": 9.0, "troops": 30, "cost": {}, "time": 0.0, "size": 1.55, "masts": 3, "ghost": true, "cargo": 0},
	"armadaskepp": {"name": "Armada Man-of-War", "desc": "A gleaming golden warship from afar.", "hp": 650, "speed": 85.0, "cannons": 12, "range": 330.0, "reload": 3.0, "damage": 10.0, "troops": 50, "cost": {}, "time": 0.0, "size": 1.95, "masts": 3, "cargo": 100},
	"kristallskepp": {"name": "Crystal Ship", "desc": "An ancient Warden ship that glows in the dark.", "hp": 520, "speed": 130.0, "cannons": 8, "range": 360.0, "reload": 2.2, "damage": 12.0, "troops": 30, "cost": {}, "time": 0.0, "size": 1.7, "masts": 2, "crystal": true, "cargo": 60},
	"kultskepp": {"name": "Cult Black Brig", "desc": "A ship of the Deep Cult with its sacrificial fire lit.", "hp": 220, "speed": 130.0, "cannons": 5, "range": 280.0, "reload": 2.6, "damage": 8.0, "troops": 20, "cost": {}, "time": 0.0, "size": 1.35, "masts": 2, "cargo": 60},
	"kraken": {"name": "The Kraken", "desc": "A beast from the deep.", "hp": 2200, "speed": 75.0, "cannons": 0, "range": 120.0, "reload": 1.6, "damage": 35.0, "troops": 0, "cost": {}, "time": 0.0, "size": 2.4, "masts": 0, "monster": true, "cargo": 0},
}
## Erfarenhet: nivåer och bonusar (omladdning, träffsäkerhet, fart).
const XP_LEVELS := [
	{"name": "Recruits", "xp": 0, "reload": 1.0, "spread": 1.0, "speed": 1.0},
	{"name": "Seasoned", "xp": 120, "reload": 0.94, "spread": 0.88, "speed": 1.03},
	{"name": "Veterans", "xp": 350, "reload": 0.88, "spread": 0.76, "speed": 1.06},
	{"name": "Elite", "xp": 800, "reload": 0.8, "spread": 0.62, "speed": 1.1},
]

## Uppgraderingar på skeppsvarvet. Varje skepp kan få varje uppgradering en gång.
const UPGRADES := {
	"kanoner": {"name": "More Cannons", "desc": "+2 cannons per side.", "cost": {"guld": 120, "sten": 40, "tra": 30}},
	"koppar": {"name": "Copper Sheathing", "desc": "+20% hull strength.", "cost": {"guld": 150, "sten": 20, "tra": 40}},
	"segel": {"name": "New Sails", "desc": "+10% speed.", "cost": {"guld": 90, "tra": 30}},
	"lastrum": {"name": "Larger Hold", "desc": "+50% cargo space.", "cost": {"guld": 60, "tra": 50}},
}

## Amiraler: egenskaper som påverkar skepp nära flaggskeppet.
const ADMIRAL_TRAITS := {
	"djarv": {"name": "Bold", "desc": "+15% cannon damage in the fleet.", "mods": {"cannon_dmg": 1.15}},
	"stormseglare": {"name": "Storm Sailor", "desc": "+10% speed and no storm damage.", "mods": {"ship_speed": 1.1, "storm_immune": 1.0}},
	"kanonmastare": {"name": "Master Gunner", "desc": "Cannons reload 15% faster.", "mods": {"reload": 0.85}},
	"forsiktig": {"name": "Cautious", "desc": "The fleet takes 12% less damage.", "mods": {"armor": 0.88}},
	"taktiker": {"name": "Tactician", "desc": "Better accuracy (-25% spread).", "mods": {"spread": 0.75}},
	"kapare": {"name": "Privateer", "desc": "Sunk enemy ships give gold and cargo.", "mods": {"plunder": 1.0}},
	"valtalig": {"name": "Inspiring", "desc": "+25% soldiers when landing.", "mods": {"troops": 1.25}},
}
const ADMIRAL_RANGE := 650.0
const ADMIRAL_NAMES := {
	"valdoria": ["Don Rodrigo Vélez", "Doña Catalina Ferrer", "Don Esteban Marín", "Don Alonso de Cuervo", "Doña Inés Salvatierra", "Don Fernán Ocampo"],
	"svartarevet": ["Jack \"the Knife\" Harrow", "Anne Blackwater", "Bartholomew Hook", "Mary \"Powder\" Reade", "Long Silas", "One-Eyed Tobias"],
	"kaluma": ["Tamu Wavebreaker", "Ayan Stormeye", "Kesi Reefdancer", "Oruko Firehand", "Yaro Mooncutter", "Ilani Deepdiver"],
	"solmar": ["Captain Lorenzo Vesk", "Captain Bianca Moravel", "Captain Matteo Orsini", "Captain Giulia Serra", "Captain Paolo Contarini", "Captain Livia Dandolo"],
}
const ADMIRAL_COST := 150.0

const SHIP_ORDER := ["handelsfartyg", "slup", "skonare", "brigg", "galeon", "fregatt", "linjeskepp"]
const SHIP_RESEARCH := {"skonare": "skonare", "brigg": "brigg", "galeon": "galeon", "fregatt": "fregatt", "linjeskepp": "linjeskepp"}

# ---------------------------------------------------------------- Forskning
## tree: byggnader / perks / skepp. effect: modifierare som multipliceras in.
const RESEARCH := {
	# Byggnader
	"fiske": {"tree": "byggnader", "name": "Fishing Nets", "cost": 25, "req": [], "desc": "Unlocks the Fishing Hut."},
	"stenbrott": {"tree": "byggnader", "name": "Stonecutting", "cost": 35, "req": [], "desc": "Unlocks the Quarry."},
	"sockerodling": {"tree": "byggnader", "name": "Sugar Cane", "cost": 40, "req": [], "desc": "Unlocks the Sugar Plantation."},
	"marknad": {"tree": "byggnader", "name": "Marketplace", "cost": 55, "req": ["fiske"], "desc": "Unlocks the Market."},
	"romdestilleri": {"tree": "byggnader", "name": "Rum Distilling", "cost": 70, "req": ["sockerodling"], "desc": "Unlocks the Rum Distillery."},
	"kanonbatteri": {"tree": "byggnader", "name": "Coastal Artillery", "cost": 70, "req": ["stenbrott"], "desc": "Unlocks the Cannon Battery."},
	"glasbruk": {"tree": "byggnader", "name": "Glassblowing", "cost": 80, "req": ["stenbrott"], "desc": "Unlocks the Glassworks."},
	"kryddhandel": {"tree": "byggnader", "name": "Spice Farming", "cost": 90, "req": ["marknad"], "desc": "Unlocks the Spice Garden."},
	"parldykning": {"tree": "byggnader", "name": "Pearl Diving", "cost": 90, "req": ["fiske"], "desc": "Unlocks the Pearl Divers."},
	"fyrtorn": {"tree": "byggnader", "name": "Lighthouses", "cost": 100, "req": ["glasbruk"], "desc": "Unlocks the Lighthouse."},
	"guldgruva": {"tree": "byggnader", "name": "Mining", "cost": 120, "req": ["stenbrott"], "desc": "Unlocks the Gold Mine."},
	"kristallgruva": {"tree": "byggnader", "name": "Crystal Cutting", "cost": 150, "req": ["guldgruva"], "desc": "Unlocks the Crystal Mine."},
	# Perks
	"jordbruk": {"tree": "perks", "name": "Irrigation", "cost": 45, "req": [], "desc": "+20% food.", "effect": {"prod_mat": 1.2}},
	"handelsvana": {"tree": "perks", "name": "Trade Savvy", "cost": 60, "req": [], "desc": "+20% gold.", "effect": {"prod_guld": 1.2}},
	"battre_segel": {"tree": "perks", "name": "Better Sails", "cost": 60, "req": [], "desc": "+10% ship speed.", "effect": {"ship_speed": 1.1}},
	"timmerhantering": {"tree": "perks", "name": "Timber Handling", "cost": 60, "req": ["jordbruk"], "desc": "+20% wood.", "effect": {"prod_tra": 1.2}},
	"snabbladdning": {"tree": "perks", "name": "Rapid Loading", "cost": 90, "req": ["battre_segel"], "desc": "Cannons reload 20% faster.", "effect": {"reload": 0.8}},
	"navigatorer": {"tree": "perks", "name": "Navigators", "cost": 80, "req": ["battre_segel"], "desc": "See 30% further through the fog.", "effect": {"vision": 1.3}},
	"diplomater": {"tree": "perks", "name": "Diplomatic Corps", "cost": 70, "req": ["handelsvana"], "desc": "Relations improve faster and trade agreements give more.", "effect": {"relations": 1.0, "trade": 1.15}},
	"kopparskrov": {"tree": "perks", "name": "Copper-Clad Hulls", "cost": 120, "req": ["snabbladdning"], "desc": "+15% hull strength.", "effect": {"ship_hp": 1.15}},
	"befastningar": {"tree": "perks", "name": "Fortifications", "cost": 120, "req": ["kanonbatteri"], "desc": "+50% garrison, +25% cannon battery damage.", "effect": {"garrison": 1.5, "fort": 1.25}},
	"marinsoldater": {"tree": "perks", "name": "Marines", "cost": 110, "req": ["kopparskrov"], "desc": "+40% landing troops.", "effect": {"troops": 1.4}},
	"industri": {"tree": "perks", "name": "Manufactories", "cost": 160, "req": ["timmerhantering", "handelsvana"], "desc": "+15% production of everything.", "effect": {"prod_all": 1.15}},
	"kristallkanoner": {"tree": "perks", "name": "Crystal Cannons", "cost": 260, "req": ["kristallgruva", "kopparskrov"], "desc": "Cannons deal 30% more damage.", "effect": {"cannon_dmg": 1.3}},
	# Skeppsmodeller
	"skonare": {"tree": "skepp", "name": "Schooner", "cost": 45, "req": [], "desc": "Unlocks the Schooner."},
	"brigg": {"tree": "skepp", "name": "Brig", "cost": 90, "req": ["skonare"], "desc": "Unlocks the Brig."},
	"galeon": {"tree": "skepp", "name": "Galleon", "cost": 110, "req": ["brigg"], "desc": "Unlocks the Galleon (transport)."},
	"fregatt": {"tree": "skepp", "name": "Frigate", "cost": 160, "req": ["brigg"], "desc": "Unlocks the Frigate."},
	"linjeskepp": {"tree": "skepp", "name": "Ship of the Line", "cost": 300, "req": ["fregatt", "kristallgruva"], "desc": "Unlocks the Ship of the Line."},
}
const RESEARCH_TREES := {"byggnader": "Buildings", "perks": "Perks", "skepp": "Ship Designs"}

# ---------------------------------------------------------------- Inställningar
## Tiden går dag för dag i realtid. En dag = DAY_SECONDS sekunder i normal fart.
## Hastigheter: paus, 1x, 2x, 4x, 8x. En genomspelning i betan: upp till ~8 timmar.
const DAY_SECONDS := 1.0
const START_YEAR := 1680
const START_DAY_OF_YEAR := 59  # 1 mars
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
## Forskningens kostnader. Piloten: snabb takt. Betan (~8 h): höjs till ca 4.
const RESEARCH_COST_SCALE := 1.5

const AI_TEMPO := {
	"fredlig": {"name": "Peaceful start", "desc": "The AI nations will not declare war for the first ~2.5 years (900 days).", "grace": 900.0, "aggro": 0.7},
	"normal": {"name": "Normal", "desc": "The AI nations may start wars after about a year.", "grace": 365.0, "aggro": 1.0},
	"aggressiv": {"name": "Aggressive", "desc": "The AI nations may attack within a few weeks.", "grace": 30.0, "aggro": 1.4},
}
## När endgame-kriserna börjar (i speldagar). Pilotens takt – förlängs i betan.
const CRISIS_TIMING := {
	"tidig": {"name": "Early (year 1682)", "time": 2.0 * 365.0},
	"normal": {"name": "Normal (year 1684)", "time": 4.0 * 365.0},
	"sen": {"name": "Late (year 1687)", "time": 7.0 * 365.0},
}


func nation_name(id: String) -> String:
	if NATIONS.has(id):
		return NATIONS[id]["name"]
	if HOSTILE_FACTIONS.has(id):
		return HOSTILE_FACTIONS[id]["name"]
	return "Nobody"


func nation_short(id: String) -> String:
	if NATIONS.has(id):
		return NATIONS[id]["short"]
	if HOSTILE_FACTIONS.has(id):
		return HOSTILE_FACTIONS[id]["short"]
	return "Neutral"


func nation_color(id: String) -> Color:
	if NATIONS.has(id):
		return NATIONS[id]["color"]
	if HOSTILE_FACTIONS.has(id):
		return HOSTILE_FACTIONS[id]["color"]
	return Color(0.85, 0.85, 0.8)


func nation_accent(id: String) -> Color:
	if NATIONS.has(id):
		return NATIONS[id]["accent"]
	if HOSTILE_FACTIONS.has(id):
		return HOSTILE_FACTIONS[id]["accent"]
	return Color(1, 1, 1)


func island_def(id: String) -> Dictionary:
	for d in ISLANDS:
		if d["id"] == id:
			return d
	return {}


func research_cost(rid: String) -> float:
	return RESEARCH[rid]["cost"] * RESEARCH_COST_SCALE


func date_text(days: float) -> String:
	var total := int(days) + START_DAY_OF_YEAR
	var year := START_YEAR + total / 365
	var doy := total % 365
	var m := 0
	while doy >= MONTH_DAYS[m]:
		doy -= MONTH_DAYS[m]
		m += 1
	return "%d %s %d" % [doy + 1, MONTHS[m], year]


func year_of(days: float) -> int:
	return START_YEAR + (int(days) + START_DAY_OF_YEAR) / 365


func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for r in cost:
		parts.append("%d %s" % [int(ceilf(cost[r])), RESOURCE_NAMES.get(r, r)])
	return ", ".join(parts) if parts.size() > 0 else "Free"
