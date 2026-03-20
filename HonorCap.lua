local HONOR_WARN_THRESHOLD = 13500
local HONOR_CURRENCY_ID = 1792
local WARN_DISPLAY_SECONDS = 15
local FONT_PATH = "Fonts\\FRIZQT__.TTF"

local DEFAULTS = { fontSize = 52, x = 0, y = 100, locked = true }

local db  -- set on ADDON_LOADED
local isLocked = true  -- mirrors db.locked at runtime

local pendingAfterCombat = false
local isShowing = false
local lastHonor = 0
local hideTimerToken = nil

local frame = CreateFrame("Frame")

-- Warning frame (movable)
local warnFrame = CreateFrame("Frame", "HonorCapWarnFrame", UIParent)
warnFrame:SetSize(520, 140)
warnFrame:SetMovable(true)
warnFrame:SetClampedToScreen(true)
warnFrame:EnableMouse(true)
warnFrame:RegisterForDrag("LeftButton")
warnFrame:Hide()

warnFrame:SetScript("OnDragStart", function(self)
    if isLocked then return end
    self:StartMoving()
end)
warnFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local x = cx - UIParent:GetWidth() / 2
    local y = cy - UIParent:GetHeight() / 2
    db.x = x
    db.y = y
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", x, y)
end)

local label = warnFrame:CreateFontString(nil, "OVERLAY")
label:SetPoint("CENTER", warnFrame, "CENTER", 0, 20)
label:SetFont(FONT_PATH, DEFAULTS.fontSize, "OUTLINE")
label:SetText("SPEND HONOR")
label:SetTextColor(1, 0, 0)

local subLabel = warnFrame:CreateFontString(nil, "OVERLAY")
subLabel:SetPoint("TOP", label, "BOTTOM", 0, -8)
subLabel:SetFont(FONT_PATH, math.max(14, math.floor(DEFAULTS.fontSize * 0.54)), "OUTLINE")
subLabel:SetTextColor(1, 0.8, 0)

local animGroup = warnFrame:CreateAnimationGroup()
animGroup:SetLooping("REPEAT")
local alphaAnim = animGroup:CreateAnimation("Alpha")
alphaAnim:SetFromAlpha(1)
alphaAnim:SetToAlpha(0)
alphaAnim:SetDuration(1.0)
alphaAnim:SetSmoothing("IN_OUT")

local function ApplySettings()
    label:SetFont(FONT_PATH, db.fontSize, "OUTLINE")
    subLabel:SetFont(FONT_PATH, math.max(14, math.floor(db.fontSize * 0.54)), "OUTLINE")
    warnFrame:ClearAllPoints()
    warnFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function GetHonor()
    local info = C_CurrencyInfo.GetCurrencyInfo(HONOR_CURRENCY_ID)
    return info and info.quantity or 0
end

local function HideWarning()
    if hideTimerToken then
        hideTimerToken:Cancel()
        hideTimerToken = nil
    end
    animGroup:Stop()
    warnFrame:SetAlpha(1)
    warnFrame:Hide()
    isShowing = false
    pendingAfterCombat = false
end

local function ShowWarning(honor)
    if isShowing then return end
    isShowing = true
    subLabel:SetText(honor .. " / 15,000")
    warnFrame:Show()
    animGroup:Play()
    hideTimerToken = C_Timer.NewTimer(WARN_DISPLAY_SECONDS, HideWarning)
end

local function EvaluateHonor(honor)
    if honor >= HONOR_WARN_THRESHOLD then
        if InCombatLockdown() then
            pendingAfterCombat = true
        else
            ShowWarning(honor)
        end
    else
        pendingAfterCombat = false
        HideWarning()
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel:SetSize(626, 534)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HonorCap")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Warns when Honor is near the 15,000 cap.")

    local sizeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sizeHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -28)
    sizeHeader:SetText("Font Size:")

    local sizeValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeValue:SetPoint("LEFT", sizeHeader, "RIGHT", 8, 0)

    -- Plain slider (no template)
    local slider = CreateFrame("Slider", nil, panel)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(300, 16)
    slider:SetPoint("TOPLEFT", sizeHeader, "BOTTOMLEFT", 8, -18)
    slider:SetMinMaxValues(20, 80)
    slider:SetValueStep(1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    sliderBg:SetAllPoints()

    local lowLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lowLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    lowLabel:SetText("20")

    local highLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    highLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    highLabel:SetText("80")

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        db.fontSize = value
        sizeValue:SetText(value)
        ApplySettings()
    end)

    local previewBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    previewBtn:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -8, -28)
    previewBtn:SetSize(200, 26)
    previewBtn:SetText("Preview / Reposition")
    previewBtn:SetScript("OnClick", function()
        if warnFrame:IsShown() then
            animGroup:Stop()
            warnFrame:SetAlpha(1)
            warnFrame:Hide()
            isShowing = false
        else
            subLabel:SetText(GetHonor() .. " / 15,000")
            isShowing = true
            warnFrame:Show()
            animGroup:Play()
        end
    end)

    local lockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", previewBtn, "BOTTOMLEFT", 0, -8)
    lockBtn:SetSize(200, 26)

    local function UpdateLockBtn()
        lockBtn:SetText(isLocked and "Unlock Position" or "Lock Position")
    end
    UpdateLockBtn()

    lockBtn:SetScript("OnClick", function()
        isLocked = not isLocked
        db.locked = isLocked
        UpdateLockBtn()
    end)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", lockBtn, "BOTTOMLEFT", 0, -6)
    hint:SetText("Unlock, then drag the warning text to reposition it.")

    panel:SetScript("OnShow", function()
        slider:SetValue(db.fontSize)
        sizeValue:SetText(db.fontSize)
        UpdateLockBtn()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "HonorCap")
    Settings.RegisterAddOnCategory(category)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "HonorCap" then
        HonorCapDB = HonorCapDB or {}
        db = HonorCapDB
        if db.fontSize == nil then db.fontSize = DEFAULTS.fontSize end
        if db.x == nil then db.x = DEFAULTS.x end
        if db.y == nil then db.y = DEFAULTS.y end
        if db.locked == nil then db.locked = DEFAULTS.locked end
        isLocked = db.locked
        ApplySettings()
        CreateOptionsPanel()

    elseif event == "PLAYER_LOGIN" then
        lastHonor = GetHonor()

    elseif event == "PLAYER_ENTERING_WORLD" then
        EvaluateHonor(GetHonor())

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        local honor = GetHonor()
        if honor ~= lastHonor then
            lastHonor = honor
            EvaluateHonor(honor)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingAfterCombat then
            local honor = GetHonor()
            if honor >= HONOR_WARN_THRESHOLD then
                pendingAfterCombat = false
                ShowWarning(honor)
            else
                pendingAfterCombat = false
            end
        end
    end
end)
