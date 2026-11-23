extends Node
## Statisk speldata för Ö-kolonin: nationer, karta, resurser, byggnader,
## forskning, skepp och endgame-kriser. Inget här ändras under spelets gång.

const WORLD_SIZE := Vector2(7200, 4800)
const SEA_NAME := "Smaragdhavet"

# ---------------------------------------------------------------- Resurser
const RESOURCES := ["guld", "tra", "mat", "sten", "sand", "kristaller", "socker", "rom", "kryddor", "parlor"]
const RESOURCE_NAMES := {
	"guld": "Guld", "tra": "Trä", "mat": "Mat", "sten": "Sten", "sand": "Sand",
	"kristaller": "Kristaller", "socker": "Socker", "rom": "Rom", "kryddor": "Kryddor",
	"parlor": "Pärlor", "forskning": "Forskning",
}
const RESOURCE_COLORS := {
	"guld": Color(1.0, 0.82, 0.25), "tra": Color(0.62, 0.42, 0.24), "mat": Color(0.55, 0.85, 0.35),
	"sten": Color(0.66, 0.68, 0.72), "sand": Color(0.98, 0.88, 0.6), "kristaller": Color(0.55, 0.9, 1.0),
	"socker": Color(0.96, 0.96, 0.92), "rom": Color(0.78, 0.42, 0.18), "kryddor": Color(0.9, 0.36, 0.2),
	"parlor": Color(0.95, 0.9, 1.0), "forskning": Color(0.72, 0.6, 1.0),
}
## Lyxvaror som marknader säljer automatiskt (pris i guld per enhet).
const LUXURY_PRICES := {"rom": 3.0, "kryddor": 5.0, "parlor": 9.0}
const LUXURY_RESERVE := 40.0

# ---------------------------------------------------------------- Nationer
const NATIONS := {
	"valdoria": {
		"name": "Valdoriska Kronan", "short": "Valdoria", "type": "Kolonialmakt",
		"color": Color(0.17, 0.3, 0.62), "accent": Color(0.93, 0.78, 0.3),
		"leader": "Guvernör Isabela de Valdor", "home": "kronholmen", "emblem": "krona",
		"lore": "För tvåhundra år sedan seglade Valdorias första galeoner in i Smaragdhavet på jakt efter guld och kryddor. Nu har kronan skickat guvernör Isabela de Valdor med ett tydligt uppdrag: gör öarna till kronans juvel innan rivalerna hinner före.\n\nValdoria har havets tyngsta skepp och mest disciplinerade sjömän, men varje spik och varje planka måste godkännas av byråkrater långt hemifrån. Från fästningen på Kronholmen blickar guvernören ut över ett hav hon tänker äga.",
		"strengths": ["+20 % skrovstyrka på alla skepp", "Kanonbatterier skjuter 25 % hårdare", "Startar med en fregatt och kan bygga briggar direkt"],
		"weaknesses": ["Byggnader kostar 20 % mer", "Forskning går 10 % långsammare"],
		"difficulty": 1,
		"mods": {"ship_hp": 1.2, "fort": 1.25, "build_cost": 1.2, "research": 0.9},
		"start_ships": ["fregatt", "slup"],
		"start_research": ["skonare", "brigg"],
		"start_relations": {"svartarevet": -40, "kaluma": -20, "solmar": 10},
	},
	"svartarevet": {
		"name": "Brödraskapet av Svarta Revet", "short": "Svarta Revet", "type": "Pirater",
		"color": Color(0.16, 0.14, 0.16), "accent": Color(0.85, 0.18, 0.18),
		"leader": "Kapten Mara \"Rödskägg\" Kell", "home": "svartarevet", "emblem": "dodskalle",
		"lore": "Svarta Revet finns inte på några kartor – ett rev av svart vulkansten där vraken från hundra skeppsbrott bleks i solen. Hit kommer rymlingar, myterister och alla som vägrar böja knä för en krona.\n\nKapten Mara Kell enade de stridande besättningarna med en enda lag: allt byte delas lika, och den som sviker går på plankan. Brödraskapets skepp är lätta och snabba, och de lever på det de tar från andra.",
		"strengths": ["+15 % fart på alla skepp", "Skepp kostar 15 % mindre", "Plundring: sänkta fiendeskepp ger guld"],
		"weaknesses": ["Alla nationer misstror dig från start", "Byggnader producerar 15 % mindre"],
		"difficulty": 2,
		"mods": {"ship_speed": 1.15, "ship_cost": 0.85, "plunder": 1.0, "prod_all": 0.85},
		"start_ships": ["skonare", "slup", "slup"],
		"start_research": ["skonare", "battre_segel"],
		"start_relations": {"valdoria": -40, "kaluma": -10, "solmar": -30},
	},
	"kaluma": {
		"name": "Kalumafolket", "short": "Kaluma", "type": "Ursprungsfolk",
		"color": Color(0.16, 0.55, 0.36), "accent": Color(0.98, 0.6, 0.2),
		"leader": "Ixara, Vulkanens röst", "home": "kaluma", "emblem": "vulkan",
		"lore": "Långt innan de första seglen syntes vid horisonten levde Kalumafolket på öarna. De läser havsströmmarna som andra läser böcker, och deras kanoter hittar vägar genom reven där tunga skepp går på grund.\n\nElden i berget Kaluma ger dem kraft, säger de äldste. När främlingar nu kommer med kanoner och flaggor har Ixara, Vulkanens röst, kallat samman alla klaner. Öarna är deras hem – och varje strand ska försvaras.",
		"strengths": ["+25 % produktion av mat och trä", "Öarnas försvar (garnison) +50 %", "Ser 30 % längre genom dimman"],
		"weaknesses": ["Startar med enklare skeppsteknik", "Skepp har 10 % lägre skrovstyrka"],
		"difficulty": 1,
		"mods": {"prod_mat": 1.25, "prod_tra": 1.25, "garrison": 1.5, "vision": 1.3, "ship_hp": 0.9},
		"start_ships": ["slup", "slup"],
		"start_research": ["fiske", "jordbruk"],
		"start_relations": {"valdoria": -20, "svartarevet": -10, "solmar": 0},
	},
	"solmar": {
		"name": "Republiken Solmar", "short": "Solmar", "type": "Handelsrepublik",
		"color": Color(0.88, 0.5, 0.15), "accent": Color(0.98, 0.95, 0.85),
		"leader": "Rådsherre Cassia Moravel", "home": "portosolmar", "emblem": "sol",
		"lore": "Republiken Solmar styrs inte av kungar utan av ett råd av köpmän, och i Solmar kan allt köpas – även fred. När ryktet om kristallerna i Smaragdhavet nådde rådet tog det bara en vecka innan de första handelsfartygen lade ut.\n\nRådsherre Cassia Moravel leder kolonin med en räknesticka i ena handen och ett kontrakt i den andra. Republiken föredrar avtal framför kanoner, men den som bryter ett avtal med Solmar får betala – med ränta.",
		"strengths": ["+30 % inkomst från handel och marknader", "Alla börjar med bättre relation till dig", "Startar med 300 extra guld"],
		"weaknesses": ["Skepp har 10 % lägre skrovstyrka", "Landstigningstrupper är 20 % svagare"],
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
	"vildpirater": {"name": "Fria pirater", "short": "Pirater", "color": Color(0.3, 0.27, 0.25), "accent": Color(0.9, 0.9, 0.85)},
	"spokflottan": {"name": "Spökflottan", "short": "Spökflottan", "color": Color(0.35, 0.95, 0.7), "accent": Color(0.75, 1.0, 0.9)},
	"armadan": {"name": "Den Gyllene Armadan", "short": "Armadan", "color": Color(0.85, 0.68, 0.18), "accent": Color(0.55, 0.08, 0.1)},
	"djupkulten": {"name": "Djupets Kult", "short": "Djupkulten", "color": Color(0.42, 0.2, 0.55), "accent": Color(0.3, 0.9, 0.8)},
	"vaktarna": {"name": "De Sovande Väktarna", "short": "Väktarna", "color": Color(0.45, 0.75, 0.95), "accent": Color(1.0, 0.95, 0.7)},
}

# ---------------------------------------------------------------- Kriser
## Endgame-kriser (Stellaris-stil). Flera kan vara igång samtidigt.
## "from_start": fraktionen finns på kartan från början och vaknar senare.
const CRISES := {
	"spokflottan": {
		"name": "Spökflottan",
		"desc": "Skeppen som sjönk i Smaragdhavet vilar inte. När dimman tätnar stiger en flotta av döda besättningar ur djupet och anfaller alla som lever.",
		"from_start": false,
		"pilot": true,
	},
	"armadan": {
		"name": "Den Gyllene Armadan",
		"desc": "Ett enormt imperium bortom horisonten har fått syn på öarnas rikedomar. Linjeskepp i hundratal seglar in från havet för att erövra allt.",
		"from_start": false,
		"pilot": false,
	},
	"djupkulten": {
		"name": "Djupets Kult",
		"desc": "En hemlig sekt dyrkar det som sover under reven. När kulten får nog med offer väcker de Krakenen – ett odjur som drar ned hela skepp i djupet.",
		"from_start": false,
		"pilot": false,
	},
	"vaktarna": {
		"name": "De Sovande Väktarna",
		"desc": "På Solstensön lever resterna av en uråldrig civilisation med kristallskepp. De vill vara ifred – den som kommer för nära eller väntar för länge väcker deras vrede.",
		"from_start": true,
		"pilot": true,
	},
}

# ---------------------------------------------------------------- Karta
## Handgjord karta. r = ungefärlig radie i pixlar.
const ISLANDS := [
	{"id": "kronholmen", "name": "Kronholmen", "pos": Vector2(1050, 950), "r": 330, "deposits": ["tra", "mat", "sten"], "home": "valdoria"},
	{"id": "svartarevet", "name": "Svarta Revet", "pos": Vector2(6150, 900), "r": 300, "deposits": ["tra", "mat", "sten"], "home": "svartarevet", "dark": true},
	{"id": "kaluma", "name": "Kaluma", "pos": Vector2(1150, 3850), "r": 370, "deposits": ["tra", "mat", "kryddor"], "home": "kaluma", "volcano": true},
	{"id": "portosolmar", "name": "Porto Solmar", "pos": Vector2(6050, 3850), "r": 320, "deposits": ["tra", "mat", "sand"], "home": "solmar"},
	{"id": "kokoson", "name": "Kokosön", "pos": Vector2(2200, 1500), "r": 200, "deposits": ["tra", "mat"]},
	{"id": "sandbanken", "name": "Sandbanken", "pos": Vector2(2950, 650), "r": 170, "deposits": ["sand", "parlor"]},
	{"id": "fyrskaret", "name": "Fyrskäret", "pos": Vector2(3800, 1150), "r": 150, "deposits": ["sten", "parlor"]},
	{"id": "stenkummel", "name": "Stenkummel", "pos": Vector2(4800, 1500), "r": 210, "deposits": ["sten", "tra"]},
	{"id": "skoldpaddson", "name": "Sköldpaddsön", "pos": Vector2(5100, 550), "r": 170, "deposits": ["mat", "socker"]},
	{"id": "mangroveholmen", "name": "Mangroveholmen", "pos": Vector2(1500, 2350), "r": 210, "deposits": ["tra", "kryddor"]},
	{"id": "smaragdon", "name": "Smaragdön", "pos": Vector2(2700, 2150), "r": 190, "deposits": ["kristaller", "tra"]},
	{"id": "kristallrevet", "name": "Kristallrevet", "pos": Vector2(3650, 2450), "r": 250, "deposits": ["kristaller", "sand", "parlor"]},
	{"id": "papegojon", "name": "Papegojön", "pos": Vector2(2350, 3150), "r": 220, "deposits": ["tra", "socker", "kryddor"]},
	{"id": "solnedgangson", "name": "Solnedgångsön", "pos": Vector2(3000, 4100), "r": 180, "deposits": ["mat", "socker"]},
	{"id": "dodmanskistan", "name": "Dödmanskistan", "pos": Vector2(4250, 3600), "r": 190, "deposits": ["guld", "sten"]},
	{"id": "parlbukten", "name": "Pärlbukten", "pos": Vector2(5150, 2750), "r": 210, "deposits": ["parlor", "sand", "mat"]},
	{"id": "spokskaret", "name": "Spökskäret", "pos": Vector2(6150, 2150), "r": 150, "deposits": ["kristaller", "sten"]},
	{"id": "hajtanden", "name": "Hajtanden", "pos": Vector2(4950, 4300), "r": 150, "deposits": ["sten", "guld"]},
	{"id": "solstenson", "name": "Solstensön", "pos": Vector2(4450, 2500), "r": 200, "deposits": ["kristaller", "guld"], "guardians": true},
]

# ---------------------------------------------------------------- Byggnader
## prod = per sekund. consumes = förbrukas per sekund (krävs för produktion).
## deposit = kräver att ön har den resursen. research = kräver forskningen.
const BUILDINGS := {
	"radhus": {"name": "Guvernörshus", "desc": "Öns hjärta. Ger guld och lite forskning.", "cost": {}, "prod": {"guld": 1.5, "forskning": 0.4}, "buildable": false, "garrison": 30, "fort": {"range": 360.0, "damage": 6.0, "reload": 3.6}, "time": 1.0},
	"bosattning": {"name": "Bosättning", "desc": "Hem åt nybyggare. Skatten ger guld.", "cost": {"tra": 30}, "prod": {"guld": 0.8}, "time": 6.0},
	"skogshuggare": {"name": "Skogshuggare", "desc": "Fäller palmer och hårdträ.", "cost": {"guld": 20}, "prod": {"tra": 1.2}, "deposit": "tra", "time": 6.0},
	"kokosodling": {"name": "Kokosodling", "desc": "Kokosnötter och frukt till befolkningen.", "cost": {"tra": 25}, "prod": {"mat": 1.2}, "deposit": "mat", "time": 6.0},
	"fiskehydda": {"name": "Fiskehydda", "desc": "Fiskare vid stranden. Fungerar på alla öar.", "cost": {"tra": 20, "guld": 10}, "prod": {"mat": 0.9}, "research": "fiske", "coastal": true, "time": 6.0},
	"stenbrott": {"name": "Stenbrott", "desc": "Bryter sten ur klipporna.", "cost": {"tra": 40, "guld": 30}, "prod": {"sten": 0.8}, "deposit": "sten", "research": "stenbrott", "time": 9.0},
	"sandtakt": {"name": "Sandtäkt", "desc": "Gräver upp vit korallsand.", "cost": {"tra": 30}, "prod": {"sand": 1.0}, "deposit": "sand", "time": 6.0},
	"sockerplantage": {"name": "Sockerplantage", "desc": "Odlar sockerrör.", "cost": {"tra": 35, "guld": 20}, "prod": {"socker": 0.9}, "deposit": "socker", "research": "sockerodling", "time": 8.0},
	"romdestilleri": {"name": "Romdestilleri", "desc": "Bränner socker till rom. Rom höjer moralen på dina skepp och säljs dyrt.", "cost": {"tra": 60, "sten": 30}, "prod": {"rom": 0.5}, "consumes": {"socker": 1.0}, "research": "romdestilleri", "time": 10.0},
	"kryddgard": {"name": "Kryddgård", "desc": "Odlar muskot, vanilj och kanel.", "cost": {"tra": 40, "guld": 40}, "prod": {"kryddor": 0.4}, "deposit": "kryddor", "research": "kryddhandel", "time": 9.0},
	"parldykare": {"name": "Pärldykare", "desc": "Dykare som hämtar pärlor från reven.", "cost": {"tra": 40, "guld": 50}, "prod": {"parlor": 0.25}, "deposit": "parlor", "research": "parldykning", "coastal": true, "time": 9.0},
	"kristallgruva": {"name": "Kristallgruva", "desc": "Bryter de lysande kristallerna.", "cost": {"tra": 80, "sten": 60}, "prod": {"kristaller": 0.3}, "deposit": "kristaller", "research": "kristallgruva", "time": 14.0},
	"guldgruva": {"name": "Guldgruva", "desc": "Gräver guld ur berget.", "cost": {"tra": 70, "sten": 50}, "prod": {"guld": 2.5}, "deposit": "guld", "research": "guldgruva", "time": 12.0},
	"marknad": {"name": "Marknad", "desc": "Ger guld och säljer automatiskt rom, kryddor och pärlor (över en reserv på 40).", "cost": {"tra": 60, "sten": 20}, "prod": {"guld": 1.5}, "research": "marknad", "market": true, "time": 10.0},
	"akademi": {"name": "Akademi", "desc": "Lärda män och kvinnor forskar fram nya idéer.", "cost": {"tra": 60, "sten": 30, "sand": 20}, "prod": {"forskning": 1.2}, "time": 12.0},
	"skeppsvarv": {"name": "Skeppsvarv", "desc": "Bygger skepp. Krävs för att utöka flottan.", "cost": {"tra": 80, "guld": 50}, "prod": {}, "shipyard": true, "coastal": true, "time": 12.0},
	"kanonbatteri": {"name": "Kanonbatteri", "desc": "Skjuter på fientliga skepp nära ön och stärker garnisonen.", "cost": {"sten": 60, "guld": 40}, "prod": {}, "fort": {"range": 420.0, "damage": 12.0, "reload": 3.2}, "garrison": 15, "research": "kanonbatteri", "coastal": true, "time": 12.0},
	"fyrtorn": {"name": "Fyrtorn", "desc": "Skingrar dimman långt ut över havet.", "cost": {"sten": 40, "sand": 40}, "prod": {}, "vision": 1100.0, "research": "fyrtorn", "coastal": true, "time": 10.0},
	"glasbruk": {"name": "Glasbruk", "desc": "Smälter sand till glas som säljs för guld.", "cost": {"tra": 50, "sten": 30}, "prod": {"guld": 2.2}, "consumes": {"sand": 0.8}, "research": "glasbruk", "time": 10.0},
}
const BUILD_ORDER := ["bosattning", "skogshuggare", "kokosodling", "fiskehydda", "sandtakt", "stenbrott", "sockerplantage", "romdestilleri", "kryddgard", "parldykare", "kristallgruva", "guldgruva", "marknad", "glasbruk", "akademi", "skeppsvarv", "kanonbatteri", "fyrtorn"]
const COST_GROWTH := 1.15

# ---------------------------------------------------------------- Skepp
const SHIPS := {
	"handelsfartyg": {"name": "Handelsfartyg", "desc": "Obeväpnat. Kör handelsrutter mellan dina öar.", "hp": 110, "speed": 120.0, "cannons": 0, "range": 0.0, "reload": 99.0, "damage": 0.0, "troops": 5, "cost": {"tra": 50, "guld": 30}, "time": 10.0, "size": 1.1, "masts": 1, "trade": true},
	"slup": {"name": "Slup", "desc": "Liten och kvick. Bra för spaning och kolonisering.", "hp": 100, "speed": 140.0, "cannons": 2, "range": 260.0, "reload": 2.6, "damage": 7.0, "troops": 10, "cost": {"tra": 60, "guld": 40}, "time": 12.0, "size": 1.0, "masts": 1},
	"skonare": {"name": "Skonare", "desc": "Snabb tvåmastare med fler kanoner.", "hp": 150, "speed": 150.0, "cannons": 3, "range": 270.0, "reload": 2.4, "damage": 7.0, "troops": 15, "cost": {"tra": 90, "guld": 60}, "time": 15.0, "size": 1.15, "masts": 2},
	"brigg": {"name": "Brigg", "desc": "Robust krigsskepp, flottans arbetshäst.", "hp": 240, "speed": 125.0, "cannons": 5, "range": 290.0, "reload": 2.6, "damage": 8.0, "troops": 20, "cost": {"tra": 140, "guld": 100, "sten": 20}, "time": 20.0, "size": 1.35, "masts": 2},
	"galeon": {"name": "Galeon", "desc": "Tungt transportskepp. Bär många soldater för landstigning.", "hp": 320, "speed": 95.0, "cannons": 4, "range": 280.0, "reload": 3.0, "damage": 8.0, "troops": 60, "cost": {"tra": 180, "guld": 120}, "time": 24.0, "size": 1.6, "masts": 3},
	"fregatt": {"name": "Fregatt", "desc": "Snabbt och tungt beväpnat. Havets jägare.", "hp": 380, "speed": 120.0, "cannons": 8, "range": 320.0, "reload": 2.6, "damage": 9.0, "troops": 25, "cost": {"tra": 220, "guld": 180, "sten": 40}, "time": 28.0, "size": 1.6, "masts": 3},
	"linjeskepp": {"name": "Linjeskepp", "desc": "Flytande fästning med tre kanondäck.", "hp": 720, "speed": 88.0, "cannons": 14, "range": 340.0, "reload": 3.0, "damage": 10.0, "troops": 40, "cost": {"tra": 400, "guld": 320, "sten": 120, "kristaller": 20}, "time": 40.0, "size": 2.0, "masts": 3},
	# Specialskepp för kriser
	"spokskepp": {"name": "Spökskepp", "desc": "En död besättning seglar mot vinden.", "hp": 300, "speed": 115.0, "cannons": 7, "range": 300.0, "reload": 2.6, "damage": 9.0, "troops": 30, "cost": {}, "time": 0.0, "size": 1.55, "masts": 3, "ghost": true},
	"armadaskepp": {"name": "Armadans linjeskepp", "desc": "Guldglänsande krigsskepp från fjärran.", "hp": 650, "speed": 85.0, "cannons": 12, "range": 330.0, "reload": 3.0, "damage": 10.0, "troops": 50, "cost": {}, "time": 0.0, "size": 1.95, "masts": 3},
	"kristallskepp": {"name": "Kristallskepp", "desc": "Väktarnas uråldriga skepp som glöder i mörkret.", "hp": 520, "speed": 130.0, "cannons": 8, "range": 360.0, "reload": 2.2, "damage": 12.0, "troops": 30, "cost": {}, "time": 0.0, "size": 1.7, "masts": 2, "crystal": true},
	"kultskepp": {"name": "Kultens svarta brigg", "desc": "Djupkultens skepp med offerelden tänd.", "hp": 220, "speed": 130.0, "cannons": 5, "range": 280.0, "reload": 2.6, "damage": 8.0, "troops": 20, "cost": {}, "time": 0.0, "size": 1.35, "masts": 2},
	"kraken": {"name": "Krakenen", "desc": "Ett odjur från djupet.", "hp": 2200, "speed": 75.0, "cannons": 0, "range": 120.0, "reload": 1.6, "damage": 35.0, "troops": 0, "cost": {}, "time": 0.0, "size": 2.4, "masts": 0, "monster": true},
}
const SHIP_ORDER := ["handelsfartyg", "slup", "skonare", "brigg", "galeon", "fregatt", "linjeskepp"]
const SHIP_RESEARCH := {"skonare": "skonare", "brigg": "brigg", "galeon": "galeon", "fregatt": "fregatt", "linjeskepp": "linjeskepp"}

# ---------------------------------------------------------------- Forskning
## tree: byggnader / perks / skepp. effect: modifierare som multipliceras in.
const RESEARCH := {
	# Byggnader
	"fiske": {"tree": "byggnader", "name": "Fiskenät", "cost": 25, "req": [], "desc": "Låser upp Fiskehydda."},
	"stenbrott": {"tree": "byggnader", "name": "Stenhuggning", "cost": 35, "req": [], "desc": "Låser upp Stenbrott."},
	"sockerodling": {"tree": "byggnader", "name": "Sockerrör", "cost": 40, "req": [], "desc": "Låser upp Sockerplantage."},
	"marknad": {"tree": "byggnader", "name": "Handelstorg", "cost": 55, "req": ["fiske"], "desc": "Låser upp Marknad."},
	"romdestilleri": {"tree": "byggnader", "name": "Romkokning", "cost": 70, "req": ["sockerodling"], "desc": "Låser upp Romdestilleri."},
	"kanonbatteri": {"tree": "byggnader", "name": "Kustartilleri", "cost": 70, "req": ["stenbrott"], "desc": "Låser upp Kanonbatteri."},
	"glasbruk": {"tree": "byggnader", "name": "Glasblåsning", "cost": 80, "req": ["stenbrott"], "desc": "Låser upp Glasbruk."},
	"kryddhandel": {"tree": "byggnader", "name": "Kryddodling", "cost": 90, "req": ["marknad"], "desc": "Låser upp Kryddgård."},
	"parldykning": {"tree": "byggnader", "name": "Pärldykning", "cost": 90, "req": ["fiske"], "desc": "Låser upp Pärldykare."},
	"fyrtorn": {"tree": "byggnader", "name": "Fyrtorn", "cost": 100, "req": ["glasbruk"], "desc": "Låser upp Fyrtorn."},
	"guldgruva": {"tree": "byggnader", "name": "Gruvdrift", "cost": 120, "req": ["stenbrott"], "desc": "Låser upp Guldgruva."},
	"kristallgruva": {"tree": "byggnader", "name": "Kristallslipning", "cost": 150, "req": ["guldgruva"], "desc": "Låser upp Kristallgruva."},
	# Perks
	"jordbruk": {"tree": "perks", "name": "Bevattning", "cost": 45, "req": [], "desc": "+20 % mat.", "effect": {"prod_mat": 1.2}},
	"handelsvana": {"tree": "perks", "name": "Handelsvana", "cost": 60, "req": [], "desc": "+20 % guld.", "effect": {"prod_guld": 1.2}},
	"battre_segel": {"tree": "perks", "name": "Bättre segel", "cost": 60, "req": [], "desc": "+10 % fart för skepp.", "effect": {"ship_speed": 1.1}},
	"timmerhantering": {"tree": "perks", "name": "Timmerhantering", "cost": 60, "req": ["jordbruk"], "desc": "+20 % trä.", "effect": {"prod_tra": 1.2}},
	"snabbladdning": {"tree": "perks", "name": "Snabbladdning", "cost": 90, "req": ["battre_segel"], "desc": "Kanonerna laddar 20 % snabbare.", "effect": {"reload": 0.8}},
	"navigatorer": {"tree": "perks", "name": "Navigatörer", "cost": 80, "req": ["battre_segel"], "desc": "Ser 30 % längre genom dimman.", "effect": {"vision": 1.3}},
	"diplomater": {"tree": "perks", "name": "Diplomatkåren", "cost": 70, "req": ["handelsvana"], "desc": "Relationer förbättras snabbare, handelsavtal ger mer.", "effect": {"relations": 1.0, "trade": 1.15}},
	"kopparskrov": {"tree": "perks", "name": "Kopparklädda skrov", "cost": 120, "req": ["snabbladdning"], "desc": "+15 % skrovstyrka.", "effect": {"ship_hp": 1.15}},
	"befastningar": {"tree": "perks", "name": "Befästningar", "cost": 120, "req": ["kanonbatteri"], "desc": "Garnison +50 %, kanonbatterier +25 % skada.", "effect": {"garrison": 1.5, "fort": 1.25}},
	"marinsoldater": {"tree": "perks", "name": "Marinsoldater", "cost": 110, "req": ["kopparskrov"], "desc": "Landstigningstrupper +40 %.", "effect": {"troops": 1.4}},
	"industri": {"tree": "perks", "name": "Manufaktur", "cost": 160, "req": ["timmerhantering", "handelsvana"], "desc": "+15 % produktion av allt.", "effect": {"prod_all": 1.15}},
	"kristallkanoner": {"tree": "perks", "name": "Kristallkanoner", "cost": 260, "req": ["kristallgruva", "kopparskrov"], "desc": "Kanonerna gör 30 % mer skada.", "effect": {"cannon_dmg": 1.3}},
	# Skeppsmodeller
	"skonare": {"tree": "skepp", "name": "Skonare", "cost": 45, "req": [], "desc": "Låser upp Skonare."},
	"brigg": {"tree": "skepp", "name": "Brigg", "cost": 90, "req": ["skonare"], "desc": "Låser upp Brigg."},
	"galeon": {"tree": "skepp", "name": "Galeon", "cost": 110, "req": ["brigg"], "desc": "Låser upp Galeon (transport)."},
	"fregatt": {"tree": "skepp", "name": "Fregatt", "cost": 160, "req": ["brigg"], "desc": "Låser upp Fregatt."},
	"linjeskepp": {"tree": "skepp", "name": "Linjeskepp", "cost": 300, "req": ["fregatt", "kristallgruva"], "desc": "Låser upp Linjeskepp."},
}
const RESEARCH_TREES := {"byggnader": "Byggnader", "perks": "Perks", "skepp": "Skeppsmodeller"}

# ---------------------------------------------------------------- Inställningar
## Tiden går dag för dag i realtid. En dag = DAY_SECONDS sekunder i normal fart.
## Hastigheter: paus, 1x, 2x, 4x, 8x. En genomspelning i betan: upp till ~8 timmar.
const DAY_SECONDS := 1.0
const START_YEAR := 1680
const START_DAY_OF_YEAR := 59  # 1 mars
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
const MONTHS := ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
## Forskningens kostnader. Piloten: snabb takt. Betan (~8 h): höjs till ca 4.
const RESEARCH_COST_SCALE := 1.5

const AI_TEMPO := {
	"fredlig": {"name": "Fredlig start", "desc": "AI-nationerna förklarar inte krig de första ~2,5 åren (900 dagar).", "grace": 900.0, "aggro": 0.7},
	"normal": {"name": "Normal", "desc": "AI-nationerna kan börja krig efter ungefär ett år.", "grace": 365.0, "aggro": 1.0},
	"aggressiv": {"name": "Aggressiv", "desc": "AI-nationerna kan anfalla redan efter några veckor.", "grace": 30.0, "aggro": 1.4},
}
## När endgame-kriserna börjar (i speldagar). Pilotens takt – förlängs i betan.
const CRISIS_TIMING := {
	"tidig": {"name": "Tidigt (år 1682)", "time": 2.0 * 365.0},
	"normal": {"name": "Normalt (år 1684)", "time": 4.0 * 365.0},
	"sen": {"name": "Sent (år 1687)", "time": 7.0 * 365.0},
}


func nation_name(id: String) -> String:
	if NATIONS.has(id):
		return NATIONS[id]["name"]
	if HOSTILE_FACTIONS.has(id):
		return HOSTILE_FACTIONS[id]["name"]
	return "Ingen"


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
		parts.append("%d %s" % [int(ceil(cost[r])), RESOURCE_NAMES.get(r, r)])
	return ", ".join(parts) if parts.size() > 0 else "Gratis"
