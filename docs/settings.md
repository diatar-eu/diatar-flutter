# Beállítások

A beállítások a fő képernyő **Beállítások** gombjával nyithatók meg. Minden szekció egy-egy bottom sheet-ben jelenik meg.

## Letöltések és a beállítások tárolása

A **Beállítások → Énektárak letöltése** ablakban énektárak, kották és zenék
tölthetők le, illetve kézzel újraletölthetők. Induláskor a program felajánlja
a letöltést, ha nincs betölthető énektár, vagy egy már telepített, hivatalos,
nem kizárt csomaghoz frissítés érhető el. Az összes énektár letiltása nem
számít üres könyvtárnak.

Üres énektárkönyvtár esetén az ablak internetkapcsolat nélkül is megjelenik,
és a hálózati állapot változása nem törli a letöltési felajánlást. Ha a
letöltési lista nem érhető el, az ablak hibát jelez. Az automatikusan
megnyitott ablak bezárása után a program ugyanabban a futásban nem ajánlja
fel újra; kézzel továbbra is megnyitható.

A frissítésvizsgálat nem fájl-épségellenőrzés: a mentett letöltési adatok
alapján keresi a szerveren elérhető újabb kiadásokat. Az énektárak és a
DTZ leírófájlok meglétét ellenőrzi, de a fájlok tartalmát és a kibontott
kép- és hangfájlok épségét nem vizsgálja. Sérülés vagy hiányzó kép, hang
esetén a letöltőablakban kézi frissítéssel lehet újraletölteni az érintett
csomagot.

Linuxon a letöltések a rendszer Dokumentumok könyvtárának `diatar`
almappájába kerülnek: az énektárak a `DTXs`, a kották a `DTZs`, a zenék a
`DTZs/Music` mappába. A Dokumentumok könyvtár neve és helye a rendszer
beállításaitól függ.

A beállítások és a letöltési nyilvántartás ettől külön tárolódnak, normál
esetben a `~/.local/share/eu.diatar.diatar/shared_preferences.json` fájlban.
Ha az `XDG_DATA_HOME` környezeti változó be van állítva, a fájl annak
`eu.diatar.diatar` almappájában található. Régebbi telepítésnél a
`diatar_app` nevű almappa is használatban maradhat. A Dokumentumok
könyvtárában lévő `diatar` mappa törlése tehát nem törli a beállításokat.

## Internet

- **Internetes közvetítés** — MQTT alapú távoli vetítés
- **MQTT felhasználó/jelszó** — hitelesítési adatok
- **MQTT csatorna** — a vetítés átszállítási csatorna
- **QR-kód** — a DiaVetito webes ứngus gyors megnyitásához
- **Felhasználói műveletek** — regisztráció, jelszóváltoztatás, fiók törlés
- **Szentírás API kulcs** — a szentiras.eu API-hoz tartozó kulcs

## Helyi hálózat (TCP/IP)

- **TCP kliens** — be/ki kapcsoló
- **Célpontok** — IP cím és port lista (soronként)

## Színek

- **Háttér** — a vetített dia háttérszíne
- **Szöveg** — a szöveg színe
- **Üres dia** — az üres (kék) dia színe
- **Kiemelés** — a kiemelt szavak színe

## Vetítési beállítások

- **Betűméret** — alap betűméret px-ben
- **Cím méret** — cím betűmérete px-ben
- **Margók** — bal, jobb, felső, alsó margó pixelben
- **Sorköz** — a sorköz mérete
- **Kotta/Akkord arány** — a kotta és akkord méretezése
- **Háttér mód** — Center, Zoom, Full, Cascade, Mirror
- **Automatikus méretezés** — a szöveg automatikus igazítása
- **Vízszintes/függőleges középre igazítás**
- **Akkordok/Kotta/Háttérkép mutatása**
- **Szókiemelés** — kulcsszó kiemelés a vetítés közben
- **Félkövér szöveg**

### A szövegbe ágyazott kotta

A kottakulcs és az előjegyzés a következő kottasorokra is érvényes;
sortörés után automatikusan megismétlődik, az új kulcsra váltás pedig
a megadott helyen történik. A csökkentett számú kottavonal szintén
érvényben marad, amíg új vonalszám nincs megadva.

A hangok helyét a kotta és a hozzájuk tartozó szöveg közös helyigénye
határozza meg, a régi androidos Diatárhoz igazodva. Tömör módban az egy
szövegrészhez tartozó hangcsoporton belül a hangfejek összeérhetnek,
a következő szövegrész hangcsoportja előtt viszont legalább egy hangfejnyi
hely marad. A hosszabb szöveg helyigénye ezen felül is érvényesül.
A kulcsok és ütemjelek után a dalszöveg is beljebb
kezdődik. A **Kotta/Akkord arány** kottaértéke nagyobb betűméretnél is
arányosan változtatja a kottát, a szöveg betűmagasságából kiindulva.

Az ütemvonalak mindig a kódolásban megadott helyükön jelennek meg:
a `||` kettősvonal nem kerül át automatikusan a sor vagy az utolsó
szótag végére. A vékony–vastag záróvonal külön jelölés (`|.`).
A kottavonalak a teljes sor tartalmáig, a hosszabb dalszöveg végéig
is elérnek. A kottarajzolás alapja az eredeti androidos algoritmus,
a következő tudatos eltérésekkel: a gerendás és a különálló hangok
alapszárhossza egyaránt három vonalköz; a dallamív követéséhez a szárak
hosszabbodhatnak. Az egymagasságú hangok triola- és kvintolajelölése
vízszintes, és vonala a szárvégektől háromnegyed vonalközre halad,
nem fél vonalközre.

Kottás versnél minden szövegsor kap kottasávot. A tördelt
sorok külön-külön kerülnek középre. A közönséges kötőjel nem töri meg
a kottához kötött szót; feltételes elválasztáshoz a `\-` jelölés használható.
A `\.` sortörési javaslat akkor kap elsőbbséget, ha ettől nem nő a
szükséges sorok száma.
Kikapcsolt automatikus méretezésnél a hosszú szótagok betűmérete sem
csökken külön: ha nem férnek el, az **Automatikus méretezés**
bekapcsolásával vagy kisebb betűmérettel lehet helyet biztosítani.