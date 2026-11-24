# Ö-kolonin – speldesign (så långt vi kommit)

## Grundidé
Byggspel/idle i Karibien. Du startar på en ö, bygger en bas, utforskar dimman runt ön
och hittar nya öar med egna resurser (sand, kokos, kristaller m.m.). Du bygger
segelskepp och handelsrutter mellan öarna och strider mot andra ö-nationer.

## Beslutat
| Område | Beslut |
|---|---|
| Motor | Godot (version 4.7.2 finns på datorn) |
| Grafik | 2D, fast kamera snett uppifrån (så detaljer syns) |
| Stämning | Karibisk: turkost vatten, vita stränder, palmer |
| Skepp | Segelskepp |
| Strid | Strategikommandon: markera skepp, ge order. Skeppen manövrerar och skjuter bredsidor själva |
| Fiender | Andra ö-nationer (AI) som bygger egna skepp och anfaller |
| Forskning | 1) byggnader, 2) perks, 3) skeppsmodeller |
| Händelser | Stormar, pirater, handelsman med sällsynta varor |
| Mål | Inget slut, sandlåda. Valfria "endgame disasters" för den som vill |
| Karta | Handgjord karta (till att börja med) |
| Nationsval | Välj nation i början, Total War-känsla i valskärmen |
| Nationer | Egen startpunkt, egna styrkor/svagheter och egen lore |

## Öppna frågor (ställs löpande)
- Hur många nationer, och vilka teman (t.ex. pirater, kolonialmakt, ursprungsfolk, handelsrepublik)?
- Vilka resurser och vilka byggnader i början?
- Hur fungerar vind för segelskeppen (påverkar fart eller bara utseende)?
- Kan man erövra/inta andras öar, eller bara sänka skepp?
- Diplomati (handel/fred/allianser) med AI-nationerna?
- Vilka endgame disasters (t.ex. vulkanutbrott, orkansäsong, spökflotta, kraken)?
- Sparning: autospar och flera sparplatser?
- Ljud/musik: karibisk stämning?

## Mina tidigare förslag (för referens)
Genrer jag föreslog först: rymdskjutspel, roguelike-arena, plattformsspel, tornförsvar,
fysikpussel, kortspel-roguelike, byggspel/idle, fiskespel, lokal 2-spelare.

Byggspel/idle-idéer: Pixelbyn, Kugghjulsfabriken, **Ö-kolonin (vald)**, Bergets dvärgar, Kosmisk gård.

## Beslut i molnsessionen
| Område | Beslut |
|---|---|
| Nationer | Valdoriska Kronan (kolonialmakt), Brödraskapet av Svarta Revet (pirater), Kalumafolket (ursprungsfolk), Republiken Solmar (handelsrepublik) |
| Vind | Påverkar farten: medvind full fart, motvind ungefär halverad |
| Erövring | Skjut sönder kanonbatterierna, sedan landstiger soldaterna |
| Diplomati | Krig, fred, handelsavtal, allians, bryt avtal, gåvor, lyxgåvor, tribut, gemensamma krig. AI föreslår också |
| Kriser | Spökflottan och De Sovande Väktarna (från start) i piloten. Den Gyllene Armadan och Djupets Kult (Krakenen) i betan |
| Resurser | Guld, trä, mat, sten, sand, kristaller, socker, rom, kryddor, pärlor (+ forskning) |
| Tid | Realtid dag för dag med kalender från 1 mars 1680, paus och 1x/2x/4x/8x |
| Längd | Pilot nu. Betan: upp till ~8 timmar per genomspelning |
| Formationer | Linje, kil, spridd. Flottan seglar i det långsammaste skeppets fart |
| Grafik | Målad stil (AI-genererad i Runway): skepp ovanifrån, byggnader snett uppifrån, palmer, gräs- och sandtexturer, menybild, ledarporträtt |
| Ljud | Väntar. Epidemic Sound kräver betald prenumeration för nedladdning |

## Spelmekanik (version 0.3)
| Område | Hur det fungerar |
|---|---|
| Lager | Varje ö har eget lager (300 per vara, hemön 600, +300 per lagerhus). Guld och forskning är gemensamma för nationen |
| Frakt | Handelsfartyg kör rutter mellan två egna öar. Överskott skickas till hemön, kolonier får byggvaror och mat de behöver. Sänkta fartyg tappar lasten – pirater och kapare tar den |
| Befolkning | Bosättningar (20) och guvernörshus (10) ger bostäder. Invånarna äter mat, betalar skatt och arbetar i byggnaderna. För få arbetare = lägre produktion. Ingen mat = svält och folk flyttar |
| Guvernör | Kan slås på för varje ö. Bygger själv efter vald inriktning: Balans, Råvaror, Handel eller Försvar. Sparar alltid 120 guld |
| Erfarenhet | Skepp får erfarenhet av att skada och sänka fiender: Rekryter, Sjövana, Veteraner, Elit. Bättre omladdning, träffsäkerhet och fart |
| Amiraler | Rekryteras för guld och sätts på ett flaggskepp. 1–2 egenskaper (Djärv, Stormseglare, Kanonmästare, Försiktig, Taktiker, Kapare, Vältalig) som gäller alla egna skepp i närheten. Kan överleva när skeppet sjunker |
| Uppgraderingar | Vid eget skeppsvarv: fler kanoner, kopparklätt skrov, nya segel, större lastrum |

## Språk
Spelet är på engelska (från version 0.4). Titel: **Island Colony**. Dokumenten i `docs/` är på svenska.
Ö-namn på engelska: Crownholm, Black Reef, Kaluma, Porto Solmar, Coconut Isle, The Sandbank, Beacon Skerry,
Stone Cairn, Turtle Isle, Mangrove Holm, Emerald Isle, Crystal Reef, Parrot Isle, Sunset Isle, Dead Man's Chest,
Pearl Bay, Ghost Skerry, Shark's Tooth och Sunstone Isle. Havet heter the Emerald Sea.

## Städer och resursplatser (version 0.5)
| Område | Hur det fungerar |
|---|---|
| Stadsplan | Varje ö har en färdigplanerad stad: rådhus och torg i mitten, hamn mot havet, platser för lagerhus, marknad, akademi, industri, kanonbatterier, fyr och vakttorn, och hus i ringar runt torget |
| Stadsnivåer | Outpost (tältläger) → Village → Town → City → Capital. Varje nivå ger nytt rådhus, fler hus (byggs ett i taget med animation), finare hus, torg med fontän (Town) och vakttorn (City). Mer bostäder, lager och garnison |
| Stadsbyggnader | Placeras automatiskt på sin plats: skeppsvarv i hamnen, fyr på udden, batterier vid kusten. Kräver viss stadsnivå (t.ex. marknad och akademi kräver Village, glasbruk och fyr kräver Town) |
| Resursplatser | Skog, kokospalmer, fiskevatten, sten, sand, sockerrör, kryddor, pärlrev, kristaller och guld syns på ön med en ikon. Klicka för att bygga resursbyggnaden |
| Nivåer på resursbyggnader | Nivå 1–3 (170 % och 250 % produktion, fler arbetare). Nivå 2 kräver Village, nivå 3 kräver Town |
| Ingen egen placering | Spelaren väljer vad som byggs, aldrig var |
| Animationer | Byggnader reser sig ur byggställningar med arbetare och damm och studsar när de är klara. Arbetsanimationer: flisor (skogshuggare), kokosnötter som faller, fiskebåtar som ror ut, damm (stenbrott, sand), sockerrör som vajar, gnistor (kryddor, kristaller, varv), gruvvagn med guld, folk på marknaden, lådor vid lagret, fyrens ljusstråle, rök från skorstenar. Vägar från torget till alla byggnader och invånare som går på dem |
