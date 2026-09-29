# Kézben tartás: második vetítő ablak (Linux + vezérlőablak elrejtése)

Ág: `hide_ctrl_window`. Alap: `main` (`0f2e4a3`). Ez a jegyzet a munkafát
folytató agentnek szól, nem felhasználói dokumentáció — a `docs/` az külön téma.

## Mi a cél

A második „Vetítő ablak” (desktop projector) két hibája:

1. a tartalom nem jut el a vetítőre Linuxon;
2. a „Vezérlő ablak elrejtése” nem működik Linuxon (szürkés-fekete ablak,
   élő gyorsbillentyűk, kattintásra sem jön vissza).

**Platformfüggetlen** megoldás kell. Egy korábbi, csak Linuxra szűkített
változat elutasítva lett, mert a Win/macOS működést is elrontotta. Bármely
javaslat, ami `if (Platform.isLinux)` ágra épül, rossz.

## Amit a tulajdonosnak ellenőriznie kell

Nem tudtam Linuxon futtatni. A Linux-ág natív plugin forrásból levezetett,
nem próbált kód. Kötelező ellenőrzés LinuxMint-en:

- `windowManager.hide()` elrejtés → valóban eltűnik a vezérlő ablak;
- kattintás a vetítésre → visszaáll és fókuszba kerül;
- `ready` kézfogás → a tartalom megérkezik az indulás után;
- a `unidirectional` vezérlőcsatorna → működik-e az átadás;
- a `desktopProjectorBridge.hideControlWindow()` `true`-t ad-e (a controller
  csak ekkor üríti ki a vezérlőfelületet).

Windows 10-en ismét ellenőrizendő: a korábbi `opacity 0.01` trükköt egy
DPI/surface desync komment védte, ami torz visszarajzolást okozott. A `hide()`
mellett ez elvész, de ha most is szellemkép látszik, az más ok.

## A négy terület és a megoldás

### 1. Adatátvitel

A `diatar/desktop_projector_control` csatorna `bidirectional` →
`unidirectional`. Ez leveszi a 2-motoros `CHANNEL_LIMIT_REACHED` korlátot
natív oldali javítás nélkül (`patches/desktop_multi_window/linux/
window_channel_plugin.cc`: egyirányúként 1 kezelő kell, és azt bárki hívhatja;
a `GetTarget` bármely hívónak visszaadja). A forgalom csak vetítő → fő irányú.

Új `ready` kézfogás: a vetítőmotor indulás után szól, a vezérlő azonnal
visszaküldi a függőben lévő állapotot. A korábbi néma feladás (10 próba) megszűnt.

A `_invoke` helyreállítás már nem dobja el a controllert átmeneti csatornahibán
(`CHANNEL_UNREGISTERED` / `CHANNEL_NOT_FOUND` / `NO_HANDLER`) — ez volt a
duplikált ablakok forrása. A nem átmeneti hibák sorosított helyreállítást
indítanak (`_scheduleProjectorRecovery`).

### 2. Főablak elrejtése

`setOpacity` + `setIgnoreMouseEvents` helyett minden platformon
`windowManager.hide()`.

A gyökérok: a régi `hideControlWindow()` egyetlen `try` blokkban hívta a
`setOpacity`-t, és a Linuxon nem létező `setIgnoreMouseEvents` (window_manager
0.5.2) dobott → a `setOpacity` sosem futott le. Windows-on is 0.01 maradt
átlátszóságként, ami a szürkés-fekete ablak. A `setIgnoreMouseEvents`
Linuxon `respond_not_implemented`-re esik, a `gtk_widget_set_opacity`
pedig compositing managert igényel.

A `hideControlWindow()` / `showControlWindow()` most `bool`-t ad vissza, és a
controller csak siker esetén állítja a `_controlWindowHidden` jelzőt.

### 3. Gyorsbillentyűk a vetítőablakból

Új `lib/src/core/hotkeys/desktop_hotkey_dispatch.dart`:
`DesktopHotkeyKind` / `DesktopHotkeyCommand` (`toMap`/`fromMap`) +
`desktopHotkeyCommandForEvent`. A vetítőablak feloldja a kombinációt és
`{kind, value}` parancsot küld, a fő ablak `runDesktopHotkeyCommand`-ban hajtja
végre.

Régebben a vetítőablak csak a `desktopActionHotkeys` táblázatot nézte, a dal- és
sorrend-kötetek nem működtek onnan. Most mindhárom, ugyanazzal a resolverrel,
mint a fő ablak (`DesktopHotkeysLayer`).

### 4. Kattintás

`showControl` → `windowManager.show()` + `focus()`. A korábbi
`setOpacity(1.0)` + `setIgnoreMouseEvents(false)` Linuxon nem futott le.

## Életciklus

A vetítőablak **egységesen hide-only**, minden platformon. A bezárás Linuxon
crash-t okoz ("The implicit view cannot be removed"), és a motor megszűnésével
a natív csatorna-regisztráció árva marad (`g_object_ref` leak a
`window_channel_plugin.cc`-ben). A `_isLinux` elág és a `window_close` metódus
is megszűnt. A `_controller` cache-eket töröl, de a rejtett ablak megtartja az
utolsó képkockáját, szóval az elrejtés nem veszít tartalmat.

A felhasználói bezárás (`onWindowClose`) most `windowManager.hide()`, nem
`_shutdown()`.

## Érintett fájlok

| Fájl | szerep |
|---|---|
| `lib/src/services/desktop_projector_bridge.dart` | szállítás, elrejtés, helyreállítás |
| `lib/src/ui/desktop_projector_window.dart` | vetítőablak, `ready`/`focus`/hotkey |
| `lib/src/core/hotkeys/desktop_hotkey_dispatch.dart` | új: parancsmodell + resolver |
| `lib/src/core/hotkeys/desktop_hotkey.dart` | áthelyezve innen: `lib/src/ui/` |
| `lib/src/controllers/diatar_main_controller.dart` | `runDesktopHotkeyCommand` (~4842), hide/show (~4936) |
| `lib/src/ui/desktop_hotkeys_layer.dart` | fő ablak Focus réteg, közös resolver |
| `lib/main.dart` | duplikált control handler eltávolítva |
| `test/desktop_hotkey_dispatch_test.dart` | új, 8 teszt |

## Állapot

`flutter analyze`: 0 hiba, 3 előzetesen is meglévő info
(`custom_order_editor_sheet.dart` deprecation, `patches/flutter_webrtc` 2 info).

`flutter test`: 188 zöld.

**Nincs commitolva, nincs pusholva** — a tulajdonosé. A munkafa tiszta volt a
`6f0ff21` commitnál; ha ez a jegyzet a repóban van, az valószínűleg egy későbbi
commitban érkezett.

## Amit a tulajdonos döntött el, ne módosítsd

- `version:` és `release-notes/` a tulajdonosé.
- A `_useRenderedText` továbbra is `DIATAR_DISABLE_IMPELLER=1` mögött maradt
  (régi Intel GPU-k) — ez külön, külön nem bántott Linux-szövegrenderelési
  kerülőút.
