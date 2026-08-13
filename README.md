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
| `/chrissi clear` | Alle Haken dieses Charakters löschen |
| `/chrissi zero` | Nullbestände ein-/ausblenden |
| `/chrissi reset` | Fensterposition zurücksetzen |
| `/chrissi help` | Befehlsübersicht |

Werkzeuge zum Ermitteln fehlender IDs:

| Befehl | Wirkung |
|---|---|
| `/chrissi scan` | Alle Währungs-IDs |
| `/chrissi questdiff` | Neue Quest-IDs. Einmal vor der Quest aufrufen, einmal danach |
| `/chrissi factions` | Fraktions-IDs und Renown-Stand |
| `/chrissi vault` | Great-Vault-Rohdaten |

Fenster ist mit der linken Maustaste verschiebbar. Position und Reiter überleben den Logout.

## Automatische Erkennung

Einträge mit `[auto]` erkennt das Add-on selbst und hakt sie ab. Der Haken lässt sich dann nicht wegklicken, weil er eine Tatsache abbildet und keine Meinung.

Erkannt wird über:

| Typ | Womit |
|---|---|
| Quests | `C_QuestLog.IsQuestFlaggedCompleted(id)` |
| Währungen | `C_CurrencyInfo.GetCurrencyInfo(id)` |
| Renown | `C_MajorFactions.GetMajorFactionData(id)` |
| Great Vault | `C_WeeklyRewards.GetActivities()` |

Alles ohne `[auto]` hakst du selbst ab. **Die Automatik entfernt niemals einen Haken, den du selbst gesetzt hast.**

Eine neue Bedingungsart hinzufügen heißt: eine Funktion in die `CHECKERS`-Tabelle in `main.lua` legen. Am Rest ändert sich nichts.

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

- **Der Reiter „Waehrungen" zeigt nur aufgeklappte Kategorien.** Eingeklappte Kategorien im Blizzard-Währungsfenster verstecken ihre Einträge auch hier. Das Add-on sagt dir, wenn welche fehlen. Einmal im Charakterfenster unter Währung aufklappen.
  Der **angepinnte Block oben ist davon nicht betroffen**, der fragt die Währungen direkt per ID ab.
- **Coffer Keys und Voidcores werden noch über den Namen erkannt** und erscheinen deshalb nur auf englischem Client. Alles andere im angepinnten Block läuft über IDs und ist sprachunabhängig. Wer die fehlenden IDs beisteuern will: `/chrissi scan` und die Ausgabe schicken.
- Das Add-on liest nur aus und rechnet. Es trifft keine Entscheidungen für dich und kann nichts automatisch ausführen. Das lässt die WoW-API nicht zu.
- Die Checkliste ist **nicht** an deinen Spielstand gekoppelt. Sie zeigt die Regeln, wendet sie aber noch nicht automatisch auf dein Itemlevel an. Das ist für eine spätere Version geplant.

## Farben und Lesbarkeit

Die vier Blockfarben sind nicht nach Geschmack gewählt, sondern gegen Farbsehschwäche geprüft (OKLab-Abstand, Deuteranopie / Protanopie / Tritanopie):

| Block | Farbe | |
|---|---|---|
| Jetzt tun | `#0ca30c` | grün |
| Danach | `#fab219` | gelb |
| Nur wenn Zeit | `#898781` | grau, bewusst zurückgenommen |
| Nicht tun | `#d03b3b` | rot |

Der schlechteste Nachbarabstand liegt bei ΔE 9,1 für Deuteranopie (Zielwert ≥ 8). Die erste Fassung lag bei 3,0, dort waren Grün und Gelb für Rot-Grün-Blinde praktisch identisch.

Zwei bewusste Abweichungen: Das Grau ist absichtlich neutral, weil „Nur wenn Zeit" leise sein soll. Das Gelb ist absichtlich hell, weil bei Farbsehschwäche genau der Helligkeitsunterschied es von Grün trennt.

**Farbe ist nie die einzige Information.** Jeder Block trägt seine Bezeichnung als Text, und die Farbe steckt in einem Streifen neben dem Text statt in der Schrift selbst. Wer die Farben gar nicht unterscheiden kann, verliert nichts.

## Lizenz

MIT, siehe `LICENSE`.

Der Guide-Inhalt stammt aus eigener Recherche. Die Idee, eine Wochen-Checkliste über feste Hash-IDs abzubilden, ist an Larias' Weekly Checklist angelehnt. Es wurde kein Code daraus übernommen.
