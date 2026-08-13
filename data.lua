--[[
    Chrissi's Addon - Datenschicht
    ------------------------------
    Diese Datei enthaelt NUR Inhalt, keine Logik. Wer den Guide aktualisiert,
    fasst ausschliesslich diese Datei an. main.lua bleibt unberuehrt.

    Aufbau:
      ns.META      Versionsstand des Guides
      ns.SOURCES   Woher der Inhalt stammt
      ns.SECTIONS  Der eigentliche Guide

    Ein Eintrag sieht so aus:
      {
        id   = "a1b2c3d4",   -- FESTE Hash-ID, aendert sich NIE.
                             -- Der Haken haengt an der ID, nicht an der Zeile.
                             -- Text darf umformuliert werden, Haken bleibt.
        text = "...",
        kind = "task",       -- "task" = abhakbar, "rule" = Merksatz ohne Haken
        block = "P1",        -- P1 = jetzt tun, P2 = danach,
                             -- P3 = nur wenn Zeit, NO = nicht tun
        proof = "ok",        -- "ok"     = mehrfach belegt (Blizzard/Method/Wowhead/Icy Veins)
                             -- "single" = nur eine Quelle, ungeprueft
        check = { ... },     -- OPTIONAL: automatische Erkennung, siehe unten
      }

    Automatische Erkennung (Feld "check"):
      { type = "quest",    id = 92600 }                  Quest abgeschlossen?
      { type = "questAny", ids = { 1, 2, 3 } }           irgendeine davon?
      { type = "currency", id = 3444, min = 100 }        Bestand erreicht?
      { type = "renown",   faction = 2600, level = 7 }   Renown-Stufe erreicht?
      { type = "vault",    row = "world", need = 8 }     Vault-Fortschritt?

    Eintraege OHNE "check" bleiben von Hand abhakbar. Eintraege MIT "check"
    haken sich selbst ab und sind im Fenster als [auto] markiert. Die
    Automatik entfernt niemals einen Haken, den man selbst gesetzt hat.

    Fehlende Quest-IDs findet man im Spiel mit /chrissi questdiff:
    einmal vor und einmal nach der Quest aufrufen, das Add-on nennt die
    Differenz. Fraktions-IDs liefert /chrissi factions.

    Wiederkehrende Aufgaben bekommen ueber alle Wochen DIESELBE ID.
    Beispiel: die woechentliche Spark-Quest ist immer "70348198".
]]

local addonName, ns = ...

ns.META = {
    guideVersion = "1.0",
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
    "Format-Idee: Larias' Weekly Checklist (kein Code uebernommen)",
}

-- Legende fuer die Bloecke, wird im UI angezeigt
ns.BLOCKS = {
    P1 = { label = "Jetzt tun",     color = "ff40ff40", order = 1 },
    P2 = { label = "Danach",        color = "ffffd100", order = 2 },
    P3 = { label = "Nur wenn Zeit", color = "ff9d9d9d", order = 3 },
    NO = { label = "Nicht tun",     color = "ffff6060", order = 4 },
}

ns.SECTIONS = {

    -- ========================================================================
    {
        id = "rules_always",
        title = "Dauerregeln (gelten immer)",
        items = {
            { id = "r_ilvl_low",  kind = "rule", block = "P1", proof = "ok",
              text = "Unter 279 oder 4+ schwache Slots: garantierte Veteran-/Champion-Quellen zuerst." },
            { id = "r_ilvl_mid",  kind = "rule", block = "P1", proof = "ok",
              text = "279 bis 285: schnelle Lueckenfueller, dann M0 und Vault." },
            { id = "r_ilvl_high", kind = "rule", block = "P1", proof = "ok",
              text = "Ab ca. 286: Veteran-Grind ueberspringen. Nur Vault und nachhaltige Upgrades." },

            { id = "r_crest_trick", kind = "rule", block = "P2", proof = "ok",
              text = "Crest-Tauschtrick: Ein hoeheres Item macht den niedrigen Track gratis bis zum gleichen ilvl. Einmal 20 Crests zahlen, danach ist die naechste Stufe gratis. Lohnt bei HERO und MYTH, nicht bei Champion." },
            { id = "r_crest_check", kind = "rule", block = "P2", proof = "ok",
              text = "Trick nur ausfuehren, wenn das Upgrade-UI 0 hoehere Crests anzeigt. Doppel-Slots (Ringe, Trinkets, Einhandwaffen) immer manuell pruefen." },

            { id = "r_renown", kind = "rule", block = "P1", proof = "ok",
              text = "Renown-Gear: Stufe erreicht + nicht abgeholt + Slot unter 292 = sofort abholen. Stufe fehlt: nur nachfarmen wenn Restaufwand unter 30 Min und Slot unter 279." },

            { id = "r_accolade", kind = "rule", block = "P3", proof = "ok",
              text = "Field Accolades: ab 750 gezielte Box bei dringendem Slot. 500 bis 749 nur wenn ueber zwei Drittel echte Upgrades waeren (Break-even 500/750 = 66,66 Prozent). Sonst sparen." },

            { id = "r_no_grind", kind = "rule", block = "NO", proof = "ok",
              text = "Kein langer Altcontent-Grind fuer Accolades. Kein blindes Crest-Ausgeben. Kein drittes Embellishment." },
        },
    },

    -- ========================================================================
    {
        id = "week0",
        title = "Woche 0 - 12.08. bis 18.08. - Pre-Season",
        items = {
            { id = "w0_campaign", kind = "task", block = "P1", proof = "ok",
              text = "Patch-Kampagne und Freischaltungen abschliessen. Oeffnet Weeklies, Delves, Prey und Coiled Isle." },

            { id = "w0_m0tour", kind = "task", block = "P1", proof = "ok",
              text = "Alle acht M0-Dungeons einmal. Diese Woche noch WOECHENTLICHE ID. Gibt 292er Champion-Drops und drei Dungeon-Vault-Felder bei 1/4/8 Runs." },

            { id = "w0_aztarec", kind = "task", block = "P1", proof = "ok",
              text = "Azta'rec im Delve Venomfall Deeps auf Stufe ? legen. 30 UNBEGRENZTE Hero Mistcrest, umgeht das Wochen-Cap. Zaehlt auch in der Gruppe." },

            { id = "w0_delve_t11", kind = "task", block = "P1", proof = "ok",
              text = "Delves bis Tier 11 pushen. Am Ende eines T11 faellt der Cracked Keystone." },

            { id = "w0_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone abschliessen: irgendeinen Dungeon auf Mythic 2 oder hoeher. Gibt 20 Hero + 20 Myth Mistcrest, UNBEGRENZT. Achtung: die Quest gibt einen M+-Keystone. Inventar-voll-Trick vorher machen." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Woechentliche Spark-Quest (Spark of Tides) bei Eldara Dawnrunner in Silvermoon abschliessen." },

            { id = "w0_atalutek_map", kind = "task", block = "P1", proof = "ok",
              text = "Vaults of Atal'Utek Wochenquest fuer die Trovehunter's Bounty Map." },

            { id = "w0_map_t8", kind = "task", block = "P1", proof = "ok",
              text = "Trovehunter's Bounty Map in einem Tier-8-Delve oder hoeher einsetzen. Schaltet die Hidden Trove frei und gibt das hoechste Delve-Itemlevel im HERO-Track. Einzige Hero-Quelle dieser Woche." },

            { id = "w0_renown_pickup", kind = "task", block = "P1", proof = "ok",
              text = "Freigeschaltetes, nicht abgeholtes Champion-Renown-Gear abholen, wenn der Slot unter 292 liegt. Silvermoon Court 9 Helm, Amani Tribe 9 Hals, Hara'ti 8 Guertel, The Singularity 7 Schmuckstueck, Zul'jarra's Forces 9 Armschienen." },

            { id = "w0_crucible", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 93933 },
              text = "Renown 7 bei The Singularity: Quest Guarded Treasures bei Void Researcher Anomander (52.5, 72.9) holen, vorher Stormarion Assault in Voidstorm abschliessen. Gibt den Crucible of Erratic Energies. Gilt als Pre-Season-BiS-Trinket, weil die Void-Research-Faehigkeiten damit UEBERALL proccen. Vorher simmen." },

            { id = "w0_weeklies", kind = "task", block = "P1", proof = "ok",
              text = "Silvermoon- und Coiled-Isle-Wochenquests: ein Spark, Keys und Fragmente, Caches, Ruf." },

            { id = "w0_world8", kind = "task", block = "P1", proof = "ok",
              check = { type = "vault", row = "world", need = 8 },
              text = "Acht World-Aktivitaeten, idealerweise Delves Tier 6+. Gibt drei World-Vault-Felder. Erste Vault-Reihe maximal Champion 3/6 = 298." },

            { id = "w0_vault3", kind = "task", block = "P1", proof = "single",
              text = "Mindestens drei Delve-Vault-Felder fuellen, damit ein SOCKEL ueberhaupt zur Wahl steht. Wer keine Raid-Splits macht, nimmt spaeter lieber ein Tier-Teil." },

            { id = "w0_hardprey", kind = "task", block = "P2", proof = "ok",
              text = "Hard Prey und World-Lair NUR bei schwachen Slots. Geben 279er Veteran-Catch-up. Ab ilvl 286 aufwaerts nicht mehr sinnvoll." },

            { id = "w0_lair_story", kind = "task", block = "P2", proof = "single",
              text = "Neuen Lair-Raidboss auf Story-Mode fuer LFR-Gear mitnehmen." },

            { id = "w0_save_keys", kind = "rule", block = "NO", proof = "ok",
              text = "Restored Coffer Keys und Sparks NICHT ausgeben. Bountiful Delves oeffnen erst am 19.08. ACHTUNG: Die Trovehunter's Bounty Map ist ein ANDERER Gegenstand und soll sofort benutzt werden." },

            { id = "w0_no_mistcrest", kind = "rule", block = "NO", proof = "ok",
              text = "Mistcrests nicht in Uebergangsitems verbrennen. Erst nach den wichtigen Drops ausgeben." },

            { id = "w0_no_pug_lair", kind = "rule", block = "NO", proof = "single",
              text = "Lair-Boss nicht auf Normal oder hoeher puggen. Fuer die Gilde aufsparen." },
        },
    },

    -- ========================================================================
    {
        id = "week1",
        title = "Woche 1 - ab 19.08. - Season-Start",
        items = {
            { id = "w1_aztarec2", kind = "task", block = "P1", proof = "ok",
              text = "Azta'rec auf Stufe ?? legen. 30 unbegrenzte Hero Mistcrest, oder 60 falls Stufe ? nicht gemacht, plus 30 unbegrenzte Myth Mistcrest." },

            { id = "70348198", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Woechentliche Spark-Quest (Spark of Tides) abschliessen." },

            { id = "w1_cracked", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 92600 },
              text = "Cracked Keystone erneut: T11-Delve, dann M2+. Wieder 20 Hero + 20 Myth unbegrenzt." },

            { id = "w1_bountiful", kind = "task", block = "P1", proof = "ok",
              text = "Gesparte Restored Coffer Keys jetzt in Bountiful Delves Tier 8+ einsetzen. Gibt 295er Champion. Delver's Bounty in T8+ gibt 305er Hero." },

            { id = "w1_raid", kind = "task", block = "P1", proof = "ok",
              text = "Raid Venomous Abyss auf der hoechsten zuverlaessig clearbaren Schwierigkeit. LFR gibt Champion, Normal gibt Hero, Heroic gibt Myth. Vault-Felder bei 2/4/6 Bossen." },

            { id = "w1_mplus", kind = "task", block = "P1", proof = "ok",
              text = "Mythic+: ab +6 Hero-Drops, ab +9 Myth-Crests, ab +10 Myth 1/6 in der Vault. Vault-Felder bei 1/4/8 Runs." },

            { id = "w1_prey", kind = "task", block = "P2", proof = "ok",
              text = "Nightmare Prey fuer fehlende Slots. Bis fuenfmal pro Woche 292er Champion." },

            { id = "w1_tier", kind = "task", block = "P2", proof = "ok",
              text = "2er- und 4er-Setbonus pruefen. Catalyst nur bei sofortigem Setgewinn einsetzen." },

            { id = "w1_lfr_tier", kind = "task", block = "P3", proof = "single",
              text = "LFR fuer Tier-Teile, falls noch welche fehlen." },

            { id = "w1_no_craft", kind = "rule", block = "NO", proof = "ok",
              text = "Zwei-Spark-Craft NICHT vor den wichtigen Wochen-Drops. Die Zweihandwaffe braucht vier Sparks." },
        },
    },

    -- ========================================================================
    {
        id = "week2",
        title = "Woche 2 - ab 26.08. - erste Season-2-Vault",
        items = {
            { id = "w2_vault", kind = "task", block = "P1", proof = "ok",
              text = "Erste Season-2-Great-Vault pruefen. Entscheidung NICHT voreilig treffen, Raid, M+ und Delves koennen am selben Tag besser droppen." },

            { id = "w2_voidcore", kind = "task", block = "P1", proof = "ok",
              text = "Ab jetzt gibt es Voidcores aus der Vault. Ein Bonus Roll kostet EINEN Voidcore, gleicher Preis wie M+, Bountiful Delves und Nightmare Prey." },

            { id = "w2_bonusroll", kind = "rule", block = "P1", proof = "ok",
              text = "Bonus Roll springt auf die erste Stufe des NAECHSTHOEHEREN Tracks. Heroic gibt ein Myth-Track-Teil, Mythic gibt ein voll aufgewertetes. Weil M+ Voidcores zum selben Preis erzeugt, finanziert eine starke M+-Woche einen spaeteren Raid-Roll." },

            { id = "70348198_w2", kind = "task", block = "P1", proof = "ok",
              check = { type = "quest", id = 96446 },
              text = "Woechentliche Spark-Quest (Spark of Tides) abschliessen." },

            { id = "w2_upgrade", kind = "task", block = "P2", proof = "ok",
              text = "Jetzt gezielt aufwerten. Vorher den Crest-Tauschtrick pruefen, spart 20 Crests pro Stufe bei Hero und Myth." },

            { id = "w2_craft", kind = "task", block = "P2", proof = "ok",
              text = "Zwei-Spark-Craft jetzt, nachdem die wichtigen Wochen-Drops durch sind." },
        },
    },

    -- ========================================================================
    {
        id = "open",
        title = "Noch offen / im Spiel pruefen",
        items = {
            { id = "o_aztarec_diff", kind = "rule", block = "P3", proof = "single",
              text = "Was genau bedeuten die Nemesis-Stufen ? und ?? bei Azta'rec? Method und Icy Veins schreiben es identisch, im Spiel gegenpruefen." },

            { id = "o_toxic_tour", kind = "rule", block = "P3", proof = "single",
              text = "Gibt die Kampagnenquest A Toxic Tour ein halbes 1/6-Champion-Item? Nicht bestaetigt. Die Karte kommt laut Method aus der WOCHENQUEST von Warleader Abdumati." },

            { id = "o_crucible_ilvl", kind = "rule", block = "P3", proof = "single",
              text = "Auf welches Itemlevel laesst sich der Crucible of Erratic Energies maximal aufwerten? Larias sagt 295, nicht bestaetigt. Eine Quelle nennt Start-ilvl 246, was nicht zur Champion-Spanne 285 bis 302 passt." },
        },
    },
}
