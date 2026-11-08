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