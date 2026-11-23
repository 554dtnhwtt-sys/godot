# Logg – vad Claude har gjort

## 2026-11-23
1. Kollade projektmappen `C:\Users\kevin\Documents\spel` – den var tom.
2. Letade efter Godot. Hittade `Downloads\Godot_v4.7.2-stable_win64.exe.zip` (ej uppackad).
3. Packade upp den till `C:\Users\kevin\Downloads\Godot_v4.7.2\`:
   - `Godot_v4.7.2-stable_win64.exe` (editorn)
   - `Godot_v4.7.2-stable_win64_console.exe` (samma, med konsolfönster)
4. Ställde fyra frågor om grafik, strid, mål och karta (svaren finns i `01_dina_meddelanden.md`).
5. Skapade den här mappen.

## Inte gjort än
- Ingen spelkod eller Godot-projekt skapat ännu. Nästa steg är att sätta upp projektet,
  efter att nationerna och de första öppna frågorna är bestämda.

## Anslutningar (Asana, Figma, Gmail, Slack m.fl.)
Behövs inte för spelet. Allt görs lokalt i Godot.

## 2026-11-23 (molnsession, fortsättning)
1. Läste zip-filen med dina meddelanden, speldesignen och loggen.
2. Nya svar från dig:
   - 4 nationer, vinden påverkar farten, landstigning (inta öar), full diplomati.
   - Endgame: fler endgame-nationer i Stellaris-stil (flera samtidigt, vissa finns från start) + Spökflottan.
   - Nya resurser: socker & rom, kryddor, pärlor.
   - Ingen offline-produktion. AI-tempo väljs i valskärmen.
   - Realtid dag för dag med kalender (start 1 mars 1680), paus och snabbspolning (1x, 2x, 4x, 8x).
   - Betan ska räcka upp till 8 timmar – men nu bygger vi bara en PILOT.
3. Byggde pilotversion 0.1 av spelet i mappen `o-kolonin/` (Godot 4.7, GL Compatibility).

## Pilot 0.1 – vad som finns
- Huvudmeny och nationsval (Total War-stil) med karta, lore, styrkor/svagheter, AI-tempo och kriser.
- Nationer: Valdoriska Kronan, Brödraskapet av Svarta Revet, Kalumafolket, Republiken Solmar.
- Handgjord karta med 19 öar, karibisk stil (turkost vatten, stränder, palmer, vulkan på Kaluma), dimma.
- 18 byggnader, 10 resurser, forskning i tre grenar (byggnader, perks, skeppsmodeller).
- Segelskepp (slup, skonare, brigg, galeon, fregatt, linjeskepp, handelsfartyg) med vind, bredsidor, landstigning.
- Kolonisering, handelsrutter (kolonier utan rutt producerar 60 %), erövring av öar.
- Full diplomati: krig, fred, handelsavtal, allians, bryt avtal, gåvor, lyxgåvor, tribut, gemensamt krig. AI föreslår också saker.
- Händelser: storm, pirater, handelsman, rikt fiske, skeppsbrutna.
- Kriser: Spökflottan (6 vågor) och De Sovande Väktarna (finns från start på Solstensön). Armadan och Djupkulten kommer i betan.

## Status
- Koden är skriven men ännu INTE provkörd. Första körningen kan ge skriptfel – de rättas i nästa uppdatering.
