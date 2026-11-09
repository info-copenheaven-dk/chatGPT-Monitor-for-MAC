# Fase 1: Platform og datakilde

Undersøgt 4. november 2026. Grundlag: [krav](./req.md) og [implementeringsplan](./plan.md).

## Status

Den tekniske undersøgelse er gennemført. Brugeren har valgt begge produkter og SwiftUI + AppKit til sine Macs med Apple Silicon. macOS 27.0 bruges som foreløbig minimumsversion baseret på lokal aflæsning af macOS 27.0.1. Andre Macs er ikke aflæst. Automatisk adgang til Codex er nu verificeret på den lokale konto. Almindelig ChatGPT-chat har fortsat ingen verificeret automatisk datakilde og følger kravets manuelle reservevej.

| Emne | Resultat |
| --- | --- |
| Lokal platform | macOS 27.0.1 på Apple Silicon |
| Værktøjer | Command Line Tools og Swift 6.4 er tilgængelige; fuld Xcode er ikke verificeret |
| Valgt app | Native macOS med SwiftUI og AppKit; bekræftet af brugeren |
| Arkitektur | Apple Silicon (arm64); Intel-understøttelse er ikke et krav |
| Produkt | Både ChatGPT-chat og Codex/ChatGPT Work; bekræftet af brugeren |
| Automatisk kilde | Codex app-server: kontoadgang og begge perioder er verificeret |
| Lokal Codex CLI | Fundet i ChatGPT-appens bundle; version 0.166.0-alpha.6 |
| Reserve | Manuel indtastning som beskrevet i kravene |

## Hvad de officielle kilder fastslår

Codex app-server dokumenterer `account/rateLimits/read` og notifikationen `account/rateLimits/updated`. Svaret kan indeholde flere kvotegrupper, forbrugt procent, vindueslængde i minutter og næste nulstilling som Unix-tid i sekunder. Browserlogin med ChatGPT er beskrevet. Kilden bekræfter ikke, hvilke felter netop brugerens konto returnerer. [OpenAI Docs: App Server](https://learn.chatgpt.com/docs/app-server).

ChatGPT Work og Codex deler forbrug. Dokumentationen omtaler femtimersperioder og mulige ugegrænser; den lover ikke begge grænser for enhver konto. Det er ikke dokumentation for, at alle former for almindelig ChatGPT-chat har samme kvoter. [OpenAI Docs: Pricing](https://learn.chatgpt.com/docs/pricing).

API Platform har separate grænser for blandt andet requests og tokens på projekt- og organisationsniveau. Disse er ikke en erstatning for den ønskede abonnementsvisning. [OpenAI Docs: API rate limits](https://developers.openai.com/api/docs/guides/rate-limits).

## Valg af integrationsvej

**Hvis produktet er Codex/ChatGPT Work:** Afprøv app-server med ChatGPT-login. Vælg integrationen, hvis den relevante konto returnerer de nødvendige kvoter. Navngiv appens produktvisning efter den faktiske kvotegruppe.

**Hvis produktet er almindelig ChatGPT-chat:** Der er i denne undersøgelse ikke verificeret en understøttet grænseflade til netop dens resterende 5-timers- og ugekvoter. Brug manuel indtastning, indtil en passende kilde er verificeret. Dette er ikke en påstand om, at en sådan grænseflade ikke findes.

Der vælges ikke browser-scraping eller udokumenterede HTTP-endpoints som fundament.

## Datakontrakt til appen

- Identificér 5 timer ved en returneret vindueslængde på 300 minutter og uge ved 10.080 minutter. Antag ikke, at `primary` og `secondary` altid svarer til disse perioder.
- Beregn resterende procent som `100 - usedPercent` for gyldige værdier mellem 0 og 100. Bevar manglende eller ugyldige værdier som ukendte.
- Brug kildens absolutte nulstillingstidspunkt og konvertér til lokal visning. Udled ikke næste nulstilling ved at lægge fem timer eller syv dage til nuværende tidspunkt.
- Fast eller rullende periodestart er ikke verificeret for brugerens konto. Appen behøver ikke antage en startregel, når næste nulstilling leveres af kilden.
- Vis kun resterende antal beskeder eller tokens, hvis en kilde faktisk leverer det. Procent kan ikke omregnes til et pålideligt antal beskeder.
- Hold produkt, kvotegrupper og eventuelle ekstra forbrugsgrænser adskilt.

## Opdatering og login

Designforslaget er opdatering hvert femte minut plus manuel opdatering, hentning efter opvågning og hentning ved udløb. En tilladt minimumsafstand mellem kvotekald er ikke verificeret; fem minutter er derfor et appforslag, ikke en dokumenteret servergaranti. Respektér serverens begrænsninger og brug begrænsede genforsøg.

Ved app-server-integration bruges den dokumenterede loginproces. Kontroller før integration, hvordan den valgte CLI-version lagrer login, og konfigurér sikker credential-lagring i systemets nøglering. Læs eller kopiér ikke tokens fra andre apps som integrationsmetode.

## Procedure til gentagelse af kontrollen

1. Produkt, målplatform og teknologi er registreret. Lokal aflæsning viser macOS 27.0.1 og arm64; foreløbigt mål er macOS 27.0 eller nyere. Kontrollér øvrige Macs ved installation.
2. Ved automatisk adgang: find eller installér en officiel Codex CLI og registrér versionen.
3. Start app-server og udfør initialiseringshåndtrykket efter den versions dokumentation.
4. Brug understøttet ChatGPT-login, hvis processen kræver det. Brugeren gennemfører selve login.
5. Foretag kun læsning af kontostatus og kvoter; der er ikke behov for at sende en modelopgave.
6. Kontrollér produkt/kvotegruppe, vindueslængder, procent og nulstilling for begge perioder. Sammenhold med kontoens egen forbrugsvisning.
7. Gem et anonymiseret kvotesvar uden identitet, tokens og login-URL'er. Registrér manglende felter og faktisk resultat.

Kontrollen er udført med den eksisterende login-session via app-server. Kun initialisering og `account/rateLimits/read` blev sendt; ingen modelopgave blev startet. Et filtreret svar uden kontoidentitet og credentials findes i [quota-sample.json](./quota-sample.json).

## Beslutningslog

- Platform: macOS på Apple Silicon (arm64), med SwiftUI + AppKit. Bekræftet af brugeren; Intel er ikke et krav. Foreløbig minimumsversion er macOS 27.0, baseret på lokal macOS 27.0.1; øvrige Macs er ikke aflæst.
- Produkt: Både almindelig ChatGPT-chat og Codex/ChatGPT Work er valgt.
- Konkrete kvoter/modeller: Afventer kvotesvar; vælg mellem returnerede kvotegrupper frem for at hardkode modelnavne.
- Datakilde: Verificeret app-server til Codex/Work. Almindelig ChatGPT-chat bruger den manuelle reservevej fra kravene, indtil automatisk adgang kan verificeres.
- Automatisk adgang på kontoen: Verificeret for kvotegruppen `codex`, med 300 og 10.080 minutters vinduer. Der blev ikke returneret en særskilt gruppe for almindelig ChatGPT-chat.

Fase 1 er afsluttet efter brugerens accept af manuel indtastning for ChatGPT-chat. Platform og teknologi er valgt, og automatisk Codex-aflæsning er verificeret.

## Teknologialternativer til flere Macs

| Teknologi | Fordel ved denne app | Afvejning |
| --- | --- | --- |
| SwiftUI + AppKit | Native macOS-brugerflade og direkte integration med vinduer og systemfunktioner | Apple-teknologi; en senere Windows-version kræver en anden brugerflade |
| Tauri | Webbrugerflade med Rust og systemets webview; mulighed for andre desktopplatforme | Flere teknologier og behov for at kontrollere webview-adfærd på understøttede macOS-versioner |
| Electron | Webbrugerflade med JavaScript/TypeScript og mulighed for andre desktopplatforme | Chromium og Node.js følger med appen og giver en større distributionspakke |

Anbefaling: SwiftUI + AppKit, når appen kun skal bruges på Macs. Flere Macs kræver ikke i sig selv en tværplatformsteknologi. Pak appen til de nødvendige processorarkitekturer og en fælles minimumsversion af macOS. Den enkelte Mac skal have adgang til den valgte datakilde; eventuel CLI skal medleveres eller installeres som en tydelig forudsætning.

Kilder: [Apple: AppKit og SwiftUI](https://developer.apple.com/documentation/appkit), [Tauri: arkitektur](https://v2.tauri.app/concept/architecture/), [Electron: introduktion](https://www.electronjs.org/docs/latest/).

## Resultat af kontoverifikation

Aflæsningen viste 9 % forbrugt i 5-timersperioden og 5 % i ugeperioden, altså henholdsvis 91 % og 95 % tilbage. Begge perioder havde absolutte nulstillingstidspunkter. Dette er et øjebliksbillede, ikke værdier som skal indbygges i appen.

Den anvendte CLI ligger i `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`. Stien er en lokal installationsdetalje og skal kunne konfigureres eller erstattes af en distribueret afhængighed. Bundleversionen er en alpha-version; integrationen skal versionskontrolleres og håndtere protokolændringer.

Undersøgelsen og den praktiske Codex-kontrol er afsluttet. Første version kan baseres på automatisk Codex-aflæsning og manuel ChatGPT-chat efter den allerede beskrevne reservevej. Automatisk understøttelse af begge produkter er ikke opnået. Sammenligning med kontoens grafiske forbrugsvisning og kontrol på øvrige Macs udestår som integrationsverifikation.
