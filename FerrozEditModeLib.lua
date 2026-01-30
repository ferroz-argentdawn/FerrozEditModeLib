local addonName = ... 
local versionString = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"
local major, minor, patch = string.match(versionString, "(%d+)%.(%d+)%.(%d+)")
local LIB_VERSION = (tonumber(major) * 10000) + (tonumber(minor) * 100) + tonumber(patch)
local LIB_NAME = "FerrozEditModeLib-1.0"
local lib = LibStub:NewLibrary(LIB_NAME, LIB_VERSION)
if not lib then return end --Guard, already loaded

lib.registeredFrames = {}
lib.selectionOverlay = nil
lib.DEBUG_MODE = false
lib.DEFAULT_PADDING = 4 -- Constant

--constants
local STRATA_TABLE = {
    ["BACKGROUND"] = "LOW",
    ["LOW"] = "MEDIUM",
    ["MEDIUM"] = "HIGH",
    ["HIGH"] = "DIALOG",
    ["DIALOG"] = "FULLSCREEN",
}

function lib:Log(...)
    if not self.DEBUG_MODE then return end

    local n = select("#", ...)
    if n == 0 then return end

    local first = select(1, ...)
    local msg
    
    -- If the first arg is a string and there are more args, assume string.format
    if type(first) == "string" and n > 1 then
        local success, formatted = pcall(string.format, ...)
        if success then
            msg = formatted
        else
            msg = table.concat({tostringall(...)}, " ")
        end
    else
        msg = table.concat({tostringall(...)}, " ")
    end

    print("|cff00ff00[FerrozLib]|r " .. msg)
end

function lib:AnnounceInit()
    --todo
end

function lib:SetDirty()
    if not EditModeManagerFrame or EditModeManagerFrame.layoutApplyInProgress then return end

    -- The brute force flag
    EditModeManagerFrame.hasActiveChanges = true
    EditModeManagerFrame.SaveChangesButton:SetEnabled(true)
    EditModeManagerFrame.RevertAllChangesButton:SetEnabled(true)
end

function lib:GetCurrentLayoutName()
    if not C_EditMode or type(C_EditMode.GetLayouts) ~= "function" then 
        return "Default" 
    end

    local layoutData = C_EditMode.GetLayouts()
    if not layoutData or not layoutData.layouts then 
        return "Default" 
    end

    local activeIdx = layoutData.activeLayout
    -- presets, hard coded as 1 and 2
    if activeIdx == 1 then
        return HUD_EDIT_MODE_PRESET_MODERN or "Modern"
    elseif activeIdx ==  2 then
        return HUD_EDIT_MODE_PRESET_CLASSIC or "Classic"
    end
    --user layouts, these are offset by 2, the number of presets.  Unfortunately we can't get that dynamically
    if activeIdx then
        local directMatch = layoutData.layouts[activeIdx-2]
        if directMatch and directMatch.layoutName then
            return directMatch.layoutName
        end
    end
    return "Default"
end 

function lib:ApplyLayout(frame)
    frame.isDirty = false
    local layoutName = self:GetCurrentLayoutName()
    lib:Log("lib:ApplyLayout: " .. (frame:GetName() or "Unknown") .. " - " .. layoutName)
    local settingsTable = frame.settingsTable
    local s = settingsTable.layouts and settingsTable.layouts[layoutName]

    if s then
        local relativeTo = (s.relativeFrame and _G[s.relativeFrame]) or UIParent
        frame:ClearAllPoints()
        frame:SetPoint(s.point, relativeTo, s.relativePoint, s.xOfs, s.yOfs)
        frame:SetScale(s.scale or 1.0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER")
        frame:SetScale(1.0)
    end
end

function lib:ResetPosition(frame)
    local layoutName = self:GetCurrentLayoutName()
    local settingsTable = frame.settingsTable
    if settingsTable.layouts then
        settingsTable.layouts[layoutName] = nil
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetScale(1.0)
end

--Selection
-- Add this helper to your lib
function lib:GetSelectionOverlay()
    if not self.selectionOverlay then
        local f = CreateFrame("Frame", "FerrozSelectionOverlay", UIParent, "BackdropTemplate")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        f:SetBackdropBorderColor(0.973, 0.851, 0.263, .8)
        f:SetBackdropColor(0.5, 0.4, 0, 0.3)
        f:SetMouseClickEnabled(false)
        f:SetPropagateMouseClicks(true)
        self.selectionOverlay = f
    end
    return self.selectionOverlay
end

function lib:AttachOverlay(targetFrame)
    local overlay = self:GetSelectionOverlay()
    overlay:SetParent(targetFrame)
    local currentStrata = targetFrame:GetFrameStrata()
    overlay:SetFrameStrata(STRATA_TABLE[currentStrata] or "TOOLTIP")
    overlay:SetFrameLevel(100)
    overlay:ClearAllPoints()
    local pad = self.DEFAULT_PADDING
    overlay:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -pad, pad)
    overlay:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", pad, -pad)
    overlay:Show()
end

-- The Registration Core
function lib:Register(frame, settingsTable)
    frame.settingsTable = settingsTable
    frame.isEditing = false
    frame.isDirty = false
    settingsTable.layouts = settingsTable.layouts or {}
    Mixin(frame, EditModeSystemMixin)
    frame.systemIndex = Enum.EditModeSystem.UnitFrame 
    if(frame.systemName == nil) then
        frame.systemName = frame:GetName() or frame:GetDebugName()
    end
    lib:Log(frame.systemName)

    RunNextFrame(function()
        lib:ApplyLayout(frame)
    end)

    local function SnapshotRevertPosition()
        local point, relFrame, rel, x, y = frame:GetPoint()
        lib:Log("Snapshotting revert position " .. (frame:GetName() or "Unknown") .. " - " .. lib:GetCurrentLayoutName())
        frame.revertPositionState = {
            point = point,
            relativeFrame = relFrame,
            relativePoint = rel,
            xOfs = x,
            yOfs = y,
            scale = frame:GetScale()
        }
    end

    local function SnapshotCurrentPosition()
        local point, relFrame, rel, x, y = frame:GetPoint()
        local lName = lib:GetCurrentLayoutName()
        lib:Log(string.format("Snapshotting current position (pre) %s - %s: X=%.2f, Y=%.2f", lName, (frame:GetName() or "Unknown"), x, y))
        frame.currentPositionState = {
            layoutName = lName,
            point = point,
            relativeFrame = relFrame,
            relativePoint = rel,
            xOfs = x,
            yOfs = y,
            scale = frame:GetScale()
        }
        lib:Log(string.format("Snapshotting current position (post) %s - %s: X=%.2f, Y=%.2f", lName, (frame:GetName() or "Unknown"), frame.currentPositionState.xOfs, frame.currentPositionState.yOfs))
    end

    -- Internal function to save current state to the active layout
    local function SaveCurrentPosition()
        if frame and not frame.isDirty then return end
        local cp = frame.currentPositionState
        if not cp then return end -- Nothing new to save
        
        local layoutName = (cp and cp.layoutName) or lib:GetCurrentLayoutName()
        local relFrame = cp.relativeFrame
        local relativeFrameName = (type(relFrame) == "table" and relFrame.GetName) and relFrame:GetName() or (type(relFrame) == "string" and relFrame) or "UIParent"
        lib:Log(string.format("Saving %s - %s: X=%.2f, Y=%.2f", layoutName, (frame:GetName() or "Unknown"), cp.xOfs, cp.yOfs))
        
        frame.settingsTable.layouts[layoutName] = {
            point = cp.point,
            relativePoint = cp.relativePoint,
            relativeFrame = relativeFrameName,
            xOfs = cp.xOfs,
            yOfs = cp.yOfs,
            scale = cp.scale
        }
        SnapshotRevertPosition()
    end

    local function RevertPosition()
        if frame and not frame.isDirty then return end
        local op = frame.revertPositionState
        if(op) then
            frame:ClearAllPoints() -- Always clear before re-anchoring
            frame:SetPoint(op.point, op.relativeFrame, op.relativePoint, op.xOfs, op.yOfs)
            frame:SetScale(op.scale)
        end
    end

    -- 1. Scaling Logic
    frame:SetScript("OnMouseWheel", function(self, delta)
        if self.isEditing then
            local centerX, centerY = self:GetCenter()
            local oldScale = self:GetScale()
            local newScale = math.max(0.4, math.min(2.5, oldScale + (delta * 0.05)))
            self:SetScale(newScale)
            if centerX and centerY then
                self:ClearAllPoints()
                self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (centerX * oldScale) / newScale, (centerY * oldScale) / newScale)
            end
            self.isDirty = true
            lib:SetDirty()
            SnapshotCurrentPosition()
        end
    end)

    -- 2. Drag Logic
    frame:SetScript("OnDragStart", function(self) 
        if self.isEditing then self:StartMoving() end 
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDirty = true
        lib:SetDirty()
        SnapshotCurrentPosition()
    end)
    frame:HookScript("OnMouseDown", function(self, button)
        if self.isEditing and button == "LeftButton" then
            lib:AttachOverlay(self)
        end
    end)

    -- 3. Blizzard Handshake (EventRegistry)
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if InCombatLockdown() then return end
        lib:ApplyLayout(frame)
        frame.isEditing = true
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        SnapshotRevertPosition()
        if frame.EditModeStartMock then frame:EditModeStartMock()
        else
            lib:Log("start else" .. frame:GetName())
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if frame.isEditing then
            frame:StopMovingOrSizing()
        end
        frame.isEditing = false
        frame:EnableMouse(false)
        frame:SetMovable(false)
        if frame.EditModeStopMock then frame:EditModeStopMock()
        else
            lib:Log("stop else" .. frame:GetName())
        end
        if lib.selectionOverlay then
            lib.selectionOverlay:Hide()
            lib.selectionOverlay:SetParent(UIParent)
            lib.selectionOverlay:SetFrameStrata("DIALOG")
        end
    end)

    frame.SaveCurrentPosition = SaveCurrentPosition
    frame.RevertPosition = RevertPosition
    frame.SnapshotRevertPosition = SnapshotRevertPosition
    frame.SnapshotCurrentPosition = SnapshotCurrentPosition

    -- Add to the library's internal tracker
    table.insert(lib.registeredFrames, frame)

end

if not lib.HooksInitialized then
    hooksecurefunc(EditModeManagerFrame, "SelectLayout", function(self, layoutInfo)
        RunNextFrame(function()
            lib:Log("hooksecurefunc(EditModeManagerFrame, OnLayoutSelected")
            for _, f in ipairs(lib.registeredFrames or {}) do
                -- 1. Move frame to its position in the NEW layout
                if f.settingsTable then
                    lib:ApplyLayout(f)
                end
            end
        end)
    end)

    hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
        lib:Log("Manager SaveLayouts detected!")
        for _, f in ipairs(lib.registeredFrames) do
            f:SaveCurrentPosition()      -- Save to its specific table
        end
    end)

    -- This catches Golden Button AND the "Discard" button on the Popup
    hooksecurefunc(EditModeManagerFrame, "RevertAllChanges", function()
        lib:Log("Revert All changes")
        if EditModeManagerFrame.isSaving then return end 
    
        for _, f in ipairs(lib.registeredFrames or {}) do
            if f.revertPositionState and f.RevertPosition then
                f:RevertPosition()
            end
        end
    end)

    if EditModeManagerFrame.RevertAllChangesButton then
        EditModeManagerFrame.RevertAllChangesButton:HookScript("OnClick", function()
            lib:Log("Physical Revert Button Clicked")
            for _, f in ipairs(lib.registeredFrames or {}) do
                if f.revertPositionState and f.RevertPosition then
                    f:RevertPosition()
                end
            end
        end)
    end

    lib.HooksInitialized = true
end