# Vetítés

A Diatár többféle módon küldheti a diákat a vetítőre.

## TCP/IP (helyi hálózat)

A vetítő és a kontroller azonos helyi hálózaton kell, hogy legyen.

1. A **Beállítások** → **Helyi hálózat** szakaszban add meg a vetítő IP-címét és portját (alapértelmezetten 1024).
2. A **Vetítés BE** gombal indítsd el a vetítést.
3. A Diatár TCP-kliensként csatlakozik a megadott címhez.

## Internetes közvetítés (MQTT)

Ha a két eszköz nem ugyanazon a hálózaton van, MQTT segítségével közvetíthetsz.

1. A **Beállítások** → **Internet** szakaszban kapcsold be az internetes közvetítést.
2. Regisztrálj egy MQTT felhasználót (regisztráció gomb).
3. Add meg a MQTT felhasználónevet és jelszót.
4. A **QR-kód** gombbal láthatod a QR-kódot, amit a DiaVetito webes verziójában beolvasva gyorsan csatlakozhatsz.

### A jelszó kezelése

A jelszó a beállításokban **nem olvasható vissza**. Amit elmentesz, azt a
program a gép biztonságos tárban (Android Keystore, iOS/macOS Keychain,
Windows DPAPI, Linux libsecret, böngészőn WebCrypto) őrzi, a beállítások
fájlában pedig csak titkosítva, AES-256-GCM-mel jelenik meg. A mező mindig
üresen nyílik, ezért:

- **üresen hagyva** a tárolt jelszó változatlan marad;
- **beírva** új jelszóra cseréli az elmentettet;
- a **Jelszó eltávolítása** gomb törli az elmentettet.

Ha a gépen nincs elérhető biztonságos tár, a program ezt jelzi a beállításokban,
és ilyenkor a jelszó titkosítva, de a beállítások fájlában marad — ilyenkor
azt, aki hozzáfér a beállításokhoz, vissza tudja olvasni.

## Asztali vetítőablak

Asztali környezetben (macOS, Windows, Linux) külön ablakban is vetíthetsz:
