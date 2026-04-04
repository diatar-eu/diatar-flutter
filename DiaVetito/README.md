# DiaVetito (Flutter)

Ez a projekt a `diatar-android/DiaVetito` Flutter portja, a kovetkezo mappaban:

- `diatar-flutter/DiaVetito`

## Atultetett funkciok

- TCP szerver a regi protokollal (`RecHdr`, `State/Text/Pic/Blank/AskSize/Idle`)
- Vetitesi felulet:
	- szoveg dia kirajzolas
	- kep dia kirajzolas (center/zoom/full/cascade/mirror mod)
	- blank allapot kezelese
	- klippeles, tukrozes, 0/90/180/270 fokos forgatas
- Beallitasok panel:
	- TCP port
	- clip margok
	- Border2Clip kapcsolo
	- tukrozes es forgatas
	- boot jelzo
	- MQTT kuldo mezo (placeholder)
- Beallitasok tarolasa `shared_preferences`-ben

## Fontos megjegyzesek

- Az MQTT funkcio ebben a verzoban placeholder: ha MQTT user van megadva, a TCP figyeles leall (mint modvaltas jelzes), de MQTT kapcsolat nem epul fel.
- Az eredeti Androidos `TxtSizer` teljes logikaja nincs 1:1 atmasolva, de a szoveg-megjelenites, igazitas, autosize es kiemeles alap viselkedese megvan.

## Futtatas

```bash
flutter pub get
flutter run
```

## Ellenorzes

```bash
flutter analyze
flutter test
```
