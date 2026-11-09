# Krav til ChatGPT-forbrugsmonitor

## Formål

En lille app på skrivebordet, der giver et hurtigt overblik over resterende forbrug for både Codex/ChatGPT Work og almindelig ChatGPT-chat i den aktuelle 5-timersperiode og ugeperiode, når disse perioder findes, samt hvornår hver grænse nulstilles.

“Tid tilbage” betyder her resterende forbrugskvote og tid frem til nulstilling. Det er ikke nødvendigvis antal minutter, brugeren kan chatte.

## Brugerflade

- Appen skal vises som et kompakt vindue på skrivebordet.
- Brugeren skal kunne vælge et mini-layout med navn, resterende procent, statusbjælke og resterende tid til nulstilling for 5 timer og uge. Mouse-over skal vise periodens nulstillingstidspunkt. Højreklik skal give adgang til fuldt layout og indstillinger. Layoutvalget skal huskes efter genstart.
- Brugeren skal kunne flytte vinduet og vælge, om det altid skal ligge øverst.
- Appen skal vise to tydelige felter: **5 timer** og **Uge**.
- Brugeren skal kunne skifte mellem **Codex/ChatGPT Work** og **ChatGPT-chat**. Hvert produkt skal have sine egne kvoteoplysninger, datakilde og opdateringsstatus. Manglende perioder skal vises som ikke tilgængelige.
- Hvert felt skal vise:
  - Resterende kvote i procent og som en enkel statusbjælke.
  - Resterende antal, hvis datakilden oplyser det, fx beskeder eller tokens.
  - **Frem til:** dato og klokkeslæt for periodens nulstilling.
  - Nedtælling til nulstilling, fx “2 t 15 min”.
- Dato og klokkeslæt skal vises i brugerens lokale tidszone med 24-timers ur.
- Tidspunkt for seneste opdatering skal være synligt.

### Eksempel på visning

```text
ChatGPT-forbrug

5 timer     65 % tilbage
Frem til:   04.11.2026 kl. 18:30
Nulstilles om 2 t 15 min

Uge         30 % tilbage
Frem til:   09.11.2026 kl. 09:00
Nulstilles om 4 d 16 t 45 min

Senest opdateret kl. 16:15   [Opdater]
```

Eksemplet indeholder illustrative værdier.

## Funktionelle krav

1. Appen skal vise den aktuelle resterende kvote for både 5-timersperioden og ugeperioden, når disse oplysninger er tilgængelige.
2. Nulstillingstidspunkter skal følge kontoudbyderens oplysninger. Ugeperioden må ikke automatisk antages at følge kalenderugen, og 5-timersperioden må ikke antages at starte ved appens opstart.
3. Appen skal opdatere forbrugsdata automatisk med et konfigurerbart interval, som udgangspunkt hvert 5. minut, hvis datakilden tillader det.
4. Brugeren skal kunne opdatere data manuelt.
5. Nedtællinger skal opdateres lokalt mindst én gang i minuttet.
6. Ved et nulstillingstidspunkt skal appen forsøge at hente nye data. Den må først vise en genopfyldt kvote, når dette er bekræftet af datakilden.
7. Lav resterende kvote skal markeres med tekst og farve: advarsel ved højst 20 % og kritisk ved højst 5 %.
8. Hvis kontoen har flere kvoter eller modeller, skal det fremgå, hvilken kvote visningen gælder for. Brugeren skal kunne vælge mellem tilgængelige kvoter.
9. Appen skal huske vinduets placering og brugerens indstillinger mellem opstarter.

## Data og integration

- Før implementering skal det afklares, om den relevante ChatGPT-konto stiller oplysninger om begge perioder til rådighed gennem en understøttet datakilde.
- Begge produkter er omfattet. Det skal verificeres særskilt, hvilke kvoter og perioder hvert produkt stiller til rådighed. Delte kvoter må ikke tælles dobbelt, og forskellige kvoter må ikke sammenblandes.
- Appen må ikke beregne resterende kvote ud fra lokal brugstid eller gætte kvoten ud fra antallet af sendte beskeder.
- Hvis automatisk aflæsning ikke er mulig, skal appen tilbyde manuel indtastning af resterende procent og nulstillingstidspunkt for hver periode. Manuelle data skal være tydeligt markeret og må ikke automatisk nedskrives som målt forbrug.
- Manglende oplysninger skal vises som **Ukendt** eller **Ikke tilgængelig**, aldrig som 0 % eller 100 %.
- Ved forbindelsesfejl skal seneste kendte værdier bevares og tydeligt markeres som forældede sammen med tidspunktet for seneste vellykkede opdatering.

## Øvrige krav

- Dansk brugerflade med letlæselig tekst og understøttelse af lyst og mørkt tema.
- Lavt ressourceforbrug, så appen kan være åben i baggrunden.
- Loginoplysninger og eventuelle adgangstokens skal opbevares sikkert i operativsystemets nøglering og må ikke skrives i logfiler.
- Første version udvikles i Swift med SwiftUI og AppKit til macOS på Apple Silicon (arm64). Intel-understøttelse er ikke et krav.
- Appen skal kunne installeres og bruges på brugerens Macs. Udgangspunktet for første version er macOS 27.0 eller nyere, baseret på den lokalt aflæste macOS 27.0.1. Andre Macs er ikke aflæst; kompatibilitet kontrolleres ved installation.
- Appen skal kunne køre selvstændigt på hver Mac uden udviklingsværktøjer. Synkronisering mellem maskiner er ikke et krav til første version.

## Acceptkriterier

- Brugeren kan se begge perioders resterende kvote og “Frem til”-tidspunkt i ét kompakt vindue.
- Nedtællinger viser korrekt tid til de oplyste nulstillingstidspunkter i lokal tidszone.
- Manuel opdatering og automatisk opdatering viser nye værdier, når datakilden leverer dem.
- Manglende data, manuelle data og forældede data kan tydeligt skelnes fra aktuelle, automatisk hentede data.
- En udløbet periode medfører ikke, at appen viser en ubekræftet genopfyldning af kvoten.
- Appen husker vinduets placering og valget om altid at ligge øverst efter genstart.

## Uden for første version

- Forbrugshistorik, statistik og eksport.
- Administration af flere konti samtidigt.
- Mobilapp og synkronisering mellem enheder.
