-- SavedVariables migration and corruption-resistance harness.

local addonPath = arg[1]
if not addonPath then error("addon path required") end
local GlobalTable = _G
function getglobal(name) return GlobalTable[name] end
function setglobal(name, value) GlobalTable[name] = value end
_G = nil

function GetNumBindings() return 0 end
function GetBinding() end
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

CCPKeybindDisplayDB = {
    categories = "broken",
    overrides = { CCP_START = "false", CCP_COME = true },
    showUnassigned = "yes",
    optionsAssignedOnly = "yes",
    showAllAssigned = "yes",
    visual = {
        visible = "yes",
        locked = 1,
        point = "BROKEN",
        relativePoint = "NOPE",
        x = "left",
        y = false,
        width = 0,
        alpha = 7,
        scale = -1,
        fontSize = 99,
        columns = 0,
        rowSpacing = -5,
        background = "no",
    },
}

assert(pcall(dofile, addonPath))
CCPKeybindDisplay:Initialize()

local function assertEqual(actual, expected, label)
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

assertEqual(type(CCPKeybindDisplay.db.categories), "table", "categories repaired")
assertEqual(CCPKeybindDisplay.db.categories.general, true, "general default restored")
assertEqual(CCPKeybindDisplay.db.categories.tank, false, "role default restored")
assertEqual(CCPKeybindDisplay.db.overrides.CCP_START, nil, "invalid override removed")
assertEqual(CCPKeybindDisplay.db.overrides.CCP_COME, true, "valid override preserved")
assertEqual(CCPKeybindDisplay.db.showUnassigned, false, "invalid assigned filter repaired")
assertEqual(CCPKeybindDisplay.db.optionsAssignedOnly, false, "invalid options-list filter repaired")
assertEqual(CCPKeybindDisplay.db.showAllAssigned, false, "invalid show-all mode repaired")
assertEqual(CCPKeybindDisplay.db.visual.visible, true, "visible repaired")
assertEqual(CCPKeybindDisplay.db.visual.locked, false, "locked repaired")
assertEqual(CCPKeybindDisplay.db.visual.point, "CENTER", "point repaired")
assertEqual(CCPKeybindDisplay.db.visual.relativePoint, "CENTER", "relative point repaired")
assertEqual(CCPKeybindDisplay.db.visual.x, 0, "x repaired")
assertEqual(CCPKeybindDisplay.db.visual.y, 0, "y repaired")
assertEqual(CCPKeybindDisplay.db.visual.width, 360, "command-key card width repaired")
assertEqual(CCPKeybindDisplay.db.visual.alpha, 0.78, "alpha repaired")
assertEqual(CCPKeybindDisplay.db.visual.scale, 1, "scale repaired")
assertEqual(CCPKeybindDisplay.db.visual.fontSize, 10, "font repaired")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "single command-key table repaired")
assertEqual(CCPKeybindDisplay.db.visual.rowSpacing, 0, "spacing repaired")
assertEqual(CCPKeybindDisplay.db.visual.background, true, "background repaired")
assertEqual(CCPKeybindDisplay.db.schemaVersion, 4, "schema version recorded")
assertEqual(CCPKeybindDisplay.db.minimap.visible, true, "minimap visibility repaired")
assertEqual(CCPKeybindDisplay.db.minimap.angle, 220, "minimap angle repaired")

CCPKeybindDisplay.db.visual.width = 319
CCPKeybindDisplay.db.visual.columns = 4
CCPKeybindDisplay:InitializeDatabase()
assertEqual(CCPKeybindDisplay.db.visual.width, 360, "saved card width below minimum is repaired")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "saved columns are repaired to one table")
CCPKeybindDisplay.db.visual.width = 320
CCPKeybindDisplay.db.visual.columns = 2
CCPKeybindDisplay:InitializeDatabase()
assertEqual(CCPKeybindDisplay.db.visual.width, 320, "valid card width survives repair")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "duplicate column state is repaired to one table")

CCPKeybindDisplayDB = {
    schemaVersion = 1,
    categories = { general = false },
    overrides = { CCP_START = false },
    showUnassigned = true,
    optionsAssignedOnly = true,
    visual = { visible = false, locked = true, point = "TOPLEFT", relativePoint = "TOPLEFT", x = 11, y = -22, width = 600, alpha = 0.5, scale = 1.2, fontSize = 14, columns = 2, rowSpacing = 3, background = false },
}
CCPKeybindDisplay:InitializeDatabase()
assertEqual(CCPKeybindDisplay.db.categories.general, false, "schema-one category choice survives migration")
assertEqual(CCPKeybindDisplay.db.overrides.CCP_START, false, "schema-one override survives migration")
assertEqual(CCPKeybindDisplay.db.visual.width, 360, "old visual width migrates to the compact card")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "old layout migrates to one command-key table")
assertEqual(CCPKeybindDisplay.db.optionsAssignedOnly, true, "schema-one list filter survives migration")
assertEqual(CCPKeybindDisplay.db.minimap.visible, true, "schema-one migration adds minimap defaults")
assertEqual(CCPKeybindDisplay.db.minimap.angle, 220, "schema-one migration adds default minimap angle")
CCPKeybindDisplay.db.minimap.visible = false
CCPKeybindDisplay.db.minimap.angle = 123
CCPKeybindDisplay:InitializeDatabase()
assertEqual(CCPKeybindDisplay.db.minimap.visible, false, "valid minimap visibility survives repair")
assertEqual(CCPKeybindDisplay.db.minimap.angle, 123, "valid minimap angle survives repair")

CCPKeybindDisplayDB = {
    schemaVersion = 4,
    categories = { general = true },
    overrides = {},
    showUnassigned = false,
    optionsAssignedOnly = false,
    showAllAssigned = true,
    visual = { visible = true, locked = false, point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 420, alpha = 0.8, scale = 1, fontSize = 11, columns = 4, rowSpacing = 2, background = true },
}
CCPKeybindDisplay:InitializeDatabase()
assertEqual(CCPKeybindDisplay.db.showAllAssigned, true, "show-all mode survives logout-login repair")
assertEqual(CCPKeybindDisplay.db.visual.width, 420, "current card width survives logout-login repair")
assertEqual(CCPKeybindDisplay.db.visual.columns, 1, "current layout remains one command-key table")

print("RUNTIME_MIGRATION=PASS")
