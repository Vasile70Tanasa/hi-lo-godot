# Hi-Lo - Direcție de dezvoltare

Document de brainstorming pentru transformarea jocului Hi-Lo într-o experiență
"run-based" mai interactivă, inspirată (dar fără a copia) de Balatro.

## Problema actuală

Jocul se termină la prima greșeală. Nu există sentiment de progres, acumulare
sau decizii. Vrem să-l transformăm într-o "rulare" cu niveluri, puncte
acumulate/pierdute și mai multă interactivitate.

## Principiu de design

Balatro funcționează pentru că transformă un joc pasiv (poker) într-o rulare
cu decizii între runde. Putem aplica același principiu la Hi-Lo fără a copia
mecanici specifice.

---

## Sistem propus (run-based)

### Elemente de bază

- **Vieți (3-5)** în loc de game over instant
  - Greșești → pierzi o viață, nu tot progresul
  - Game over doar când rămâi fără vieți

- **Niveluri cu target**
  - Fiecare nivel cere X puncte strânse din Y cărți
  - Exemplu: nivelul 1 = 5 puncte din 10 cărți
  - Atingi target-ul → avansezi la nivelul următor
  - Nu atingi target-ul → pierzi o viață

- **Multiplicator pe streak**
  - 3 ghiciri corecte consecutive → x2
  - 5 consecutive → x3
  - Dă greutate ghicirilor în serie, nu doar ghicirilor izolate

- **Bonusuri între niveluri**
  - După fiecare nivel, alegi 1 din 3 bonusuri simple
  - Exemple: +1 viață, streak inițial x2, "peek" la următoarea carte (3x), etc.

---

## Două direcții posibile

### Direcția simplă (recomandată ca punct de plecare)

Doar **vieți + niveluri cu target**. Fără bonusuri încă.

**Avantaje:**
- Dă deja sentimentul de "progres" și "rulare"
- Codul rămâne manageable
- Vezi cum se simte înainte să adaugi complexitate

**Dezavantaje:**
- Mai puțin variat decât Balatro
- Nu ai "decizii între runde" încă

### Direcția ambițioasă

Adăugăm și **modificatori de nivel**:
- Nivelul 3: "doar cărțile roșii contează"
- Nivelul 5: "egal = greșit"
- Nivelul 7: "trebuie 2 ghiciri corecte consecutive ca să conteze"

**Avantaje:**
- Varietate reală, fiecare nivel se simte diferit
- Reasonable de implementat dacă arhitectura e bună

**Dezavantaje:**
- Complică logica de scor
- Mai multe edge cases de testat

**Tradeoff principal:** cât de mult vrei să planifici acum sistemul de
progresie? Simplu = ușor de extins mai târziu. Ambițios = direct la
experiența finală, dar mai mult refactor dacă te răzgândești.

---

## Cărți egale - reguli decise

### Egal simplu (două cărți consecutive cu același rang)

Momentul devine dramatic - eveniment special, nu caz banal:
1. Muzica se oprește
2. Apare text mare "EGAL!"
3. Jucătorul pariază: "Următoarea e mai mare sau mai mică decât ambele?"

**Dacă ghicește corect:** bonus dublu de puncte
**Dacă greșește:** reset streak + -1 draw (fără pierdere de viață)

Logica: transformă ceva rar într-un moment memorabil cu tensiune reală.
Pedeapsa e semnificativă (pierzi multiplicatorul și un draw) dar nu
devastatoare (vieța rămâne intactă).

### Triplu egal (trei cărți consecutive cu același rang)

- **Eveniment extrem de rar** (~0.3% probabilitate)
- **Recompensă:** bonus masiv instant de puncte + fanfare vizuală
  (confetti, animație specială, sunet de jackpot)
- **Fără pariere** - recompensă pură, fără decizie
- **Streak:** se resetează (ca la egal simplu)
- **Vieți:** neatinse

Logica: triplu egal e deja o poveste în sine. Jackpot pur fără complicații
- consistent cu logica jocului și distinct față de egalul simplu.
+1 viață e rezervat pentru alte mecanici (recompense între niveluri).

### Tabel rezumat

| Situație | Puncte | Streak | Vieți | Draw-uri |
|----------|--------|--------|-------|----------|
| Corect | +1 × multiplicator | +1 | neatinse | neatinse |
| Greșit | neatinse | reset | -1 | neatinse |
| Egal - pariere corect | +bonus dublu | reset | neatinse | neatinse |
| Egal - pariere greșit | neatinse | reset | neatinse | -1 |
| Triplu egal | +bonus masiv | reset | neatinse | neatinse |

---

## Arhitectura pentru extensibilitate

Ca să putem adăuga features ulterior fără refactor mare, sunt 3 decizii
importante de luat **acum**:

### 1. Separarea logicii de UI
`GameState` ca obiect separat de scena vizuală. Ține scor, vieți, nivel,
streak. UI-ul doar îl citește și îl afișează.

**De ce:** Poți schimba regulile jocului fără să atingi UI-ul.

### 2. Nivelurile ca date, nu cod
O listă de configurații (`{target: 5, cards: 10, rules: [...]}`) în loc să
hardcodezi fiecare nivel în GDScript.

**De ce:** Adaugi un nivel nou = o linie nouă în array, nu o funcție nouă.

### 3. Sistem de "modificatori"
Chiar dacă nu folosim modificatori acum, logica de scor ar trebui să treacă
printr-o funcție care poate fi interceptată de reguli speciale.

**De ce:** Adăugarea de bonusuri, jokere sau reguli de nivel devine trivială
mai târziu.

---

## Features ușor de adăugat ulterior

Dacă arhitectura de mai sus e respectată, toate astea devin extinderi simple:

- **Jokere / cărți speciale** (wild, skip, double)
- **Shop între niveluri** cu monede câștigate
- **Achievements / statistici** persistente
- **Moduri diferite:** daily challenge, endless, puzzle
- **Multiplayer local** (hot-seat)
- **Deck-uri tematice** (diferite culori, simboluri)
- **Boss levels** cu reguli unice
- **Narrative / progres meta** (deblochezi conținut între rulări)

## Features greu de adăugat târziu (deci merită gândite acum)

- **Animații complexe pentru cărți** - dacă UI-ul devine spaghetti, e greu de reparat
- **Save/load de run** - dacă state-ul e împrăștiat prin scene, salvarea devine un coșmar

---

## Plan de implementare sugerat

1. **Refactor: extrage `GameState` ca clasă separată**
   - Mută toată logica de scor/vieți/nivel din `main.gd` într-un obiect
   - UI-ul doar citește și afișează
2. **Adaugă sistemul de vieți** (3 vieți default)
3. **Adaugă niveluri cu target** (ca array de configurații)
4. **Adaugă multiplicator pe streak**
5. **Testează și ajustează balance-ul** (cât de greu/ușor e să treci nivelurile)
6. **Opțional:** adaugă bonusuri între niveluri
7. **Opțional:** adaugă modificatori de nivel
