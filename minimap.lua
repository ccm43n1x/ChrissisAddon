-- ============================================================================
-- Chrissi's Addon - Minimap-Knopf
-- ============================================================================
--
-- Bewusst ohne LibDBIcon, aus demselben Grund wie das ganze Add-on ohne Ace3
-- auskommt: die Grundmuster selbst verstehen. Ein Minimap-Knopf ist rund
-- achtzig Zeilen, eine Bibliothek dafuer waere mehr Abhaengigkeit als Nutzen.
--
-- Die Position wird als WINKEL gespeichert, nicht als Koordinate. Die Minimap
-- ist rund, der Knopf sitzt auf ihrem Rand. Ein Winkel bleibt richtig, auch
-- wenn die Minimap ihre Groesse oder Position aendert, ein x/y-Paar nicht.

local addonName, ns = ...

local RADIUS = 80
local ICON   = "Interface\\Icons\\INV_Scroll_11"

local btn = CreateFrame("Button", "ChrissisAddonMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("AnyUp")
btn:RegisterForDrag("LeftButton")
btn:SetMovable(true)

local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
icon:SetTexture(ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetSize(31, 31)
highlight:SetPoint("CENTER")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")

local function Place(angle)
    local rad = math.rad(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER",
        RADIUS * math.cos(rad), RADIUS * math.sin(rad))
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale  = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        ChrissisAddonDB.minimapAngle = angle
        Place(angle)
    end)
end)

btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- Nutzt die globale Funktion, die ohnehin schon fuer das Addon-Compartment
-- existiert. So gibt es nur einen Weg, das Fenster zu oeffnen.
btn:SetScript("OnClick", function()
    if ChrissisAddon_OnCompartmentClick then ChrissisAddon_OnCompartmentClick() end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Chrissi's Addon")
    GameTooltip:AddLine("Klick öffnet die Wochen-Checkliste", 0.85, 0.82, 0.76)
    GameTooltip:AddLine("Ziehen verschiebt den Knopf", 0.65, 0.63, 0.58)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

ns.Minimap = {}

function ns.Minimap:Init()
    Place(tonumber(ChrissisAddonDB.minimapAngle) or 200)
    if ChrissisAddonDB.hideMinimap then btn:Hide() else btn:Show() end
end

function ns.Minimap:Toggle()
    ChrissisAddonDB.hideMinimap = not ChrissisAddonDB.hideMinimap
    if ChrissisAddonDB.hideMinimap then btn:Hide() else btn:Show() end
    return not ChrissisAddonDB.hideMinimap
end
