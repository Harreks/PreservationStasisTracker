local version = select(4, GetBuildInfo())
if version ~= 120000 then
    print('Preservation Stasis Tracker is designed only for Midnight.')
    return
end
local _, class = UnitClass("player")
if class ~= "EVOKER" then return end

--Create Display
local stasisDisplay = CreateFrame("Frame", "PreservationStasisTrackerDisplay", UIParent)
stasisDisplay:SetSize(120, 40)
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
end
stasisDisplay.icons[1]:SetPoint("LEFT", stasisDisplay, "LEFT")
stasisDisplay.icons[2]:SetPoint("CENTER", stasisDisplay, "CENTER")
stasisDisplay.icons[3]:SetPoint("RIGHT", stasisDisplay, "RIGHT")

stasisDisplay.bar = CreateFrame("StatusBar", nil, stasisDisplay, "InsetFrameTemplate3")
stasisDisplay.bar:SetFrameStrata("LOW")
stasisDisplay.bar:SetSize(120, 15)
stasisDisplay.bar:SetPoint("BOTTOM", stasisDisplay, "TOP")
stasisDisplay.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-TargetingFrame-LevelBackground")
stasisDisplay.bar:SetStatusBarColor(1, 1, 0)
stasisDisplay.bar:SetMinMaxValues(0, 30)
stasisDisplay.bar:SetValue(15)

stasisDisplay.text = stasisDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stasisDisplay.text:SetPoint("CENTER", stasisDisplay.bar, "CENTER")
stasisDisplay.text:SetShadowColor(0, 0, 0, 1)
stasisDisplay.text:SetShadowOffset(-2, -2)
stasisDisplay.text:SetScale(1.2)
stasisDisplay.text:SetText(15)

stasisDisplay:Hide()

-- Dumb Workaround for Secret Empowers
local empowerCancelTracker = CreateFrame("Frame")
empowerCancelTracker:SetScript("OnEvent", function()
    empowerCancelTracker.startedMovingTimestamp = GetTime()
end)
empowerCancelTracker:SetPropagateKeyboardInput(true)
empowerCancelTracker:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        empowerCancelTracker.escapePressedTimestamp = GetTime()
    end
end)

local function StartedCastingDreamBreath()
    empowerCancelTracker.currentlyCastingDreamBreath = true
    empowerCancelTracker:RegisterEvent("PLAYER_STARTED_MOVING")
    empowerCancelTracker:EnableKeyboard(true)
end

local function FinishedCastingEmpower()
    if empowerCancelTracker.currentlyCastingDreamBreath then
        local timeStamp = GetTime()
        local empowerWasCanceled = false
        if empowerCancelTracker.startedMovingTimestamp and math.floor(timeStamp) == math.floor(empowerCancelTracker.startedMovingTimestamp) then
            empowerWasCanceled = true
        elseif empowerCancelTracker.escapePressedTimestamp and math.floor(timeStamp) == math.floor(empowerCancelTracker.escapePressedTimestamp) then
            empowerWasCanceled = true
        end
        empowerCancelTracker.currentlyCastingDreamBreath = false
        empowerCancelTracker:UnregisterAllEvents()
        empowerCancelTracker:EnableKeyboard(false)
        return empowerWasCanceled
    end
end

-- Spell Casting Logic
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
    [373861] = 'Temporal Anomaly',
    [355936] = 'Dream Breath'
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
                if spellList[spellId] == 'Dream Breath' then
                    StartedCastingDreamBreath()
                else
                    if currentState.storedSpells < 3 and spellList[spellId] then
                        AddSpell(spellId)
                    elseif spellList[spellId] == 'Stasis Release' then
                        ReleaseStasis()
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local empowerWasCanceled = FinishedCastingEmpower()
        if empowerWasCanceled ~= nil and not empowerWasCanceled then
            AddSpell(355936)
        end
    end
end)