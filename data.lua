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
        text = "...",
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
    guideVersion = "1.1",
    updated      = "2026-08-13",
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
              text = "Renown-Gear: Stufe erreicht, nicht abgeholt und Slot unter 292 bedeutet sofort abholen. Fehlt die Stufe, nur nachfarmen wenn Restaufwand unter 30 Minuten und Slot unter 279." },

            { id = "r_crest_trick", kind = "rule", block = "P2", proof = "ok",
              text = "Crest-Tauschtrick: Ein höheres Item macht den niedrigen Track gratis bis zum gleichen Itemlevel. Einmal 20 Crests zahlen, danach ist die nächste Stufe gratis. Lohnt bei HERO und MYTH, nicht bei Champion." },
            { id = "r_crest_check", kind = "rule", block = "P2", proof = "ok",
              text = "Trick nur ausführen, wenn das Upgrade-Fenster 0 höhere Crests anzeigt. Doppel-Slots wie Ringe, Trinkets und Einhandwaffen immer manuell prüfen." },

            { id = "r_accolade", kind = "rule", block = "P3", proof = "ok",
              text = "Field Accolades: ab 750 gezielte Box bei dringendem Slot. Zwischen 500 und 749 nur, wenn über zwei Drittel echte Upgrades wären. Break-even liegt bei 500 zu 750, also 66,7 Prozent. Sonst sparen." },

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
              text = "Alle acht M0-Dungeons einmal. Diese Woche noch WÖCHENTLICHE ID. Gibt 292er Champion-Drops und drei Dungeon-Vault-Felder bei 1, 4 und 8 Runs." },

            { id = "w0_aztarec", kind = "task", block = "P1", proof = "ok",
              text = "Azta'rec im Delve Venomfall Deeps auf Stufe ? legen. 30 UNBEGRENZTE Hero Mistcrest, umgeht das Wochen-Cap. Zählt auch in der Gruppe." },

            { id = "w0_delve_t11", kind = "task", block = "P1", proof = "ok",
              text = "Delves bis Tier 11 pushen. Am Ende eines T11 fällt der Cracked Keystone." },

            { id = "w0_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone abschließen: irgendeinen Dungeon auf Mythic 2 oder höher. Gibt 20 Hero und 20 Myth Mistcrest, UNBEGRENZT. Achtung: die Quest gibt einen M+-Keystone. Inventar-voll-Trick vorher machen." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Wöchentliche Spark-Quest (Spark of Tides) bei Eldara Dawnrunner in Silvermoon abschließen." },

            { id = "w0_atalutek_map", kind = "task", block = "P1", proof = "ok",
              text = "Vaults of Atal'Utek Wochenquest für die Trovehunter's Bounty Map." },

            { id = "w0_map_t8", kind = "task", block = "P1", proof = "ok",
              text = "Trovehunter's Bounty Map in einem Tier-8-Delve oder höher einsetzen. Schaltet die Hidden Trove frei und gibt das höchste Delve-Itemlevel im HERO-Track. Einzige Hero-Quelle dieser Woche." },

            { id = "w0_renown_pickup", kind = "task", block = "P1", proof = "ok",
              text = "Freigeschaltetes, nicht abgeholtes Champion-Renown-Gear abholen, wenn der Slot unter 292 liegt. Silvermoon Court 9 Helm, Amani Tribe 9 Hals, Hara'ti 8 Gürtel, The Singularity 7 Schmuckstück, Zul'jarra's Forces 9 Armschienen." },

            { id = "w0_crucible", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 93933 },
              text = "Renown 7 bei The Singularity: Quest Guarded Treasures bei Void Researcher Anomander (52.5, 72.9) holen, vorher Stormarion Assault in Voidstorm abschließen. Gibt den Crucible of Erratic Energies. Gilt als Pre-Season-BiS-Trinket, weil die Void-Research-Fähigkeiten damit ÜBERALL proccen. Vorher simmen." },

            { id = "w0_weeklies", kind = "task", block = "P1", proof = "ok",
              text = "Silvermoon- und Coiled-Isle-Wochenquests: Keys und Fragmente, Caches, Ruf." },

            { id = "w0_world8", kind = "task", block = "P1", proof = "ok",
              check = { type = "vault", row = "world", need = 8 },
              text = "Acht World-Aktivitäten, idealerweise Delves Tier 6 oder höher. Gibt drei World-Vault-Felder. Erste Vault-Reihe maximal Champion 3/6, also 298." },

            { id = "w0_vault3", kind = "task", block = "P1", proof = "single",
              check = { type = "vault", row = "world", need = 4 },
              text = "Mindestens drei Delve-Vault-Felder füllen, damit ein SOCKEL überhaupt zur Wahl steht. Wer keine Raid-Splits macht, nimmt später lieber ein Tier-Teil." },

            { id = "w0_hardprey", kind = "task", block = "P2", proof = "ok",
              text = "Hard Prey und World-Lair NUR bei schwachen Slots. Geben 279er Veteran-Catch-up. Ab Itemlevel 286 aufwärts nicht mehr sinnvoll." },

            { id = "w0_lair_story", kind = "task", block = "P2", proof = "single",
              text = "Neuen Lair-Raidboss auf Story-Mode für LFR-Gear mitnehmen." },

            { id = "w0_save_keys", kind = "rule", block = "NO", proof = "ok",
              text = "Restored Coffer Keys und Sparks NICHT ausgeben. Bountiful Delves öffnen erst am 19.08. Achtung: Die Trovehunter's Bounty Map ist ein ANDERER Gegenstand und soll sofort benutzt werden." },

            { id = "w0_no_mistcrest", kind = "rule", block = "NO", proof = "ok",
              text = "Mistcrests nicht in Übergangsitems verbrennen. Erst nach den wichtigen Drops ausgeben." },

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
              text = "Azta'rec auf Stufe ?? legen. 30 unbegrenzte Hero Mistcrest, oder 60 falls Stufe ? nicht gemacht, plus 30 unbegrenzte Myth Mistcrest." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Wöchentliche Spark-Quest (Spark of Tides) abschließen." },

            { id = "w1_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone erneut: T11-Delve, dann M2 oder höher. Wieder 20 Hero und 20 Myth unbegrenzt." },

            { id = "w1_bountiful", kind = "task", block = "P1", proof = "ok",
              text = "Gesparte Restored Coffer Keys jetzt in Bountiful Delves Tier 8 oder höher einsetzen. Gibt 295er Champion. Delver's Bounty in T8+ gibt 305er Hero." },

            { id = "w1_raid", kind = "task", block = "P1", proof = "ok",
              text = "Raid Venomous Abyss auf der höchsten zuverlässig clearbaren Schwierigkeit. LFR gibt Champion, Normal gibt Hero, Heroic gibt Myth. Vault-Felder bei 2, 4 und 6 Bossen." },

            { id = "w1_mplus", kind = "task", block = "P1", proof = "ok",
              text = "Mythic+: ab +6 Hero-Drops, ab +9 Myth-Crests, ab +10 Myth 1/6 in der Vault. Vault-Felder bei 1, 4 und 8 Runs." },

            { id = "w1_prey", kind = "task", block = "P2", proof = "ok",
              text = "Nightmare Prey für fehlende Slots. Bis fünfmal pro Woche 292er Champion." },

            { id = "w1_tier", kind = "task", block = "P2", proof = "ok",
              text = "2er- und 4er-Setbonus prüfen. Catalyst nur bei sofortigem Setgewinn einsetzen." },

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
              text = "Erste Season-2-Great-Vault prüfen. Entscheidung NICHT voreilig treffen, Raid, M+ und Delves können am selben Tag besser droppen." },

            { id = "w2_voidcore", kind = "task", block = "P1", proof = "ok",
              text = "Ab jetzt gibt es Voidcores aus der Vault. Ein Bonus Roll kostet EINEN Voidcore, gleicher Preis wie M+, Bountiful Delves und Nightmare Prey." },

            { id = "w2_bonusroll", kind = "rule", block = "P1", proof = "ok",
              text = "Bonus Roll springt auf die erste Stufe des NÄCHSTHÖHEREN Tracks. Heroic gibt ein Myth-Track-Teil, Mythic gibt ein voll aufgewertetes. Weil M+ Voidcores zum selben Preis erzeugt, finanziert eine starke M+-Woche einen späteren Raid-Roll." },

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
              text = "Was genau bedeuten die Nemesis-Stufen ? und ?? bei Azta'rec? Method und Icy Veins schreiben es identisch, im Spiel gegenprüfen." },

            { id = "o_toxic_tour", kind = "rule", block = "P3", proof = "single",
              text = "Gibt die Kampagnenquest A Toxic Tour ein halbes 1/6-Champion-Item? Nicht bestätigt. Die Karte kommt laut Method aus der WOCHENQUEST von Warleader Abdumati." },

            { id = "o_crucible_ilvl", kind = "rule", block = "P3", proof = "single",
              text = "Auf welches Itemlevel lässt sich der Crucible of Erratic Energies maximal aufwerten? Larias sagt 295, nicht bestätigt. Eine Quelle nennt Start-Itemlevel 246, was nicht zur Champion-Spanne 285 bis 302 passt." },
        },
    },
}
