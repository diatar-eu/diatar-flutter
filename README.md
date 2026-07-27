# Diatár

Templomi énekkivetítő alkalmazás. Több platformon: Android, iOS, Web, macOS, Windows, Linux.

## Funkciók

- **Énektárak (DTX):** Letöltés, kezelés, böngészés könyv/ének/verszszak szerint
- **Kottafotók (DTZ):** Kotta és akkord képek megjelenítése versszakok mellett
- **Egyéni énekrend:** Összeállítás, szerkesztés, .dia import/export, több párhuzamos sorrend
- **Vetítés:** TCP/IP (helyi), MQTT (internet), Google Cast, asztali vetítőablak
- **Zsolozsma:** Napi zsolozsma betöltése és diákká alakítása
- **Napi lelki batyu:** Napi olvasmányok importálása
- **Szentírás:** Biblia versek beillesztése (szentiras.eu API)
- **Keresés:** Teljes szöveges keresés énektárakban
- **Hang:** Versszakokhoz tartozó hangfájlok lejátszása
- **Billentyűparancsok:** Asztali gyorsbillentyűk a vezérléshez
- **Biztonsági mentés:** Teljes adatmappa ZIP export/import

## Indítás

```bash
cd Ditar
flutter pub get
flutter run
```

A projektben két alkalmazás van:
- `Diatar/` -- a vezérlő alkalmazás (ide építed az énekrendet és küldöd a vetítőre)
- `DiaVetito/` -- a vevő alkalmazás (a kivetítő gépen fut)

Részletes dokumentáció: [https://web.diatar.eu/docs/](https://web.diatar.eu/docs/)

## Tesztelés

```bash
cd Diatar && flutter test
```