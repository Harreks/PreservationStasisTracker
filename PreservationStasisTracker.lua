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

----------------------------------------[[
-- Display
----------------------------------------]]
local stasisDisplay = CreateFrame("Frame", "PreservationStasisTrackerDisplay", UIParent)
stasisDisplay:SetSize(120, 55)
stasisDisplay:SetPoint("CENTER")
stasisDisplay:SetClampedToScreen(true)

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

stasisDisplay.bar = CreateFrame("StatusBar", nil, stasisDisplay)
stasisDisplay.bar:SetFrameStrata("LOW")
stasisDisplay.bar:SetSize(120, 15)
stasisDisplay.bar:SetPoint("TOPLEFT", stasisDisplay, "TOPLEFT")
stasisDisplay.bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
stasisDisplay.bar:SetStatusBarColor(0.2, 0.5, 0.4)
stasisDisplay.bar:SetMinMaxValues(0, 30)
stasisDisplay.bar:SetValue(15)

stasisDisplay.barBackground = stasisDisplay.bar:CreateTexture(nil, 'BACKGROUND')
stasisDisplay.barBackground:SetAllPoints(stasisDisplay.bar)
stasisDisplay.barBackground:SetColorTexture(0, 0, 0, 1)

stasisDisplay.text = stasisDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stasisDisplay.text:SetPoint("CENTER", stasisDisplay.bar, "CENTER")
stasisDisplay.text:SetShadowColor(0, 0, 0, 1)
stasisDisplay.text:SetShadowOffset(-1, -1)
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
    local xPad, yPad, point, rel, barX, barY, width, height
    if orientation and orientation == 'Vertical' then
        xPad, yPad, point, rel, barX, barY = 0, value, 'BOTTOM', 'TOP', 15, ((iconSize * 3) + value * 2)
        width, height = iconSize + barX, barY
    else
        xPad, yPad, point, rel, barX, barY = value, 0, 'LEFT', 'RIGHT', ((iconSize * 3) + value * 2), 15
        width, height = barX, iconSize + barY
    end
    for i = 2, 3 do
        stasisDisplay.icons[i]:ClearAllPoints()
        stasisDisplay.icons[i]:SetPoint(point, stasisDisplay.icons[i - 1], rel, xPad, yPad)
    end
    stasisDisplay:SetSize(width, height)
    stasisDisplay.bar:SetSize(barX, barY)
    PSTDB['iconPadding'] = value
end

local function SetGrowDirection(direction, layout)
    local point, rel, padX, padY, barX, barY, width, height
    if direction == "Horizontal" then
        point, rel, padX, padY, barX, barY = "LEFT", "RIGHT", PSTDB[layout].iconPadding, 0, ((PSTDB[layout].iconSize * 3) + PSTDB[layout].iconPadding * 2), 15
        width, height = barX, PSTDB[layout].iconSize + barY
        stasisDisplay:SetSize(PSTDB[layout].iconSize * 3, PSTDB[layout].iconSize + 15)
        stasisDisplay.bar:ClearAllPoints()
        stasisDisplay.bar:SetPoint("TOPLEFT", stasisDisplay, "TOPLEFT")
        stasisDisplay.bar:SetOrientation('HORIZONTAL')
    elseif direction == "Vertical" then
        point, rel, padX, padY, barX, barY = "BOTTOM", "TOP", 0, PSTDB[layout].iconPadding, 15, ((PSTDB[layout].iconSize * 3) + PSTDB[layout].iconPadding * 2)
        width, height = PSTDB[layout].iconSize + barX, barY
        stasisDisplay:SetSize(PSTDB[layout].iconSize + 15, PSTDB[layout].iconSize * 3)
        stasisDisplay.bar:ClearAllPoints()
        stasisDisplay.bar:SetPoint("BOTTOMRIGHT", stasisDisplay, "BOTTOMRIGHT")
        stasisDisplay.bar:SetOrientation('VERTICAL')
    end
    stasisDisplay:SetSize(width, height)
    stasisDisplay.bar:SetSize(barX, barY)
    for i = 2, 3 do
        stasisDisplay.icons[i]:ClearAllPoints()
        stasisDisplay.icons[i]:SetPoint(point, stasisDisplay.icons[i - 1], rel, padX, padY)
    end
end

stasisDisplay:Hide()

----------------------------------------[[
-- Functionality
----------------------------------------]]

local spellList = {
    [370537] = 'Stasis Store',
    [370564] = 'Stasis Release',
    [361509] = 'Living Flame',
    [364343] = 'Echo',
    [360995] = 'Verdant Embrace',
    [366155] = 'Reversion',
    [1256581] = 'Merithras Blessing',
    [355913] = 'Emerald Blossom',
    [374251] = 'Cauterizing Flame',
    [360823] = 'Naturalize',
    [373861] = 'Temporal Anomaly'
}

local empowers = {
    TTS = 370553,
    DreamBreath = 355936,
    FireBreath = 357208
}

local currentState = {
    showing = false,
    storedSpells = 0,
    fillTime = nil,
    ticker = nil,
    tts = false
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
    if stasisDisplay.icons[currentState.storedSpells] then
        stasisDisplay.icons[currentState.storedSpells]:SetTexture(C_Spell.GetSpellTexture(spellId))
    end
    if currentState.storedSpells == 3 then
        FillStasis()
    end
end

-- This function is intentionally global, it is meant to be called from a macro to manually cancel the Stasis
function CancelAuraStasis()
    ReleaseStasis()
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
                if currentState.storedSpells < 3 then
                    if spellList[spellId] then
                        AddSpell(spellId)
                    elseif spellId == empowers.TTS and not currentState.tts then
                        currentState.tts = true
                    elseif currentState.tts then
                        if spellId == empowers.DreamBreath then
                            currentState.tts = false
                            AddSpell(spellId)
                        elseif spellId == empowers.FireBreath then
                            currentState.tts = false
                        end
                    end
                elseif spellList[spellId] == 'Stasis Release' then
                    ReleaseStasis()
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local _, _, spellId, success = ...
        if not issecretvalue(spellId) and spellId == empowers.DreamBreath and success then
            AddSpell(spellId)
        end
    end
end)

----------------------------------------[[
-- Options
----------------------------------------]]

local optionsFrame = CreateFrame('Frame')
optionsFrame:RegisterEvent("PLAYER_LOGIN")
optionsFrame:SetScript("OnEvent", function()
    PSTDB = PSTDB or {}

    local defaultData = {
        point = 'CENTER',
        x = 0,
        y = 0,
        iconSize = 40,
        growDirection = 'Horizontal',
        iconPadding = 0,
        color = { r = 0.2, g = 0.5, b = 0.4}
    }

    local function displayPositionChanged(frame, layout, point, x, y)
        PSTDB[layout].point = point
        PSTDB[layout].x = x
        PSTDB[layout].y = y
    end

    local LEM = LibStub('LibEditMode')

    LEM:RegisterCallback('enter', function()
        ShowExample()
    end)

    LEM:RegisterCallback('exit', function()
        stasisDisplay:Hide()
    end)

    LEM:RegisterCallback('layout', function(layout)
        if not PSTDB[layout] then
            PSTDB[layout] = CopyTable(defaultData)
        end
        stasisDisplay:ClearAllPoints()
        stasisDisplay:SetPoint(PSTDB[layout].point, PSTDB[layout].x, PSTDB[layout].y)
        stasisDisplay.bar:SetStatusBarColor(PSTDB[layout].color.r, PSTDB[layout].color.g, PSTDB[layout].color.b)
        ChangeIconSize(PSTDB[layout].iconSize, PSTDB[layout].growDirection, PSTDB[layout].iconPadding)
        SetGrowDirection(PSTDB[layout].growDirection, layout)
        ChangeIconPadding(PSTDB[layout].iconPadding, PSTDB[layout].growDirection, PSTDB[layout].iconSize)
    end)

    LEM:AddFrame(stasisDisplay, displayPositionChanged, defaultData)

    LEM:AddFrameSettings(stasisDisplay, {
        {
            name = 'Icon Size',
            kind = LEM.SettingType.Slider,
            default = defaultData.iconSize,
            get = function(layout)
                return PSTDB[layout].iconSize
            end,
            set = function(layout, value)
                PSTDB[layout].iconSize = value
                ChangeIconSize(value, PSTDB[layout].growDirection, PSTDB[layout].iconPadding)
            end,
            minValue = 30,
            maxValue = 60,
            valueStep = 1
        },
        {
            name = 'Icon Padding',
            kind = LEM.SettingType.Slider,
            default = defaultData.iconPadding,
            get = function(layout)
                return PSTDB[layout].iconPadding
            end,
            set = function(layout, value)
                PSTDB[layout].iconPadding = value
                ChangeIconPadding(value, PSTDB[layout].growDirection, PSTDB[layout].iconSize)
            end,
            minValue = -5,
            maxValue = 5,
            valueStep = 1
        },
        {
            name = 'Grow Direction',
            kind = LEM.SettingType.Dropdown,
            default = defaultData.growDirection,
            get = function(layout)
                return PSTDB[layout].growDirection
            end,
            set = function(layout, value)
                PSTDB[layout].growDirection = value
                SetGrowDirection(value, layout)
            end,
            values = {
                { text = 'Horizontal' },
                { text = 'Vertical' }
            }
        },
        {
            name = 'Bar Color',
            kind = LEM.SettingType.ColorPicker,
            default = CreateColor(defaultData.color.r, defaultData.color.g, defaultData.color.b),
            get = function(layout)
                return CreateColor(PSTDB[layout].color.r, PSTDB[layout].color.g, PSTDB[layout].color.b)
            end,
            set = function(layout, color)
                local colorDataR, colorDataG, colorDataB = color:GetRGB()
                PSTDB[layout].color = { r = colorDataR, g = colorDataG, b = colorDataB }
                stasisDisplay.bar:SetStatusBarColor(colorDataR, colorDataG, colorDataB)
            end
        }
    })

end)

