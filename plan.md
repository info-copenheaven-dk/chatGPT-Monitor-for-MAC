# Implementeringsplan

Planen omsætter [kravbeskrivelsen](./req.md) til en lille skrivebordsapp med to kvotevisninger, lokale nedtællinger og tydelig angivelse af datakvalitet.

## 1. Afklar platform og datakilde

**Status:** Begge produkter samt SwiftUI + AppKit til macOS på Apple Silicon er valgt. macOS 27.0 eller nyere bruges som foreløbigt mål ud fra den lokale macOS 27.0.1. Codex-kontoadgang er verificeret for begge perioder; almindelig ChatGPT-chat følger den manuelle reservevej, da automatisk adgang ikke er verificeret. Se [fase 1-resultatet](./fase1.md).

- Målplatformen er macOS på Apple Silicon (arm64), uden krav om Intel. Brug macOS 27.0 som foreløbig minimumsversion, og kontrollér kompatibilitet ved installation på øvrige Macs.
- Understøt både almindelig ChatGPT-chat og Codex/ChatGPT Work med separate datakilder og tilstande. Verificér tilgængelige kvoter for hvert produkt.
- Undersøg understøttede muligheder for at hente resterende kvote, enhed og nulstillingstidspunkt for begge perioder. Dokumentér kilde, loginmetode, begrænsninger og tilladt opdateringsfrekvens.
- Kontrollér datakildens betydning af perioderne: faste eller rullende vinduer, tidszone og eventuelle separate modelkvoter.
- Brug manuel indtastning, hvis ingen understøttet automatisk datakilde er tilgængelig. Automatisk integration må ikke baseres på en antagelse om, at en API findes.

**Leverance:** Beslutning om platform, produkt og datakilde samt et anonymiseret eksempel på data, hvis automatisk adgang er mulig. Disse beslutninger skal være afklaret før implementering af appen.

## 2. Opret appens fundament

**Status: Gennemført.** Swift Package med SwiftUI/AppKit, datakildeinterface, manuel hukommelseskilde, debug-demo, produktvalg og separat lokal præferencelagring er oprettet. Debug- og release-app er bygget til arm64. Normal visning, produktvalg og tydeligt markerede udviklingsdata er kontrolleret i appens vindue. Se [byggevejledningen](./README.md).

Der anvendes Swift, SwiftUI og enkelte AppKit-funktioner til vinduesstyring. Appen bygges til Apple Silicon (arm64) med en minimumsversion af macOS, som dækker brugerens Macs.

- Opret appprojekt og en kort vejledning til at bygge og starte appen.
- Adskil kode til brugerflade, kvotetilstand, datakilder, opdateringsstyring og lokal lagring.
- Indfør en udskiftelig datakilde med operationer til at hente kvoter og beskrive, hvilke funktioner kilden understøtter.
- Opret en manuel datakilde og en udviklingsdatakilde med faste eksempler. Udviklingsdata skal kun være aktive under udvikling og test.

**Leverance:** En startbar app med tomme kvotefelter og tydeligt markerede udviklingsdata ved udviklingskørsel.

## 3. Implementér datamodel og tilstande

**Status: Gennemført.** Stabile kvotegrupper, validerede værdier, kilde, individuelle tidsstempler og alle krævede statustyper er modelleret. Delvise svar udfylder kun manglende perioder med ukendte værdier. Model- og datakildetests består.

Modellér en kvotegruppe med produkt, stabilt ID og visningsnavn samt to perioder: 5 timer og uge. Hver periode skal kunne indeholde:

- Resterende procent som valgfri værdi fra 0 til 100.
- Valgfrit resterende antal og tilhørende enhed.
- Valgfrit absolut nulstillingstidspunkt.
- Datakilde: automatisk eller manuel.
- Tidspunkt for seneste vellykkede hentning eller manuelle indtastning.
- Tilstand: aktuel, manuel, ukendt, ikke tilgængelig, forældet eller afventer bekræftet nulstilling.

Bevar fraværende værdier som fraværende. Validér input og datakildens svar, og håndtér delvise svar separat for hver periode, så én manglende periode ikke skjuler den anden.

**Leverance:** En fælles model, der kan vise korrekte værdier og fejltilstande uden at opfinde kvoter.

## 4. Byg den kompakte brugerflade

**Status: Gennemført.** Produkt-/kvotevælger, kvotekort, procentbjælker, antal/enhed, lokale danske datoer, minutvise nedtællinger, advarsler og valideret manuel formular er implementeret. Indstillinger rummer vinduesniveau og opdateringsinterval; vedvarende lagring er implementeret i fase 7. Tastaturgenveje og tilgængelighedstekster er tilføjet. Lys og mørk visning er kontrolleret i fase 8; installation på øvrige Macs er ikke afprøvet.

- Vis produkt og valgt kvotegruppe øverst; tilføj en vælger, når flere grupper findes.
- Vis to kort med overskrifterne **5 timer** og **Uge**.
- Vis procent, statusbjælke, eventuelt resterende antal, **Frem til** og nedtælling i hvert kort.
- Formatér datoer på dansk med lokalt klokkeslæt og 24-timers ur.
- Vis advarsel ved højst 20 % og kritisk status ved højst 5 %, med både tekst og farve.
- Vis datakilde, eventuelle fejl og seneste vellykkede opdatering. Bevar særskilte tidspunkter, hvis perioderne er opdateret forskelligt.
- Tilføj **Opdater**, indstillinger og en formular til manuel procent og nulstillingstidspunkt for hver periode.
- Understøt lyst og mørkt tema, tastaturbetjening og læsbare tilgængelighedstekster.

**Leverance:** Et brugbart vindue med alle visningstilstande fra kravbeskrivelsen.

## 5. Implementér opdateringer og nulstilling

**Status: Gennemført.** Fælles henteforløb for opstart, manuel opdatering, interval, udløb og opvågning. Opdateringspolitikken respekterer kildens minimumsinterval og serverens ventetid. Højst tre forsøg med stigende ventetid ved klassificerede midlertidige fejl; login-/permanente fejl genforsøges ikke i samme forløb. Seneste værdier/tidsstempler bevares ved fejl. Nulstillinger udløser kun én ekstra hentning pr. produkt, kvotegruppe, periode og nulstillingstidspunkt. Simulerede tests dækker planlægning, fejl, genopretning, dvale-trigger og overlappende kald. Codex-adapteren er tilsluttet i fase 6.

- Hent automatiske data ved opstart og derefter som udgangspunkt hvert 5. minut.
- Gør intervallet konfigurerbart inden for datakildens begrænsninger.
- Lad manuel opdatering bruge samme henteforløb; undgå samtidige, overlappende kald.
- Opdatér nedtællinger lokalt mindst én gang i minuttet uden netværkskald.
- Når et nulstillingstidspunkt passeres, vis **Afventer bekræftet nulstilling** og forsøg en ny hentning for automatiske data. Vis aldrig en automatisk genopfyldning uden nye bekræftede data.
- For manuelle data skal udløb markeres, og brugeren skal kunne indtaste nye værdier. Appen må ikke gætte en ny kvote eller et nyt nulstillingstidspunkt.
- Bevar seneste kendte data ved fejl og markér dem som forældede. Brug begrænsede genforsøg med stigende ventetid og respekter eventuelle grænser fra serveren.
- Genberegn nedtællinger og hent relevante data, når computeren vågner. Undgå gentagne nulstillingskald for det samme udløbne tidspunkt.

**Leverance:** Stabil opdatering med korrekt håndtering af fejl, dvale og udløbne perioder.

## 6. Tilslut automatisk datakilde, hvis tilgængelig

**Status: Gennemført.** Swift-adapteren bruger Codex app-server over JSON-RPC med nøgleringslagring. Login er gennemført, og faktiske kvoter er verificeret med både Swift-adapteren og den installerede release-app. Manuel opdatering og hentning efter genstart er kontrolleret. Proceskommunikation, fejl og loginnotifikation er desuden testet med en simuleret CLI. Codex-hjælpeprocessen lukkes efter 10 sekunders inaktivitet, men holdes åben under login. Automatisk og manuel kilde er adskilt.

- Implementér den integration, der blev verificeret i fase 1, bag det fælles datakildeinterface.
- Oversæt kildens data til appens model, inklusive eventuel omregning fra forbrugt til resterende procent, når kildens definition gør det entydigt.
- Håndtér login, udløbet adgang, manglende tilladelser og begrænset kaldsfrekvens.
- Gem adgangsoplysninger i macOS Keychain. Fjern tokens og følsomt indhold fra logning.
- Hold manuelle og automatiske værdier adskilt, og vis tydeligt, hvilken kilde der er valgt.

**Leverance:** Verificeret automatisk aflæsning eller en fuldt brugbar første version med tydeligt markeret manuel indtastning. Hvis kun manuel adgang er mulig, skal leverancen beskrive denne begrænsning.

## 7. Gem indstillinger og vinduestilstand

**Status: Gennemført.** Produkt, datakilde og kvotegruppe pr. produkt/kilde, interval, CLI-sti og Altid øverst gemmes lokalt. Manuelle kvoter og automatisk cache lagres adskilt med oprindelige tidsstempler; automatisk cache gendannes forældet. Codable-indlæsning validerer værdier; beskadiget cache giver ukendte værdier. Vinduets placering gemmes og begrænses til en tilgængelig skærm ved gendannelse, størrelsesændring og ændret skærmopsætning. Lagring, kildeadskillelse og skærmgeometri er testet.

- Gem valgt kvotegruppe, datakilde, opdateringsinterval og indstillingen **Altid øverst** lokalt.
- Gem manuelle data og seneste kendte automatiske værdier med deres oprindelige tidsstempler.
- Gendan gemte automatiske data som forældede, indtil en ny hentning lykkes.
- Gem vinduets position og gendan den inden for en tilgængelig skærm, også når skærmopsætningen ændres.
- Brug AppKit til vinduesniveauet, når **Altid øverst** slås til eller fra.

**Leverance:** En app, som bevarer brugerens valg efter genstart uden at fremstille gamle data som aktuelle.

## 8. Verificér krav og klargør levering

**Status: Gennemført på den lokale målmaskine.** Version 0.2.0 er bygget, lokalt signeret, installeret og startet. Automatiserede tests består; lys/mørk visning, faktiske kvoter, manuel opdatering og gendannelse af indstillinger/vinduesplacering er kontrolleret. ZIP-pakke er oprettet til øvrige Macs. Se [test- og leveringsrapport](./VERIFICATION.md) for acceptkriterier, observationer og begrænsninger. Fysisk test på øvrige Macs samt faktisk dvale/skærmfrakobling er ikke udført; de tilhørende tilstandsforløb er testet med simuleret tid og skærmgeometri.

Brug målrettede automatiske tests til tilstandslogik og tidsberegninger. Brug en udskiftelig klokke og simulerede datakilder, så tests ikke kræver en rigtig konto.

| Område | Verifikation |
| --- | --- |
| Kvoter | 0 %, 5 %, 20 % og 100 %, manglende værdier og ugyldige input |
| Tid | Lokal tidszone, sommertid, datoovergang og allerede udløbet nulstilling |
| Nulstilling | Ingen ubekræftet genopfyldning; ingen gentagne kald for samme udløb |
| Opdatering | Automatisk og manuel hentning, delvise svar, fejl og genopretning |
| Manuel kilde | Validering, tydelig mærkning og ingen automatisk nedskrivning |
| Lagring | Genstart, oprindelige tidsstempler og sikker håndtering af adgangsoplysninger |

Foretag derudover manuel kontrol af kompakt layout, lyst og mørkt tema, kvotevælger, flytning, **Altid øverst**, ændret skærmopsætning og opvågning fra dvale. Kontrollér ressourceforbruget i inaktiv tilstand og byg en release-version på den valgte platform.

**Leverance:** En kørbar første version og en kort vejledning til installation, valg af datakilde og kendte begrænsninger. Gennemgå alle acceptkriterier i [req.md](./req.md) og registrér resultatet før aflevering.

## Rækkefølge og færdigkriterium

Fase 1 afklarer forudsætningerne. Fase 2–5 bygger appens kerne med manuel adgang. Fase 6 tilføjer automatisk adgang, hvis den er mulig. Fase 7–8 afslutter lagring, kvalitetssikring og levering.

Første version er færdig, når begge perioder kan vises med korrekt datakilde og tilstand, nedtællinger og nulstillinger fungerer, indstillinger bevares, og acceptkriterierne er gennemgået. Historik, eksport, flere samtidige konti og mobilapp indgår ikke.

## Aflevering

Fase 1–8 er afsluttet for den lokale første version. ChatGPT-chat anvender den accepterede manuelle reservevej. Den installerede app ligger i brugerens lokale Programmer-mappe; ZIP-pakken og installationsvejledningen er beskrevet i [README](./README.md).
