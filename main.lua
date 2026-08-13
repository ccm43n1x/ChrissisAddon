--[[
    Chrissi's Addon v0.2.0 - Logik
    ------------------------------
    Diese Datei enthaelt KEINEN Guide-Inhalt. Der steht in data.lua.
    Wer den Guide aktualisiert, fasst nur data.lua an.

    Aufbau:
      A) Namespace und Konstanten
      B) SavedVariables
      C) Spieldaten holen
      D) Frames
      E) Widget-Pools
      F) Rendering
      G) Event-Frame
      H) Slash-Commands
]]

local addonName, ns = ...

-- ============================================================================
-- A) Konstanten
-- ============================================================================

local WINDOW_WIDTH  = 430
local WINDOW_HEIGHT = 560
local PAD           = 16

-- Welche Waehrungen oben festgepinnt werden. Treffer per Teilstring.
-- ACHTUNG: Das sind englische Namen. Auf einem deutschen Client greift die
-- Anpinnung nicht. Dauerhafte Loesung waeren Waehrungs-IDs, die sind
-- sprachunabhaengig. Dafuer einmal /chrissi scan laufen lassen.
local PINNED_PATTERNS = {
    "Mistcrest",
    "Spark Dust",
    "Coffer Key",
    "Voidcore",
    "Field Accolade",
}

local BLOCK_ORDER = { "P1", "P2", "P3", "NO" }

-- ============================================================================
-- B) SavedVariables
-- ============================================================================

-- Bewusst global. WoW persistiert nur globale Tabellen aus der .toc.
ChrissisAddonDB     = ChrissisAddonDB or {}       -- accountweit
ChrissisAddonCharDB = ChrissisAddonCharDB or {}   -- pro Charakter

local DEFAULTS = {
    point    = "CENTER",
    relPoint = "CENTER",
    x        = 0,
    y        = 0,
    scale    = 1.0,
    tab      = "guide",   -- "guide" oder "currency"
    showZero = false,
    collapsed = {},
}

local CHAR_DEFAULTS = {
    checks = {},          -- [itemID] = true
}

local function ApplyDefaults()
    for key, value in pairs(DEFAULTS) do
        -- Booleans brauchen die nil-Pruefung, "or" wuerde false verschlucken
        if ChrissisAddonDB[key] == nil then
            if type(value) == "table" then
                ChrissisAddonDB[key] = {}
            else
                ChrissisAddonDB[key] = value
            end
        end
    end
    for key, value in pairs(CHAR_DEFAULTS) do
        if ChrissisAddonCharDB[key] == nil then
            ChrissisAddonCharDB[key] = (type(value) == "table") and {} or value
        end
    end
end

local function IsChecked(id)
    return ChrissisAddonCharDB.checks[id] and true or false
end

local function SetChecked(id, value)
    ChrissisAddonCharDB.checks[id] = value and true or nil
end

local function IsCollapsed(id)
    return ChrissisAddonDB.collapsed[id] and true or false
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

-- Laeuft Blizzards Waehrungsliste ab. Wir verdrahten keine IDs hart, weil
-- die sich mit jeder Season aendern. Ein Scan bleibt gueltig.
local function GetCurrencies()
    local list, collapsedHeaders = {}, 0

    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then
        return list, collapsedHeaders
    end

    local size = C_CurrencyInfo.GetCurrencyListSize() or 0

    for i = 1, size do
        -- pcall: Wenn Blizzard das Format aendert, faellt eine Zeile aus
        -- statt das ganze Add-on zu zerlegen.
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
        if ok and info then
            if info.isHeader then
                if not info.isHeaderExpanded then
                    collapsedHeaders = collapsedHeaders + 1
                end
                list[#list + 1] = { isHeader = true, name = info.name or "?" }
            else
                local quantity = tonumber(info.quantity) or 0
                local id
                if C_CurrencyInfo.GetCurrencyListLink then
                    local okLink, link = pcall(C_CurrencyInfo.GetCurrencyListLink, i)
                    if okLink and link then
                        id = tonumber(link:match("currency:(%d+)"))
                    end
                end
                list[#list + 1] = {
                    isHeader       = false,
                    id             = id,
                    name           = info.name or "?",
                    quantity       = quantity,
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

-- Die angepinnten Waehrungen, in der Reihenfolge von PINNED_PATTERNS
local function GetPinnedCurrencies()
    local all = GetCurrencies()
    local out = {}
    for _, pattern in ipairs(PINNED_PATTERNS) do
        for _, entry in ipairs(all) do
            if not entry.isHeader and entry.name:find(pattern, 1, true) then
                out[#out + 1] = entry
            end
        end
    end
    return out
end

local function FormatCurrencyValue(entry)
    local text = FormatNumber(entry.quantity)
    if entry.canEarnPerWeek and entry.maxWeekly > 0 then
        text = text .. string.format("  |cff808080(Woche %s/%s)|r",
            FormatNumber(entry.earnedThisWeek), FormatNumber(entry.maxWeekly))
    elseif entry.maxQuantity > 0 then
        text = text .. string.format("  |cff808080(max %s)|r", FormatNumber(entry.maxQuantity))
    end
    return text
end

-- ============================================================================
-- D) Frames
-- ============================================================================

local frame = CreateFrame("Frame", "ChrissisAddon_MainFrame", UIParent, "BackdropTemplate")
frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})

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

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -14)
title:SetText("Chrissi's Addon")

local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subTitle:SetPoint("TOP", title, "BOTTOM", 0, -2)

local ilvlText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ilvlText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -56)
ilvlText:SetJustifyH("LEFT")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)

-- Container fuer die angepinnten Waehrungen
local pinned = CreateFrame("Frame", nil, frame)
pinned:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -76)
pinned:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + 2), -76)
pinned:SetHeight(1)

-- Reiter
local function CreateTab(key, label)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:SetText(label)
    b.key = key
    b:SetScript("OnClick", function(self)
        ChrissisAddonDB.tab = self.key
        ns.Render()
    end)
    return b
end

local tabGuide    = CreateTab("guide",    "Checkliste")
local tabCurrency = CreateTab("currency", "Waehrungen")

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + 18), PAD + 2)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(1, 1)
scrollFrame:SetScrollChild(scrollChild)

scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local new = self:GetVerticalScroll() - (delta * 32)
    local max = self:GetVerticalScrollRange()
    if new < 0 then new = 0 end
    if new > max then new = max end
    self:SetVerticalScroll(new)
end)

-- ============================================================================
-- E) Widget-Pools
-- ============================================================================

-- Frames lassen sich in WoW nicht loeschen, nur verstecken. Ohne Pool waechst
-- der Speicher bei jedem Neuaufbau. Das ist Pflicht, keine Optimierung.
local pools = { line = {}, check = {}, header = {} }
local active = {}

local function NewLine(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetJustifyH("LEFT")
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    f.value:SetJustifyH("RIGHT")
    return f
end

local function NewCheck(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.box:SetSize(20, 20)
    f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(true)
    return f
end

local function NewHeader(parent)
    local f = CreateFrame("Button", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
    return f
end

local FACTORY = { line = NewLine, check = NewCheck, header = NewHeader }

local function Acquire(kind)
    local f = table.remove(pools[kind]) or FACTORY[kind](scrollChild)
    active[#active + 1] = { kind = kind, frame = f }
    f:Show()
    return f
end

local function AcquirePinned(kind)
    -- Die angepinnten Zeilen haengen an "pinned", nicht am Scrollbereich
    local f = table.remove(pools[kind]) or FACTORY[kind](pinned)
    f:SetParent(pinned)
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

        -- Nur die Anker loesen, die beim Rendern auch neu gesetzt werden.
        -- Der Header-Text wird EINMAL bei der Erstellung verankert. Wuerde man
        -- ihn hier mitloeschen, waere die Ueberschrift beim Recyceln unsichtbar.
        if rec.kind == "check" and rec.frame.text then
            rec.frame.text:ClearAllPoints()
        end
        if rec.kind == "line" and rec.frame.name then
            rec.frame.name:ClearAllPoints()
        end

        if rec.frame.box then rec.frame.box:SetScript("OnClick", nil) end
        if rec.kind == "header" then rec.frame:SetScript("OnClick", nil) end

        active[i] = nil
        pools[rec.kind][#pools[rec.kind] + 1] = rec.frame
    end
end

-- ============================================================================
-- F) Rendering
-- ============================================================================

local function RenderPinned()
    local entries = GetPinnedCurrencies()
    local y = 0

    if #entries == 0 then
        pinned:SetHeight(1)
        return 0
    end

    for _, entry in ipairs(entries) do
        local row = AcquirePinned("line")
        row:SetHeight(18)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pinned, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", pinned, "TOPRIGHT", 0, -y)

        if entry.icon then
            row.icon:SetTexture(entry.icon)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
        row.name:SetWordWrap(false)
        row.name:SetText(entry.name)
        row.value:SetText(FormatCurrencyValue(entry))

        y = y + 18
    end

    pinned:SetHeight(y)
    return y
end

local function RenderCurrencyTab(width)
    local list, collapsedHeaders = GetCurrencies()
    local y = 0

    if collapsedHeaders > 0 then
        local row = Acquire("check")
        row.box:Hide()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        row.text:SetWidth(width - 4)
        row.text:SetText("|cffff8080" .. collapsedHeaders ..
            " Kategorie(n) im Waehrungsfenster eingeklappt, deren Eintraege fehlen hier.|r")
        local h = math.max(18, row.text:GetStringHeight() + 6)
        row:SetHeight(h)
        row:SetWidth(width)
        y = y + h + 4
    end

    for _, entry in ipairs(list) do
        if entry.isHeader then
            local row = Acquire("header")
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            row:SetWidth(width)
            row.text:SetText("|cffffd100" .. entry.name .. "|r")
            row:SetScript("OnClick", nil)
            y = y + 22
        elseif entry.quantity > 0 or ChrissisAddonDB.showZero then
            local row = Acquire("line")
            row:SetHeight(18)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -y)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)

            if entry.icon then
                row.icon:SetTexture(entry.icon); row.icon:Show()
            else
                row.icon:Hide()
            end
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
            row.name:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
            row.name:SetWordWrap(false)
            row.name:SetText(entry.name)
            row.value:SetText(FormatCurrencyValue(entry))
            y = y + 18
        end
    end

    return y
end

local function RenderGuideTab(width)
    local y = 0

    for _, section in ipairs(ns.SECTIONS) do
        -- Fortschritt der Sektion zaehlen
        local done, total = 0, 0
        for _, item in ipairs(section.items) do
            if item.kind == "task" then
                total = total + 1
                if IsChecked(item.id) then done = done + 1 end
            end
        end

        local collapsed = IsCollapsed(section.id)
        local arrow = collapsed and "+" or "-"
        local counter = (total > 0) and string.format("  |cff808080(%d/%d)|r", done, total) or ""

        local head = Acquire("header")
        head:SetHeight(24)
        head:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        head:SetWidth(width)
        head.text:SetText(string.format("|cffffd100%s %s|r%s", arrow, section.title, counter))
        head:SetScript("OnClick", function()
            ChrissisAddonDB.collapsed[section.id] = not collapsed or nil
            ns.Render()
        end)
        y = y + 26

        if not collapsed then
            -- Nach den vier Bloecken gruppieren: das ist die eigene Struktur,
            -- die Larias' Guide nicht hat.
            for _, blockKey in ipairs(BLOCK_ORDER) do
                local block = ns.BLOCKS[blockKey]
                local any = false

                for _, item in ipairs(section.items) do
                    if item.block == blockKey then
                        if not any then
                            any = true
                            local sub = Acquire("header")
                            sub:SetHeight(20)
                            sub:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -y)
                            sub:SetWidth(width - 10)
                            sub.text:SetText("|c" .. block.color .. block.label .. "|r")
                            sub:SetScript("OnClick", nil)
                            y = y + 20
                        end

                        local row = Acquire("check")
                        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 14, -y)
                        row:SetWidth(width - 14)

                        local textLeft, textWidth
                        if item.kind == "task" then
                            row.box:Show()
                            row.box:SetChecked(IsChecked(item.id))
                            row.box:SetScript("OnClick", function(self)
                                SetChecked(item.id, self:GetChecked())
                                ns.Render()
                            end)
                            textLeft, textWidth = 24, width - 42
                        else
                            row.box:Hide()
                            textLeft, textWidth = 4, width - 22
                        end

                        local body = item.text
                        if item.proof == "single" then
                            body = body .. "  |cff808080[1 Quelle]|r"
                        end
                        if item.kind == "task" and IsChecked(item.id) then
                            body = "|cff808080" .. body .. "|r"
                        elseif item.kind == "rule" then
                            body = "|c" .. block.color .. body .. "|r"
                        end

                        row.text:ClearAllPoints()
                        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -3)
                        row.text:SetWidth(textWidth)
                        row.text:SetWordWrap(true)
                        row.text:SetText(body)

                        local h = math.max(20, row.text:GetStringHeight() + 8)
                        row:SetHeight(h)
                        y = y + h + 2
                    end
                end
            end
            y = y + 6
        end
    end

    return y
end

function ns.Render()
    ReleaseAll()

    -- Untertitel mit Guide-Stand. Billiges, wirksames Vertrauenssignal.
    subTitle:SetText(string.format("Guide %s, Stand %s  |  %s",
        ns.META.guideVersion, ns.META.updated, ns.META.season))

    local overall, equipped = GetItemLevels()
    if math.abs(overall - equipped) < 0.05 then
        ilvlText:SetText(string.format("Itemlevel: |cffffd100%.1f|r", equipped))
    else
        ilvlText:SetText(string.format(
            "Itemlevel: |cffffd100%.1f|r angelegt, %.1f gesamt", equipped, overall))
    end

    local pinnedHeight = RenderPinned()

    -- Reiter unter den angepinnten Waehrungen platzieren
    local tabsY = -(76 + pinnedHeight + 8)
    tabGuide:ClearAllPoints()
    tabGuide:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, tabsY)
    tabCurrency:ClearAllPoints()
    tabCurrency:SetPoint("LEFT", tabGuide, "RIGHT", 6, 0)

    local isGuide = (ChrissisAddonDB.tab ~= "currency")
    tabGuide:SetEnabled(not isGuide)
    tabCurrency:SetEnabled(isGuide)

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, tabsY - 28)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + 18), PAD + 2)

    -- Breite rechnen statt abfragen. GetWidth() liefert direkt nach dem
    -- Neuverankern noch den alten Wert, weil WoW Anker erst spaeter aufloest.
    -- Beim ersten Render waere die Breite sonst 0 und nichts umgebrochen.
    local width = WINDOW_WIDTH - (PAD + 2) - (PAD + 18)
    scrollChild:SetWidth(width)

    local height
    if isGuide then
        height = RenderGuideTab(width)
    else
        height = RenderCurrencyTab(width)
    end

    scrollChild:SetHeight(math.max(height, 1))
end

-- Debouncing: zehn Events in einer Sekunde erzeugen genau einen Neuaufbau
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
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        ns.Render()
    end
end

-- ============================================================================
-- G) Event-Frame
-- ============================================================================

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
init:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
init:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")

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
        frame:SetScale(tonumber(ChrissisAddonDB.scale) or 1.0)

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        print("|cff33ff99Chrissi's Addon|r geladen. Tippe |cffffd100/chrissi|r.")

    else
        RequestRefresh()
    end
end)

-- ============================================================================
-- H) Slash-Commands
-- ============================================================================

local function PrintCurrencyScan()
    local list, collapsedHeaders = GetCurrencies()
    print("|cff33ff99Chrissi's Addon|r Waehrungs-Scan:")
    local count = 0
    for _, e in ipairs(list) do
        if not e.isHeader and (e.quantity > 0 or ChrissisAddonDB.showZero) then
            count = count + 1
            print(string.format("  ID |cffffd100%s|r  %s  = %s",
                tostring(e.id or "?"), e.name, FormatNumber(e.quantity)))
        end
    end
    if count == 0 then
        print("  Nichts gefunden. Waehrungsfenster oeffnen und Kategorien aufklappen.")
    end
    if collapsedHeaders > 0 then
        print(string.format("  |cffff8080Hinweis:|r %d Kategorie(n) eingeklappt.", collapsedHeaders))
    end
end

SLASH_CHRISSISADDON1 = "/chrissi"
SLASH_CHRISSISADDON2 = "/chrissisaddon"

SlashCmdList["CHRISSISADDON"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "scan" then
        PrintCurrencyScan()

    elseif msg == "zero" then
        ChrissisAddonDB.showZero = not ChrissisAddonDB.showZero
        print("|cff33ff99Chrissi's Addon|r Nullbestaende: "
            .. (ChrissisAddonDB.showZero and "an" or "aus"))
        if frame:IsShown() then ns.Render() end

    elseif msg == "reset" then
        ChrissisAddonDB.point, ChrissisAddonDB.relPoint = "CENTER", "CENTER"
        ChrissisAddonDB.x, ChrissisAddonDB.y = 0, 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("|cff33ff99Chrissi's Addon|r Fensterposition zurueckgesetzt.")

    elseif msg == "clear" then
        wipe(ChrissisAddonCharDB.checks)
        print("|cff33ff99Chrissi's Addon|r Alle Haken dieses Charakters geloescht.")
        if frame:IsShown() then ns.Render() end

    elseif msg == "quellen" or msg == "sources" then
        print("|cff33ff99Chrissi's Addon|r Guide " .. ns.META.guideVersion
            .. ", Stand " .. ns.META.updated .. ". Quellen:")
        for _, s in ipairs(ns.SOURCES) do print("  " .. s) end

    elseif msg == "help" then
        print("|cff33ff99Chrissi's Addon|r Befehle:")
        print("  |cffffd100/chrissi|r          Fenster auf/zu")
        print("  |cffffd100/chrissi scan|r     Waehrungs-IDs ins Chatfenster")
        print("  |cffffd100/chrissi quellen|r  Guide-Stand und Quellen")
        print("  |cffffd100/chrissi clear|r    Alle Haken dieses Charakters loeschen")
        print("  |cffffd100/chrissi zero|r     Nullbestaende ein-/ausblenden")
        print("  |cffffd100/chrissi reset|r    Fensterposition zuruecksetzen")

    else
        ToggleWindow()
    end
end

function ChrissisAddon_OnCompartmentClick()
    ToggleWindow()
end
