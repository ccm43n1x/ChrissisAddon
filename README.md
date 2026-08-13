# Chrissi's Addon

Gearing-Checkliste und Währungs-Übersicht für World of Warcraft, Midnight Season 2 (Patch 12.1).

Zeigt in einem Fenster:

- **Angepinnte Währungen** ganz oben: Mistcrests, Sparks, Coffer Keys, Voidcores, Field Accolades, jeweils mit Wochen-Cap
- **Checkliste** nach Wochen, sortiert in vier Blöcke: Jetzt tun, Danach, Nur wenn Zeit, Nicht tun
- **Alle Währungen** im zweiten Reiter

## Installation

1. Ordner `ChrissisAddon` nach `World of Warcraft\_retail_\Interface\AddOns\` kopieren
2. WoW neu starten oder `/reload` eingeben
3. Im Spiel `/chrissi` tippen

Wichtig: Der Ordner muss exakt `ChrissisAddon` heißen, sonst lädt WoW ihn nicht.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/chrissi` | Fenster auf/zu |
| `/chrissi quellen` | Guide-Stand und Quellenliste |
| `/chrissi scan` | Alle Währungs-IDs ins Chatfenster |
| `/chrissi clear` | Alle Haken dieses Charakters löschen |
| `/chrissi zero` | Nullbestände ein-/ausblenden |
| `/chrissi reset` | Fensterposition zurücksetzen |
| `/chrissi help` | Befehlsübersicht |

Fenster ist mit der linken Maustaste verschiebbar. Position und Reiter überleben den Logout.

## Wie die Haken funktionieren

Jeder Eintrag hat eine feste ID. Der Haken hängt an dieser ID, nicht an der Zeilennummer. Der Guide-Text kann also umformuliert oder umsortiert werden, ohne dass dein Fortschritt verloren geht.

**Haken werden pro Charakter gespeichert.** Jeder Twink hat seine eigene Liste.

Wiederkehrende Aufgaben tragen über mehrere Wochen dieselbe ID, zum Beispiel die wöchentliche Spark-Quest.

## Guide aktualisieren

Der gesamte Inhalt steht in **`data.lua`**. Diese Datei enthält keine Logik, nur Text. `main.lua` muss dafür nicht angefasst werden.

Ein Eintrag sieht so aus:

```lua
{
    id    = "w0_m0tour",    -- feste ID, NIE ändern
    text  = "Alle acht M0-Dungeons einmal ...",
    kind  = "task",         -- "task" = abhakbar, "rule" = Merksatz ohne Haken
    block = "P1",           -- P1 jetzt tun, P2 danach, P3 nur wenn Zeit, NO nicht tun
    proof = "ok",           -- "ok" = mehrfach belegt, "single" = eine Quelle
},
```

Nach dem Bearbeiten im Spiel `/reload`.

Wird eine ID geändert, gilt der Eintrag als neu und der Haken ist weg. Deshalb: Text ändern ja, ID ändern nein.

## Quellenlage

Einträge mit `proof = "single"` stammen aus einer einzelnen, ungeprüften Quelle und sind im Fenster mit `[1 Quelle]` markiert. Alles andere ist gegen mindestens zwei der folgenden Quellen geprüft:

- Blizzard (offizielle Patch-Notes)
- Method
- Icy Veins
- Wowhead
- Warcraft Wiki

Der Guide-Stand steht im Fenster unter dem Titel und ist über `/chrissi quellen` abrufbar.

## Bekannte Einschränkungen

- **Die angepinnten Währungen greifen nur auf einem englischen Client.** Sie werden über den Namen erkannt (`Mistcrest`, `Spark Dust`, ...). Auf einem deutschen Client bleibt der Block leer, der Reiter „Waehrungen" funktioniert aber weiterhin. Eine sprachunabhängige Lösung über Währungs-IDs ist geplant.
- **Eingeklappte Kategorien** im Blizzard-Währungsfenster verstecken ihre Einträge auch hier. Einmal im Charakterfenster unter Währung aufklappen.
- Das Add-on liest nur aus und rechnet. Es trifft keine Entscheidungen für dich und kann nichts automatisch ausführen. Das lässt die WoW-API nicht zu.

## Lizenz

MIT, siehe `LICENSE`.

Der Guide-Inhalt stammt aus eigener Recherche. Die Idee, eine Wochen-Checkliste über feste Hash-IDs abzubilden, ist an Larias' Weekly Checklist angelehnt. Es wurde kein Code daraus übernommen.
