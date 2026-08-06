-- CCP Keybind Display
-- Standalone companion-keybind overlay for Vanilla 1.12 / Interface 11200.

CCPKeybindDisplay = CCPKeybindDisplay or {}
local Addon = CCPKeybindDisplay
local MIN_WIDTH = 320
local MAX_WIDTH = 800
local MIN_AUTO_WIDTH = 220
local OVERLAY_PADDING = 6
local KEY_WIDTH = 88
local KEY_GAP = 16
local HEADER_HEIGHT = 22
local FIXED_COLUMNS = 1
local MAX_LABEL_WIDTH = 220

local ROLE_SUFFIXES = {
    { "_HEALER", "healer" },
    { "_TANK", "tank" },
    { "_MDPS", "mdps" },
    { "_RDPS", "rdps" },
    { "_DPS", "dps" },
    { "_TANHE", "tanhe" },
}

local DEFAULT_CATEGORIES = {
    general = true,
    tank = false,
    healer = false,
    tanhe = false,
    dps = false,
    mdps = false,
    rdps = false,
}

local DEFAULT_VISUAL = {
    visible = true,
    locked = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 360,
    alpha = 0.78,
    scale = 1,
    fontSize = 10,
    columns = FIXED_COLUMNS,
    rowSpacing = 0,
    background = true,
}

local DEFAULT_MINIMAP = {
    visible = true,
    angle = 220,
}

local VALID_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local function CopyDefaults(target, defaults)
    local key, value
    for key, value in defaults do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local function RestoreActionBindings(action, key1, key2)
    if not action or action == "" then return true end
    local current1, current2 = GetBindingKey(action)
    if current1 then SetBinding(current1) end
    if current2 then SetBinding(current2) end
    if key1 then SetBinding(key1, action) end
    if key2 then SetBinding(key2, action) end
    local restored1, restored2 = GetBindingKey(action)
    local expectedCount = (key1 and 1 or 0) + (key2 and 1 or 0)
    local restoredCount = (restored1 and 1 or 0) + (restored2 and 1 or 0)
    local hasKey1 = not key1 or restored1 == key1 or restored2 == key1
    local hasKey2 = not key2 or restored1 == key2 or restored2 == key2
    return expectedCount == restoredCount and hasKey1 and hasKey2
end

local function ReportBindingRollbackFailure()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555CCP Keybind Display: binding recovery was incomplete; review this command in WoW Key Bindings.|r")
    end
end

local function IsCCPAction(action)
    return action == "CP" or string.sub(action or "", 1, 4) == "CCP_"
end

local function EndsWith(text, suffix)
    return string.sub(text, -string.len(suffix)) == suffix
end

function Addon:CategoryForAction(action)
    local index, row
    for index = 1, table.getn(ROLE_SUFFIXES) do
        row = ROLE_SUFFIXES[index]
        if EndsWith(action, row[1]) then
            return row[2]
        end
    end
    return "general"
end

function Addon:InitializeDatabase()
    local previousSchema = 0
    if type(CCPKeybindDisplayDB) == "table" and type(CCPKeybindDisplayDB.schemaVersion) == "number" then
        previousSchema = CCPKeybindDisplayDB.schemaVersion
    end
    if type(CCPKeybindDisplayDB) ~= "table" then
        CCPKeybindDisplayDB = {}
    end
    self.db = CCPKeybindDisplayDB
    if type(self.db.categories) ~= "table" then
        self.db.categories = {}
    end
    CopyDefaults(self.db.categories, DEFAULT_CATEGORIES)
    local key, value
    for key, value in DEFAULT_CATEGORIES do
        if type(self.db.categories[key]) ~= "boolean" then
            self.db.categories[key] = value
        end
    end
    if type(self.db.overrides) ~= "table" then
        self.db.overrides = {}
    end
    for key, value in self.db.overrides do
        if type(value) ~= "boolean" then
            self.db.overrides[key] = nil
        end
    end
    if type(self.db.showUnassigned) ~= "boolean" then
        self.db.showUnassigned = false
    end
    if type(self.db.optionsAssignedOnly) ~= "boolean" then
        self.db.optionsAssignedOnly = false
    end
    if type(self.db.showAllAssigned) ~= "boolean" then
        self.db.showAllAssigned = false
    end
    if type(self.db.visual) ~= "table" then
        self.db.visual = {}
    end
    CopyDefaults(self.db.visual, DEFAULT_VISUAL)
    local visual = self.db.visual
    if previousSchema < 4 then
        visual.width = DEFAULT_VISUAL.width
        visual.columns = FIXED_COLUMNS
    end
    if type(visual.visible) ~= "boolean" then visual.visible = DEFAULT_VISUAL.visible end
    if type(visual.locked) ~= "boolean" then visual.locked = DEFAULT_VISUAL.locked end
    if type(visual.background) ~= "boolean" then visual.background = DEFAULT_VISUAL.background end
    if not VALID_POINTS[visual.point] then visual.point = DEFAULT_VISUAL.point end
    if not VALID_POINTS[visual.relativePoint] then visual.relativePoint = DEFAULT_VISUAL.relativePoint end
    if type(visual.x) ~= "number" then visual.x = DEFAULT_VISUAL.x end
    if type(visual.y) ~= "number" then visual.y = DEFAULT_VISUAL.y end
    if type(visual.width) ~= "number" or visual.width < MIN_WIDTH or visual.width > MAX_WIDTH then visual.width = DEFAULT_VISUAL.width end
    if type(visual.alpha) ~= "number" or visual.alpha < 0.1 or visual.alpha > 1 then visual.alpha = DEFAULT_VISUAL.alpha end
    if type(visual.scale) ~= "number" or visual.scale < 0.5 or visual.scale > 2 then visual.scale = DEFAULT_VISUAL.scale end
    if type(visual.fontSize) ~= "number" or visual.fontSize < 8 or visual.fontSize > 24 then visual.fontSize = DEFAULT_VISUAL.fontSize end
    visual.columns = FIXED_COLUMNS
    if type(visual.rowSpacing) ~= "number" or visual.rowSpacing < 0 or visual.rowSpacing > 20 then visual.rowSpacing = DEFAULT_VISUAL.rowSpacing end
    if type(self.db.minimap) ~= "table" then self.db.minimap = {} end
    CopyDefaults(self.db.minimap, DEFAULT_MINIMAP)
    if type(self.db.minimap.visible) ~= "boolean" then self.db.minimap.visible = DEFAULT_MINIMAP.visible end
    if type(self.db.minimap.angle) ~= "number" or self.db.minimap.angle < 0 or self.db.minimap.angle >= 360 then
        self.db.minimap.angle = DEFAULT_MINIMAP.angle
    end
    self.db.schemaVersion = 4
end

function Addon:DiscoverBindings()
    local entries = {}
    local count = GetNumBindings and GetNumBindings() or 0
    local index, action, key1, key2, label
    for index = 1, count do
        action, key1, key2 = GetBinding(index)
        if IsCCPAction(action) then
            label = getglobal("BINDING_NAME_" .. action)
            if not label or label == "" then
                label = action
            end
            table.insert(entries, {
                action = action,
                label = label,
                key1 = key1,
                key2 = key2,
                category = self:CategoryForAction(action),
            })
        end
    end
    self.entries = entries
    return entries
end

function Addon:IsEntryEnabled(entry)
    if self.db.showAllAssigned and (entry.key1 or entry.key2) then
        return true
    end
    local override = self.db.overrides[entry.action]
    if override ~= nil then
        return override and true or false
    end
    return self.db.categories[entry.category] and true or false
end

function Addon:SetShowAllAssigned(enabled)
    self.db.showAllAssigned = enabled and true or false
end

function Addon:SetCategory(category, enabled)
    if DEFAULT_CATEGORIES[category] ~= nil then
        self.db.categories[category] = enabled and true or false
    end
end

function Addon:SetEntryOverride(action, enabled)
    self.db.overrides[action] = enabled and true or false
end

function Addon:ClearEntryOverride(action)
    self.db.overrides[action] = nil
end

function Addon:HasAction(action)
    local index
    for index = 1, table.getn(self.entries or {}) do
        if self.entries[index].action == action then return true end
    end
    return false
end

function Addon:CommitBinding(action, key)
    if not self:HasAction(action) or type(key) ~= "string" or key == "" then return false end
    local old1, old2 = GetBindingKey(action)
    if key == old1 or key == old2 then return true end
    local previousAction = GetBindingAction(key)
    if previousAction == "" then previousAction = nil end
    local previous1, previous2
    if previousAction and previousAction ~= action then previous1, previous2 = GetBindingKey(previousAction) end
    local cleared1, cleared2 = true, true
    if old1 then cleared1 = SetBinding(old1) and true or false end
    if old2 then cleared2 = SetBinding(old2) and true or false end
    if not cleared1 or not cleared2 or not SetBinding(key, action) then
        local restored = RestoreActionBindings(action, old1, old2)
        if previousAction and previousAction ~= action and GetBindingAction(key) ~= previousAction then
            if not RestoreActionBindings(previousAction, previous1, previous2) then restored = false end
        end
        if not restored then ReportBindingRollbackFailure() end
        return false
    end
    SaveBindings(GetCurrentBindingSet())
    self:RequestBindingRefresh()
    return true
end

function Addon:ClearBinding(action)
    if not self:HasAction(action) then return false end
    local key1, key2 = GetBindingKey(action)
    local cleared1, cleared2 = true, true
    if key1 then cleared1 = SetBinding(key1) and true or false end
    if key2 then cleared2 = SetBinding(key2) and true or false end
    if not cleared1 or not cleared2 then
        if not RestoreActionBindings(action, key1, key2) then ReportBindingRollbackFailure() end
        return false
    end
    SaveBindings(GetCurrentBindingSet())
    self:RequestBindingRefresh()
    return true
end

function Addon:SetShowUnassigned(enabled)
    self.db.showUnassigned = enabled and true or false
end

function Addon:GetVisibleEntries()
    local visible = {}
    local index, entry, assigned
    for index = 1, table.getn(self.entries or {}) do
        entry = self.entries[index]
        assigned = entry.key1 or entry.key2
        if self:IsEntryEnabled(entry) and (self.db.showUnassigned or assigned) then
            table.insert(visible, entry)
        end
    end
    return visible
end

local function KeyText(entry)
    if entry.key1 and entry.key2 then
        return entry.key1 .. " / " .. entry.key2
    end
    return entry.key1 or entry.key2 or "Unassigned"
end

function Addon:CreateOverlay()
    if self.overlay then
        return self.overlay
    end
    local visual = self.db.visual
    local frame = CreateFrame("Frame", "CCPKeybindDisplayOverlay", UIParent)
    frame:SetWidth(visual.width)
    frame:SetHeight(40)
    frame:SetPoint(visual.point, UIParent, visual.relativePoint, visual.x, visual.y)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if visual.background then
        frame:SetBackdropColor(0, 0, 0, 0.85)
        frame:SetBackdropBorderColor(0.25, 0.5, 0.8, 0.75)
    else
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    frame:SetAlpha(visual.alpha)
    frame:SetScale(visual.scale)
    frame:SetMovable(true)
    frame:EnableMouse(not visual.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not Addon.db.visual.locked then
            this:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = this:GetPoint(1)
        if type(point) == "string" and type(relativePoint) == "string" and
           type(x) == "number" and type(y) == "number" then
            Addon.db.visual.point = point
            Addon.db.visual.relativePoint = relativePoint
            Addon.db.visual.x = x
            Addon.db.visual.y = y
        end
    end)
    self.overlay = frame
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 9)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", OVERLAY_PADDING, -6)
    title:SetWidth(220)
    title:SetJustifyH("LEFT")
    title:SetText("CCP KEYBINDS")
    title:SetTextColor(0.45, 0.8, 1)
    title:Show()
    self.overlayTitle = title
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetTexture(0.3, 0.6, 1, 0.28)
    divider:Show()
    self.overlayDivider = divider
    self.rows = {}
    return frame
end

function Addon:CreateRow(index)
    local row = {}
    row.label = self.overlay:CreateFontString(nil, "OVERLAY")
    row.label:SetFont(STANDARD_TEXT_FONT, self.db.visual.fontSize)
    row.label:SetJustifyH("LEFT")
    row.keys = self.overlay:CreateFontString(nil, "OVERLAY")
    row.keys:SetFont(STANDARD_TEXT_FONT, self.db.visual.fontSize)
    row.keys:SetJustifyH("LEFT")
    row.keys:SetTextColor(1, 0.82, 0)
    self.rows[index] = row
    return row
end

function Addon:SetLocked(locked)
    self.db.visual.locked = locked and true or false
    if self.overlay then
        self.overlay:EnableMouse(not self.db.visual.locked)
    end
end

function Addon:SetVisible(visible)
    self.db.visual.visible = visible and true or false
    if self.overlay then
        if self.db.visual.visible then
            self.overlay:Show()
        else
            self.overlay:Hide()
        end
    end
end

function Addon:SetVisualOption(option, value)
    local valid = false
    if option == "alpha" and type(value) == "number" and value >= 0.1 and value <= 1 then
        valid = true
    elseif option == "scale" and type(value) == "number" and value >= 0.5 and value <= 2 then
        valid = true
    elseif option == "fontSize" and type(value) == "number" and value >= 8 and value <= 24 then
        valid = true
    elseif option == "width" and type(value) == "number" and value >= MIN_WIDTH and value <= MAX_WIDTH then
        valid = true
    elseif option == "columns" and value == FIXED_COLUMNS then
        valid = true
    elseif option == "rowSpacing" and type(value) == "number" and value >= 0 and value <= 20 then
        valid = true
    elseif option == "background" and type(value) == "boolean" then
        valid = true
    end
    if not valid then
        return false
    end
    self.db.visual[option] = value
    if self.overlay then
        self.overlay:SetWidth(self.db.visual.width)
        self.overlay:SetAlpha(self.db.visual.alpha)
        self.overlay:SetScale(self.db.visual.scale)
        if self.db.visual.background then
            self.overlay:SetBackdropColor(0, 0, 0, 0.85)
            self.overlay:SetBackdropBorderColor(0.35, 0.65, 1, 0.9)
        else
            self.overlay:SetBackdropColor(0, 0, 0, 0)
            self.overlay:SetBackdropBorderColor(0, 0, 0, 0)
        end
        local index
        for index = 1, table.getn(self.rows) do
            self.rows[index].label:SetFont(STANDARD_TEXT_FONT, self.db.visual.fontSize)
            self.rows[index].keys:SetFont(STANDARD_TEXT_FONT, self.db.visual.fontSize)
        end
        self:UpdateDisplay()
    end
    return true
end

function Addon:UpdateDisplay()
    self:CreateOverlay()
    local visible = self:GetVisibleEntries()
    local count = table.getn(visible)
    local columns = FIXED_COLUMNS
    local rowsPerColumn = 0
    if count > 0 then
        rowsPerColumn = math.floor((count + columns - 1) / columns)
    end
    local rowHeight = self.db.visual.fontSize + self.db.visual.rowSpacing + 2
    local maximumCardWidth = self.db.visual.width
    local scaledLabelLimit = math.floor((MAX_LABEL_WIDTH * self.db.visual.fontSize / 10) + 0.5)
    local maxLabelWidth = 1
    local maxKeyWidth = KEY_WIDTH
    local keyTexts = {}
    local index, row, zeroIndex, column, rowIndex, x, y, measuredWidth
    for index = 1, count do
        row = self.rows[index] or self:CreateRow(index)
        keyTexts[index] = KeyText(visible[index])
        row.label:SetWidth(2000)
        row.keys:SetWidth(2000)
        row.label:SetText(visible[index].label)
        row.keys:SetText(keyTexts[index])
        measuredWidth = row.label:GetStringWidth()
        if measuredWidth and measuredWidth > maxLabelWidth then maxLabelWidth = measuredWidth end
        measuredWidth = row.keys:GetStringWidth()
        if measuredWidth and measuredWidth > maxKeyWidth then maxKeyWidth = measuredWidth end
    end
    local availableLabelWidth = maximumCardWidth - (OVERLAY_PADDING * 2) - KEY_GAP - maxKeyWidth
    maxLabelWidth = math.min(maxLabelWidth, scaledLabelLimit, math.max(80, availableLabelWidth))
    local requiredColumnWidth = (OVERLAY_PADDING * 2) + maxLabelWidth + KEY_GAP + maxKeyWidth
    local columnWidth = math.max(MIN_AUTO_WIDTH, requiredColumnWidth)
    local overlayWidth = columnWidth * columns
    local overlayHeight = HEADER_HEIGHT + OVERLAY_PADDING + (rowsPerColumn * rowHeight)
    self.overlay:SetWidth(overlayWidth)
    self.overlay:SetHeight(overlayHeight)
    self.overlayTitle:SetWidth(overlayWidth - (OVERLAY_PADDING * 2))
    self.overlayDivider:ClearAllPoints()
    self.overlayDivider:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", OVERLAY_PADDING + maxLabelWidth + math.floor(KEY_GAP / 2), -HEADER_HEIGHT)
    self.overlayDivider:SetHeight(math.max(1, overlayHeight - HEADER_HEIGHT - OVERLAY_PADDING))
    for index = 1, count do
        row = self.rows[index]
        zeroIndex = index - 1
        column = math.floor(zeroIndex / rowsPerColumn)
        rowIndex = zeroIndex - (column * rowsPerColumn)
        x = OVERLAY_PADDING + (column * columnWidth)
        y = -HEADER_HEIGHT - (rowIndex * rowHeight)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", x, y)
        row.label:SetWidth(maxLabelWidth)
        row.label:SetHeight(rowHeight)
        row.label:Show()
        row.keys:ClearAllPoints()
        row.keys:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", x + maxLabelWidth + KEY_GAP, y)
        row.keys:SetWidth(maxKeyWidth)
        row.keys:SetHeight(rowHeight)
        row.keys:Show()
    end
    for index = count + 1, table.getn(self.rows) do
        self.rows[index].label:Hide()
        self.rows[index].keys:Hide()
    end
    if self.db.visual.visible then
        self.overlay:Show()
    else
        self.overlay:Hide()
    end
end

function Addon:Refresh()
    self.bindingRefreshPending = false
    self:DiscoverBindings()
    if self.overlay then
        self:UpdateDisplay()
    end
    if self.options and self.RefreshOptions then
        self:RefreshOptions()
    end
end

function Addon:RequestBindingRefresh()
    self.bindingRefreshPending = true
end

function Addon:UpdateMinimapButtonPosition()
    if not self.minimapButton or not Minimap then return end
    local angle = math.rad(self.db.minimap.angle)
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 54 - (78 * math.cos(angle)), (78 * math.sin(angle)) - 55)
end

function Addon:SetMinimapVisible(enabled)
    self.db.minimap.visible = enabled and true or false
    if not self.minimapButton then self:CreateMinimapButton() end
    if self.minimapButton then
        if self.db.minimap.visible then self.minimapButton:Show() else self.minimapButton:Hide() end
    end
end

function Addon:UpdateMinimapButtonFromCursor()
    local cursorX, cursorY = GetCursorPosition()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    cursorX = left - (cursorX / UIParent:GetScale()) + 70
    cursorY = (cursorY / UIParent:GetScale()) - bottom - 70
    local angle = math.deg(math.atan2(cursorY, cursorX))
    if angle < 0 then angle = angle + 360 end
    self.db.minimap.angle = angle
    self:UpdateMinimapButtonPosition()
end

function Addon:CreateMinimapButton()
    if self.minimapButton or not Minimap then return self.minimapButton end
    local button = CreateFrame("Button", "CCPKeybindDisplayMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(52)
    border:SetHeight(52)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function()
        if Addon.ToggleOptions then Addon:ToggleOptions() end
    end)
    button:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function() Addon:UpdateMinimapButtonFromCursor() end)
    end)
    button:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
        Addon:UpdateMinimapButtonFromCursor()
    end)
    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
    if self.db.minimap.visible then button:Show() else button:Hide() end
    return button
end

function Addon:Initialize()
    self:InitializeDatabase()
    self:Refresh()
    if UIParent then
        self:CreateOverlay()
        self:UpdateDisplay()
        self:CreateMinimapButton()
    end
    if not self.loadedMessageShown and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCP Keybind Display|r loaded. Type /ckd for options.")
        self.loadedMessageShown = true
    end
end

local eventFrame = CreateFrame("Frame", "CCPKeybindDisplayEventFrame")
Addon.eventFrame = eventFrame
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        Addon:Initialize()
    elseif event == "UPDATE_BINDINGS" then
        Addon:RequestBindingRefresh()
    end
end)
eventFrame:SetScript("OnUpdate", function()
    if Addon.bindingRefreshPending then
        Addon:Refresh()
    end
end)
