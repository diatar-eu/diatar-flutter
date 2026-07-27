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

## Asztali vetítőablak

Asztali környezetben (macOS, Windows, Linux) külön ablakban is vetíthetsz:
