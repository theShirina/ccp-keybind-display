-- UI behavior harness for CCP Keybind Display under Lua 5.0 callbacks.

local addonPath = arg[1]
if not addonPath then error("addon path required") end
local optionsPath = arg[2]
if not optionsPath then error("options path required") end
local GlobalTable = _G
function getglobal(name) return GlobalTable[name] end
function setglobal(name, value) GlobalTable[name] = value end
_G = nil
local sliderSetCalls = 0
local sliderSetDepth = 0

local function NewWidget(kind, name)
    local widget = { kind = kind, name = name, shown = false, scripts = {}, points = {} }
    function widget:SetWidth(value) self.width = value end
    function widget:SetHeight(value) self.height = value end
    function widget:SetPoint(...) self.points[1] = arg end
    function widget:ClearAllPoints() self.points = {} end
    function widget:GetPoint() if self.points[1] then return unpack(self.points[1]) end end
    function widget:SetBackdrop(value) self.backdrop = value end
    function widget:SetBackdropColor(...) self.backdropColor = arg end
    function widget:SetBackdropBorderColor(...) self.backdropBorderColor = arg end
    function widget:SetMovable(value) self.movable = value end
    function widget:EnableMouse(value) self.mouseEnabled = value end
    function widget:EnableKeyboard(value) self.keyboardEnabled = value end
    function widget:RegisterForDrag(...) self.dragButtons = arg end
    function widget:SetScript(script, callback) self.scripts[script] = callback end
    function widget:GetScript(script) return self.scripts[script] end
    function widget:RegisterEvent() end
    function widget:CreateFontString(childName)
        local child = NewWidget("FontString", childName)
        self.children = self.children or {}
        table.insert(self.children, child)
        return child
    end
    function widget:SetFont(path, size, flags) self.font = { path, size, flags } end
    function widget:SetText(value) self.text = value end
    function widget:GetText() return self.text end
    function widget:GetStringWidth()
        local size = self.font and self.font[2] or 10
        local naturalWidth = string.len(self.text or "") * size * 0.5
        if self.width and self.width > 0 and naturalWidth > self.width then return self.width end
        return naturalWidth
    end
    function widget:SetTextColor(...) self.textColor = arg end
    function widget:SetJustifyH(value) self.justifyH = value end
    function widget:SetAlpha(value) self.alpha = value end
    function widget:SetScale(value) self.scale = value end
    function widget:SetChecked(value) self.checked = value and true or false end
    -- Vanilla check buttons return 1 or nil rather than strict booleans.
    function widget:GetChecked() if self.checked then return 1 end return nil end
    function widget:SetMinMaxValues(low, high) self.low = low; self.high = high end
    function widget:SetValueStep(value) self.valueStep = value end
    function widget:SetValue(value)
        self.value = value
        if self.kind == "Slider" and self.scripts.OnValueChanged then
            sliderSetCalls = sliderSetCalls + 1
            sliderSetDepth = sliderSetDepth + 1
            if sliderSetDepth > 2 then error("recursive slider refresh") end
            this = self
            arg1 = value
            self.scripts.OnValueChanged()
            sliderSetDepth = sliderSetDepth - 1
        end
    end
    function widget:GetValue() return self.value end
    function widget:SetID(value) self.id = value end
    function widget:GetID() return self.id end
    function widget:SetFrameStrata(value) self.strata = value end
    function widget:SetFrameLevel(value) self.frameLevel = value end
    function widget:GetFrameLevel() return self.frameLevel or 1 end
    function widget:SetToplevel(value) self.toplevel = value end
    function widget:SetClampedToScreen(value) self.clamped = value end
    function widget:RegisterForClicks() end
    function widget:SetHighlightTexture(value) self.highlightTexture = value end
    function widget:SetTexture(value) self.texture = value end
    function widget:SetTexCoord(...) self.texCoord = arg end
    function widget:CreateTexture(childName)
        local child = NewWidget("Texture", childName)
        self.children = self.children or {}
        table.insert(self.children, child)
        return child
    end
    function widget:GetLeft() return self.left or 100 end
    function widget:GetBottom() return self.bottom or 100 end
    function widget:GetScale() return self.scale or 1 end
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    function widget:IsShown() return self.shown end
    function widget:IsVisible() return self.shown end
    function widget:StartMoving() self.moving = true end
    function widget:StopMovingOrSizing() self.moving = false end
    return widget
end

UIParent = NewWidget("Frame", "UIParent")
Minimap = NewWidget("Frame", "Minimap")
Minimap.frameLevel = 2
local cursorX, cursorY = 170, 200
function GetCursorPosition() return cursorX, cursorY end
if not math.atan2 then math.atan2 = function(y, x) return math.atan(y / x) end end
function CreateFrame(kind, name, parent, template)
    local frame = NewWidget(kind, name)
    if name then setglobal(name, frame) end
    if template == "OptionsSliderTemplate" then
        setglobal(name .. "Text", NewWidget("FontString", name .. "Text"))
        setglobal(name .. "Low", NewWidget("FontString", name .. "Low"))
        setglobal(name .. "High", NewWidget("FontString", name .. "High"))
    end
    return frame
end

local bindings = {
    { "CP", "CTRL-C", nil },
    { "CCP_START", "F1", "ALT-F1" },
    { "CCP_COME", "F2", "CTRL-F2" },
    { "CCP_START_TANK", "SHIFT-F1", nil },
}
function GetNumBindings() return table.getn(bindings) end
function GetBinding(index) local row = bindings[index]; return row[1], row[2], row[3] end
function GetBindingKey(action)
    local index
    for index = 1, table.getn(bindings) do if bindings[index][1] == action then return bindings[index][2], bindings[index][3] end end
end
function GetBindingAction(key)
    local index
    for index = 1, table.getn(bindings) do if bindings[index][2] == key or bindings[index][3] == key then return bindings[index][1] end end
    return ""
end
function SetBinding(key, action)
    local index, row
    for index = 1, table.getn(bindings) do
        row = bindings[index]
        if row[2] == key then row[2] = nil end
        if row[3] == key then row[3] = nil end
    end
    if not action then return true end
    for index = 1, table.getn(bindings) do
        if bindings[index][1] == action then
            if bindings[index][2] == key or bindings[index][3] == key then return true end
            if not bindings[index][2] then bindings[index][2] = key elseif not bindings[index][3] then bindings[index][3] = key else bindings[index][2] = key end
            return true
        end
    end
    return false
end
local bindingSaveCalls = 0
function GetCurrentBindingSet() return 1 end
function SaveBindings()
    bindingSaveCalls = bindingSaveCalls + 1
    if CCPKeybindDisplay and CCPKeybindDisplay.eventFrame then
        this = CCPKeybindDisplay.eventFrame
        event = "UPDATE_BINDINGS"
        CCPKeybindDisplay.eventFrame:GetScript("OnEvent")()
    end
end
local shiftDown, altDown, controlDown = false, false, false
function IsShiftKeyDown() return shiftDown end
function IsAltKeyDown() return altDown end
function IsControlKeyDown() return controlDown end
StaticPopupDialogs = {}
local shownPopup
function StaticPopup_Show(name) shownPopup = name end

BINDING_NAME_CP = "Show/Hide CCP"
BINDING_NAME_CCP_START = "Start"
BINDING_NAME_CCP_COME = "Come"
BINDING_NAME_CCP_START_TANK = "Start: Tank"
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
CCPKeybindDisplayDB = nil

assert(pcall(dofile, addonPath))
local optionsLoaded, optionsMessage = pcall(dofile, optionsPath)
if not optionsLoaded then error("options failed to load: " .. tostring(optionsMessage)) end
CCPKeybindDisplay:Initialize()
local function FlushBindingRefresh()
    this = CCPKeybindDisplay.eventFrame
    arg1 = 0.016
    CCPKeybindDisplay.eventFrame:GetScript("OnUpdate")()
end

if not CCPKeybindDisplay.CreateOverlay then error("CreateOverlay is missing") end
CCPKeybindDisplay:CreateOverlay()
CCPKeybindDisplay:UpdateDisplay()

local function assertEqual(actual, expected, label)
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local originalRefresh = CCPKeybindDisplay.Refresh
local coalescedRefreshes = 0
CCPKeybindDisplay.Refresh = function(self)
    coalescedRefreshes = coalescedRefreshes + 1
    originalRefresh(self)
end
local burstIndex
for burstIndex = 1, 3 do
    this = CCPKeybindDisplay.eventFrame
    event = "UPDATE_BINDINGS"
    CCPKeybindDisplay.eventFrame:GetScript("OnEvent")()
end
assertEqual(CCPKeybindDisplay.bindingRefreshPending, true, "UPDATE_BINDINGS burst queues one refresh")
FlushBindingRefresh()
assertEqual(coalescedRefreshes, 1, "UPDATE_BINDINGS burst coalesces to one refresh")
assertEqual(CCPKeybindDisplay.bindingRefreshPending, false, "coalesced refresh clears pending state")
FlushBindingRefresh()
assertEqual(coalescedRefreshes, 1, "idle OnUpdate does not repeat a refresh")
local originalDiscoverBindings = CCPKeybindDisplay.DiscoverBindings
local injectedDuringRefresh = false
CCPKeybindDisplay.DiscoverBindings = function(self)
    local result = originalDiscoverBindings(self)
    if not injectedDuringRefresh then
        injectedDuringRefresh = true
        self:RequestBindingRefresh()
    end
    return result
end
coalescedRefreshes = 0
CCPKeybindDisplay:RequestBindingRefresh()
FlushBindingRefresh()
assertEqual(coalescedRefreshes, 1, "first queued refresh runs")
assertEqual(CCPKeybindDisplay.bindingRefreshPending, true, "event raised during refresh remains pending")
FlushBindingRefresh()
assertEqual(coalescedRefreshes, 2, "event raised during refresh runs on the next frame")
assertEqual(CCPKeybindDisplay.bindingRefreshPending, false, "follow-up refresh clears pending state")
FlushBindingRefresh()
assertEqual(coalescedRefreshes, 2, "event-during-refresh path settles without looping")
CCPKeybindDisplay.DiscoverBindings = originalDiscoverBindings
CCPKeybindDisplay.Refresh = originalRefresh

assertEqual(CCPKeybindDisplay.overlay.shown, true, "overlay visible by default")
assertEqual(CCPKeybindDisplay.overlay.width, 220, "command-key card auto-fits its default content")
assertEqual(CCPKeybindDisplay.overlay.height, 64, "single-list card default height")
assertEqual(CCPKeybindDisplay.overlayTitle.text, "CCP KEYBINDS", "HUD card title")
assertEqual(CCPKeybindDisplay.overlayDivider.shown, true, "HUD column divider shown")
assertEqual(table.getn(CCPKeybindDisplay.rows), 3, "one row per visible assigned general binding")
assertEqual(CCPKeybindDisplay.rows[1].label.text, "Show/Hide CCP", "first label")
assertEqual(CCPKeybindDisplay.rows[1].keys.text, "CTRL-C", "first key")
assertEqual(CCPKeybindDisplay.rows[3].keys.text, "F2 / CTRL-F2", "two assigned keys")
assertEqual(CCPKeybindDisplay.rows[2].keys.justifyH, "LEFT", "heads-up key values start beside their commands")
assertEqual(CCPKeybindDisplay.rows[2].keys.points[1][4], CCPKeybindDisplay.rows[2].label.points[1][4] + CCPKeybindDisplay.rows[2].label.width + 16, "short command key uses the aligned table gap")
assertEqual(CCPKeybindDisplay.rows[2].keys.points[1][4] < 100, true, "short command key no longer sits at the overlay border")
assertEqual(CCPKeybindDisplay.overlay.mouseEnabled, true, "overlay movable while unlocked")
setglobal("BINDING_NAME_CCP_START", "Selector: Previous (All/Role/Class)")
CCPKeybindDisplay:Refresh()
assertEqual(CCPKeybindDisplay.rows[2].label.width > 100, true, "reused label is unconstrained before measuring longer text")
assertEqual(CCPKeybindDisplay.rows[2].label.width <= 220, true, "command column caps long CCP labels safely")
assertEqual(CCPKeybindDisplay.rows[2].label.height, 12, "long labels are clipped to one row instead of overlapping")
assertEqual(CCPKeybindDisplay.rows[2].keys.points[1][4], CCPKeybindDisplay.rows[2].label.points[1][4] + CCPKeybindDisplay.rows[2].label.width + 16, "long command key follows the command column")
assertEqual(CCPKeybindDisplay.rows[2].keys.points[1][4] + CCPKeybindDisplay.rows[2].keys.width <= CCPKeybindDisplay.overlay.width - 6, true, "long command key stays inside the auto-fitted card")
CCPKeybindDisplay:SetVisualOption("fontSize", 24)
assertEqual(CCPKeybindDisplay.rows[2].label.width > 220, true, "command width cap grows with the selected font size")
assertEqual(CCPKeybindDisplay.rows[2].label:GetStringWidth() <= CCPKeybindDisplay.rows[2].label.width, true, "large-font command stays complete")
CCPKeybindDisplay:SetVisualOption("fontSize", 10)
setglobal("BINDING_NAME_CCP_START", "Start")
CCPKeybindDisplay:Refresh()
bindings[2][2] = "NUMPADDIVIDE"
bindings[2][3] = nil
CCPKeybindDisplay:Refresh()
assertEqual(CCPKeybindDisplay.rows[2].keys.width > 55, true, "reused key field is unconstrained before measuring longer text")
bindings[2][2] = "CTRL-SHIFT-PAGEDOWN"
bindings[2][3] = "ALT-CTRL-SHIFT-PAGEUP"
CCPKeybindDisplay:Refresh()
CCPKeybindDisplay:SetEntryOverride("CCP_START_TANK", true)
local geometryFont, geometryRow
for geometryFont = 8, 24 do
        CCPKeybindDisplay:SetVisualOption("fontSize", geometryFont)
        local geometryCount = table.getn(CCPKeybindDisplay:GetVisibleEntries())
        local rowsPerColumn = geometryCount
        local actualColumnWidth = CCPKeybindDisplay.overlay.width
        local firstLabelWidth = CCPKeybindDisplay.rows[1].label.width
        local firstKeyWidth = CCPKeybindDisplay.rows[1].keys.width
        for geometryRow = 1, geometryCount do
            local geometryKeys = CCPKeybindDisplay.rows[geometryRow].keys
            local geometryLabel = CCPKeybindDisplay.rows[geometryRow].label
            local geometryColumn = math.floor((geometryRow - 1) / rowsPerColumn)
            assertEqual(geometryLabel.width, firstLabelWidth, "all command cells use one aligned width")
            assertEqual(geometryKeys.width, firstKeyWidth, "all key cells use one aligned width")
            assertEqual(geometryKeys:GetStringWidth() <= geometryKeys.width, true, "complete key text fits the aligned key cell")
            assertEqual(geometryKeys.points[1][4], geometryLabel.points[1][4] + geometryLabel.width + 16, "aligned key text keeps the table gap")
            assertEqual(geometryKeys.points[1][4] + geometryKeys.width <= ((geometryColumn + 1) * actualColumnWidth) - 6, true, "aligned key cell stays inside its column")
        end
        if geometryFont == 24 then
            assertEqual(CCPKeybindDisplay.overlay.width > 320, true, "auto-fit expands for unusually long key values")
        end
end
bindings[2][2] = "F1"
bindings[2][3] = "ALT-F1"
CCPKeybindDisplay:ClearEntryOverride("CCP_START_TANK")
CCPKeybindDisplay:SetVisualOption("fontSize", 10)
assertEqual(CCPKeybindDisplay.minimapButton.shown, true, "minimap button shown by default")
assertEqual(CCPKeybindDisplay.minimapButton.width, 32, "minimap button compact size")
this = CCPKeybindDisplay.minimapButton
CCPKeybindDisplay.minimapButton:GetScript("OnDragStart")()
CCPKeybindDisplay.minimapButton:GetScript("OnUpdate")()
CCPKeybindDisplay.minimapButton:GetScript("OnDragStop")()
assertEqual(math.floor(CCPKeybindDisplay.db.minimap.angle), 90, "minimap drag saves angle")

print("UI_DEFAULT_OVERLAY=PASS")

CCPKeybindDisplay:SetLocked(true)
assertEqual(CCPKeybindDisplay.overlay.mouseEnabled, false, "locked overlay ignores mouse")
CCPKeybindDisplay:SetLocked(false)
assertEqual(CCPKeybindDisplay.overlay.mouseEnabled, true, "unlocked overlay accepts mouse")

CCPKeybindDisplay:SetVisualOption("alpha", 0.5)
CCPKeybindDisplay:SetVisualOption("fontSize", 10)
local compactAutoWidth = CCPKeybindDisplay.overlay.width
CCPKeybindDisplay:SetVisualOption("scale", 1)
CCPKeybindDisplay:SetVisualOption("fontSize", 24)
local largeFontLogicalWidth = CCPKeybindDisplay.overlay.width
CCPKeybindDisplay:SetVisualOption("scale", 1.25)
assertEqual(CCPKeybindDisplay.overlay.alpha, 0.5, "alpha applies immediately")
assertEqual(CCPKeybindDisplay.overlay.scale, 1.25, "scale applies immediately")
assertEqual(CCPKeybindDisplay.overlay.width > compactAutoWidth, true, "card grows when larger text needs more room")
assertEqual(CCPKeybindDisplay.overlay.width, largeFontLogicalWidth, "scale does not double-apply to logical card width")
assertEqual(CCPKeybindDisplay.overlay.width * CCPKeybindDisplay.overlay.scale, largeFontLogicalWidth * 1.25, "scale controls the final on-screen card width exactly once")
assertEqual(CCPKeybindDisplay.rows[1].label.font[2], 24, "font size applies immediately")

CCPKeybindDisplay.overlay:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 44, -55)
this = CCPKeybindDisplay.overlay
CCPKeybindDisplay.overlay:GetScript("OnDragStop")()
assertEqual(CCPKeybindDisplay.db.visual.point, "TOPLEFT", "drag saves point")
assertEqual(CCPKeybindDisplay.db.visual.relativePoint, "TOPLEFT", "drag saves relative point")
assertEqual(CCPKeybindDisplay.db.visual.x, 44, "drag saves x")
assertEqual(CCPKeybindDisplay.db.visual.y, -55, "drag saves y")

CCPKeybindDisplay:SetVisible(false)
assertEqual(CCPKeybindDisplay.overlay.shown, false, "visibility setting hides overlay")
CCPKeybindDisplay:SetVisible(true)
assertEqual(CCPKeybindDisplay.overlay.shown, true, "visibility setting shows overlay")

print("UI_VISUAL_SETTINGS=PASS")

assertEqual(CCPKeybindDisplay:SetVisualOption("columns", 2), false, "duplicate command-key pairs are rejected")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "HUD remains one vertical command-key table")
assertEqual(CCPKeybindDisplay:SetVisualOption("width", 400), false, "removed preferred-width option is rejected")
assertEqual(CCPKeybindDisplay.db.visual.width, nil, "removed preferred width is not persisted")
assertEqual(CCPKeybindDisplay:SetVisualOption("rowSpacing", 6), true, "row-spacing option accepted")
assertEqual(CCPKeybindDisplay:SetVisualOption("background", false), true, "background option accepted")
assertEqual(CCPKeybindDisplay.rows[3].label.points[1][4], CCPKeybindDisplay.rows[1].label.points[1][4], "all commands stay in one left column")
assertEqual(CCPKeybindDisplay.rows[3].label.points[1][5] < CCPKeybindDisplay.rows[1].label.points[1][5], true, "bindings continue down the table")
assertEqual(CCPKeybindDisplay.rows[1].label.width, CCPKeybindDisplay.rows[2].label.width, "commands use one small aligned column")
assertEqual(CCPKeybindDisplay.rows[1].keys.width, CCPKeybindDisplay.rows[2].keys.width, "keybinds use one aligned column")
assertEqual(CCPKeybindDisplay.overlay.backdropColor[4], 0, "background can be hidden")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "rejected width preserves the command-key table")

print("UI_LAYOUT_OPTIONS=PASS")

local function click(widget, checked)
    widget:SetChecked(checked)
    this = widget
    arg1 = "LeftButton"
    widget:GetScript("OnClick")()
end

CCPKeybindDisplay:CreateOptions()
assertEqual(CCPKeybindDisplay.options.shown, false, "options start hidden")
CCPKeybindDisplay:ToggleOptions()
assertEqual(CCPKeybindDisplay.options.shown, true, "options can be opened")
assertEqual(CCPKeybindDisplay.options.width, 790, "polished settings width")
assertEqual(CCPKeybindDisplay.options.height, 680, "polished settings height")
assertEqual(CCPKeybindDisplay.versionLabel.text, "v0.3.1", "release version shown")
assertEqual(CCPKeybindDisplay.creditLabel.text, "Shirina", "Shirina credit shown")
assertEqual(math.abs(CCPKeybindDisplay.displayPanel.points[1][5]) + CCPKeybindDisplay.displayPanel.height <= 594, true, "display card stays above its footer gap")
assertEqual(math.abs(CCPKeybindDisplay.sliders.rowSpacing.points[1][5]) + CCPKeybindDisplay.sliders.rowSpacing.height <= 594, true, "row-spacing slider stays inside the display card")
assertEqual(CCPKeybindDisplay.sliders.width, nil, "preferred-width slider is removed")
assertEqual(math.abs(CCPKeybindDisplay.footerPanel.points[1][5]) + CCPKeybindDisplay.footerPanel.height <= CCPKeybindDisplay.options.height, true, "settings footer stays inside the frame")
assertEqual(math.abs(CCPKeybindDisplay.creditLabel.points[1][5]) + 9 <= CCPKeybindDisplay.options.height, true, "Shirina credit stays inside the frame")
assertEqual(CCPKeybindDisplay.displayPanel.shown, true, "settings display section card")
assertEqual(CCPKeybindDisplay.entriesPanel.shown, true, "settings bindings section card")
assertEqual(CCPKeybindDisplay.optionsCategoryFilter, "all", "settings list starts with all categories")
assertEqual(CCPKeybindDisplay.showUnassignedCheck:GetChecked(), nil, "assigned-only default reflected")
assertEqual(table.getn(CCPKeybindDisplay.bindingRows), 14, "settings allocates one complete binding page")
assertEqual(CCPKeybindDisplay.bindingRows[5].check.shown, false, "unused initial rows stay hidden")
assertEqual(CCPKeybindDisplay.bindingRows[1].label:GetText(), "Show/Hide CCP", "binding row uses CCP label")
assertEqual(sliderSetCalls <= 12, true, "slider refresh is bounded")

local originalTankDefault = CCPKeybindDisplay.db.categories.tank
this = CCPKeybindDisplay.categoryFilterButtons.tank
CCPKeybindDisplay.categoryFilterButtons.tank:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.optionsCategoryFilter, "tank", "category control filters the settings list")
assertEqual(table.getn(CCPKeybindDisplay.optionsEntries), 1, "tank category displays only tank bindings")
assertEqual(CCPKeybindDisplay.optionsEntries[1].action, "CCP_START_TANK", "tank filter shows the tank action")
assertEqual(CCPKeybindDisplay.db.categories.tank, originalTankDefault, "category filter does not select HUD bindings")
this = CCPKeybindDisplay.categoryFilterButtons.all
CCPKeybindDisplay.categoryFilterButtons.all:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.optionsCategoryFilter, "all", "all category restores the full settings list")

click(CCPKeybindDisplay.backgroundCheck, false)
assertEqual(CCPKeybindDisplay.db.visual.background, false, "Vanilla nil checkbox value hides the card background")
assertEqual(CCPKeybindDisplay.overlay.backdropColor[4], 0, "background checkbox hides the backdrop immediately")
click(CCPKeybindDisplay.backgroundCheck, true)
assertEqual(CCPKeybindDisplay.db.visual.background, true, "Vanilla numeric checkbox value restores the card background")
click(CCPKeybindDisplay.visibleCheck, false)
assertEqual(CCPKeybindDisplay.db.visual.visible, false, "Vanilla nil checkbox value hides the HUD")
assertEqual(CCPKeybindDisplay.overlay.shown, false, "HUD checkbox hides the overlay immediately")
click(CCPKeybindDisplay.visibleCheck, true)
assertEqual(CCPKeybindDisplay.db.visual.visible, true, "Vanilla numeric checkbox value restores the HUD")
assertEqual(CCPKeybindDisplay.overlay.shown, true, "HUD checkbox restores the overlay immediately")

setglobal("BINDING_NAME_CCP_UNUSED", "Unused command")
table.insert(bindings, { "CCP_UNUSED", nil, nil })
CCPKeybindDisplay:Refresh()
assertEqual(table.getn(CCPKeybindDisplay.optionsEntries), 5, "front list initially includes assigned and unassigned commands")
this = CCPKeybindDisplay.assignedOnlyButton
CCPKeybindDisplay.assignedOnlyButton:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.db.optionsAssignedOnly, true, "assigned-only list filter toggles on")
assertEqual(table.getn(CCPKeybindDisplay.optionsEntries), 4, "assigned-only list hides unassigned commands")
assertEqual(CCPKeybindDisplay.assignedOnlyButton.text, "List: Assigned only", "filter button shows its active state")
CCPKeybindDisplay:SetCategory("tank", false)
CCPKeybindDisplay:ClearEntryOverride("CCP_START_TANK")
click(CCPKeybindDisplay.showAllAssignedCheck, true)
assertEqual(CCPKeybindDisplay.db.showAllAssigned, true, "show-all assigned mode toggles on")
assertEqual(CCPKeybindDisplay:IsEntryEnabled(CCPKeybindDisplay.entries[4]), true, "show-all mode includes assigned role bindings")
assertEqual(CCPKeybindDisplay.db.overrides.CCP_UNUSED, nil, "show-all mode leaves unassigned overrides unchanged")
click(CCPKeybindDisplay.bindingRows[2].check, false)
assertEqual(CCPKeybindDisplay.db.showAllAssigned, false, "hiding one binding leaves show-all mode")
assertEqual(CCPKeybindDisplay.db.overrides.CCP_START, false, "individual binding can be hidden after show-all mode")
assertEqual(CCPKeybindDisplay:IsEntryEnabled(CCPKeybindDisplay.entries[2]), false, "individual exclusion takes effect immediately")
CCPKeybindDisplay:ClearEntryOverride("CCP_START")
click(CCPKeybindDisplay.showAllAssignedCheck, true)
CCPKeybindDisplay:Refresh()
assertEqual(CCPKeybindDisplay.db.showAllAssigned, true, "show-all mode survives a full addon refresh")
assertEqual(CCPKeybindDisplay.showAllAssignedCheck:GetChecked(), 1, "show-all persisted state is reflected in settings")
SetBinding("SHIFT-F1")
CCPKeybindDisplay:Refresh()
assertEqual(table.getn(CCPKeybindDisplay:GetVisibleEntries()), 3, "show-all mode drops a binding that becomes unassigned")
assertEqual(CCPKeybindDisplay.db.showAllAssigned, true, "show-all mode remains enabled after a binding is cleared")
SetBinding("SHIFT-F1", "CCP_START_TANK")
CCPKeybindDisplay:Refresh()
assertEqual(table.getn(CCPKeybindDisplay:GetVisibleEntries()), 4, "show-all mode includes a binding assigned later")
click(CCPKeybindDisplay.showAllAssignedCheck, false)
assertEqual(CCPKeybindDisplay.db.showAllAssigned, false, "show-all assigned mode toggles off")
CCPKeybindDisplay:ToggleAssignedOnlyList()
assertEqual(CCPKeybindDisplay.db.optionsAssignedOnly, false, "assigned-only list filter toggles off")
table.remove(bindings)
CCPKeybindDisplay:Refresh()

this = CCPKeybindDisplay.manageBindingsButton
local firstManagerUpdates = 0
local firstManagerUpdate = CCPKeybindDisplay.UpdateBindingManager
CCPKeybindDisplay.UpdateBindingManager = function(self)
    firstManagerUpdates = firstManagerUpdates + 1
    firstManagerUpdate(self)
end
CCPKeybindDisplay.manageBindingsButton:GetScript("OnClick")()
CCPKeybindDisplay.UpdateBindingManager = firstManagerUpdate
assertEqual(CCPKeybindDisplay.bindingManager.shown, true, "binding manager opens")
assertEqual(CCPKeybindDisplay.options.shown, false, "binding manager hides settings")
assertEqual(firstManagerUpdates, 1, "first binding-manager open refreshes once")
assertEqual(CCPKeybindDisplay.bindingManager.width, 790, "polished binding manager width")
assertEqual(CCPKeybindDisplay.bindingManager.height, 610, "polished binding manager height")
assertEqual(math.abs(CCPKeybindDisplay.bindingListPanel.points[1][5]) + CCPKeybindDisplay.bindingListPanel.height <= 504, true, "binding list card stays above its footer gap")
assertEqual(math.abs(CCPKeybindDisplay.bindingFooterPanel.points[1][5]) + CCPKeybindDisplay.bindingFooterPanel.height <= CCPKeybindDisplay.bindingManager.height, true, "binding manager footer stays inside the frame")
assertEqual(CCPKeybindDisplay.bindingManagerRows[1].label.text, "Come", "manager rows render after the polished layout")
this = CCPKeybindDisplay.bindingFilterButtons.tank
CCPKeybindDisplay.bindingFilterButtons.tank:GetScript("OnClick")()
assertEqual(table.getn(CCPKeybindDisplay.bindingManagerEntries), 1, "tank filter isolates tank commands")
assertEqual(CCPKeybindDisplay.bindingManagerRows[1].bind._ckdAction, "CCP_START_TANK", "tank row targets tank action")
CCPKeybindDisplay:BeginBindingCapture("CCP_COME", "Come")
this = CCPKeybindDisplay.bindingCapture; arg1 = "UNKNOWN"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
assertEqual(CCPKeybindDisplay.bindingCapture.shown, true, "unknown input leaves capture open")
local modifierKeys = { "SHIFT", "CTRL", "ALT", "LSHIFT", "RSHIFT", "LCTRL", "RCTRL", "LALT", "RALT" }
local modifierIndex
for modifierIndex = 1, table.getn(modifierKeys) do
    arg1 = modifierKeys[modifierIndex]
    CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
    assertEqual(CCPKeybindDisplay.bindingCapture.shown, true, modifierKeys[modifierIndex] .. " alone leaves capture open")
end
arg1 = "ESCAPE"; CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
assertEqual(CCPKeybindDisplay.bindingCapture.shown, false, "Escape cancels capture")
CCPKeybindDisplay:BeginBindingCapture("CCP_COME", "Come")
this = CCPKeybindDisplay.bindingCapture; arg1 = "F2"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
local comePrimary, comeAlternate = GetBindingKey("CCP_COME")
assertEqual(comePrimary, "F2", "same-key capture preserves primary")
assertEqual(comeAlternate, "CTRL-F2", "same-key capture preserves alternate")
assertEqual(bindingSaveCalls, 0, "same-key capture does not save")
this = CCPKeybindDisplay.bindingManagerRows[1].bind
CCPKeybindDisplay.bindingManagerRows[1].bind:GetScript("OnClick")()
controlDown = true; this = CCPKeybindDisplay.bindingCapture; arg1 = "T"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
controlDown = false
assertEqual(shownPopup, "CCPKD_BIND_CONFLICT", "replacing an action's existing keys requires confirmation")
assertEqual(StaticPopupDialogs.CCPKD_BIND_CONFLICT.hideOnEscape, 1, "replacement confirmation can be cancelled with Escape")
StaticPopupDialogs.CCPKD_BIND_CONFLICT.OnCancel()
assertEqual(GetBindingAction("SHIFT-F1"), "CCP_START_TANK", "replacement cancellation preserves the selected action")
assertEqual(bindingSaveCalls, 0, "replacement cancellation does not save")
assertEqual(CCPKeybindDisplay.pendingBinding, nil, "replacement cancellation clears pending state")
CCPKeybindDisplay:BeginBindingCapture("CCP_START_TANK", "Start: Tank")
controlDown = true; this = CCPKeybindDisplay.bindingCapture; arg1 = "T"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
controlDown = false
local originalUpdateBindingManager = CCPKeybindDisplay.UpdateBindingManager
local bindingManagerRefreshes = 0
CCPKeybindDisplay.UpdateBindingManager = function(self)
    bindingManagerRefreshes = bindingManagerRefreshes + 1
    originalUpdateBindingManager(self)
end
StaticPopupDialogs.CCPKD_BIND_CONFLICT.OnAccept()
FlushBindingRefresh()
CCPKeybindDisplay.UpdateBindingManager = originalUpdateBindingManager
assertEqual(GetBindingAction("CTRL-T"), "CCP_START_TANK", "captured modified key is assigned")
assertEqual(GetBindingAction("SHIFT-F1"), "", "confirmed replace-all removes the former key")
assertEqual(bindingSaveCalls, 1, "captured binding is saved once")
assertEqual(bindingManagerRefreshes, 1, "successful replacement refreshes the binding manager once")
CCPKeybindDisplay:BeginBindingCapture("CCP_START_TANK", "Start: Tank")
this = CCPKeybindDisplay.bindingCapture; arg1 = "F1"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
assertEqual(shownPopup, "CCPKD_BIND_CONFLICT", "conflicting key requires confirmation")
StaticPopupDialogs.CCPKD_BIND_CONFLICT.OnAccept()
FlushBindingRefresh()
assertEqual(GetBindingAction("F1"), "CCP_START_TANK", "confirmed conflict replaces old action")
assertEqual(GetBindingAction("ALT-F1"), "CCP_START", "confirmed conflict preserves the displaced action's alternate key")
CCPKeybindDisplay:CommitBinding("CCP_START", "F1")
CCPKeybindDisplay:CommitBinding("CCP_START_TANK", "CTRL-T")
CCPKeybindDisplay:SetBindingManagerFilter("tank")
this = CCPKeybindDisplay.bindingManagerRows[1].clear
bindingManagerRefreshes = 0
CCPKeybindDisplay.UpdateBindingManager = function(self)
    bindingManagerRefreshes = bindingManagerRefreshes + 1
    originalUpdateBindingManager(self)
end
CCPKeybindDisplay.bindingManagerRows[1].clear:GetScript("OnClick")()
FlushBindingRefresh()
CCPKeybindDisplay.UpdateBindingManager = originalUpdateBindingManager
assertEqual(GetBindingAction("CTRL-T"), "", "clear removes all keys from selected tank action")
assertEqual(bindingManagerRefreshes, 1, "successful clear-all refreshes the binding manager once")
CCPKeybindDisplay:BeginBindingCapture("CCP_START_TANK", "Start: Tank")
altDown = true; controlDown = true; shiftDown = true
this = CCPKeybindDisplay.bindingCapture; arg1 = "K"
CCPKeybindDisplay.bindingCapture:GetScript("OnKeyDown")()
altDown = false; controlDown = false; shiftDown = false
assertEqual(GetBindingAction("ALT-CTRL-SHIFT-K"), "CCP_START_TANK", "three modifiers use canonical Vanilla order")
CCPKeybindDisplay:ClearBinding("CCP_START_TANK")
FlushBindingRefresh()
this = CCPKeybindDisplay.minimapButton
CCPKeybindDisplay.minimapButton:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.options.shown, true, "minimap button opens settings")
assertEqual(CCPKeybindDisplay.bindingManager.shown, false, "minimap settings launcher hides binding manager")
CCPKeybindDisplay:ShowBindingManager()
SlashCmdList["CCPKEYBINDDISPLAY"]("")
assertEqual(CCPKeybindDisplay.options.shown, true, "slash command opens settings from binding manager")
assertEqual(CCPKeybindDisplay.bindingManager.shown, false, "slash settings launcher hides binding manager")
CCPKeybindDisplay:SetMinimapVisible(false)
assertEqual(CCPKeybindDisplay.minimapButton.shown, false, "minimap button can be hidden")
CCPKeybindDisplay:SetMinimapVisible(true)
assertEqual(CCPKeybindDisplay.minimapButton.shown, true, "minimap button can be restored")

click(CCPKeybindDisplay.bindingRows[2].check, false)
assertEqual(CCPKeybindDisplay.db.overrides.CCP_START, false, "individual general binding hide persists")
click(CCPKeybindDisplay.bindingRows[4].check, true)
assertEqual(CCPKeybindDisplay.db.overrides.CCP_START_TANK, true, "individual role binding add persists")

CCPKeybindDisplay:ResetOverrides()
assertEqual(next(CCPKeybindDisplay.db.overrides), nil, "individual overrides reset")
assertEqual(CCPKeybindDisplay.bindingRows[2].check:GetChecked(), 1, "reset restores general category default")
assertEqual(CCPKeybindDisplay.bindingRows[4].check:GetChecked(), nil, "reset restores tank category default")

SlashCmdList.CCPKEYBINDDISPLAY("lock")
assertEqual(CCPKeybindDisplay.db.visual.locked, true, "slash lock command")
SlashCmdList.CCPKEYBINDDISPLAY("unlock")
assertEqual(CCPKeybindDisplay.db.visual.locked, false, "slash unlock command")
local originalRefreshOptions = CCPKeybindDisplay.RefreshOptions
local refreshOptionsCalls = 0
CCPKeybindDisplay.RefreshOptions = function(self)
    refreshOptionsCalls = refreshOptionsCalls + 1
    originalRefreshOptions(self)
end
SlashCmdList.CCPKEYBINDDISPLAY("refresh")
assertEqual(refreshOptionsCalls, 1, "slash refresh updates options exactly once")
CCPKeybindDisplay.RefreshOptions = originalRefreshOptions

local growthIndex
for growthIndex = 1, 11 do
    local action = "CCP_GROWTH_" .. growthIndex
    setglobal("BINDING_NAME_" .. action, "Growth " .. growthIndex)
    table.insert(bindings, { action, "ALT-" .. growthIndex, nil })
end
event = "UPDATE_BINDINGS"
this = CCPKeybindDisplayEventFrame
CCPKeybindDisplayEventFrame:GetScript("OnEvent")()
FlushBindingRefresh()
assertEqual(table.getn(CCPKeybindDisplay.entries), 15, "UPDATE_BINDINGS discovers later CCP entries")
assertEqual(table.getn(CCPKeybindDisplay.bindingRows), 14, "options row pool grows to a full page")
assertEqual(CCPKeybindDisplay.bindingRows[14].check._ckdAction, "CCP_GROWTH_10", "page one reaches the fourteenth binding")

this = CCPKeybindDisplay.nextButton
CCPKeybindDisplay.nextButton:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.bindingRows[1].check._ckdAction, "CCP_GROWTH_11", "page two starts at the fifteenth binding")
assertEqual(CCPKeybindDisplay.bindingRows[2].check.shown, false, "partial final page hides unused rows")
click(CCPKeybindDisplay.bindingRows[1].check, false)
assertEqual(CCPKeybindDisplay.db.overrides.CCP_GROWTH_11, false, "reused page row updates its current action")
this = CCPKeybindDisplay.prevButton
CCPKeybindDisplay.prevButton:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.bindingRows[1].check._ckdAction, "CP", "previous returns to the first page")
this = CCPKeybindDisplay.nextButton
CCPKeybindDisplay.nextButton:GetScript("OnClick")()

local roleFixtures = {
    { "CCP_FIX_HEALER", "Fixture Healer" },
    { "CCP_FIX_TANHE", "Fixture Tank and Healer" },
    { "CCP_FIX_A_DPS", "Alpha DPS" },
    { "CCP_FIX_Z_DPS", "Zulu DPS" },
    { "CCP_FIX_MDPS", "Fixture Melee" },
    { "CCP_FIX_RDPS", "Fixture Ranged" },
}
local fixtureIndex
for fixtureIndex = 1, table.getn(roleFixtures) do
    setglobal("BINDING_NAME_" .. roleFixtures[fixtureIndex][1], roleFixtures[fixtureIndex][2])
    table.insert(bindings, { roleFixtures[fixtureIndex][1], "CTRL-F" .. fixtureIndex, nil })
end
CCPKeybindDisplay:Refresh()
CCPKeybindDisplay:ShowBindingManager()
local expectedFilterCounts = { general = 14, tank = 1, healer = 1, tanhe = 1, dps = 2, mdps = 1, rdps = 1, all = 21 }
local filterName, expectedCount
for filterName, expectedCount in expectedFilterCounts do
    CCPKeybindDisplay:SetBindingManagerFilter(filterName)
    assertEqual(table.getn(CCPKeybindDisplay.bindingManagerEntries), expectedCount, filterName .. " binding-manager filter count")
end
CCPKeybindDisplay:SetBindingManagerFilter("dps")
assertEqual(CCPKeybindDisplay.bindingManagerEntries[1].label, "Alpha DPS", "binding-manager sorts labels within a role")
assertEqual(CCPKeybindDisplay.bindingManagerEntries[2].label, "Zulu DPS", "binding-manager sort order is stable")
CCPKeybindDisplay:SetBindingManagerFilter("all")
local orderIndex
for orderIndex = 2, table.getn(CCPKeybindDisplay.bindingManagerEntries) do
    local previousEntry = CCPKeybindDisplay.bindingManagerEntries[orderIndex - 1]
    local currentEntry = CCPKeybindDisplay.bindingManagerEntries[orderIndex]
    assertEqual(previousEntry.category <= currentEntry.category, true, "unfiltered manager sorts categories")
    if previousEntry.category == currentEntry.category then
        assertEqual(string.lower(previousEntry.label) <= string.lower(currentEntry.label), true, "unfiltered manager sorts labels inside categories")
    end
end
assertEqual(CCPKeybindDisplay.bindingManagerPage, 1, "binding-manager filter resets to page one")
this = CCPKeybindDisplay.bindingManagerNext
CCPKeybindDisplay.bindingManagerNext:GetScript("OnClick")()
assertEqual(CCPKeybindDisplay.bindingManagerPage, 2, "binding manager reaches its second page")
assertEqual(CCPKeybindDisplay.bindingManagerRows[9].bind.shown, true, "binding-manager partial page shows its final entry")
assertEqual(CCPKeybindDisplay.bindingManagerRows[10].bind.shown, false, "binding-manager partial page hides stale rows")

while table.getn(bindings) > 3 do table.remove(bindings) end
bindings[1][2] = "CTRL-SHIFT-C"
event = "UPDATE_BINDINGS"
this = CCPKeybindDisplayEventFrame
CCPKeybindDisplayEventFrame:GetScript("OnEvent")()
FlushBindingRefresh()
assertEqual(CCPKeybindDisplay.optionsPage, 1, "shrinking discovery clamps the current page")
assertEqual(CCPKeybindDisplay.bindingManagerPage, 1, "shrinking discovery clamps the binding-manager page")
assertEqual(CCPKeybindDisplay.bindingManagerRows[4].bind.shown, false, "binding-manager shrink hides stale rows")
assertEqual(CCPKeybindDisplay.bindingRows[1].keys:GetText(), "CTRL-SHIFT-C", "open options refresh changed assignments")
assertEqual(CCPKeybindDisplay.bindingRows[4].check.shown, false, "shrink hides stale rows")

CCPKeybindDisplay.overlay = nil
CCPKeybindDisplay.rows = {}
CCPKeybindDisplay.db.visual.background = false
CCPKeybindDisplay:CreateOverlay()
assertEqual(CCPKeybindDisplay.overlay.backdropColor[4], 0, "saved transparent background applies on login")
assertEqual(CCPKeybindDisplay.overlay.backdropBorderColor[4], 0, "saved transparent border applies on login")

print("UI_OPTIONS_PANEL=PASS")
