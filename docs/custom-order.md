# Diasor

Az diasor összeállítása a **Diasor** ablakban érhető el.

## Diasor létrehozása

1. A felső sávban nyomj a **Diasor** gombra
2. Válaszd ki, mit szeretnél hozzáadni:
   - **Ének** — konkrét versszakokkal
   - **Szöveges dia** — saját szöveg beírása
   - **Képes dia** — kép hozzáadása
   - **Elválasztó** — vizuális elválasztó a diák között
   - **Zsolozsma** — napi zsolozsma betöltése
   - **Napi lelki batyu** — napi olvasmányok betöltése
   - **Szentírás** — bibliai versek beillesztése

## Diasor szerkesztése

- **Csoport áthelyezés** — több dia egyszeri áthelyezése egy csoportban
- **Átnevezés** — a diasor neve szerkeszthető
- **Törlés** — a diasor eltávolítása
- **Kapcsolás** — a diasor be-/kapcsolása (a kikapcsolt nem jelenik meg a nézetekben)

### Akkordok a szöveges diákban

A szöveges dia szerkesztőjének akkord gombjával külön ablakban választható ki
az alaphang, a dúr vagy moll jelleg, a hangzat és az opcionális basszushang. Az
akkord a szövegben vékony keretben, egyetlen elemként jelenik meg: egyben
kijelölhető, kivágható, másolható, beilleszthető és törölhető. Dupla kattintással
ismét megnyitható az akkordszerkesztő ablak.

### Kotta a szöveges diákban

A kotta helyét a szövegben egy keskeny, színes vonás jelzi. A jelölés a
közvetlenül utána álló szótaghoz tartozik, ezért a teljes szótag másolásakor,
kivágásakor vagy törlésekor a kotta is vele mozog. A kotta a szerkesztő
eszköztárából vagy a **Ctrl+K** billentyűvel szúrható be; meglévő jelölésen
ugyanez a billentyű, illetve a dupla kattintás nyitja meg a külön
kottaszerkesztőt. Az ablak a kottát és a hozzá tartozó szöveget együtt,
vetítési előnézetben mutatja.

A felső előnézetben egérkattintással vagy ujjal koppintva a legközelebbi
szerkesztési pozícióra léphetünk. A kottasorra kattintva a kottakurzor,
a szövegsorra kattintva a szövegkurzor lesz aktív. A balra/jobbra
nyílbillentyűkkel az aktív kurzor mozgatható, a **Tab** pedig vált a két
kurzor között. Hosszú soroknál az előnézet vízszintesen görgethető.

A kottasorban lenyomott bal egérgombbal húzva, illetve aktív kottakurzor
mellett a **Shift+balra/jobbra** billentyűkkel több kottaelem jelölhető ki.
A kijelölt részt kék háttér jelzi. A **Kulcs**, **Előjegyzés**,
**Ütemvonalak**, **Ütemjelek**, **Szünet** vagy **Hang** bármely beszúrógombja a kijelölt
kottaelemeket egyetlen új elemre cseréli; a hozzájuk tartozó szöveg megmarad.
Kattintással vagy a **Tab** billentyűvel megszüntethető a kijelölés.
Shift nélküli nyílbillentyűvel a kijelölés megfelelő végére léphetünk.

A **Kulcs** sorban a többi grafikus gombbal azonos méretű gombok a kulcs képét
mutatják ötvonalas háttéren. A Do-kulcsok vektorosan rajzolt jelek, ezért
nagy felbontáson is élesek, és nem igényelnek telepített zenei betűtípust.
Választható G- és F-kulcs, szoprán-, mezzoszoprán-, alt-, tenor- és
baritonkulcs (C-kulcs az 1–5. vonalon), valamint Do-kulcs mind az öt vonalon
és a négy vonalközben. A kulcs neve egér fölévitelére, mobilon hosszú
koppintásra jelenik meg.

Az **Előjegyzés** sorban az **1♭–7♭** és **1#–7#** gombokkal
szúrható be előjegyzés. Egér fölévitelére vagy hosszú koppintásra a hozzá
tartozó dúr és párhuzamos moll hangnem jelenik meg, például
**F-dúr/d-moll**, **B-dúr/g-moll**, illetve **G-dúr/e-moll**.

Az **Ütemvonalak** sor nyolc grafikus gombja sorrendben: szimpla,
dupla, záró ütemvonal, rövid cezúra, hosszú cezúra, nyitó ismétlőjel,
kétirányú ismétlőjel és záró ismétlőjel. A jel neve egér fölévitelére
vagy hosszú koppintásra jelenik meg.

Az **Ütemjelek** sor az ütemvonalak alatt található. A grafikus gombok
sorrendben a **4/4, 2/4, 3/4, 3/8, 6/8, 2/2, 3/2, 5/4, 6/4**
ütemjelet szúrják be; a súgó a nevüket mutatja, például **négy-negyed**.
A gombokon az ütemjel két félkövér számjegye egymás alatt jelenik
meg, így nagy felbontáson is éles és mindkét színtémában jól olvasható.

A **Szünet** sor az ütemjelek alatt található. Öt grafikus gombja sorrendben
**Egész**, **Fél**, **Negyed**, **Nyolcad** és **Tizenhatod** szünetet szúr be.
A szünetjelek kisebb méretben, a változatlan méretű gombok közepén jelennek meg.
A gombok neve egér fölévitelére vagy hosszú koppintásra jelenik meg.

A **Hang** sor a szünetek alatt található. Nyolc grafikus gombja sorrendben:
**Longa**, **Brevis**, **Semi-brevis**, **Egész**, **Fél**, **Negyed**,
**Nyolcad**, **Tizenhatod**. A szünetgombokhoz hasonlóan kisebb grafikával
és névsúgóval jelennek meg. A kiválasztott ritmusértékkel tényleges hangot
szúrnak be, a megelőző hang magasságával; ha a sorban még nincs előtte hang,
a kezdő hangmagasság `2g`. Az új hang kódja mindig kisbetűs, nagybetűs
előzmény után is; a meglévő hangkódokat ez nem módosítja.
Ritmuskód csak ritmusváltáskor kerül a hang elé.
A későbbi hangok ritmusa nem változik: szükség esetén a program az új hang
után visszaállítja az eredeti ritmusértéket. Ez kijelölt kottaelemek cseréjekor
is érvényes.

A **Szünet** és **Hang** sor végén, kis térköz után külön **Pontozott**
kapcsoló található. Önmagában nem szúr be jelet: bekapcsolva a következő
szünetet vagy hangot pontozva szúrja be. A Longa, Brevis és Semi-brevis
hangokra nincs hatása. Kijelöléskor a kapcsolók a kijelölt szünetek,
illetve hangok pontozását mutatják és kattintásra módosítják; vegyes
kijelölésnél kikapcsolt állapot látszik, és az első kattintás pontozottá
teszi az érintett elemeket. A kijelölésen kívüli hangok ritmusa és
pontozása változatlan marad.

A **Módosítójelek** sorban öt grafikus kapcsoló található: **Bé** (`mb`),
**Feloldó** (`m0`), **Kereszt** (`mk`), **Bebé** (`mB`) és **Kettős kereszt**
(`mK`). Egyszerre legfeljebb egy lehet bekapcsolva; ismételt kattintással
kikapcsolható. Kijelölés nélkül a következő beszúrt hang elé kerül a
módosítójel, majd a kapcsoló automatikusan kikapcsol. Szünet vagy más jel
beszúrása nem használja fel a választást.
Kijelöléskor a választott módosítójelet az összes kijelölt hang megkapja,
korábbi módosítójelük helyett. Ha már mindegyiken ez a módosítójel van,
a gomb eltávolítja azt. A kijelölésen kívüli hangok és a szünetek változatlanok.

A hangmagasság beszúróvezérlői átmenetileg nem érhetők el. A meglévő kották jelei továbbra
is megjelennek az előnézetben és a vetítésben.

## Export/Import

- **Mentés** — `.dia` fájl mentése a lemezre
- **Betöltés** — korábban mentett `.dia` fájl megnyitása
- Az `.dia` fájl formátum az INI fájlformátum

Asztali rendszereken a **Beállítások > Énektárak és fájlok > Automatikus
mentés** kapcsolóval kérhető, hogy a program a Diasor szerkesztő bezárásakor,
illetve a programból nyitott szerkesztő mellett történő kilépéskor lemezre
írja a módosított diasorokat. A korábban mentett vagy betöltött fájlokat a
program felülírja; az új diasorokhoz mentési helyet és fájlnevet kér. A
mentési ablak megszakításakor az adott diasor mentetlen marad.

## Betöltött diasorok száma

A **Beállítások > Általános > Diasorok száma** szabályzóval 1 és 20 között
állítható be, hány diasor lehet egyszerre betöltve. Új diasor létrehozásakor
vagy mellé töltésekor a legrégebben szerkesztett vagy vetített diasor
automatikusan törlődik, ha a beállított korlát már betelt. Gyorsbillentyűhöz
rendelt diasor nem törlődik automatikusan; ha csak ilyen diasorok maradtak, a
program figyelmeztetés mellett ideiglenesen túllépi a korlátot. Egyes korlátnál
a betöltés kérdés nélkül felülírja az aktuális diasort, kivéve, ha ahhoz
gyorsbillentyű tartozik.