-- Lua 5.0 runtime test harness for CCP Keybind Display.

local addonPath = arg[1]
if not addonPath then error("addon path required") end
local GlobalTable = _G
function getglobal(name) return GlobalTable[name] end
function setglobal(name, value) GlobalTable[name] = value end
_G = nil

local bindings = {
    { "CP", "CTRL-C", nil },
    { "CCP_START", "F1", "ALT-F1" },
    { "CCP_START_TANK", "SHIFT-F1", nil },
    { "CCP_START_HEALER", "SHIFT-F2", nil },
    { "CCP_COME", nil, nil },
    { "CCP_WIN_FUTURE", "ALT-F", nil },
    { "JUMP", "SPACE", "ALT-SPACE" },
}

BINDING_NAME_CP = "Show/Hide CCP"
BINDING_NAME_CCP_START = "Start"
BINDING_NAME_CCP_START_TANK = "Start: Tank"
BINDING_NAME_CCP_START_HEALER = "Start: Healer"
BINDING_NAME_CCP_COME = "Come"
BINDING_NAME_CCP_WIN_FUTURE = "Future CCP Window"

function GetNumBindings()
    return table.getn(bindings)
end

function GetBinding(index)
    local row = bindings[index]
    return row[1], row[2], row[3]
end

function GetBindingKey(action)
    local index
    for index = 1, table.getn(bindings) do
        if bindings[index][1] == action then return bindings[index][2], bindings[index][3] end
    end
end

function GetBindingAction(key)
    local index
    for index = 1, table.getn(bindings) do
        if bindings[index][2] == key or bindings[index][3] == key then return bindings[index][1] end
    end
    return ""
end

local failBindingKey
local failBindingAction
local failUnbindKey
local failAfterBindingKey
local failAfterBindingAction
local failRestoreKey
local failRestoreAction
function SetBinding(key, action)
    if action and key == failBindingKey and (not failBindingAction or action == failBindingAction) then return false end
    if action and key == failRestoreKey and action == failRestoreAction then return false end
    if not action and key == failUnbindKey then return false end
    local index, row
    for index = 1, table.getn(bindings) do
        row = bindings[index]
        if row[2] == key then row[2] = nil end
        if row[3] == key then row[3] = nil end
    end
    if action and key == failAfterBindingKey and action == failAfterBindingAction then return false end
    if not action then return true end
    for index = 1, table.getn(bindings) do
        row = bindings[index]
        if row[1] == action then
            if row[2] == key or row[3] == key then return true end
            if not row[2] then row[2] = key elseif not row[3] then row[3] = key else row[2] = key end
            return true
        end
    end
    return false
end

local saveBindingsCalls = 0
function GetCurrentBindingSet() return 1 end
function SaveBindings() saveBindingsCalls = saveBindingsCalls + 1 end

function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

local chatMessages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(frame, message) table.insert(chatMessages, message) end }
CCPKeybindDisplayDB = nil

local loaded, message = pcall(dofile, addonPath)
if not loaded then
    error("addon failed to load: " .. tostring(message))
end
if not CCPKeybindDisplay then
    error("CCPKeybindDisplay namespace was not created")
end

CCPKeybindDisplay:Initialize()
local visible = CCPKeybindDisplay:GetVisibleEntries()

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

assertEqual(table.getn(visible), 3, "default visible count")
assertEqual(visible[1].action, "CP", "first general binding")
assertEqual(visible[2].action, "CCP_START", "second general binding")
assertEqual(visible[3].action, "CCP_WIN_FUTURE", "future CCP binding is discovered")
assertEqual(visible[3].label, "Future CCP Window", "future label")
assertEqual(string.find(chatMessages[1] or "", "/ckd") ~= nil, true, "login message points to options")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_TANK"), "tank", "tank suffix")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_HEALER"), "healer", "healer suffix")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_TANHE"), "tanhe", "tank-healer suffix")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_DPS"), "dps", "DPS suffix")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_MDPS"), "mdps", "melee DPS suffix beats DPS overlap")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_TEST_RDPS"), "rdps", "ranged DPS suffix beats DPS overlap")
assertEqual(CCPKeybindDisplay:CategoryForAction("CCP_FUTURE_OTHER"), "general", "unknown future action defaults to general")

print("RUNTIME_DEFAULT_DISCOVERY=PASS")

local function containsAction(entries, action)
    local index
    for index = 1, table.getn(entries) do
        if entries[index].action == action then
            return true
        end
    end
    return false
end

CCPKeybindDisplay:SetCategory("tank", true)
visible = CCPKeybindDisplay:GetVisibleEntries()
assertEqual(containsAction(visible, "CCP_START_TANK"), true, "whole tank category can be added")

CCPKeybindDisplay:SetEntryOverride("CCP_START", false)
CCPKeybindDisplay:SetEntryOverride("CCP_START_HEALER", true)
visible = CCPKeybindDisplay:GetVisibleEntries()
assertEqual(containsAction(visible, "CCP_START"), false, "individual general binding can be hidden")
assertEqual(containsAction(visible, "CCP_START_HEALER"), true, "individual healer binding can be added")

CCPKeybindDisplay:SetShowUnassigned(true)
visible = CCPKeybindDisplay:GetVisibleEntries()
assertEqual(containsAction(visible, "CCP_COME"), true, "unassigned binding can be shown when requested")

CCPKeybindDisplay:ClearEntryOverride("CCP_START")
visible = CCPKeybindDisplay:GetVisibleEntries()
assertEqual(containsAction(visible, "CCP_START"), true, "clearing override restores category default")

print("RUNTIME_CUSTOM_FILTERS=PASS")

assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START", "ALT-F1"), true, "same-key assignment is a no-op")
local sameKey1, sameKey2 = GetBindingKey("CCP_START")
assertEqual(sameKey1, "F1", "same-key assignment preserves primary")
assertEqual(sameKey2, "ALT-F1", "same-key assignment preserves alternate")
assertEqual(saveBindingsCalls, 0, "same-key assignment does not save")
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_TANK", "CTRL-T"), true, "binding editor assigns a key")
assertEqual(GetBindingAction("CTRL-T"), "CCP_START_TANK", "assigned key targets selected CCP action")
assertEqual(saveBindingsCalls, 1, "assignment saves the active binding set once")
assertEqual(CCPKeybindDisplay:CommitBinding("JUMP", "CTRL-J"), false, "binding editor rejects non-CCP actions")
assertEqual(CCPKeybindDisplay:ClearBinding("CCP_START_TANK"), true, "binding editor clears an action")
assertEqual(GetBindingAction("CTRL-T"), "", "cleared key is unassigned")
assertEqual(saveBindingsCalls, 2, "clear saves the active binding set once")
failBindingKey = "CTRL-X"
failBindingAction = "CCP_START_HEALER"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_HEALER", "CTRL-X"), false, "failed assignment reports failure")
assertEqual(GetBindingAction("SHIFT-F2"), "CCP_START_HEALER", "failed assignment rolls back the old key")
assertEqual(saveBindingsCalls, 2, "failed assignment does not save")
failBindingKey = nil
failBindingAction = nil
failBindingKey = "SPACE"
failBindingAction = "CCP_START_HEALER"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_HEALER", "SPACE"), false, "failed conflict assignment reports failure")
assertEqual(GetBindingAction("SHIFT-F2"), "CCP_START_HEALER", "failed conflict restores the target action")
assertEqual(GetBindingAction("SPACE"), "JUMP", "failed conflict restores the proposed key's previous owner")
assertEqual(GetBindingAction("ALT-SPACE"), "JUMP", "pre-mutation failure preserves the previous owner's alternate")
assertEqual(saveBindingsCalls, 2, "failed conflict does not save")
failBindingKey = nil
failBindingAction = nil
failUnbindKey = "ALT-F1"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START", "CTRL-X"), false, "partial replace-all clear reports failure")
assertEqual(GetBindingAction("F1"), "CCP_START", "partial replace-all failure restores primary")
assertEqual(GetBindingAction("ALT-F1"), "CCP_START", "partial replace-all failure restores alternate")
assertEqual(saveBindingsCalls, 2, "partial replace-all failure does not save")
assertEqual(CCPKeybindDisplay:ClearBinding("CCP_START"), false, "partial clear-all failure reports failure")
assertEqual(GetBindingAction("F1"), "CCP_START", "partial clear-all failure restores primary")
assertEqual(GetBindingAction("ALT-F1"), "CCP_START", "partial clear-all failure restores alternate")
assertEqual(saveBindingsCalls, 2, "partial clear-all failure does not save")
failUnbindKey = nil
failUnbindKey = "F1"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START", "CTRL-X"), false, "first-slot replace-all clear failure reports failure")
assertEqual(GetBindingAction("F1"), "CCP_START", "first-slot replace-all failure restores primary")
assertEqual(GetBindingAction("ALT-F1"), "CCP_START", "first-slot replace-all failure restores alternate")
assertEqual(CCPKeybindDisplay:ClearBinding("CCP_START"), false, "first-slot clear-all failure reports failure")
assertEqual(GetBindingAction("F1"), "CCP_START", "first-slot clear-all failure restores primary")
assertEqual(GetBindingAction("ALT-F1"), "CCP_START", "first-slot clear-all failure restores alternate")
assertEqual(saveBindingsCalls, 2, "first-slot failures do not save")
failUnbindKey = nil
local untouchedWarningCount = table.getn(chatMessages)
failBindingKey = "SPACE"
failBindingAction = "CCP_START_HEALER"
failRestoreKey = "SPACE"
failRestoreAction = "JUMP"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_HEALER", "SPACE"), false, "pre-mutation failure does not restore an untouched owner")
assertEqual(GetBindingAction("SPACE"), "JUMP", "untouched previous owner keeps candidate key")
assertEqual(GetBindingAction("ALT-SPACE"), "JUMP", "untouched previous owner keeps alternate key")
assertEqual(table.getn(chatMessages), untouchedWarningCount, "untouched previous owner causes no rollback warning")
failBindingKey = nil
failBindingAction = nil
failRestoreKey = nil
failRestoreAction = nil
failAfterBindingKey = "SPACE"
failAfterBindingAction = "CCP_START_HEALER"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_HEALER", "SPACE"), false, "post-displacement assignment failure reports failure")
assertEqual(GetBindingAction("SHIFT-F2"), "CCP_START_HEALER", "post-displacement failure restores target")
assertEqual(GetBindingAction("SPACE"), "JUMP", "post-displacement failure restores previous owner")
assertEqual(GetBindingAction("ALT-SPACE"), "JUMP", "post-displacement failure restores previous owner's alternate")
assertEqual(saveBindingsCalls, 2, "post-displacement failure does not save")
failAfterBindingKey = nil
failAfterBindingAction = nil
local warningCount = table.getn(chatMessages)
failAfterBindingKey = "SPACE"
failAfterBindingAction = "CCP_START_HEALER"
failRestoreKey = "SPACE"
failRestoreAction = "JUMP"
assertEqual(CCPKeybindDisplay:CommitBinding("CCP_START_HEALER", "SPACE"), false, "incomplete rollback remains fail-closed")
assertEqual(GetBindingAction("SHIFT-F2"), "CCP_START_HEALER", "incomplete rollback still restores target")
assertEqual(GetBindingAction("SPACE"), "", "injected former-owner restore failure remains visible")
assertEqual(GetBindingAction("ALT-SPACE"), "JUMP", "incomplete rollback preserves the former owner's restorable alternate")
assertEqual(table.getn(chatMessages), warningCount + 1, "incomplete rollback emits one warning")
assertEqual(string.find(chatMessages[table.getn(chatMessages)], "recovery was incomplete") ~= nil, true, "incomplete rollback warning is explicit")
assertEqual(saveBindingsCalls, 2, "incomplete rollback does not save")
failAfterBindingKey = nil
failAfterBindingAction = nil
failRestoreKey = nil
failRestoreAction = nil
SetBinding("SPACE", "JUMP")

print("RUNTIME_BINDING_EDITOR=PASS")

BINDING_NAME_CCP_FUTURE_RDPS = "Future Ranged Command"
table.insert(bindings, { "CCP_FUTURE_RDPS", "CTRL-SHIFT-R", nil })
CCPKeybindDisplay:Refresh()
CCPKeybindDisplay:SetEntryOverride("CCP_FUTURE_RDPS", true)
visible = CCPKeybindDisplay:GetVisibleEntries()
assertEqual(containsAction(visible, "CCP_FUTURE_RDPS"), true, "binding added by a later CCP update is discovered on refresh")
assertEqual(CCPKeybindDisplay.entries[table.getn(CCPKeybindDisplay.entries)].label, "Future Ranged Command", "later CCP label is read dynamically")

print("RUNTIME_FUTURE_CCP_REFRESH=PASS")
