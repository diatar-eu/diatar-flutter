# Letöltések és importálás

## Windows-telepítő

[A legfrissebb Windows-telepítő letöltése](https://web.diatar.eu/downloads/Diatar/Diatar-Setup.exe)

A `Diatar-Setup-<verzió>-windows-x64.exe` egyetlen telepítőben tartalmazza a
**Diatár** és a **DiaVetítő** programot. Windows 10 (1809-es vagy újabb), illetve
Windows 11 64 bites rendszerre telepíthető.

A fenti hivatkozás állandó: minden webes vagy kiadási közzétételkor az új
telepítő kerül erre a címre. A letöltött fájl neve `Diatar-Setup.exe`.

1. Indítsd el a telepítőt, és engedélyezd a rendszergazdai jogosultságot.
2. Válaszd ki, hogy mindkét programot, csak a Diatárt vagy csak a DiaVetítőt kéred.
3. Igény szerint kérj asztali parancsikonokat, majd indítsd el a telepítést.

A szükséges Microsoft Visual C++ futtatókörnyezetet a telepítő tartalmazza és
szükség esetén telepíti; ehhez internetkapcsolat nem kell. Külön Flutter, Dart
vagy .NET telepítése nem szükséges. Ha a telepítő újraindítást kér, a programok
első indítása előtt indítsd újra a számítógépet.

A programok a Start menüből indíthatók. Újabb verzió ugyanazzal a telepítővel
rátelepíthető a régire; a saját adatok megmaradnak. Korábban telepített komponens
kijelölésének elhagyása nem távolítja el azt: eltávolításhoz a Windows
**Telepített alkalmazások** listájában keresd a **Diatár és DiaVetítő** bejegyzést.
Az eltávolítás a közös csomag mindkét telepített programját törli, a saját
adatokat és a más programok által is használt VC++ futtatókörnyezetet nem.

A telepítő egyelőre nincs digitálisan aláírva, ezért a Windows SmartScreen
figyelmeztethet. Csak megbízható Diatár-forrásból származó telepítőt indíts el.
Windows N kiadáson a kamera- és hangfunkciókhoz a Windows Médiafunkció-csomagja
is szükséges lehet. Az énektárak és egyéb tartalmak letöltése továbbra is a
programból történik.

## Linux – Flatpak-telepítők

Mindkét program külön telepíthető:

| Program | Intel/AMD 64 bit | ARM 64 bit (például Raspberry Pi) |
|---|---|---|
| Diatár | [Letöltés](https://web.diatar.eu/downloads/Diatar/Diatar-x86_64.flatpak) | [Letöltés](https://web.diatar.eu/downloads/Diatar/Diatar-aarch64.flatpak) |
| DiaVetítő | [Letöltés](https://web.diatar.eu/downloads/DiaVetito/DiaVetito-x86_64.flatpak) | [Letöltés](https://web.diatar.eu/downloads/DiaVetito/DiaVetito-aarch64.flatpak) |

Először a Linux-disztribúciód csomagkezelőjével telepítsd a Flatpakot.
Ezután a letöltött fájl könyvtárában futtasd:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./Diatar-x86_64.flatpak
flatpak install --user ./DiaVetito-x86_64.flatpak
```

ARM gépen a fájlnevekben az `x86_64` helyett `aarch64` szerepeljen.
Raspberry Pi esetén 64 bites, grafikus Linux szükséges; a 32 bites rendszer
nem támogatott. Az első telepítés internetkapcsolatot igényel, mert a közös
GNOME futtatókörnyezetet a Flathubról tölti le. Flutter vagy Dart nem kell.

A programok az alkalmazásmenüből, illetve a `flatpak run eu.diatar.diatar`
és `flatpak run eu.diatar.vetito` parancsokkal indíthatók.
Frissítéshez töltsd le az újabb `.flatpak` fájlt, majd a telepítésnél add meg a
`--reinstall` kapcsolót, például:
`flatpak install --user --reinstall ./Diatar-x86_64.flatpak`.
A saját adatok megmaradnak.
Egyelőre nincs saját frissítési tároló vagy hivatalos Flathub-megjelenés:
a `flatpak update` önmagában nem tölti le a program új verzióját.

A csomagok nincsenek digitálisan aláírva; csak a fenti HTTPS-hivatkozásokról
vagy a projekt GitHub-kiadásaiból töltsd le őket. A programok hozzáférnek a
saját könyvtáradhoz, a hálózathoz, a hanghoz, a kijelzőkhöz és az eszközökhöz
(például a kamerához); nem szigorúan elkülönített alkalmazások.

## Énektárak (DTX) letöltése

1. Kattints a **Letöltés** gombra a főképernyőn
2. A letöltési párbeszédben jelöld ki a letölteni kívánt könyveket vagy a frissíteni kívánt könyveket
3. A **Letöltés** gombbal indítsd el a letöltést
4. A letöltési folyamat statusza alul látható

## Kották (DTZ) letöltése

1. Válts a **Letöltés** ablak **Kották** lapjára
2. Jelöld ki a DTZ fájlokat és a hozzájuk tartozó képeket (ZIP)
3. Nyomj a **Letöltés** gombra

## Zenék letöltése

1. Válts a **Letöltés** ablak **Zenék** lapjára
2. A kötetek alapértelmezetten mellőzöttek; a frissítés jelölésével válaszd ki a letöltendő zenéket
3. Nyomj a **Letöltés** gombra
4. A zenék a hozzájuk tartozó DTZ- és ZIP-csomagból kerülnek kibontásra; a mellőzött csomagok helyi fájljai törlődnek

## Felhasználói import

- **DTX importálás fájlból** — saját `dtx` fájlok importálása
- **DTZ importálás** — saját `dtz` fájl és médiumok importálása
- A fájlok automatikusan ellenőrzésre kerülnek (párosított médiafájlok, helyes dia-azonosítók)

## Biztonsági mentés

A **Beállítások → Fájlok** szakaszban:
- **Exportálás** — a teljes Diatár adatmappa ZIP-be mentése
- **Importálás** — korábban mentett biztonsági mentés visszaállítása
- Konfliktus esetén felülírás vagy mellőzés választható

### iPhone és iPad

Mivel iOS-en nincs rendszer-mentőpárbeszéd, az export a program saját
mappájába kerül. A mentett ZIP a **Fájlok** alkalmazásban a **Saját iPhone →
Diatár → export** útvonalon található, ahonnan továbbítható felhőbe, e-mailbe
vagy számítógépre. Az **Importálás** ugyanabból a mappából választja ki a
visszaállítandó ZIP fájlt.