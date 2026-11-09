# Test og levering – version 0.2.0

Kontrolleret 4. november 2026 på macOS 27.0.1, Apple Silicon, Swift 6.4. Grundlag: [krav](./req.md) og [implementeringsplan](./plan.md).

## Resultat

Første version er færdig og installeret lokalt. Faktiske Codex/ChatGPT Work-kvoter læses automatisk med login i macOS-nøgleringen. Almindelig ChatGPT-chat bruger den accepterede manuelle indtastning. Alle lokale automatiserede tests består.

## Acceptkriterier

| Kriterium | Resultat og evidens |
| --- | --- |
| Begge perioder, resterende kvote og Frem til i ét vindue | Bestået i installeret release-app med faktiske data. Begge kilder kan vælges for Codex; ChatGPT-chat har manuel kilde. |
| Korrekte lokale datoer og nedtællinger | Bestået i UI og tests af dansk 24-timersvisning, datoovergang og sommertid. Nedtælling bruger absolut tid og opdateres mindst hvert minut. |
| Manuel og automatisk opdatering | Faktisk manuel hentning og hentning ved opstart/genstart er verificeret. Intervalstyring, genforsøg, serverventetid og samtidighed er testet med simuleret tid/kilde. |
| Ukendte, manuelle, forældede og aktuelle data kan skelnes | Bestået gennem UI og tests. Cache gendannes som forældet med oprindelige tidsstempler; delvise/ugyldige data giver ingen opdigtede kvoter. |
| Udløb genopfylder ikke automatisk kvoten | Bestået med faste tider. Samme nulstilling udløser kun én ekstra hentning; procent ændres først ved nye data. |
| Placering og Altid øverst huskes efter genstart | Bestået: vinduet blev flyttet, og samme gemte koordinater blev aflæst efter genstart. Altid øverst, interval, tema, produkt og kilde blev genfundet i den installerede release-app. |

## Udførte checks

- `scripts/test.sh`: validering af procent/antal, delvise svar, 0/5/20/100 %-grænser, nedtælling og udløb.
- Tidszone: dansk lokal dato, midnat og overgangen til sommertid i Europe/Copenhagen.
- Opdatering: opstart, interval, maksimum tre forsøg, stigende ventetid, serverventetid, opvågnings-trigger, genopretning efter fejl og ingen overlappende kald.
- Procesintegration: initialisering, kvotelæsning og loginnotifikation gennem en simuleret CLI.
- Data: omregning fra brugt til resterende procent, varighedsbaseret periodevalg og håndtering af ugyldige svar.
- Lagring: adskilte kilder/produkter, indstillinger, kvotevalg, oprindelige tidsstempler, automatisk cache som forældet og sikker håndtering af beskadiget cache.
- Vindue: geometri ved manglende skærm samt native flytning og genstart.
- Visuel kontrol: lyst og mørkt tema, statusbjælker, advarsler, manuel formular og fejlbeskeder.
- Kontodata: Swift-adapteren og den installerede app hentede faktiske kvoter fra nøgleringssessionen. Ved release-opstart kl. 23:19 blev 47 % og 88 % resterende observeret. Tallene er øjebliksbilleder og bruges ikke som appdata eller faste forventninger i tests.
- Debug og release: begge bygger til arm64. Appens plist og lokale signatur er valideret. Release-binæren benytter systembiblioteker og kræver ingen udviklingsværktøjer på målmaskinen.
- Editorens problemkontrol: ingen fejl.

## Ressourceforbrug

Den installerede release-app blev observeret inaktiv med 0,0 % CPU og cirka 122 MiB resident hukommelse. Codex-hjælpeprocessen var afsluttet efter inaktivitetsfristen; under hentning bruger den kortvarigt yderligere hukommelse. Målingen er et øjebliksbillede og ikke en garanti for alle maskiner eller belastninger.

## Leverance

- Installeret app: `~/Applications/ChatGPT Monitor.app`.
- Release-bundle: [ChatGPT Monitor.app](./dist/release/ChatGPT%20Monitor.app).
- Transportpakke: [ChatGPT-Monitor-0.2.0-arm64.zip](./dist/ChatGPT-Monitor-0.2.0-arm64.zip), med separat SHA-256-fil.
- [Installations- og brugsvejledning](./README.md).

## Praktiske begrænsninger

- Der er ikke verificeret en automatisk kvotekilde til almindelig ChatGPT-chat. Denne del er manuel som accepteret af brugeren.
- Andre Macs, fysisk skærmfrakobling og faktisk dvale er ikke testet. Tid, wake-trigger og skærmgeometri er i stedet testet lokalt og deterministisk.
- Codex CLI skal være tilgængelig på hver Mac. Den er ikke indlejret i pakken; en alternativ sti kan angives i Indstillinger.
- Pakken er lokalt ad hoc-signeret og ikke notariseret. Der findes ingen gyldig Developer ID-identitet på maskinen.
- Linkeren viser to advarsler om manglende lokale Command Line Tools-søgestier. Bygninger og den installerede release-app fungerer.

## Tilføjelse: Mini-layout

Mini-layout er implementeret efter brugerens referencebillede og kontrolleret visuelt i den installerede release-app. Vinduet reduceres til 360 pixels i bredden med to kompakte perioder. Begge rækkers native mouse-over-hjælp indeholder det korrekte nulstillingstidspunkt, nedtælling og datakilde. Højreklikmenu og gendannelse af mini-valget efter genstart er verificeret. Den opdaterede ZIP indeholder samme app som den lokale installation.
