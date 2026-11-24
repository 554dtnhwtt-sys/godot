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

## Provinser i Total War-stil (version 0.6, ersätter stadsplanen i 0.5)
| Område | Hur det fungerar |
|---|---|
| Ön = provins | En stadsmodell i mitten (en bild per nivå) med rök, skylt, flagga, nivåstjärnor och garnison. Inga separata hus eller stadsbyggnader på kartan |
| Stadsnivåer | Outpost (palissadläger) → Village (palmby) → Town (kolonialstad med kyrka) → City (befäst stad) → Capital (huvudstad med citadell). Väktarnas ö är en uråldrig tempelstad |
| Stadsbyggnader | Skeppsvarv, marknad, akademi, lagerhus, batterier, destilleri, glasbruk och fyr finns "i staden" och byggs via stadspanelen (Build-fliken), som byggnadskedjor i Total War |
| Resursplatser | Små miniatyrer runt ön (som Total Wars mindre bosättningar): skogsläger, palmplantage, fiskeläge, stenbrott, sandtag, sockerplantage med väderkvarn, kryddgård, pärldykare, kristallgruva, guldgruva. Klicka för att bygga och uppgradera |
| Mindre detaljer | Inga gående invånare, inga hus, få palmer, diskreta vägar mellan staden och resursplatserna |

## Övergångar mellan modeller och ö (version 0.7)
- Alla stads- och resursmodeller är rena byggnader utan egen mark, vatten eller kust.
- Spelet ritar en mjuk markyta under varje stad och resursplats: oregelbunden kant som tonar ut i gräset.
  Stadens yta växer med nivån och blir stenlagd från nivå Town.
- Hamnen (hamnmagasin) placeras vid den riktiga kusten med en brygga ut i vattnet, och en väg till staden.
  Fiskelägen och pärldykare får egna bryggor. Båtar guppar vid bryggorna.
- När staden växer tonas den gamla modellen över i den nya, med byggställning och damm under uppgraderingen.

## 3D-skepp och 3D-byggnader (version 0.8)
| Område | Hur det fungerar |
|---|---|
| Teknik | Havet, öarna och dimman är kvar som målad 2D. Skepp, städer, resursbyggnader, palmer och vulkaner är 3D-modeller som byggs i kod och renderas i ett eget 3D-lager med genomskinlig bakgrund. 3D-kameran tittar snett ned i exakt samma vinkel som 2D-världen (cirka 46°), så modellerna står precis där de ska |
| Ljus | En sol snett framifrån från vänster med riktiga skuggor. Skuggorna faller på havet och öarna via en osynlig skuggyta |
| Skepp | Skrov med färgade band i nationsfärgen, däck, reling, kanonportar med kanoner (en rad per kanondäck), akter- och förkastell med fönster, bogspröt, master med mastkorgar och rår. Råsegel eller gaffelsegel efter skeppstyp, klyvare och en flagga som vajar med vinden |
| Rörelse | Seglen buktar mer ju fortare skeppet går, gaffelsegel byter sida efter vinden, skeppet krängar i vinden och gungar mer i storm. Sjunkande skepp lutar och försvinner ned under vattenytan. Mynningsflammor när bredsidan avfyras |
| Specialskepp | Spökskepp lyser grönt, kristallskepp lyser blått, pirater har svarta segel, Armadan gyllene och Djupkulten lila |
| Städer | Husen ligger i kvarter med gator och växer fram ett i taget medan staden uppgraderas. Nivå 1: palissad, tält, eldstad och utkikstorn. Nivå 2: timmerhus med halmtak och kapell. Nivå 3: vita hus med tegeltak, kyrka och brunn. Nivå 4: katedral, högre hus, stadsmur med bastioner. Nivå 5: palats med kupol och pelargång, stjärnfort. Väktarnas ö: trappstegspyramider med glödande kristaller |
| Anpassning | Hus och murar hamnar aldrig i havet, på vulkanen, på varvet eller på resursplatserna |
| Resursplatser | Egna 3D-modeller för alla tio (skog med stuga och timmerstaplar, palmodling, fiskeläge på pålar med torkställningar, stenbrott med kran, sandtag med såll, sockerplantage med väderkvarn, kryddgård, pärldykare, kristallgruva, guldgruva med lyftverk) och för varvet (slip med ett skepp under byggnad och kran). Nivå 2 och 3 ger fler hus, träd och förråd |
| Animationer | Väderkvarnens vingar snurrar, kranar svänger, guldgruvans hjul snurrar, kristaller pulserar, fiskebåtar seglar ut och tillbaka, palmer vajar i vinden, rök från skorstenar och vulkanen. Byggnader reser sig ur marken medan de byggs och studsar när de är klara |
| Mätare | HP-mätare, trupper, erfarenhet, amiralsstjärna och brand ritas ovanför 3D-lagret |
