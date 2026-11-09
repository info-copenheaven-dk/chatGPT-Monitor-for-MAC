# chatGPT Monitor for MAC

En lille macOS-app til overblik over Codex/ChatGPT Work og ChatGPT-chat.

## Version 0.2.0

Appen har produkt- og kvotevalg, valideret kvotemodel, individuelle periodestatusser, lokale nedtællinger hvert minut, procentbjælker, eventuelle antal/enheder samt advarsler med tekst og farve ved 20 % og 5 %.

**Indtast værdier…** åbner en manuel formular for hver periode. Procent og nulstilling valideres før samlet lagring; fjern periodens markering for at vise ukendte værdier. Danske decimaltal accepteres. Manuelle data holdes adskilt mellem produkter og gemmes lokalt mellem opstarter. De nedskrives eller genopfyldes ikke automatisk.

Indstillinger rummer **Altid øverst** og interval for automatiske datakilder. Indstillinger, produkt, datakilde, kvotegruppe og vinduesplacering huskes mellem opstarter. Udviklingskilden findes kun i debug med `--demo`; den viser flere kvotegrupper, advarsler, udløb og manglende data.

Opdateringsstyringen er implementeret: opstart, konfigurerbart interval (standard 5 minutter), manuel opdatering, udløb og opvågning bruger samme henteforløb. Ingen samtidige hentninger tillades. Midlertidige fejl får højst tre forsøg med stigende ventetid; lange serverventetider udskydes i stedet for at blokere. Seneste kendte værdier markeres forældede ved fejl, og tidsstempler bevares. Manuelle data hentes ikke automatisk og ændres ikke ved udløb.

Codex-forbindelsen er implementeret med den officielle app-server-protokol. Codex vælges automatisk for Codex/ChatGPT Work; vælg **Manuel indtastning** i Datakilde for at bruge manuelle værdier. ChatGPT-chat bruger fortsat manuel indtastning. Kildernes data holdes adskilt. Automatisk cache vises som forældet efter genstart, indtil en ny hentning lykkes. Appen bruger ikke det historiske [kvotesvar](./quota-sample.json) som aktuelle data.

## Forudsætninger

- Apple Silicon og macOS 27.0 eller nyere.
- På udviklingsmaskinen: Swift 6.0 eller nyere og macOS SDK med understøttelse af macOS 27. Bygningen er kontrolleret med Swift 6.4.
- Den byggede app kræver hverken Swift-værktøjer, Node.js eller Xcode på målmaskinen. Automatisk aflæsning kræver en lokal Codex CLI; appen søger blandt andet i ChatGPT-appens bundle og Homebrew. En anden sti kan angives i Indstillinger.

## Byg og start

Kør fra projektmappen:

```sh
./scripts/build-app.sh debug
open 'dist/debug/ChatGPT Monitor.app'
```

VS Code-tasken **Byg Mac-app** udfører samme debug-build.

For udviklingsdata: afslut først en eventuelt kørende instans, og start derefter:

```sh
open 'dist/debug/ChatGPT Monitor.app' --args --demo
```

Normal opstart viser **Ukendt**, indtil manuelle værdier er indtastet eller Codex har hentet data. Demo er tydeligt mærket som udviklingsdata.

Byg en version uden udviklingsdatakilden:

```sh
./scripts/build-app.sh release
open 'dist/release/ChatGPT Monitor.app'
```

Kopiér den byggede `.app` til Programmer på den ønskede Mac. Pakken er lokalt ad hoc-signeret; Developer ID-signering og notarisation til nem distribution er endnu ikke etableret.

## Struktur

- [Models](./Sources/QuotaMonitor/Models/): kvoter, validering, nedtælling og manuelle formularværdier.
- [DataSources](./Sources/QuotaMonitor/DataSources/): capabilities, manuel kilde og debug-demo.
- [State](./Sources/QuotaMonitor/State/): indlæsning, produktvalg og fejltilstande.
- [Views](./Sources/QuotaMonitor/Views/): kvotekort, formular og indstillinger.
- [Persistence](./Sources/QuotaMonitor/Persistence/): lokale præferencer, præferencer og adskilte kvotecaches.
- [App](./Sources/QuotaMonitor/QuotaMonitorApp.swift): opstart og AppKit-livscyklus.

## Verifikation

```sh
./scripts/test.sh
```

Testprogrammet bruger Swift-værktøjerne direkte, da maskinens Command Line Tools ikke indeholder XCTest. Det kontrollerer ugyldige tal, ukendte og delvise svar, 0/5/20 %-grænser, nedtælling, udløb uden genopfyldning, isolation mellem produkter og manuel indtastning med decimalkomma. Simulerede kilder og en udskiftelig klokke kontrollerer også intervalstyring, maksimum tre forsøg, serverventetid, opvågning, genopretning og beskyttelse mod samtidige kald.

Debug- og release-app bygges til arm64. Produktvalg, kvotevalg, advarsler, udløb, manglende data, manuel formular, afvisning af 101 %, lagring af 12,5 % og indstillinger er kontrolleret i den kørende app. Layout er visuelt kontrolleret i både lyst og mørkt tema. Indstillinger har et gemt temavalg: Følg systemet, Lyst eller Mørkt.

Linkeren udsender lokale advarsler om to manglende søgestier under Command Line Tools. Bygningerne lykkes. Installation på øvrige Macs er ikke afprøvet.

Se [krav](./req.md), [plan](./plan.md) og [fase 1](./fase1.md).

## Kontrakt for automatiske datakilder

Kilden angiver `minimumRefreshSeconds` i sine capabilities. Midlertidige fejl rapporteres som `QuotaFetchError.temporary(retryAfter:)`, mens loginfejl og permanente fejl klassificeres særskilt. Et eventuelt HTTP Retry-After skal oversættes til sekunder af adapteren. Monitoren respekterer ventetiden ved både manuelle og automatiske kald. Normal opstart bruger Codex-adapteren til Codex-produktet. Adapteren kan kun videreføre serverventetid, hvis app-serverens fejlsvar indeholder den struktureret; rå fejlmeddelelser logges ikke.


## Login og sikker lagring

Åbn **Indstillinger → Log ind med ChatGPT…** og gennemfør browserlogin. Monitorens Codex-proces bruger eksplicit nøgleringslagring. Hvis din eksisterende Codex-session bruger filbaseret standardlagring, kræver monitoren derfor et nyt login; den kopierer ikke eksisterende tokens. Brug samme konto som den ønskede kvotevisning.

Programmet gemmer ingen adgangskoder eller tokens i sine præferencer. Codex håndterer OAuth, fornyelse og macOS-nøglering. Processens stderr og rå JSON-svar logges ikke af monitoren. Login-URL'er gemmes ikke. Programmet starter ingen modelopgaver for at hente kvoter.

Den lokale CLI er aktuelt 0.166.0-alpha.6; monitoren validerer initialiseringshåndtrykket og de nødvendige svarfelter og fejler med en statusmeddelelse ved inkompatibilitet. CLI'en medleveres ikke; den skal være installeret på hver Mac. ZIP-pakken er til personlig lokal installation; Developer ID-signering og notarisation indgår ikke i denne leverance.

Kilder: [OpenAI Docs: App Server](https://learn.chatgpt.com/docs/app-server) og [OpenAI Docs: Authentication](https://learn.chatgpt.com/docs/auth).

## Verifikation af fase 6 og 7

Testene omfatter native proceskommunikation med en simuleret CLI, initialisering, kvotelæsning, loginnotifikation, omregning af procent, genkendelse af perioder, ugyldige svar, kildeadskillelse, cache-rundtur, oprindelige tidsstempler, forældet automatisk cache, indstillinger og vinduesplacering uden for den aktuelle skærm.

Login til nøgleringen er gennemført. Faktiske kvoter er verificeret både gennem Swift-adapteren og i den installerede release-app, inklusive manuel opdatering og ny hentning efter genstart. Øvrige Macs samt fysisk dvale/skærmfrakobling er ikke afprøvet. Se [afsluttende testoversigt](./VERIFICATION.md).


## Installation af den færdige app

Appen er installeret på udviklingsmaskinen i brugerens Programmer-mappe og er startet med faktiske Codex-data.

Til en anden Mac:

1. Hent [ZIP-pakken fra GitHub Releases](https://github.com/info-copenheaven-dk/chatGPT-Monitor-for-MAC/releases/latest) og pak den ud.
2. Flyt **ChatGPT Monitor.app** til Programmer og start den.
3. Sørg for macOS 27.0 eller nyere og Apple Silicon. Automatisk Codex-visning kræver en installeret Codex CLI, eksempelvis fra ChatGPT-appens bundle.
4. Brug **Indstillinger → Log ind med ChatGPT…**, hvis der ikke allerede findes en egnet nøgleringssession på maskinen.
5. Vælg **ChatGPT-chat** for manuel indtastning. Alle indstillinger og data er lokale for den enkelte Mac.

Pakken er ad hoc-signeret til personlig lokal brug og er ikke Apple-notariseret. Der findes ingen gyldig Developer ID-signatur på denne udviklingsmaskine. Distribution uden Apples almindelige advarsler kræver derfor separat Developer ID-signering og notarisation.

Lav en ny pakke med:

```sh
./scripts/package-release.sh
```

Codex-hjælpeprocessen lukkes efter 10 sekunders inaktivitet, så den ikke ligger i hukommelsen mellem opdateringerne. Den holdes åben under login.

## Mini-layout

Klik på mini-knappen øverst eller slå **Mini-layout** til i Indstillinger. Mini-visningen viser kun **5 timer** og **Uge**, hver med resterende procent, statusbjælke og en synlig **Nulstilles om**-nedtælling, der opdateres hvert minut. Hold musen over en række for at se **Frem til**, nedtælling, datakilde og seneste opdatering.

Højreklik i mini-vinduet for **Vis fuldt layout**, **Indstillinger…** eller **Opdater**. Valget huskes efter genstart. Et lille ur markerer forældede eller udløbne værdier; udviklingsdata har et hammerikon.
