-- Options panel for CCP Keybind Display.
-- Kept separate from CCP and from the overlay's discovery/runtime logic.

local Addon = CCPKeybindDisplay
local PAGE_SIZE = 14
local BINDING_PAGE_SIZE = 12

local CATEGORY_ORDER = {
    { "general", "General" },
    { "tank", "Tank" },
    { "healer", "Healer" },
    { "tanhe", "Tank + Healer" },
    { "dps", "DPS" },
    { "mdps", "Melee DPS" },
    { "rdps", "Ranged DPS" },
}

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCP Keybind Display:|r " .. message)
    end
end

local function CreateLabel(parent, text, x, y, width, size)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, size or 12)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 200)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    label:Show()
    return label
end

local function CreateCheck(parent, name, text, x, y)
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check.label = CreateLabel(parent, text, x + 26, y - 4, 170, 11)
    check:Show()
    return check
end

local function CreateButton(parent, name, text, x, y, width)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 100)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:Show()
    return button
end

local function CreatePanel(parent, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(width)
    panel:SetHeight(height)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.015, 0.025, 0.05, 0.72)
    panel:SetBackdropBorderColor(0.2, 0.45, 0.72, 0.58)
    panel:Show()
    return panel
end

local function CreateSlider(parent, name, label, option, x, y, low, high, step)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(160)
    slider:SetHeight(16)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider._ckdOption = option
    getglobal(name .. "Text"):SetText(label)
    getglobal(name .. "Low"):SetText(tostring(low))
    getglobal(name .. "High"):SetText(tostring(high))
    slider:SetScript("OnValueChanged", function()
        if Addon.optionsRefreshing then return end
        local value = arg1 or this:GetValue()
        Addon:SetVisualOption(this._ckdOption, value)
        Addon:RefreshOptionsValues()
    end)
    slider:Show()
    return slider
end

function Addon:RefreshOptionsValues()
    if not self.options then return end
    if self.optionsRefreshing then return end
    self.optionsRefreshing = true
    self.showUnassignedCheck:SetChecked(self.db.showUnassigned)
    self.showAllAssignedCheck:SetChecked(self.db.showAllAssigned)
    self.visibleCheck:SetChecked(self.db.visual.visible)
    self.lockedCheck:SetChecked(self.db.visual.locked)
    self.backgroundCheck:SetChecked(self.db.visual.background)
    self.minimapCheck:SetChecked(self.db.minimap.visible)
    self.sliders.alpha:SetValue(self.db.visual.alpha)
    self.sliders.scale:SetValue(self.db.visual.scale)
    self.sliders.fontSize:SetValue(self.db.visual.fontSize)
    self.sliders.rowSpacing:SetValue(self.db.visual.rowSpacing)
    self.optionsRefreshing = false
end

function Addon:UpdateBindingPage()
    if not self.options then return end
    local optionsEntries = {}
    local sourceIndex, sourceEntry
    for sourceIndex = 1, table.getn(self.entries or {}) do
        sourceEntry = self.entries[sourceIndex]
        if (not self.optionsCategoryFilter or self.optionsCategoryFilter == "all" or sourceEntry.category == self.optionsCategoryFilter) and
           (not self.db.optionsAssignedOnly or sourceEntry.key1 or sourceEntry.key2) then
            table.insert(optionsEntries, sourceEntry)
        end
    end
    self.optionsEntries = optionsEntries
    local count = table.getn(optionsEntries)
    local maxPage = math.max(1, math.floor((count + PAGE_SIZE - 1) / PAGE_SIZE))
    if self.optionsPage < 1 then self.optionsPage = 1 end
    if self.optionsPage > maxPage then self.optionsPage = maxPage end
    local startIndex = ((self.optionsPage - 1) * PAGE_SIZE) + 1
    local rowIndex, entryIndex, row, entry, assigned
    for rowIndex = 1, table.getn(self.bindingRows) do
        entryIndex = startIndex + rowIndex - 1
        row = self.bindingRows[rowIndex]
        entry = optionsEntries[entryIndex]
        if entry then
            row.check._ckdAction = entry.action
            row.check:SetChecked(self:IsEntryEnabled(entry))
            row.label:SetText(entry.label)
            row.category:SetText(entry.category)
            assigned = entry.key1 or entry.key2 or "Unassigned"
            if entry.key1 and entry.key2 then assigned = entry.key1 .. " / " .. entry.key2 end
            row.keys:SetText(assigned)
            row.check:Show()
            row.label:Show()
            row.category:Show()
            row.keys:Show()
        else
            row.check:Hide()
            row.label:Hide()
            row.category:Hide()
            row.keys:Hide()
        end
    end
    self.pageLabel:SetText("Page " .. self.optionsPage .. " / " .. maxPage)
    if self.optionsPage > 1 then self.prevButton:Enable() else self.prevButton:Disable() end
    if self.optionsPage < maxPage then self.nextButton:Enable() else self.nextButton:Disable() end
end

function Addon:SetOptionsCategoryFilter(category)
    local valid = category == "all"
    local index, label
    for index = 1, table.getn(CATEGORY_ORDER) do
        if CATEGORY_ORDER[index][1] == category then
            valid = true
            label = CATEGORY_ORDER[index][2]
        end
    end
    if not valid then category = "all" end
    self.optionsCategoryFilter = category
    self.optionsPage = 1
    self:UpdateBindingPage()
    if self.optionsFilterLabel then
        self.optionsFilterLabel:SetText("Showing: " .. (label or "All"))
    end
end

function Addon:ToggleAssignedOnlyList()
    self.db.optionsAssignedOnly = not self.db.optionsAssignedOnly
    self.optionsPage = 1
    self:RefreshOptions()
end

function Addon:ShowAllAssignedBindings()
    self:SetShowAllAssigned(not self.db.showAllAssigned)
    self:UpdateDisplay()
    self:RefreshOptions()
end

function Addon:RefreshOptions()
    self:RefreshOptionsValues()
    self:UpdateBindingPage()
    self:UpdateBindingManager()
    if self.assignedOnlyButton then
        if self.db.optionsAssignedOnly then
            self.assignedOnlyButton:SetText("List: Assigned only")
        else
            self.assignedOnlyButton:SetText("List: All bindings")
        end
    end
end

function Addon:ResetOverrides()
    self.db.overrides = {}
    self:UpdateDisplay()
    self:RefreshOptions()
end

function Addon:BuildBindingManagerEntries()
    local filtered = {}
    local index, entry
    for index = 1, table.getn(self.entries or {}) do
        entry = self.entries[index]
        if not self.bindingFilter or self.bindingFilter == "all" or entry.category == self.bindingFilter then table.insert(filtered, entry) end
    end
    table.sort(filtered, function(left, right)
        if left.category == right.category then return string.lower(left.label) < string.lower(right.label) end
        return left.category < right.category
    end)
    self.bindingManagerEntries = filtered
    return filtered
end

function Addon:UpdateBindingManager()
    if not self.bindingManager then return end
    local entries = self:BuildBindingManagerEntries()
    local count = table.getn(entries)
    local maxPage = math.max(1, math.floor((count + BINDING_PAGE_SIZE - 1) / BINDING_PAGE_SIZE))
    if self.bindingManagerPage < 1 then self.bindingManagerPage = 1 end
    if self.bindingManagerPage > maxPage then self.bindingManagerPage = maxPage end
    local startIndex = ((self.bindingManagerPage - 1) * BINDING_PAGE_SIZE) + 1
    local rowIndex, entry, row, assigned
    for rowIndex = 1, table.getn(self.bindingManagerRows) do
        row = self.bindingManagerRows[rowIndex]
        entry = entries[startIndex + rowIndex - 1]
        if entry then
            row.label:SetText(entry.label); row.category:SetText(entry.category)
            assigned = entry.key1 or entry.key2 or "Unassigned"
            if entry.key1 and entry.key2 then assigned = entry.key1 .. " / " .. entry.key2 end
            row.keys:SetText(assigned)
            row.bind._ckdAction = entry.action; row.bind._ckdLabel = entry.label; row.clear._ckdAction = entry.action
            row.label:Show(); row.category:Show(); row.keys:Show(); row.bind:Show(); row.clear:Show()
        else
            row.label:Hide(); row.category:Hide(); row.keys:Hide(); row.bind:Hide(); row.clear:Hide()
        end
    end
    self.bindingManagerPageLabel:SetText("Page " .. self.bindingManagerPage .. " / " .. maxPage)
    self.bindingManagerFilterLabel:SetText("Showing: " .. (self.bindingFilter or "all"))
    if self.bindingManagerPage > 1 then self.bindingManagerPrev:Enable() else self.bindingManagerPrev:Disable() end
    if self.bindingManagerPage < maxPage then self.bindingManagerNext:Enable() else self.bindingManagerNext:Disable() end
end

function Addon:SetBindingManagerFilter(category)
    self.bindingFilter = category or "all"
    self.bindingManagerPage = 1
    self:UpdateBindingManager()
end

function Addon:FinishBindingCapture(action, key)
    if self:CommitBinding(action, key) then Chat(key .. " bound to " .. action .. ".") else Chat("could not bind " .. key .. ".") end
    self.pendingBinding = nil
end

function Addon:HandleCapturedKey(key)
    if key == "ESCAPE" then self.bindingCapture:Hide(); self.pendingBinding = nil; return end
    if key == "UNKNOWN" or key == "SHIFT" or key == "LSHIFT" or key == "RSHIFT" or key == "ALT" or key == "LALT" or key == "RALT" or key == "CTRL" or key == "LCTRL" or key == "RCTRL" then return end
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    key = prefix .. key
    local action = self.pendingBinding and self.pendingBinding.action
    if not action then self.bindingCapture:Hide(); return end
    self.bindingCapture:Hide()
    local previous = GetBindingAction(key)
    local old1, old2 = GetBindingKey(action)
    if previous == action then
        Chat(key .. " is already assigned to " .. action .. ".")
        self.pendingBinding = nil
    elseif (previous and previous ~= "") or old1 or old2 then
        self.pendingBinding.key = key
        local warning = "This replaces all current keys for " .. (self.pendingBinding.label or action) .. "."
        if previous and previous ~= "" then
            local previousLabel = getglobal("BINDING_NAME_" .. previous) or previous
            warning = warning .. "\n\n" .. key .. " is also used for " .. previousLabel .. "."
        end
        StaticPopupDialogs["CCPKD_BIND_CONFLICT"].text = warning .. "\n\nContinue?"
        StaticPopup_Show("CCPKD_BIND_CONFLICT")
    else
        self:FinishBindingCapture(action, key)
    end
end

function Addon:BeginBindingCapture(action, label)
    self.pendingBinding = { action = action, label = label }
    self.bindingCaptureLabel:SetText("Press a key to replace all keys for " .. label .. "\nEscape cancels")
    self.bindingCapture:Show()
end

function Addon:CreateBindingManager()
    if self.bindingManager then return self.bindingManager end
    local frame = CreateFrame("Frame", "CCPKeybindDisplayBindingManager", UIParent)
    frame:SetWidth(790); frame:SetHeight(610); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:SetClampedToScreen(true)
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    frame:SetBackdropColor(0.025, 0.035, 0.065, 0.99); frame:Hide()
    self.bindingManager = frame; self.bindingManagerPage = 1; self.bindingFilter = "all"
    self.bindingListPanel = CreatePanel(frame, 18, -58, 754, 446)
    self.bindingFooterPanel = CreatePanel(frame, 18, -518, 754, 48)
    local managerTitle = CreateLabel(frame, "Companion keybinds", 26, -20, 330, 18)
    managerTitle:SetTextColor(0.45, 0.82, 1)
    local managerSubtitle = CreateLabel(frame, "Filter by role, then replace or clear keys.", 27, -44, 440, 11)
    managerSubtitle:SetTextColor(0.68, 0.72, 0.8)
    self.bindingManagerFilterLabel = CreateLabel(frame, "", 620, -24, 140, 10)
    self.bindingManagerFilterLabel:SetJustifyH("RIGHT")
    local filters = { {"all","All"}, {"general","General"}, {"tank","Tank"}, {"healer","Healer"}, {"tanhe","T+H"}, {"dps","DPS"}, {"mdps","Melee"}, {"rdps","Ranged"} }
    self.bindingFilterButtons = {}
    local index, data, button
    for index = 1, table.getn(filters) do
        data = filters[index]
        button = CreateButton(frame, "CCPKeybindDisplayFilter" .. index, data[2], 28 + ((index - 1) * 91), -70, 85)
        button._ckdFilter = data[1]
        button:SetScript("OnClick", function() Addon:SetBindingManagerFilter(this._ckdFilter) end)
        self.bindingFilterButtons[data[1]] = button
    end
    CreateLabel(frame, "Command", 32, -108, 250, 11); CreateLabel(frame, "Role", 292, -108, 68, 11); CreateLabel(frame, "Current key", 370, -108, 168, 11)
    self.bindingManagerRows = {}
    local rowIndex, y, row
    for rowIndex = 1, BINDING_PAGE_SIZE do
        y = -126 - ((rowIndex - 1) * 30); row = {}
        row.label = CreateLabel(frame, "", 32, y - 4, 250, 10); row.category = CreateLabel(frame, "", 292, y - 4, 68, 10); row.keys = CreateLabel(frame, "", 370, y - 4, 168, 10)
        row.bind = CreateButton(frame, "CCPKeybindDisplayBind" .. rowIndex, "Replace", 550, y, 76)
        row.bind:SetScript("OnClick", function() Addon:BeginBindingCapture(this._ckdAction, this._ckdLabel) end)
        row.clear = CreateButton(frame, "CCPKeybindDisplayClear" .. rowIndex, "Clear all", 636, y, 76)
        row.clear:SetScript("OnClick", function() if Addon:ClearBinding(this._ckdAction) then Chat("all keys cleared.") end end)
        table.insert(self.bindingManagerRows, row)
    end
    self.bindingManagerPrev = CreateButton(frame, "CCPKeybindDisplayBindPrev", "Previous", 260, -530, 90)
    self.bindingManagerPrev:SetScript("OnClick", function() Addon.bindingManagerPage = Addon.bindingManagerPage - 1; Addon:UpdateBindingManager() end)
    self.bindingManagerPageLabel = CreateLabel(frame, "", 360, -534, 120, 11)
    self.bindingManagerNext = CreateButton(frame, "CCPKeybindDisplayBindNext", "Next", 480, -530, 90)
    self.bindingManagerNext:SetScript("OnClick", function() Addon.bindingManagerPage = Addon.bindingManagerPage + 1; Addon:UpdateBindingManager() end)
    local back = CreateButton(frame, "CCPKeybindDisplayBindBack", "Back to settings", 620, -530, 140)
    back:SetScript("OnClick", function() Addon.bindingManager:Hide(); Addon.options:Show() end)
    local managerCredit = CreateLabel(frame, "Shirina", 28, -584, 120, 9)
    managerCredit:SetTextColor(0.46, 0.52, 0.62)
    local capture = CreateFrame("Frame", "CCPKeybindDisplayCapture", frame)
    capture:SetWidth(420); capture:SetHeight(110); capture:SetPoint("CENTER", frame, "CENTER", 0, 0); capture:SetFrameStrata("TOOLTIP"); capture:EnableKeyboard(true)
    capture:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    capture:SetBackdropColor(0.03, 0.03, 0.05, 1)
    self.bindingCaptureLabel = CreateLabel(capture, "", 24, -30, 372, 14)
    capture:SetScript("OnKeyDown", function() Addon:HandleCapturedKey(arg1) end); capture:Hide(); self.bindingCapture = capture
    if not StaticPopupDialogs["CCPKD_BIND_CONFLICT"] then
        StaticPopupDialogs["CCPKD_BIND_CONFLICT"] = { text = "Replace this keybind?", button1 = "Replace", button2 = "Cancel", timeout = 0, whileDead = 1, hideOnEscape = 1,
            OnAccept = function() local pending = Addon.pendingBinding; if pending then Addon:FinishBindingCapture(pending.action, pending.key) end end,
            OnCancel = function() Addon.pendingBinding = nil end }
    end
    return frame
end

function Addon:ShowBindingManager()
    self:CreateBindingManager()
    if self.options then self.options:Hide() end
    self:UpdateBindingManager(); self.bindingManager:Show()
end

function Addon:CreateOptions()
    if self.options then return self.options end
    local frame = CreateFrame("Frame", "CCPKeybindDisplayOptions", UIParent)
    frame:SetWidth(790)
    frame:SetHeight(680)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.025, 0.035, 0.065, 0.99)
    frame:Hide()
    self.options = frame
    self.optionsPage = 1

    self.displayPanel = CreatePanel(frame, 18, -72, 350, 522)
    self.entriesPanel = CreatePanel(frame, 380, -72, 392, 522)
    self.footerPanel = CreatePanel(frame, 18, -606, 754, 42)

    local title = CreateLabel(frame, "CCP Keybind Display", 26, -20, 330, 18)
    title:SetTextColor(0.45, 0.82, 1)
    local subtitle = CreateLabel(frame, "Companion controls, clearly organized.", 27, -44, 400, 11)
    subtitle:SetTextColor(0.68, 0.72, 0.8)
    local version = CreateLabel(frame, "v0.3.1", 690, -24, 70, 10)
    self.versionLabel = version
    version:SetJustifyH("RIGHT")
    version:SetTextColor(0.55, 0.72, 0.88)

    local categoriesTitle = CreateLabel(frame, "FILTER BINDINGS", 34, -90, 220, 11)
    categoriesTitle:SetTextColor(1, 0.82, 0)
    self.optionsCategoryFilter = "all"
    self.categoryFilterButtons = {}
    local categoryFilters = { { "all", "All" } }
    local index, category
    for index = 1, table.getn(CATEGORY_ORDER) do table.insert(categoryFilters, CATEGORY_ORDER[index]) end
    for index = 1, table.getn(categoryFilters) do
        category = categoryFilters[index]
        local filterX = 34 + (math.mod(index - 1, 2) * 160)
        local filterY = -108 - (math.floor((index - 1) / 2) * 30)
        local button = CreateButton(frame, "CCPKeybindDisplayCategoryFilter" .. index, category[2], filterX, filterY, 150)
        button._ckdCategoryFilter = category[1]
        button:SetScript("OnClick", function() Addon:SetOptionsCategoryFilter(this._ckdCategoryFilter) end)
        self.categoryFilterButtons[category[1]] = button
    end
    self.optionsFilterLabel = CreateLabel(frame, "Showing: All", 34, -230, 310, 10)
    self.optionsFilterLabel:SetTextColor(0.62, 0.72, 0.84)

    local displayTitle = CreateLabel(frame, "HUD BEHAVIOR", 34, -256, 220, 11)
    displayTitle:SetTextColor(1, 0.82, 0)
    self.showUnassignedCheck = CreateCheck(frame, "CCPKeybindDisplayShowUnassigned", "Include unassigned", 34, -272)
    self.showUnassignedCheck:SetScript("OnClick", function()
        Addon:SetShowUnassigned(this:GetChecked() and true or false)
        Addon:UpdateDisplay()
        Addon:RefreshOptions()
    end)
    self.showAllAssignedCheck = CreateCheck(frame, "CCPKeybindDisplayShowAllAssigned", "Show all assigned", 190, -272)
    self.showAllAssignedCheck.label:SetWidth(145)
    self.showAllAssignedCheck:SetScript("OnClick", function() Addon:ShowAllAssignedBindings() end)
    self.visibleCheck = CreateCheck(frame, "CCPKeybindDisplayVisible", "HUD visible", 34, -300)
    self.visibleCheck:SetScript("OnClick", function() Addon:SetVisible(this:GetChecked() and true or false) end)
    self.lockedCheck = CreateCheck(frame, "CCPKeybindDisplayLocked", "Lock HUD", 190, -300)
    self.lockedCheck:SetScript("OnClick", function() Addon:SetLocked(this:GetChecked() and true or false) end)
    self.backgroundCheck = CreateCheck(frame, "CCPKeybindDisplayBackground", "Card background", 34, -328)
    self.backgroundCheck:SetScript("OnClick", function() Addon:SetVisualOption("background", this:GetChecked() and true or false) end)
    self.minimapCheck = CreateCheck(frame, "CCPKeybindDisplayMinimapVisible", "Minimap button", 190, -328)
    self.minimapCheck.label:SetWidth(145)
    self.minimapCheck:SetScript("OnClick", function() Addon:SetMinimapVisible(this:GetChecked() and true or false) end)
    self.assignedOnlyButton = CreateButton(frame, "CCPKeybindDisplayAssignedOnly", "List: All bindings", 34, -364, 150)
    self.assignedOnlyButton:SetScript("OnClick", function() Addon:ToggleAssignedOnlyList() end)
    local fixedColumns = CreateLabel(frame, "HUD layout: command | key", 194, -370, 150, 10)
    fixedColumns:SetTextColor(0.62, 0.72, 0.84)

    local appearanceTitle = CreateLabel(frame, "APPEARANCE", 34, -410, 220, 11)
    appearanceTitle:SetTextColor(1, 0.82, 0)
    self.sliders = {}
    self.sliders.alpha = CreateSlider(frame, "CCPKeybindDisplayAlpha", "Opacity", "alpha", 34, -434, 0.1, 1, 0.05)
    self.sliders.scale = CreateSlider(frame, "CCPKeybindDisplayScale", "Scale", "scale", 194, -434, 0.5, 2, 0.05)
    self.sliders.fontSize = CreateSlider(frame, "CCPKeybindDisplayFont", "Font size", "fontSize", 34, -478, 8, 24, 1)
    self.sliders.rowSpacing = CreateSlider(frame, "CCPKeybindDisplaySpacing", "Row spacing", "rowSpacing", 194, -478, 0, 20, 1)

    local entriesTitle = CreateLabel(frame, "INDIVIDUAL BINDINGS", 396, -90, 260, 11)
    entriesTitle:SetTextColor(1, 0.82, 0)
    CreateLabel(frame, "Show", 396, -112, 42, 10)
    CreateLabel(frame, "Command", 434, -112, 174, 10)
    CreateLabel(frame, "Role", 610, -112, 58, 10)
    CreateLabel(frame, "Key", 668, -112, 96, 10)

    self.bindingRows = {}
    local rowCount = PAGE_SIZE
    for index = 1, rowCount do
        local y = -128 - ((index - 1) * 28)
        local row = {}
        row.check = CreateFrame("CheckButton", "CCPKeybindDisplayEntry" .. index, frame, "UICheckButtonTemplate")
        row.check:SetWidth(22)
        row.check:SetHeight(22)
        row.check:SetPoint("TOPLEFT", frame, "TOPLEFT", 394, y)
        row.check:SetScript("OnClick", function()
            Addon:SetEntryTracked(this._ckdAction, this:GetChecked() and true or false)
            Addon:UpdateDisplay()
            Addon:RefreshOptions()
        end)
        row.label = CreateLabel(frame, "", 432, y - 4, 174, 10)
        row.category = CreateLabel(frame, "", 610, y - 4, 56, 10)
        row.keys = CreateLabel(frame, "", 668, y - 4, 96, 10)
        table.insert(self.bindingRows, row)
    end

    self.prevButton = CreateButton(frame, "CCPKeybindDisplayPrev", "Previous", 398, -536, 82)
    self.prevButton:SetScript("OnClick", function()
        Addon.optionsPage = Addon.optionsPage - 1
        Addon:UpdateBindingPage()
    end)
    self.nextButton = CreateButton(frame, "CCPKeybindDisplayNext", "Next", 682, -536, 70)
    self.nextButton:SetScript("OnClick", function()
        Addon.optionsPage = Addon.optionsPage + 1
        Addon:UpdateBindingPage()
    end)
    self.pageLabel = CreateLabel(frame, "", 500, -540, 150, 11)

    self.manageBindingsButton = CreateButton(frame, "CCPKeybindDisplayManageBindings", "Manage keybinds", 306, -615, 160)
    self.manageBindingsButton:SetScript("OnClick", function() Addon:ShowBindingManager() end)
    self.resetButton = CreateButton(frame, "CCPKeybindDisplayResetEntries", "Use category defaults", 478, -615, 154)
    self.resetButton:SetScript("OnClick", function() Addon:ResetOverrides() end)
    self.closeButton = CreateButton(frame, "CCPKeybindDisplayClose", "Close", 690, -615, 62)
    self.closeButton:SetScript("OnClick", function() Addon.options:Hide() end)
    local credit = CreateLabel(frame, "Shirina", 28, -657, 120, 9)
    self.creditLabel = credit
    credit:SetTextColor(0.46, 0.52, 0.62)

    self:RefreshOptions()
    return frame
end

function Addon:ToggleOptions()
    self:CreateOptions()
    if self.options:IsShown() then
        self.options:Hide()
    else
        if self.bindingManager then self.bindingManager:Hide() end
        self:Refresh()
        self.options:Show()
    end
end

SLASH_CCPKEYBINDDISPLAY1 = "/ckd"
SlashCmdList["CCPKEYBINDDISPLAY"] = function(message)
    local command = string.lower(message or "")
    command = string.gsub(command, "^%s+", "")
    command = string.gsub(command, "%s+$", "")
    if command == "show" then
        Addon:SetVisible(true)
    elseif command == "hide" then
        Addon:SetVisible(false)
    elseif command == "lock" then
        Addon:SetLocked(true)
    elseif command == "unlock" then
        Addon:SetLocked(false)
    elseif command == "refresh" then
        Addon:Refresh()
        Chat("bindings refreshed.")
    elseif command == "reset" then
        Addon:ResetOverrides()
        Chat("individual choices reset to category defaults.")
    elseif command == "minimap" then
        Addon:SetMinimapVisible(not Addon.db.minimap.visible)
        Addon:RefreshOptionsValues()
    elseif command == "" or command == "options" then
        Addon:ToggleOptions()
    else
        Chat("/ckd options, show, hide, lock, unlock, minimap, refresh, reset")
    end
end
