--[[
    Chrissi's Addon v0.5.0 - Logik
    ------------------------------
    Diese Datei enthält KEINEN Guide-Inhalt. Der steht in data.lua.

    Designsprache, abgeleitet aus Chris' eigenem Interface (EllesmereUI):
      - Keine Zierrahmen. Flache, dunkle, halbtransparente Fläche
      - Trennung über Haarlinien, nicht über Kästen
      - Überschrift links, dünne Linie füllt den Rest der Zeile
      - Farbe nur wo sie Bedeutung trägt
      - Werte rechtsbündig, Beschriftung links

    Aufbau:
      A) Konstanten und Design-Tokens
      B) SavedVariables
      C) Spieldaten holen
      D) Automatische Erkennung
      E) Frames
      F) Widget-Pools
      G) Rendering
      H) Event-Frame
      I) Slash-Commands
]]

local addonName, ns = ...

-- ============================================================================
-- A) Konstanten und Design-Tokens
-- ============================================================================

local WINDOW_WIDTH  = 420
local WINDOW_HEIGHT = 600
local PAD           = 14

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 1.5, 0.05

-- Angepinnte Währungen. IDs sind sprachunabhängig und funktionieren auch bei
-- eingeklappter Kategorie. Ermittelt über /chrissi scan am 13.08.2026.
local PINNED_IDS = {
    3442,  -- Adventurer Mistcrest
    3443,  -- Veteran Mistcrest
    3444,  -- Champion Mistcrest
    3445,  -- Hero Mistcrest   (belegt: Method verlinkt currency=3445)
    3446,  -- Myth Mistcrest   (aus der Reihe erschlossen, nicht belegt)
    3509,  -- Tidal Spark Dust
    3405,  -- Field Accolade
}

-- Fallback für Währungen ohne bekannte ID. Greift nur auf englischem Client.
local PINNED_PATTERNS = { "Coffer Key", "Voidcore" }

local BLOCK_ORDER = { "P1", "P2", "P3", "NO" }

-- Design-Tokens ---------------------------------------------------------------
-- Grundregel: Text trägt Textfarben, niemals die Kategoriefarbe. Die
-- Zugehörigkeit übernimmt ein Streifen NEBEN dem Text.
local GOLD     = "ffe8c15a"   -- Titel, wie die Questnamen im Tracker
local INK      = "ffd6d2c8"   -- Fließtext
local INK_DIM  = "ff8d887e"   -- Nebeninfos
local INK_DONE = "ff5f5b54"   -- erledigt, bewusst zurückgenommen
local GREEN    = "ff0ca30c"   -- automatisch erkannt

-- Flächen
local BG_R, BG_G, BG_B, BG_A = 0.035, 0.035, 0.045, 0.88
local RULE_ALPHA = 0.10

-- Rhythmus
local ROW_GAP     = 5
local BLOCK_GAP   = 12
local LINE_H      = 20

local function HexToRGB(hex)
    if #hex == 8 then hex = hex:sub(3) end
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

-- ============================================================================
-- B) SavedVariables
-- ============================================================================

ChrissisAddonDB     = ChrissisAddonDB or {}
ChrissisAddonCharDB = ChrissisAddonCharDB or {}

local DEFAULTS = {
    point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
    scale = 1.0,
    tab = "guide",
    section = 1,        -- welche Seite des Karussells
    showZero = false,
}

local CHAR_DEFAULTS = { checks = {} }

local function ApplyDefaults()
    for key, value in pairs(DEFAULTS) do
        if ChrissisAddonDB[key] == nil then
            ChrissisAddonDB[key] = (type(value) == "table") and {} or value
        end
    end
    for key, value in pairs(CHAR_DEFAULTS) do
        if ChrissisAddonCharDB[key] == nil then
            ChrissisAddonCharDB[key] = (type(value) == "table") and {} or value
        end
    end
end

local function SetChecked(id, value)
    ChrissisAddonCharDB.checks[id] = value and true or nil
end

-- ============================================================================
-- C) Spieldaten holen
-- ============================================================================

local function FormatNumber(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    local k
    repeat
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
    until k == 0
    return s
end

local function GetItemLevels()
    if not GetAverageItemLevel then return 0, 0 end
    local overall, equipped = GetAverageItemLevel()
    return tonumber(overall) or 0, tonumber(equipped) or 0
end

local function GetCurrencies()
    local list, collapsedHeaders = {}, 0
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then
        return list, collapsedHeaders
    end
    local size = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = 1, size do
        -- pcall: Wenn Blizzard das Format ändert, fällt eine Zeile aus statt
        -- das ganze Addon zu zerlegen.
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
        if ok and info then
            if info.isHeader then
                if not info.isHeaderExpanded then
                    collapsedHeaders = collapsedHeaders + 1
                end
                list[#list + 1] = { isHeader = true, name = info.name or "?" }
            else
                local id
                if C_CurrencyInfo.GetCurrencyListLink then
                    local okLink, link = pcall(C_CurrencyInfo.GetCurrencyListLink, i)
                    if okLink and link then id = tonumber(link:match("currency:(%d+)")) end
                end
                list[#list + 1] = {
                    isHeader = false, id = id, name = info.name or "?",
                    quantity       = tonumber(info.quantity) or 0,
                    icon           = info.iconFileID,
                    maxQuantity    = tonumber(info.maxQuantity) or 0,
                    earnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0,
                    maxWeekly      = tonumber(info.maxWeeklyQuantity) or 0,
                    canEarnPerWeek = info.canEarnPerWeek and true or false,
                }
            end
        end
    end
    return list, collapsedHeaders
end

local function GetCurrencyByID(id)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    if not ok or not info or not info.name or info.name == "" then return nil end
    return {
        isHeader = false, id = id, name = info.name,
        quantity       = tonumber(info.quantity) or 0,
        icon           = info.iconFileID,
        maxQuantity    = tonumber(info.maxQuantity) or 0,
        earnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0,
        maxWeekly      = tonumber(info.maxWeeklyQuantity) or 0,
        canEarnPerWeek = info.canEarnPerWeek and true or false,
    }
end

local function GetPinnedCurrencies()
    local out, seen = {}, {}
    for _, id in ipairs(PINNED_IDS) do
        local e = GetCurrencyByID(id)
        if e then out[#out + 1] = e; seen[id] = true end
    end
    if #PINNED_PATTERNS > 0 then
        local all = GetCurrencies()
        for _, pattern in ipairs(PINNED_PATTERNS) do
            for _, e in ipairs(all) do
                if not e.isHeader and not (e.id and seen[e.id])
                   and e.name:find(pattern, 1, true) then
                    out[#out + 1] = e
                    if e.id then seen[e.id] = true end
                end
            end
        end
    end
    return out
end

-- Anzeigetext plus Fortschritt als Bruch, falls es einen Deckel gibt
local function CurrencyDisplay(entry)
    local main = FormatNumber(entry.quantity)
    if entry.maxQuantity and entry.maxQuantity > 0 then
        return main .. "  |c" .. INK_DIM .. "/ " .. FormatNumber(entry.maxQuantity) .. "|r",
               entry.quantity / entry.maxQuantity
    end
    if entry.canEarnPerWeek and entry.maxWeekly > 0 then
        return main .. "  |c" .. INK_DIM .. "Woche " .. FormatNumber(entry.earnedThisWeek)
               .. "/" .. FormatNumber(entry.maxWeekly) .. "|r",
               entry.earnedThisWeek / entry.maxWeekly
    end
    return main, nil
end

-- ============================================================================
-- D) Automatische Erkennung
-- ============================================================================

-- Registry nach dem Vorbild von RestedXP: eine neue Bedingungsart hinzufügen
-- heißt, eine Funktion in diese Tabelle zu legen.
local renderCache = {}

local function VaultTypeFor(row)
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    if row == "raid"  then return (E and E.Raid) or 3 end
    if row == "mplus" then return (E and E.Activities) or 1 end
    if row == "world" then return (E and (E.World or E.Delves)) or 6 end
end

local function GetVaultActivities()
    if renderCache.vault then return renderCache.vault end
    local acts = {}
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        local ok, a = pcall(C_WeeklyRewards.GetActivities)
        if ok and type(a) == "table" then acts = a end
    end
    renderCache.vault = acts
    return acts
end

local CHECKERS = {
    quest = function(spec)
        if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and spec.id) then return false end
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, spec.id)
        return (ok and done) and true or false
    end,
    questAny = function(spec)
        if type(spec.ids) ~= "table" then return false end
        for _, id in ipairs(spec.ids) do
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
            if ok and done then return true end
        end
        return false
    end,
    currency = function(spec)
        local info = GetCurrencyByID(spec.id)
        return (info and info.quantity >= (tonumber(spec.min) or 1)) and true or false
    end,
    renown = function(spec)
        if not (C_MajorFactions and C_MajorFactions.GetMajorFactionData) then return false end
        local ok, data = pcall(C_MajorFactions.GetMajorFactionData, spec.faction)
        if not ok or type(data) ~= "table" then return false end
        return (tonumber(data.renownLevel) or 0) >= (tonumber(spec.level) or 1)
    end,
    vault = function(spec)
        local want = VaultTypeFor(spec.row)
        if not want then return false end
        local best = 0
        for _, a in ipairs(GetVaultActivities()) do
            if a.type == want then
                local p = a.progress
                if type(p) == "table" then p = p.progress or p.current or p.value end
                p = tonumber(p) or 0
                if p > best then best = p end
            end
        end
        return best >= (tonumber(spec.need) or 1)
    end,
}

-- Liefert: istAbgehakt, wurdeAutomatischErkannt
-- Ein von Hand gesetzter Haken gewinnt immer. Die Automatik hakt nur
-- zusätzlich ab, sie entfernt nie etwas.
local function GetItemState(item)
    local checks = ChrissisAddonCharDB and ChrissisAddonCharDB.checks
    if checks and checks[item.id] then return true, false end
    local spec = item.check
    if spec then
        local fn = CHECKERS[spec.type]
        if fn then
            local ok, result = pcall(fn, spec)
            if ok and result then return true, true end
        end
    end
    return false, false
end

-- ============================================================================
-- E) Frames
-- ============================================================================

local frame = CreateFrame("Frame", "ChrissisAddon_MainFrame", UIParent)
frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:Hide()

-- Flache Fläche statt Zierrahmen. Das ist der Kern der Umstellung.
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(BG_R, BG_G, BG_B, BG_A)

-- Ein Pixel Kante, mehr nicht
local function AddHairlineBorder(f, alpha)
    local a = alpha or RULE_ALPHA
    local t = {}
    for i = 1, 4 do
        t[i] = f:CreateTexture(nil, "BORDER")
        t[i]:SetColorTexture(1, 1, 1, a)
    end
    t[1]:SetPoint("TOPLEFT");    t[1]:SetPoint("TOPRIGHT");    t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT");    t[3]:SetPoint("BOTTOMLEFT");  t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT");   t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(1)
end
AddHairlineBorder(frame)

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ChrissisAddonDB.point, ChrissisAddonDB.relPoint = point, relPoint
    ChrissisAddonDB.x, ChrissisAddonDB.y = x, y
end)

-- Titel links statt zentriert, wie im Quest-Tracker
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
title:SetText("|c" .. GOLD .. "Chrissi's Addon|r")

local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
subTitle:SetJustifyH("LEFT")

-- Schlichtes Kreuz statt Blizzard-Knopf
local closeBtn = CreateFrame("Button", nil, frame)
closeBtn:SetSize(18, 18)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 4, -PAD + 2)
closeBtn.label = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeBtn.label:SetPoint("CENTER")
closeBtn.label:SetText("|c" .. INK_DIM .. "x|r")
closeBtn:SetScript("OnEnter", function(self) self.label:SetText("|c" .. GOLD .. "x|r") end)
closeBtn:SetScript("OnLeave", function(self) self.label:SetText("|c" .. INK_DIM .. "x|r") end)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Kennzahlen
local ilvlLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ilvlLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -52)
ilvlLabel:SetText("|c" .. INK_DIM .. "Itemlevel|r")

local ilvlValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ilvlValue:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -50)
ilvlValue:SetJustifyH("RIGHT")

local pinned = CreateFrame("Frame", nil, frame)
pinned:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -70)
pinned:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -70)
pinned:SetHeight(1)

local pinnedRule = frame:CreateTexture(nil, "ARTWORK")
pinnedRule:SetHeight(1)
pinnedRule:SetColorTexture(1, 1, 1, RULE_ALPHA)

-- Flache Textreiter mit Unterstrich statt Blizzard-Knöpfen
local function CreateTab(key, label)
    local b = CreateFrame("Button", nil, frame)
    b:SetHeight(20)
    b.key = key
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("LEFT")
    b.label:SetText(label)
    b:SetWidth(b.label:GetStringWidth() + 4)
    b.underline = b:CreateTexture(nil, "ARTWORK")
    b.underline:SetHeight(2)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, -2)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -2)
    b:SetScript("OnClick", function(self)
        ChrissisAddonDB.tab = self.key
        ns.Render()
    end)
    return b
end

local tabGuide    = CreateTab("guide", "Checkliste")
local tabCurrency = CreateTab("currency", "Währungen")

local tabRule = frame:CreateTexture(nil, "ARTWORK")
tabRule:SetHeight(1)
tabRule:SetColorTexture(1, 1, 1, RULE_ALPHA)

-- Wochen-Karussell -----------------------------------------------------------
local nav = CreateFrame("Frame", nil, frame)
nav:SetHeight(38)

local function CreateArrow(text)
    local b = CreateFrame("Button", nil, nav)
    b:SetSize(22, 22)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self.label:SetTextColor(HexToRGB(GOLD)) end
    end)
    b:SetScript("OnLeave", function(self)
        self.label:SetTextColor(HexToRGB(self:IsEnabled() and INK or INK_DONE))
    end)
    return b
end

local navPrev = CreateArrow("<")
navPrev:SetPoint("LEFT", nav, "LEFT", 0, 4)
local navNext = CreateArrow(">")
navNext:SetPoint("RIGHT", nav, "RIGHT", 0, 4)

local navTitle = nav:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
navTitle:SetPoint("TOP", nav, "TOP", 0, -1)

local navSub = nav:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
navSub:SetPoint("TOP", navTitle, "BOTTOM", 0, -2)

local navMeterBg = nav:CreateTexture(nil, "ARTWORK")
navMeterBg:SetHeight(2)
navMeterBg:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 0)
navMeterBg:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, 0)
navMeterBg:SetColorTexture(1, 1, 1, 0.07)

local navMeterFill = nav:CreateTexture(nil, "OVERLAY")
navMeterFill:SetHeight(2)
navMeterFill:SetPoint("BOTTOMLEFT", navMeterBg, "BOTTOMLEFT", 0, 0)

local navCount = nav:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
navCount:SetPoint("BOTTOMRIGHT", navMeterBg, "TOPRIGHT", 0, 3)

local function ClampSection(i)
    local n = #ns.SECTIONS
    if n == 0 then return 1 end
    if i < 1 then return n end
    if i > n then return 1 end
    return i
end

local function StepSection(delta)
    ChrissisAddonDB.section = ClampSection((tonumber(ChrissisAddonDB.section) or 1) + delta)
    ns.Render()
end

navPrev:SetScript("OnClick", function() StepSection(-1) end)
navNext:SetScript("OnClick", function() StepSection(1) end)

-- Inhalt ----------------------------------------------------------------------
local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(1, 1)
scrollFrame:SetScrollChild(scrollChild)

-- Fußzeile: Skalierung ---------------------------------------------------------
local footRule = frame:CreateTexture(nil, "ARTWORK")
footRule:SetHeight(1)
footRule:SetColorTexture(1, 1, 1, RULE_ALPHA)
footRule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 28)
footRule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 28)

local function ApplyScale(v)
    v = math.max(SCALE_MIN, math.min(SCALE_MAX, v))
    v = math.floor(v * 100 + 0.5) / 100
    ChrissisAddonDB.scale = v
    frame:SetScale(v)
    return v
end
ns.ApplyScale = ApplyScale

local scaleText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
scaleText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 9)

local function CreateStepButton(text, delta)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(16, 16)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText("|c" .. INK_DIM .. text .. "|r")
    b:SetScript("OnEnter", function(self) self.label:SetText("|c" .. GOLD .. text .. "|r") end)
    b:SetScript("OnLeave", function(self) self.label:SetText("|c" .. INK_DIM .. text .. "|r") end)
    b:SetScript("OnClick", function()
        ApplyScale((tonumber(ChrissisAddonDB.scale) or 1) + delta)
        ns.Render()
    end)
    return b
end

local scaleMinus = CreateStepButton("-", -SCALE_STEP)
local scalePlus  = CreateStepButton("+",  SCALE_STEP)
scalePlus:SetPoint("RIGHT", scaleText, "LEFT", -6, 0)
scaleMinus:SetPoint("RIGHT", scalePlus, "LEFT", -2, 0)

local scaleHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
scaleHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 9)
scaleHint:SetText("|c" .. INK_DONE .. "Strg + Mausrad: Größe|r")

-- Mausrad: mit Strg skalieren, sonst scrollen
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    if IsControlKeyDown() then
        ApplyScale((tonumber(ChrissisAddonDB.scale) or 1) + delta * SCALE_STEP)
        ns.Render()
        return
    end
    local new = self:GetVerticalScroll() - (delta * 34)
    local max = self:GetVerticalScrollRange()
    if new < 0 then new = 0 end
    if new > max then new = max end
    self:SetVerticalScroll(new)
end)

frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function(_, delta)
    if IsControlKeyDown() then
        ApplyScale((tonumber(ChrissisAddonDB.scale) or 1) + delta * SCALE_STEP)
        ns.Render()
    end
end)

-- ============================================================================
-- F) Widget-Pools
-- ============================================================================

-- Frames lassen sich in WoW nicht löschen, nur verstecken. Ohne Pool wächst
-- der Speicher bei jedem Neuaufbau.
local pools = { line = {}, check = {}, header = {} }
local active = {}

local function NewLine(parent)
    local f = CreateFrame("Frame", nil, parent)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(14, 14)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetJustifyH("LEFT")

    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    f.value:SetJustifyH("RIGHT")

    f.meterBg = f:CreateTexture(nil, "ARTWORK")
    f.meterBg:SetHeight(2)
    f.meterBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 1)
    f.meterBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
    f.meterBg:SetColorTexture(1, 1, 1, 0.07)

    f.meterFill = f:CreateTexture(nil, "OVERLAY")
    f.meterFill:SetHeight(2)
    f.meterFill:SetPoint("BOTTOMLEFT", f.meterBg, "BOTTOMLEFT", 0, 0)

    return f
end

local function NewCheck(parent)
    local f = CreateFrame("Frame", nil, parent)

    -- Farbiger Streifen links trägt die Blockzugehörigkeit, damit der Text
    -- in normaler Schriftfarbe bleiben kann.
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetWidth(2)
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
    f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 1)

    f.box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.box:SetSize(18, 18)
    f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 8, 1)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(true)

    return f
end

-- Überschrift im Tracker-Stil: Text links, Haarlinie füllt den Rest
local function NewHeader(parent)
    local f = CreateFrame("Button", nil, parent)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")

    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    f.rule:SetColorTexture(1, 1, 1, RULE_ALPHA)
    f.rule:SetPoint("LEFT", f.text, "RIGHT", 8, 0)
    f.rule:SetPoint("RIGHT", f, "RIGHT", 0, 0)

    return f
end

local FACTORY = { line = NewLine, check = NewCheck, header = NewHeader }

local function Acquire(kind, parent)
    local f = table.remove(pools[kind]) or FACTORY[kind](parent or scrollChild)
    if parent then f:SetParent(parent) end
    active[#active + 1] = { kind = kind, frame = f }
    f:Show()
    return f
end

local function ReleaseAll()
    for i = #active, 1, -1 do
        local rec = active[i]
        rec.frame:Hide()
        rec.frame:ClearAllPoints()
        rec.frame:SetParent(scrollChild)
        -- Nur lösen, was beim Rendern auch neu gesetzt wird. Header-Text und
        -- Header-Linie sind einmalig verankert und bleiben es.
        if rec.kind == "check" and rec.frame.text then rec.frame.text:ClearAllPoints() end
        if rec.kind == "line"  and rec.frame.name then rec.frame.name:ClearAllPoints() end
        if rec.frame.box then
            rec.frame.box:SetScript("OnClick", nil)
            rec.frame.box:SetEnabled(true)
        end
        active[i] = nil
        pools[rec.kind][#pools[rec.kind] + 1] = rec.frame
    end
end

-- ============================================================================
-- G) Rendering
-- ============================================================================

local CONTENT_W = WINDOW_WIDTH - 2 * PAD

local function RenderPinned()
    local entries = GetPinnedCurrencies()
    local y = 0

    for _, entry in ipairs(entries) do
        local row = Acquire("line", pinned)
        row:SetHeight(LINE_H)
        row:SetPoint("TOPLEFT", pinned, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", pinned, "TOPRIGHT", 0, -y)

        if entry.icon then row.icon:SetTexture(entry.icon); row.icon:Show()
        else row.icon:Hide() end

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
        row.name:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
        row.name:SetWordWrap(false)
        row.name:SetText("|c" .. INK .. entry.name .. "|r")

        local valueText, frac = CurrencyDisplay(entry)
        row.value:SetText(valueText)

        if frac then
            frac = math.max(0, math.min(1, frac))
            row.meterBg:Show(); row.meterFill:Show()
            if frac >= 1 then
                row.meterFill:SetColorTexture(HexToRGB(ns.BLOCKS.P2.color))
            else
                row.meterFill:SetColorTexture(1, 1, 1, 0.34)
            end
            row.meterFill:SetWidth(math.max(1, (CONTENT_W - 20) * frac))
        else
            row.meterBg:Hide(); row.meterFill:Hide()
        end

        y = y + LINE_H
    end

    pinned:SetHeight(math.max(y, 1))
    return y
end

local function RenderCurrencyTab(width)
    local list, collapsedHeaders = GetCurrencies()
    local y = 0

    if collapsedHeaders > 0 then
        local row = Acquire("check")
        row.box:Hide()
        row.bar:SetColorTexture(0, 0, 0, 0)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        row.text:SetWidth(width)
        row.text:SetText("|c" .. INK_DIM .. collapsedHeaders ..
            " Kategorie(n) im Währungsfenster eingeklappt, deren Einträge fehlen hier.|r")
        local h = math.max(18, row.text:GetStringHeight() + 6)
        row:SetHeight(h)
        y = y + h + 8
    end

    for _, entry in ipairs(list) do
        if entry.isHeader then
            local head = Acquire("header")
            head:SetHeight(18)
            head:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            head:SetWidth(width)
            head.text:SetText("|c" .. GOLD .. entry.name .. "|r")
            head:EnableMouse(false)
            y = y + 22
        elseif entry.quantity > 0 or ChrissisAddonDB.showZero then
            local row = Acquire("line")
            row:SetHeight(LINE_H)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, -y)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
            if entry.icon then row.icon:SetTexture(entry.icon); row.icon:Show()
            else row.icon:Hide() end
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
            row.name:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
            row.name:SetWordWrap(false)
            row.name:SetText("|c" .. INK .. entry.name .. "|r")
            row.value:SetText((CurrencyDisplay(entry)))
            row.meterBg:Hide(); row.meterFill:Hide()
            y = y + LINE_H
        end
    end

    return y
end

-- Zeigt GENAU EINEN Abschnitt. Die Navigation sitzt in der Kopfzeile.
local function RenderGuideTab(width, section)
    local y = 0
    if not section then return 0 end

    for _, blockKey in ipairs(BLOCK_ORDER) do
        local block = ns.BLOCKS[blockKey]
        local br, bg2, bb = HexToRGB(block.color)
        local any = false

        for _, item in ipairs(section.items) do
            if item.block == blockKey then
                if not any then
                    any = true
                    if y > 0 then y = y + BLOCK_GAP end
                    local head = Acquire("header")
                    head:SetHeight(16)
                    head:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
                    head:SetWidth(width)
                    head.text:SetText("|c" .. block.color .. block.label .. "|r")
                    head:EnableMouse(false)
                    y = y + 22
                end

                local checked, isAuto = GetItemState(item)

                local row = Acquire("check")
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
                row:SetWidth(width)
                row.bar:SetColorTexture(br, bg2, bb, checked and 0.25 or 0.8)

                local textLeft, textWidth
                if item.kind == "task" then
                    row.box:Show()
                    row.box:SetChecked(checked)
                    if isAuto then
                        -- Automatisch erkannt: bildet eine Tatsache ab,
                        -- also nicht wegklickbar.
                        row.box:SetEnabled(false)
                        row.box:SetScript("OnClick", nil)
                    else
                        row.box:SetEnabled(true)
                        row.box:SetScript("OnClick", function(self)
                            SetChecked(item.id, self:GetChecked())
                            ns.Render()
                        end)
                    end
                    textLeft, textWidth = 30, width - 36
                else
                    row.box:Hide()
                    textLeft, textWidth = 12, width - 18
                end

                local body = "|c" .. (checked and INK_DONE or INK) .. item.text .. "|r"
                local suffix = ""
                if isAuto then suffix = suffix .. "  |c" .. GREEN .. "[auto]|r" end
                if item.proof == "single" then
                    suffix = suffix .. "  |c" .. INK_DIM .. "[1 Quelle]|r"
                end

                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -2)
                row.text:SetWidth(textWidth)
                row.text:SetWordWrap(true)
                row.text:SetText(body .. suffix)

                local h = math.max(18, row.text:GetStringHeight() + 7)
                row:SetHeight(h)
                y = y + h + ROW_GAP
            end
        end
    end

    return y
end

function ns.Render()
    ReleaseAll()
    wipe(renderCache)

    subTitle:SetText(string.format("|c%sGuide %s · Stand %s|r",
        INK_DIM, ns.META.guideVersion, ns.META.updated))

    local overall, equipped = GetItemLevels()
    if math.abs(overall - equipped) < 0.05 then
        ilvlValue:SetText(string.format("|c%s%.1f|r", GOLD, equipped))
    else
        ilvlValue:SetText(string.format("|c%s%.1f|r  |c%s(%.1f)|r",
            GOLD, equipped, INK_DIM, overall))
    end

    local pinnedHeight = RenderPinned()

    local ruleY = -(70 + pinnedHeight + 8)
    pinnedRule:ClearAllPoints()
    pinnedRule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, ruleY)
    pinnedRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, ruleY)

    -- Reiter
    local isGuide = (ChrissisAddonDB.tab ~= "currency")
    local tabsY = ruleY - 10

    tabGuide:ClearAllPoints()
    tabGuide:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, tabsY)
    tabCurrency:ClearAllPoints()
    tabCurrency:SetPoint("LEFT", tabGuide, "RIGHT", 18, 0)

    tabGuide.label:SetText(isGuide and ("|c" .. GOLD .. "Checkliste|r")
                                    or ("|c" .. INK_DIM .. "Checkliste|r"))
    tabCurrency.label:SetText(isGuide and ("|c" .. INK_DIM .. "Währungen|r")
                                       or ("|c" .. GOLD .. "Währungen|r"))
    tabGuide:SetWidth(tabGuide.label:GetStringWidth() + 4)
    tabCurrency:SetWidth(tabCurrency.label:GetStringWidth() + 4)

    if isGuide then
        tabGuide.underline:SetColorTexture(HexToRGB(GOLD))
        tabGuide.underline:Show()
        tabCurrency.underline:Hide()
    else
        tabCurrency.underline:SetColorTexture(HexToRGB(GOLD))
        tabCurrency.underline:Show()
        tabGuide.underline:Hide()
    end

    local tabRuleY = tabsY - 24
    tabRule:ClearAllPoints()
    tabRule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, tabRuleY)
    tabRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, tabRuleY)

    -- Karussell nur im Checklisten-Reiter
    local contentTop
    if isGuide then
        local idx = ClampSection(tonumber(ChrissisAddonDB.section) or 1)
        ChrissisAddonDB.section = idx
        local section = ns.SECTIONS[idx]

        nav:ClearAllPoints()
        nav:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, tabRuleY - 8)
        nav:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, tabRuleY - 8)
        nav:Show()

        navTitle:SetText("|c" .. GOLD .. (section and section.title or "?") .. "|r")
        navSub:SetText("|c" .. INK_DIM .. ((section and section.subtitle) or "") .. "|r")

        local done, total = 0, 0
        if section then
            for _, item in ipairs(section.items) do
                if item.kind == "task" then
                    total = total + 1
                    if (GetItemState(item)) then done = done + 1 end
                end
            end
        end

        if total > 0 then
            local frac = math.max(0, math.min(1, done / total))
            navMeterBg:Show(); navMeterFill:Show()
            if frac >= 1 then
                navMeterFill:SetColorTexture(HexToRGB(ns.BLOCKS.P1.color))
            else
                navMeterFill:SetColorTexture(1, 1, 1, 0.30)
            end
            navMeterFill:SetWidth(math.max(1, CONTENT_W * frac))
            navCount:SetText(string.format("|c%s%d/%d|r", INK_DIM, done, total))
        else
            navMeterBg:Hide(); navMeterFill:Hide()
            navCount:SetText("")
        end

        navPrev.label:SetTextColor(HexToRGB(INK))
        navNext.label:SetTextColor(HexToRGB(INK))

        contentTop = tabRuleY - 8 - 38 - 8
    else
        nav:Hide()
        contentTop = tabRuleY - 10
    end

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, contentTop)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 34)

    local width = CONTENT_W
    scrollChild:SetWidth(width)

    local height
    if isGuide then
        height = RenderGuideTab(width, ns.SECTIONS[ChrissisAddonDB.section])
    else
        height = RenderCurrencyTab(width)
    end
    scrollChild:SetHeight(math.max(height, 1))

    scaleText:SetText(string.format("|c%s%d%%|r", INK_DIM,
        math.floor((tonumber(ChrissisAddonDB.scale) or 1) * 100 + 0.5)))
end

local refreshTimer
local function RequestRefresh()
    if not frame:IsShown() then return end
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(0.2, function()
        refreshTimer = nil
        if frame:IsShown() then ns.Render() end
    end)
end

local function ToggleWindow()
    if frame:IsShown() then frame:Hide() else frame:Show(); ns.Render() end
end

-- ============================================================================
-- H) Event-Frame
-- ============================================================================

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
init:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
init:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
init:RegisterEvent("QUEST_TURNED_IN")
init:RegisterEvent("QUEST_LOG_UPDATE")
init:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
init:RegisterEvent("WEEKLY_REWARDS_UPDATE")

init:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ApplyDefaults()
        frame:ClearAllPoints()
        local okPos = pcall(frame.SetPoint, frame,
            ChrissisAddonDB.point, UIParent,
            ChrissisAddonDB.relPoint, ChrissisAddonDB.x, ChrissisAddonDB.y)
        if not okPos then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        ApplyScale(tonumber(ChrissisAddonDB.scale) or 1.0)

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        print("|cff33ff99Chrissi's Addon|r geladen. Tippe |cffffd100/chrissi|r.")

    else
        RequestRefresh()
    end
end)

-- ============================================================================
-- I) Slash-Commands
-- ============================================================================

local function PrintCurrencyScan()
    local list, collapsedHeaders = GetCurrencies()
    print("|cff33ff99Chrissi's Addon|r Währungs-Scan:")
    local count = 0
    for _, e in ipairs(list) do
        -- Zeigt IMMER alles, auch Nullbestände. Zweck ist das Ermitteln von
        -- IDs, dabei sind gerade die leeren wichtig.
        if not e.isHeader then
            count = count + 1
            print(string.format("  ID |cffffd100%s|r  %s  = %s",
                tostring(e.id or "?"), e.name, FormatNumber(e.quantity)))
        end
    end
    if count == 0 then
        print("  Nichts gefunden. Währungsfenster öffnen und Kategorien aufklappen.")
    end
    if collapsedHeaders > 0 then
        print(string.format("  |cffff8080Hinweis:|r %d Kategorie(n) eingeklappt.", collapsedHeaders))
    end
end

local questSnapshot

local function TakeQuestSnapshot()
    local set, count = {}, 0
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do set[id] = true; count = count + 1 end
        end
    end
    return set, count
end

local function PrintQuestDiff()
    local now, count = TakeQuestSnapshot()
    if count == 0 then
        print("|cff33ff99Chrissi's Addon|r Quest-Liste nicht verfügbar.")
        return
    end
    if not questSnapshot then
        questSnapshot = now
        print(string.format("|cff33ff99Chrissi's Addon|r %d abgeschlossene Quests gemerkt. Quest erledigen, dann |cffffd100/chrissi questdiff|r erneut.", count))
        return
    end
    local new = {}
    for id in pairs(now) do
        if not questSnapshot[id] then new[#new + 1] = id end
    end
    table.sort(new)
    if #new == 0 then
        print("|cff33ff99Chrissi's Addon|r Keine neue Quest seit dem Merken.")
    else
        print(string.format("|cff33ff99Chrissi's Addon|r %d neue Quest-ID(n):", #new))
        for _, id in ipairs(new) do
            local okT, t
            if C_QuestLog.GetTitleForQuestID then
                okT, t = pcall(C_QuestLog.GetTitleForQuestID, id)
            end
            print(string.format("  |cffffd100%d|r  %s", id, (okT and t) or "(Name noch nicht geladen)"))
        end
    end
    questSnapshot = now
end

local function PrintFactions()
    if not (C_MajorFactions and C_MajorFactions.GetMajorFactionIDs) then
        print("|cff33ff99Chrissi's Addon|r Fraktions-API nicht verfügbar.")
        return
    end
    local ok, ids = pcall(C_MajorFactions.GetMajorFactionIDs)
    if not ok or type(ids) ~= "table" then
        print("|cff33ff99Chrissi's Addon|r Keine Fraktionsdaten.")
        return
    end
    print("|cff33ff99Chrissi's Addon|r Major Factions:")
    for _, id in ipairs(ids) do
        local ok2, d = pcall(C_MajorFactions.GetMajorFactionData, id)
        if ok2 and type(d) == "table" then
            print(string.format("  ID |cffffd100%d|r  %s  (Renown %s)",
                id, d.name or "?", tostring(d.renownLevel or 0)))
        end
    end
end

local function PrintVault()
    wipe(renderCache)
    local acts = GetVaultActivities()
    print("|cff33ff99Chrissi's Addon|r Great Vault, Rohdaten:")
    if #acts == 0 then
        print("  Keine Aktivitäten. Vault öffnet sich erst mit der Season.")
        return
    end
    for i, a in ipairs(acts) do
        local p = a.progress
        if type(p) == "table" then p = p.progress or p.current or p.value end
        print(string.format("  [%d] type=%s  progress=%s  threshold=%s  level=%s",
            i, tostring(a.type), tostring(p), tostring(a.threshold), tostring(a.level)))
    end
    print("  Erwartet: raid=" .. tostring(VaultTypeFor("raid"))
        .. ", mplus=" .. tostring(VaultTypeFor("mplus"))
        .. ", world=" .. tostring(VaultTypeFor("world")))
end

SLASH_CHRISSISADDON1 = "/chrissi"
SLASH_CHRISSISADDON2 = "/chrissisaddon"

SlashCmdList["CHRISSISADDON"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd or ""

    if cmd == "scan" then
        PrintCurrencyScan()

    elseif cmd == "questdiff" then
        PrintQuestDiff()

    elseif cmd == "factions" then
        PrintFactions()

    elseif cmd == "vault" then
        PrintVault()

    elseif cmd == "scale" then
        local v = tonumber(rest)
        if v then
            if v > 5 then v = v / 100 end   -- "120" genauso erlauben wie "1.2"
            local applied = ApplyScale(v)
            print(string.format("|cff33ff99Chrissi's Addon|r Größe: %d%%", applied * 100))
            if frame:IsShown() then ns.Render() end
        else
            print(string.format("|cff33ff99Chrissi's Addon|r Größe ist %d%%. Nutzung: /chrissi scale 50 bis 150",
                math.floor((tonumber(ChrissisAddonDB.scale) or 1) * 100 + 0.5)))
        end

    elseif cmd == "zero" then
        ChrissisAddonDB.showZero = not ChrissisAddonDB.showZero
        print("|cff33ff99Chrissi's Addon|r Nullbestände: "
            .. (ChrissisAddonDB.showZero and "an" or "aus"))
        if frame:IsShown() then ns.Render() end

    elseif cmd == "reset" then
        ChrissisAddonDB.point, ChrissisAddonDB.relPoint = "CENTER", "CENTER"
        ChrissisAddonDB.x, ChrissisAddonDB.y = 0, 0
        ApplyScale(1.0)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("|cff33ff99Chrissi's Addon|r Position und Größe zurückgesetzt.")
        if frame:IsShown() then ns.Render() end

    elseif cmd == "clear" then
        wipe(ChrissisAddonCharDB.checks)
        print("|cff33ff99Chrissi's Addon|r Alle Haken dieses Charakters gelöscht.")
        if frame:IsShown() then ns.Render() end

    elseif cmd == "quellen" or cmd == "sources" then
        print("|cff33ff99Chrissi's Addon|r Guide " .. ns.META.guideVersion
            .. ", Stand " .. ns.META.updated .. ". Quellen:")
        for _, s in ipairs(ns.SOURCES) do print("  " .. s) end

    elseif cmd == "help" then
        print("|cff33ff99Chrissi's Addon|r Befehle:")
        print("  |cffffd100/chrissi|r            Fenster auf/zu")
        print("  |cffffd100/chrissi scale 120|r  Größe 50 bis 150 Prozent")
        print("  |cffffd100/chrissi quellen|r    Guide-Stand und Quellen")
        print("  |cffffd100/chrissi clear|r      Alle Haken dieses Charakters löschen")
        print("  |cffffd100/chrissi zero|r       Nullbestände ein-/ausblenden")
        print("  |cffffd100/chrissi reset|r      Position und Größe zurücksetzen")
        print("|cff808080  Werkzeuge zum Ermitteln fehlender IDs:|r")
        print("  |cffffd100/chrissi scan|r       Alle Währungs-IDs")
        print("  |cffffd100/chrissi questdiff|r  Neue Quest-IDs (vorher und nachher aufrufen)")
        print("  |cffffd100/chrissi factions|r   Fraktions-IDs und Renown-Stand")
        print("  |cffffd100/chrissi vault|r      Great-Vault-Rohdaten")

    else
        ToggleWindow()
    end
end

function ChrissisAddon_OnCompartmentClick()
    ToggleWindow()
end
