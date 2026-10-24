# Hiányzó felületek

**A fájl célja változott.** Korábban a `home_page.dart` kikommentezett
`/* */` blokkjait listázta, hogy ne tekintsük késznek, ami nincs. A
`home_page.dart`-ben ma **nincs egyetlen kikommentezett blokk sem**, és a
fájl 6180 soros, szóval a sorhivatkozások már régen nem tartoznak semmihez.

Amit alább írunk, azok **hiányzó kezelőfelületek** — kész háttérmunkával,
amelyre senki nem hív. Nézd meg, mielőtt úgy döntesz, hogy valami
nincs implementálva.

## Transzponálás

Az engine és a tárolás kész, a gombok hiányoznak. Egyetlen hívója sincs
semminek, amihez hozzáférne a kezelő:

| Kész rész | Hely |
|---|---|
| `TranspositionUtils` — akkord, kotta, kevert sor | `packages/diatar_common/lib/utils/transposition_utils.dart` |
| `setTransposition(int)` — eltárolja, elmenti, újrajelez | `diatar_main_controller.dart:4340` |
| `currentTransposition` + a `displayLines` / `projectionDisplayLines` útvonal áttranszponál | ugyanott |
| `loadTranspositions` / `saveTranspositions` | `settings_store.dart:107` / `:119` |
| `transposeUp`, `transposeDown`, `transposeReset` l10n kulcs | `app_hu.arb`, `app_en.arb` |

**Két dolog kell hozzá, és az egyik nem csak UI:**

1. A `home_page.dart`-ben nincs semmi, ami meghívná a
   `setTransposition`-t. A három ARB kulcs emiatt halott.
2. A `packages/diatar_common/lib/services/dtx_parser.dart` **soha nem
   állítja** a `DtxSong.transposition` mezőt, így az énekkönyvből jövő
   alapértelmezett transzpozíció mindig 0. Ha ez élesben kell, a DTX
   megfelelő mezőjét is implementálni kell — ez formátumismeret, nem
   egyszerű bekötés.

## Már kész, korábban itt szerepelt

Ezek a sorok a valóságban nem kikommentezett kódot, hanem már kész
funkciót jelöltek:

- **Napi lelki batyu** — kész: `napi_lelki_batyu_service.dart`, a
  `customOrderLooksLikeBatyu` a controllerben, `docs/batyu.md`, és
  benne van az `mkdocs.yml` navban.
- **Fényképnézet** — kész: `_FileImageWidget`, `_PhotoPreviewWithFallback`,
  `_CustomImagePreview` a `home_page.dart`-ben.
- **reloadbooks** — kész és be van kötve: `home_page.dart:2057`.
