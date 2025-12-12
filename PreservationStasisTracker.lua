----------------------------------------[[
-- Initialization
----------------------------------------]]

local version = select(4, GetBuildInfo())
if version < 120000 then
    print('Preservation Stasis Tracker is designed only for Midnight.')
    return
end
local _, class = UnitClass("player")
if class ~= "EVOKER" then return end

local colorList = {
    Red = { r = 1, g = 0, b = 0 },
    Green = { r = 0, g = 1, b = 0 },
    Blue = { r = 0, g = 0, b = 1 },
    Yellow = { r = 1, g = 1, b = 0 },
    Orange = { r = 1, g = 0.5, b = 0 },
    Purple = { r = 0.5, g = 0, b = 1 },
    Pink = { r = 1, g = 0, b = 0.5 }
}

----------------------------------------[[
-- Display
----------------------------------------]]
local stasisDisplay = CreateFrame("Frame", "PreservationStasisTrackerDisplay", UIParent)
stasisDisplay:SetSize(120, 55)
stasisDisplay:SetPoint("CENTER", UIParent, "CENTER")
stasisDisplay:SetMovable(true)
stasisDisplay:SetClampedToScreen(true)
stasisDisplay:EnableMouse(true)
stasisDisplay:RegisterForDrag("LeftButton")
stasisDisplay:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
stasisDisplay:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

stasisDisplay.icons = {}
for i = 1, 3 do
    stasisDisplay.icons[i] = stasisDisplay:CreateTexture(nil, "BACKGROUND")
    stasisDisplay.icons[i]:SetSize(40, 40)
    stasisDisplay.icons[i]:SetTexture(134400)
    if i == 1 then
        stasisDisplay.icons[i]:SetPoint("BOTTOMLEFT", stasisDisplay, "BOTTOMLEFT")
    else
        stasisDisplay.icons[i]:SetPoint("LEFT", stasisDisplay.icons[i - 1], "RIGHT")
    end
end

stasisDisplay.bar = CreateFrame("StatusBar", nil, stasisDisplay, "TooltipBorderedFrameTemplate")
stasisDisplay.bar:SetFrameStrata("LOW")
stasisDisplay.bar:SetSize(120, 15)
stasisDisplay.bar:SetPoint("TOPLEFT", stasisDisplay, "TOPLEFT")
stasisDisplay.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-TargetingFrame-LevelBackground")
stasisDisplay.bar:SetStatusBarColor(1, 1, 0)
stasisDisplay.bar:SetMinMaxValues(0, 30)
stasisDisplay.bar:SetValue(15)

stasisDisplay.text = stasisDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stasisDisplay.text:SetPoint("CENTER", stasisDisplay.bar, "CENTER")
stasisDisplay.text:SetShadowColor(0, 0, 0, 1)
stasisDisplay.text:SetShadowOffset(-2, -2)
stasisDisplay.text:SetScale(1.2)
stasisDisplay.text:SetText('15')

local function ChangeIconSize(value, orientation, iconPadding)
    if not iconPadding then iconPadding = 0 end
    for i = 1, 3 do
        stasisDisplay.icons[i]:SetSize(value, value)
    end
    local width, height
    if orientation and orientation == 'Vertical' then
        width, height = value + 15, (value * 3) + iconPadding * 2
        stasisDisplay.bar:SetSize(15, height)
    else
        width, height = (value * 3) + iconPadding * 2, value + 15
        stasisDisplay.bar:SetSize(width, 15)
    end
    stasisDisplay:SetSize(width, height)
    PSTDB['iconSize'] = value
end

local function ShowExample()
    stasisDisplay.bar:SetValue(15)
    stasisDisplay:Show()
    for i = 1, 3 do
        stasisDisplay.icons[i]:SetTexture(134400)
    end
end

local function ChangeIconPadding(value, orientation, iconSize)
    if not iconSize then iconSize = 40 end
    local xPad, yPad, point, rel, barX, barY
    if orientation and orientation == 'Vertical' then
        xPad, yPad, point, rel, barX, barY = 0, value, 'BOTTOM', 'TOP', 15, ((iconSize * 3) + value * 2)
    else
        xPad, yPad, point, rel, barX, barY = value, 0, 'LEFT', 'RIGHT', ((iconSize * 3) + value * 2), 15
    end
    for i = 2, 3 do
        stasisDisplay.icons[i]:ClearAllPoints()
        stasisDisplay.icons[i]:SetPoint(point, stasisDisplay.icons[i - 1], rel, xPad, yPad)
    end
    stasisDisplay.bar:SetSize(barX, barY)
    PSTDB['iconPadding'] = value
end

stasisDisplay:Hide()

----------------------------------------[[
-- Functionality
----------------------------------------]]

local spellList = {
    [370537] = 'Stasis Store',
    [370564] = 'Stasis Release',
    [361509] = 'Living Flame',
    [360995] = 'Verdant Embrace',
    [366155] = 'Reversion',
    [1256581] = 'Merithras Blessing',
    [355913] = 'Emerald Blossom',
    [374251] = 'Cauterizing Flame',
    [360823] = 'Naturalize',
    [373861] = 'Temporal Anomaly'
}

local currentState = {
    showing = false,
    storedSpells = 0,
    fillTime = nil,
    ticker = nil
}

local function StartStasis()
    stasisDisplay:Show()
    currentState.storedSpells = 0
    currentState.showing = true
    stasisDisplay.text:SetText('')
    stasisDisplay.bar:SetValue(0)
    for i = 1, 3 do
        stasisDisplay.icons[i]:SetTexture(134400)
    end
end

local function ReleaseStasis()
    if currentState.ticker then
        currentState.ticker:Cancel()
    end
    currentState.showing = false
    stasisDisplay:Hide()
end

local function FillStasis()
    currentState.fillTime = GetTime()
    currentState.ticker = C_Timer.NewTicker(0.2, function()
        local timeLeft = currentState.fillTime + 30 - GetTime()
        if timeLeft <= 0 then
            ReleaseStasis()
        end
        stasisDisplay.text:SetText(math.floor(timeLeft))
        stasisDisplay.bar:SetValue(timeLeft)
    end)
end

local function AddSpell(spellId)
    currentState.storedSpells = currentState.storedSpells + 1
    stasisDisplay.icons[currentState.storedSpells]:SetTexture(C_Spell.GetSpellTexture(spellId))
    if currentState.storedSpells == 3 then
        FillStasis()
    end
end

-- Event Tracker Frame
local castTracker = CreateFrame("Frame")
castTracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castTracker:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
castTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellId = ...
        if not issecretvalue(unit) and not issecretvalue(spellId) and unit == "player" then
            if not currentState.showing and spellList[spellId] == 'Stasis Store' then
                StartStasis()
            elseif currentState.showing then
                if currentState.storedSpells < 3 and spellList[spellId] then
                    AddSpell(spellId)
                elseif spellList[spellId] == 'Stasis Release' then
                    ReleaseStasis()
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local _, _, spellId, success = ...
        if spellId == 355936 and success then
            AddSpell(355936)
        end
    end
end)

----------------------------------------[[
-- Options
----------------------------------------]]

--Parent Frame
local optionsFrame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
optionsFrame:SetPoint("CENTER")
optionsFrame:SetSize(300, 200)
optionsFrame:SetMovable(true)
optionsFrame:SetClampedToScreen(true)
optionsFrame:EnableMouse(true)
optionsFrame:RegisterForDrag("LeftButton")
optionsFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
optionsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
optionsFrame:SetScript("OnShow", function()
    ShowExample()
end)
optionsFrame:SetScript("OnHide", function()
    stasisDisplay:Hide()
end)
optionsFrame:Hide()

--Title
optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
optionsFrame.title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 5, -3)
optionsFrame.title:SetScale(1.3)
optionsFrame.title:SetText('|cnNORMAL_FONT_COLOR:Preservation Stasis Tracker|r')

--Icon size
optionsFrame.iconSize = CreateFrame("Slider", nil, optionsFrame, "UISliderTemplateWithLabels")
optionsFrame.iconSize:SetPoint("TOP", optionsFrame, "TOP", 0, -45)
optionsFrame.iconSize:SetSize(200, 20)
optionsFrame.iconSize:SetMinMaxValues(30, 60)
optionsFrame.iconSize:SetValue(40)
optionsFrame.iconSize:SetValueStep(1)
optionsFrame.iconSize:SetObeyStepOnDrag(true)
optionsFrame.iconSize.Text:SetText("Icon Size")
optionsFrame.iconSize.Low:SetText("30")
optionsFrame.iconSize.High:SetText("60")

--Grow direction
optionsFrame.growDirectionContainer = CreateFrame("Frame", nil, optionsFrame)
optionsFrame.growDirectionContainer:SetPoint("TOP", optionsFrame.iconSize, "BOTTOM", 0, -15)
optionsFrame.growDirectionContainer:SetSize(210, 20)
optionsFrame.growDirectionTitle = optionsFrame.growDirectionContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
optionsFrame.growDirectionTitle:SetPoint("LEFT", optionsFrame.growDirectionContainer, "LEFT")
optionsFrame.growDirectionTitle:SetText("Grow Direction")
optionsFrame.growDirection = CreateFrame("Frame", "PSTOptionsGrowDirectionDropdown", optionsFrame, "UIDropDownMenuTemplate")
optionsFrame.growDirection:SetPoint("RIGHT", optionsFrame.growDirectionContainer, "RIGHT", 20, -3)
UIDropDownMenu_SetWidth(optionsFrame.growDirection, 70)

--Icon padding
optionsFrame.iconPadding = CreateFrame("Slider", nil, optionsFrame, "UISliderTemplateWithLabels")
optionsFrame.iconPadding:SetPoint("TOP", optionsFrame.growDirectionContainer, "BOTTOM", 0, -20)
optionsFrame.iconPadding:SetSize(200, 20)
optionsFrame.iconPadding:SetMinMaxValues(-5, 5)
optionsFrame.iconPadding:SetValue(0)
optionsFrame.iconPadding:SetValueStep(1)
optionsFrame.iconPadding:SetObeyStepOnDrag(true)
optionsFrame.iconPadding.Text:SetText("Icon Padding")
optionsFrame.iconPadding.Low:SetText("-5")
optionsFrame.iconPadding.High:SetText("5")

--Bar Color
optionsFrame.barColorContainer = CreateFrame("Frame", nil, optionsFrame)
optionsFrame.barColorContainer:SetPoint("TOP", optionsFrame.iconPadding, "BOTTOM", 0, -15)
optionsFrame.barColorContainer:SetSize(210, 20)
optionsFrame.barColorTitle = optionsFrame.barColorContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
optionsFrame.barColorTitle:SetPoint("LEFT", optionsFrame.barColorContainer, "LEFT")
optionsFrame.barColorTitle:SetText("Bar Color")
optionsFrame.barColor = CreateFrame("Frame", "PSTOptionsBarColorDropdown", optionsFrame, "UIDropDownMenuTemplate")
optionsFrame.barColor:SetPoint("RIGHT", optionsFrame.barColorContainer, "RIGHT", 20, -3)
UIDropDownMenu_SetWidth(optionsFrame.barColor, 70)

--Setup saved options
optionsFrame:RegisterEvent("PLAYER_LOGIN")
optionsFrame:SetScript("OnEvent", function()
    PSTDB = PSTDB or {}

    if PSTDB['iconSize'] then
        ChangeIconSize(PSTDB['iconSize'], PSTDB['growDirection'], PSTDB['iconPadding'])
        optionsFrame.iconSize:SetValue(PSTDB['iconSize'])
    end
    optionsFrame.iconSize:SetScript("OnValueChanged", function(_, value)
        ChangeIconSize(value, PSTDB['growDirection'], PSTDB['iconPadding'])
    end)

    if PSTDB['iconPadding'] then
        ChangeIconPadding(PSTDB['iconPadding'], PSTDB['growDirection'], PSTDB['iconSize'])
        optionsFrame.iconPadding:SetValue(PSTDB['iconPadding'])
    end
    optionsFrame.iconPadding:SetScript("OnValueChanged", function(_, value)
        ChangeIconPadding(value, PSTDB['growDirection'], PSTDB['iconSize'])
    end)

    UIDropDownMenu_Initialize(optionsFrame.growDirection, function(self)
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(_, direction)
            local point, rel, padX, padY, barX, barY
            if direction == "Horizontal" then
                point, rel, padX, padY, barX, barY = "LEFT", "RIGHT", PSTDB['iconPadding'], 0, ((PSTDB['iconSize'] * 3) + PSTDB['iconPadding'] * 2), 15
                stasisDisplay:SetSize(PSTDB['iconSize'] * 3, PSTDB['iconSize'] + 15)
                stasisDisplay.bar:ClearAllPoints()
                stasisDisplay.bar:SetPoint("TOPLEFT", stasisDisplay, "TOPLEFT")
                stasisDisplay.bar:SetOrientation('HORIZONTAL')
            elseif direction == "Vertical" then
                point, rel, padX, padY, barX, barY = "BOTTOM", "TOP", 0, PSTDB['iconPadding'], 15, ((PSTDB['iconSize'] * 3) + PSTDB['iconPadding'] * 2)
                stasisDisplay:SetSize(PSTDB['iconSize'] + 15, PSTDB['iconSize'] * 3)
                stasisDisplay.bar:ClearAllPoints()
                stasisDisplay.bar:SetPoint("BOTTOMRIGHT", stasisDisplay, "BOTTOMRIGHT")
                stasisDisplay.bar:SetOrientation('VERTICAL')
            end
            stasisDisplay.bar:SetSize(barX, barY)
            for i = 2, 3 do
                stasisDisplay.icons[i]:ClearAllPoints()
                stasisDisplay.icons[i]:SetPoint(point, stasisDisplay.icons[i - 1], rel, padX, padY)
            end
            UIDropDownMenu_SetText(self, direction)
            PSTDB['growDirection'] = direction
        end
        local options = {
            Horizontal = false,
            Vertical = false
        }
        if PSTDB['growDirection'] then
            options[PSTDB['growDirection']] = true
            UIDropDownMenu_SetText(self, PSTDB['growDirection'])
            if PSTDB['growDirection'] == 'Vertical' then
                for i = 2, 3 do
                    stasisDisplay.icons[i]:ClearAllPoints()
                    stasisDisplay.icons[i]:SetPoint('BOTTOM', stasisDisplay.icons[i - 1], 'TOP', 0, PSTDB['iconPadding'])
                end
                stasisDisplay:SetSize(PSTDB['iconSize'] + 15, PSTDB['iconSize'] * 3)
                stasisDisplay.bar:SetSize(15, ((PSTDB['iconSize'] * 3) + PSTDB['iconPadding'] * 2))
                stasisDisplay.bar:ClearAllPoints()
                stasisDisplay.bar:SetPoint("BOTTOMRIGHT", stasisDisplay, "BOTTOMRIGHT")
                stasisDisplay.bar:SetOrientation('VERTICAL')
            end
        else
            options.Horizontal = true
            UIDropDownMenu_SetText(self, 'Horizontal')
        end
        for direction, selected in pairs(options) do
            info.text, info.checked, info.arg1 = direction, selected, direction
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_Initialize(optionsFrame.barColor, function(self)
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(_, color)
            local selectedColor = colorList[color]
            stasisDisplay.bar:SetStatusBarColor(selectedColor.r, selectedColor.g, selectedColor.b)
            UIDropDownMenu_SetText(self, color)
            PSTDB['barColor'] = color
        end
        local options = {}
        for key, _ in pairs(colorList) do
            options[key] = false
        end
        if PSTDB['barColor'] then
            options[PSTDB['barColor']] = true
            local selectedColor = colorList[PSTDB['barColor']]
            stasisDisplay.bar:SetStatusBarColor(selectedColor.r, selectedColor.g, selectedColor.b)
            UIDropDownMenu_SetText(self, PSTDB['barColor'])
        else
            options.Yellow = true
            UIDropDownMenu_SetText(self, 'Yellow')
        end
        for color, selected in pairs(options) do
            info.text, info.checked, info.arg1 = color, selected, color
            UIDropDownMenu_AddButton(info)
        end
    end)

end)

SLASH_STASISTRACKER1 = "/pst"
SlashCmdList.STASISTRACKER = function()
    optionsFrame:Show()
end
