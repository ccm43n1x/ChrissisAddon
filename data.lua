--[[
    Chrissi's Addon - Datenschicht
    ------------------------------
    Diese Datei enthält NUR Inhalt, keine Logik. Wer den Guide aktualisiert,
    fasst ausschließlich diese Datei an. main.lua bleibt unberührt.

    Aufbau:
      ns.META      Versionsstand des Guides
      ns.SOURCES   Woher der Inhalt stammt
      ns.SECTIONS  Der eigentliche Guide

    Ein Eintrag sieht so aus:
      {
        id   = "a1b2c3d4",   -- FESTE ID, ändert sich NIE.
                             -- Der Haken hängt an der ID, nicht an der Zeile.
                             -- Text darf umformuliert werden, Haken bleibt.
        text = "...",        -- KURZ. Eine Zeile, was zu tun ist. Nicht mehr.
        detail = "...",      -- OPTIONAL: Begründung, Zahlen, Fallstricke.
                             -- Landet im Tooltip, nicht in der Liste.
                             -- Regel: Was man zum HANDELN braucht, gehört in
                             -- text. Was man zum VERSTEHEN braucht, in detail.
        kind = "task",       -- "task" = abhakbar, "rule" = Merksatz ohne Haken
        block = "P1",        -- P1 = jetzt tun, P2 = danach,
                             -- P3 = nur wenn Zeit, NO = nicht tun
        proof = "ok",        -- "ok"     = mehrfach belegt (Blizzard/Method/Wowhead/Icy Veins)
                             -- "single" = nur eine Quelle, ungeprüft
        check = { ... },     -- OPTIONAL: automatische Erkennung, siehe unten
      }

    Automatische Erkennung (Feld "check"):
      { type = "quest",    id = 92600 }                  Quest abgeschlossen?
      { type = "questAny", ids = { 1, 2, 3 } }           irgendeine davon?
      { type = "currency", id = 3444, min = 100 }        Bestand erreicht?
      { type = "renown",   faction = 2600, level = 7 }   Renown-Stufe erreicht?
      { type = "vault",    row = "world", need = 8 }     Vault-Fortschritt?

    Einträge OHNE "check" bleiben von Hand abhakbar. Einträge MIT "check"
    haken sich selbst ab und sind im Fenster als [auto] markiert. Die
    Automatik entfernt niemals einen Haken, den man selbst gesetzt hat.

    Fehlende Quest-IDs findet man im Spiel mit /chrissi questdiff:
    einmal vor und einmal nach der Quest aufrufen, das Addon nennt die
    Differenz. Fraktions-IDs liefert /chrissi factions.
]]

local addonName, ns = ...

ns.META = {
    guideVersion = "1.4",
    updated      = "2026-08-14",
    season       = "Midnight Season 2 (Patch 12.1)",
    region       = "EU",
    preSeason    = "12.08. bis 18.08.2026",
    seasonStart  = "19.08.2026",
    author       = "Chris Cohrt",
}

ns.SOURCES = {
    "Blizzard: Curse of Ula'tek Pre-Season Details",
    "Method: How to Gear Fast, Azta'rec Nemesis Guide, Vaults of Atal'Utek",
    "Icy Veins: Crest-Cap-Umgehung, Pre-Season BiS Trinket",
    "Wowhead: Item Level Upgrade System, Cracked Keystone",
    "Warcraft Wiki: Cracked Keystone",
    "Format-Idee: Larias' Weekly Checklist (kein Code übernommen)",
}

-- Legende für die Blöcke. Farben sind gegen Farbsehschwäche geprüft
-- (OKLab-Validator, Deutan/Protan/Tritan). Details in der README.
ns.BLOCKS = {
    P1 = { label = "Jetzt tun",     color = "ff0ca30c", order = 1 },
    P2 = { label = "Danach",        color = "fffab219", order = 2 },
    P3 = { label = "Nur wenn Zeit", color = "ff898781", order = 3 },
    NO = { label = "Nicht tun",     color = "ffd03b3b", order = 4 },
}

-- Itemlevel-Einstufung ---------------------------------------------------------
-- Schwellen aus der eigenen Master-Notiz, nicht neu erfunden:
--   unter 279  garantierte Veteran- und Champion-Quellen zuerst
--   279 - 285  Lückenfüller, Method warnt unter 286 vor zäher Gruppensuche
--   ab 286     nur noch Vault und nachhaltige Upgrades
--   ab 292     Wochenmaximum der Pre-Season (M0 gibt Champion 1/6 = 292)
-- Absteigend sortiert, der erste Treffer gewinnt.
ns.ILVL_TARGET = 292

ns.ILVL_TIERS = {
    { min = 292, face = ":D", color = "ff0ca30c",
      label = "Wochenmaximum erreicht",
      hint  = "Mehr geht in der Pre-Season nur über Vault und das eine Hero-Item aus dem Delve mit Karte." },
    { min = 286, face = ":)", color = "ff0ca30c",
      label = "gut aufgestellt",
      hint  = "Über der 286er-Schwelle. Gruppensuche für Mythic+ ist damit unproblematisch." },
    { min = 279, face = ":|", color = "fffab219",
      label = "knapp",
      hint  = "Unter 286 wird die Gruppensuche laut Method zäh. Schnelle Lückenfüller, dann M0 und Vault." },
    { min = 0,   face = ":(", color = "ffd03b3b",
      label = "zu niedrig",
      hint  = "Garantierte Veteran- und Champion-Quellen zuerst, bevor irgendetwas anderes." },
}

ns.SECTIONS = {

    -- ========================================================================
    {
        id = "rules_always",
        title = "Dauerregeln",
        subtitle = "Gelten immer, unabhängig von der Woche",
        items = {
            { id = "r_ilvl_low",  kind = "rule", block = "P1", proof = "ok",
              text = "Unter 279 oder 4+ schwache Slots: garantierte Veteran- und Champion-Quellen zuerst." },
            { id = "r_ilvl_mid",  kind = "rule", block = "P1", proof = "ok",
              text = "279 bis 285: schnelle Lückenfüller, dann M0 und Vault." },
            { id = "r_ilvl_high", kind = "rule", block = "P1", proof = "ok",
              text = "Ab ca. 286: Veteran-Grind überspringen. Nur Vault und nachhaltige Upgrades." },

            { id = "r_renown", kind = "rule", block = "P1", proof = "ok",
              text = "Erreichtes Renown-Gear sofort abholen, wenn der Slot unter 292 liegt.",
              detail = "Fehlt die Renown-Stufe noch, nur nachfarmen wenn der Restaufwand unter 30 Minuten liegt und der Slot unter 279. Sonst in der Pre-Season liegen lassen." },

            { id = "r_crest_trick", kind = "rule", block = "P2", proof = "ok",
              text = "Crest-Tauschtrick nutzen, aber nur bei Hero und Myth.",
              detail = "Ein höheres Item macht den niedrigen Track gratis bis zum gleichen Itemlevel. Einmal 20 Crests zahlen, danach ist die nächste Stufe gratis. Bei Champion lohnt es nicht, weil Champion-Crests ab Woche 1 im Überfluss da sind." },
            { id = "r_crest_check", kind = "rule", block = "P2", proof = "ok",
              text = "Vor dem Trick prüfen, ob das Upgrade-Fenster 0 höhere Crests anzeigt.",
              detail = "Doppel-Slots wie Ringe, Trinkets und Einhandwaffen immer manuell prüfen. Das alte Item erst verkaufen, wenn das Fenster die Nullkosten bestätigt." },

            { id = "r_accolade", kind = "rule", block = "P3", proof = "ok",
              text = "Field Accolades: ab 750 gezielte Box, darunter sparen.",
              detail = "Zwischen 500 und 749 lohnt die Zufallsbox nur, wenn über zwei Drittel der Slots echte Upgrades wären. Break-even liegt bei 500 zu 750, also 66,7 Prozent. Kein Altcontent-Grind dafür." },

            { id = "r_no_grind", kind = "rule", block = "NO", proof = "ok",
              text = "Kein langer Altcontent-Grind für Accolades. Kein blindes Crest-Ausgeben. Kein drittes Embellishment." },
        },
    },

    -- ========================================================================
    {
        id = "week0",
        title = "Woche 0",
        subtitle = "12.08. bis 18.08. – Pre-Season",
        items = {
            { id = "w0_campaign", kind = "task", block = "P1", proof = "ok",
              text = "Patch-Kampagne und Freischaltungen abschließen. Öffnet Weeklies, Delves, Prey und Coiled Isle." },

            { id = "w0_m0tour", kind = "task", block = "P1", proof = "ok",
              text = "Alle acht M0-Dungeons einmal laufen.",
              detail = "Diese Woche gilt noch die WÖCHENTLICHE ID. Gibt 292er Champion-Drops und drei Dungeon-Vault-Felder bei 1, 4 und 8 Runs." },

            { id = "w0_aztarec", kind = "task", block = "P1", proof = "ok",
              text = "Azta'rec auf Stufe ? legen. 30 unbegrenzte Hero Mistcrest.",
              detail = "Nemesis-Boss im Delve Venomfall Deeps, Coiled Isle. Die Crests umgehen das Wochen-Cap. Zählt auch, wenn er in der Gruppe gelegt wird." },

            { id = "w0_delve_t11", kind = "task", block = "P1", proof = "ok",
              text = "Delves bis Tier 11 pushen.",
              detail = "Am Ende eines T11-Delve fällt der Cracked Keystone, der die nächste Aufgabe startet." },

            { id = "w0_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone abschließen: ein Dungeon auf Mythic 2 oder höher.",
              detail = "Gibt 20 Hero und 20 Myth Mistcrest, unbegrenzt. Achtung: die Quest vergibt einen M+-Keystone. Wer den Inventar-voll-Trick für eine höhere Stufe nutzen will, muss das vorher machen." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Wöchentliche Spark-Quest abschließen.",
              detail = "Spark of Tides bei Eldara Dawnrunner in Silvermoon." },

            -- ID am 14.08.2026 per /chrissi watch im Spiel eingesammelt. Die
            -- Quest heißt "Purging the Vaults", nicht wie vermutet nach
            -- Atal'Utek benannt. Deshalb war sie über die Wowhead-Suche nicht
            -- zu finden.
            { id = "w0_atalutek_map", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 95520 },
              text = "Atal'Utek-Wochenquest holen für die Trovehunter's Bounty Map.",
              detail = "Purging the Vaults bei Warleader Abdumati." },

            { id = "w0_map_t8", kind = "task", block = "P1", proof = "ok",
              text = "Karte in einem Tier-8-Delve oder höher einsetzen.",
              detail = "Schaltet die Hidden Trove frei und gibt das höchste Delve-Itemlevel im Hero-Track. Das ist die einzige Hero-Quelle dieser Woche." },

            { id = "w0_renown_pickup", kind = "task", block = "P1", proof = "ok",
              text = "Offenes Champion-Renown-Gear abholen, wenn der Slot unter 292 liegt.",
              detail = "Silvermoon Court 9 Helm, Amani Tribe 9 Hals, Hara'ti 8 Gürtel, The Singularity 7 Schmuckstück, Zul'jarra's Forces 9 Armschienen." },

            { id = "w0_crucible", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 93933 },
              text = "Crucible of Erratic Energies holen. Pre-Season-BiS-Trinket.",
              detail = "Ab Renown 7 bei The Singularity: Quest Guarded Treasures bei Void Researcher Anomander (52.5, 72.9). Vorher das Stormarion Assault in Voidstorm abschließen. Gilt als BiS, weil die Void-Research-Fähigkeiten damit überall in Azeroth proccen statt nur in Voidstorm. Vorher simmen." },

            { id = "w0_weeklies", kind = "task", block = "P1", proof = "ok",
              text = "Silvermoon- und Coiled-Isle-Wochenquests: Keys, Caches, Ruf." },

            { id = "w0_world8", kind = "task", block = "P1", proof = "ok",
              check = { type = "vault", row = "world", need = 8 },
              text = "Acht World-Aktivitäten, am besten Delves Tier 6 oder höher.",
              detail = "Gibt drei World-Vault-Felder. Die erste Vault-Reihe liefert maximal Champion 3/6, also Itemlevel 298." },

            { id = "w0_vault3", kind = "task", block = "P1", proof = "single",
              check = { type = "vault", row = "world", need = 4 },
              text = "Mindestens drei Delve-Vault-Felder füllen.",
              detail = "Erst dann steht in der Vault ein Sockel zur Wahl. Wer keine Raid-Splits macht, nimmt später allerdings lieber ein Tier-Teil." },

            { id = "w0_hardprey", kind = "task", block = "P2", proof = "ok",
              text = "Hard Prey und World-Lair nur bei schwachen Slots.",
              detail = "Geben 279er Veteran-Catch-up. Ab Itemlevel 286 aufwärts nicht mehr sinnvoll." },

            { id = "w0_lair_story", kind = "task", block = "P2", proof = "single",
              text = "Neuen Lair-Raidboss auf Story-Mode für LFR-Gear mitnehmen." },

            { id = "w0_save_keys", kind = "rule", block = "NO", proof = "ok",
              text = "Restored Coffer Keys und Sparks nicht ausgeben.",
              detail = "Bountiful Delves öffnen erst am 19.08. ACHTUNG Verwechslungsgefahr: Die Trovehunter's Bounty Map ist ein anderer Gegenstand und soll sofort benutzt werden." },

            { id = "w0_no_mistcrest", kind = "rule", block = "NO", proof = "ok",
              text = "Mistcrests nicht in Übergangsitems verbrennen.",
              detail = "Erst nach den wichtigen Drops der Woche ausgeben." },

            { id = "w0_no_pug_lair", kind = "rule", block = "NO", proof = "single",
              text = "Lair-Boss nicht auf Normal oder höher puggen. Für die Gilde aufsparen." },
        },
    },

    -- ========================================================================
    {
        id = "week1",
        title = "Woche 1",
        subtitle = "ab 19.08. – Season-Start",
        items = {
            { id = "w1_aztarec2", kind = "task", block = "P1", proof = "ok",
              text = "Azta'rec auf Stufe ?? legen.",
              detail = "30 unbegrenzte Hero Mistcrest, oder 60 falls Stufe ? nicht gemacht wurde, plus 30 unbegrenzte Myth Mistcrest. Der Gesamtertrag ist gleich, der frühe Kill verlagert ihn nur nach vorn." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Wöchentliche Spark-Quest (Spark of Tides) abschließen." },

            { id = "w1_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone erneut: T11-Delve, dann M2 oder höher. Wieder 20 Hero und 20 Myth unbegrenzt." },

            { id = "w1_bountiful", kind = "task", block = "P1", proof = "ok",
              text = "Gesparte Coffer Keys in Bountiful Delves ab Tier 8 einsetzen.",
              detail = "Gibt 295er Champion. Delver's Bounty in T8 oder höher gibt 305er Hero." },

            { id = "w1_raid", kind = "task", block = "P1", proof = "ok",
              text = "Venomous Abyss auf der höchsten zuverlässig clearbaren Schwierigkeit.",
              detail = "LFR gibt Champion, Normal gibt Hero, Heroic gibt Myth. Vault-Felder bei 2, 4 und 6 Bossen." },

            { id = "w1_mplus", kind = "task", block = "P1", proof = "ok",
              text = "Mythic+ laufen. Ab +6 lohnt es, ab +10 für das Myth-Vault-Feld.",
              detail = "Ab +6 fallen Hero-Drops, ab +9 gibt es Myth-Crests, ab +10 ein Myth 1/6 in der Vault. Vault-Felder bei 1, 4 und 8 Runs." },

            { id = "w1_prey", kind = "task", block = "P2", proof = "ok",
              text = "Nightmare Prey für fehlende Slots.",
              detail = "Bis fünfmal pro Woche, gibt 292er Champion." },

            { id = "w1_tier", kind = "task", block = "P2", proof = "ok",
              text = "Setbonus prüfen. Catalyst nur bei sofortigem Setgewinn.",
              detail = "2er- und 4er-Bonus gegenrechnen, bevor eine Catalyst-Ladung verbraucht wird." },

            { id = "w1_lfr_tier", kind = "task", block = "P3", proof = "single",
              text = "LFR für Tier-Teile, falls noch welche fehlen." },

            { id = "w1_no_craft", kind = "rule", block = "NO", proof = "ok",
              text = "Zwei-Spark-Craft NICHT vor den wichtigen Wochen-Drops. Die Zweihandwaffe braucht vier Sparks." },
        },
    },

    -- ========================================================================
    {
        id = "week2",
        title = "Woche 2",
        subtitle = "ab 26.08. – erste Season-2-Vault",
        items = {
            { id = "w2_vault", kind = "task", block = "P1", proof = "ok",
              text = "Erste Season-2-Vault prüfen, Entscheidung nicht voreilig treffen.",
              detail = "Raid, M+ und Delves können am selben Tag noch besser droppen. Erst am Ende des Tages entscheiden." },

            { id = "w2_voidcore", kind = "task", block = "P1", proof = "ok",
              text = "Voidcore aus der Vault nehmen, wenn ein Bonus Roll geplant ist.",
              detail = "Ein Bonus Roll kostet einen Voidcore, gleicher Preis wie bei M+, Bountiful Delves und Nightmare Prey." },

            { id = "w2_bonusroll", kind = "rule", block = "P1", proof = "ok",
              text = "Bonus Roll springt auf die erste Stufe des nächsthöheren Tracks.",
              detail = "Heroic gibt ein Myth-Track-Teil, Mythic gibt ein voll aufgewertetes. Weil M+ Voidcores zum selben Preis erzeugt, finanziert eine starke M+-Woche einen späteren Raid-Roll." },

            { id = "70348198_w2", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Wöchentliche Spark-Quest (Spark of Tides) abschließen." },

            { id = "w2_upgrade", kind = "task", block = "P2", proof = "ok",
              text = "Jetzt gezielt aufwerten. Vorher den Crest-Tauschtrick prüfen, spart 20 Crests pro Stufe bei Hero und Myth." },

            { id = "w2_craft", kind = "task", block = "P2", proof = "ok",
              text = "Zwei-Spark-Craft jetzt, nachdem die wichtigen Wochen-Drops durch sind." },
        },
    },

    -- ========================================================================
    {
        id = "open",
        title = "Noch offen",
        subtitle = "Im Spiel prüfen, dann hier festschreiben",
        items = {
            { id = "o_aztarec_diff", kind = "rule", block = "P3", proof = "single",
              text = "Was bedeuten die Nemesis-Stufen ? und ?? bei Azta'rec?",
              detail = "Method und Icy Veins schreiben beide ? und ??, es ist also offenbar die echte Bezeichnung. Im Spiel gegenprüfen." },

            { id = "o_toxic_tour", kind = "rule", block = "P3", proof = "ok",
              text = "Die Bounty kommt aus der Wochenquest, nicht aus der Kampagne.",
              detail = "Am 14.08.2026 im Spiel bestätigt: Purging the Vaults bei Warleader Abdumati gibt die Trovehunter's Bounty. Method hatte recht, die Kampagnenquest A Toxic Tour ist nicht die Quelle." },

            { id = "o_crucible_ilvl", kind = "rule", block = "P3", proof = "single",
              text = "Wie weit lässt sich der Crucible aufwerten?",
              detail = "Larias sagt 295, nicht bestätigt. Eine Quelle nennt Start-Itemlevel 246, was nicht zur Champion-Spanne 285 bis 302 passt. Vermutlich veralteter PTR-Stand." },
        },
    },
}
