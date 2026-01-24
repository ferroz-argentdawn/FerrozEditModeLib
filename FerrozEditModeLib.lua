FerrozEditModeLib = {}
FerrozEditModeLib.registeredFrames = {}
FerrozEditModeLib.DebugMode = false

function FerrozEditModeLib:Log(...)
    if not self.DebugMode then return end

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
            -- If formatting fails (wrong tags), just join them like print()
            msg = table.concat({tostringall(...)}, " ")
        end
    else
        -- Otherwise, just join everything with spaces (like the real print)
        msg = table.concat({tostringall(...)}, " ")
    end

    print("|cff00ff00[FerrozLib]|r " .. msg)
end

function FerrozEditModeLib:SetDirty()
    if not EditModeManagerFrame or EditModeManagerFrame.layoutApplyInProgress then return end

    -- The brute force flag
    EditModeManagerFrame.hasActiveChanges = true
    EditModeManagerFrame.SaveChangesButton:SetEnabled(true)
    EditModeManagerFrame.RevertAllChangesButton:SetEnabled(true)
end

function FerrozEditModeLib:GetCurrentLayoutName()
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

function FerrozEditModeLib:ApplyLayout(frame)
    local layoutName = self:GetCurrentLayoutName()
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

function FerrozEditModeLib:ResetPosition(frame)
    local layoutName = self:GetCurrentLayoutName()
    local settingsTable = frame.settingsTable
    if settingsTable.layouts then
        settingsTable.layouts[layoutName] = nil
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetScale(1.0)
end

-- The Registration Core
function FerrozEditModeLib:Register(frame, settingsTable, onEnter, onExit)
    frame.settingsTable = settingsTable
    frame.isEditing = false
    settingsTable.layouts = settingsTable.layouts or {}

    self:ApplyLayout(frame)

    local function SnapshotRevertPosition()
        local point, relFrame, rel, x, y = frame:GetPoint()
        FerrozEditModeLib:Log("Snapshotting revert position " .. (frame:GetName() or "Unknown") .. " - " .. FerrozEditModeLib:GetCurrentLayoutName())
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
        local lName = FerrozEditModeLib:GetCurrentLayoutName()
        FerrozEditModeLib:Log(string.format("Snapshotting current position (pre) %s - %s: X=%.2f, Y=%.2f", lName, (frame:GetName() or "Unknown"), x, y))
        frame.currentPositionState = {
            layoutName = lName,
            point = point,
            relativeFrame = relFrame,
            relativePoint = rel,
            xOfs = x,
            yOfs = y,
            scale = frame:GetScale()
        }
        FerrozEditModeLib:Log(string.format("Snapshotting current position (post) %s - %s: X=%.2f, Y=%.2f", lName, (frame:GetName() or "Unknown"), frame.currentPositionState.xOfs, frame.currentPositionState.yOfs))
    end

    -- Internal function to save current state to the active layout
    local function SaveCurrentPosition()
        local cp = frame.currentPositionState
        if not cp then return end -- Nothing new to save
        
        local layoutName = (cp and cp.layoutName) or FerrozEditModeLib:GetCurrentLayoutName()
        local relativeFrameName = (cp.relativeFrame and cp.relativeFrame.GetName and cp.relativeFrame:GetName()) or "UIParent"
        FerrozEditModeLib:Log(string.format("Saving %s - %s: X=%.2f, Y=%.2f", layoutName, (frame:GetName() or "Unknown"), cp.xOfs, cp.yOfs))
        
        frame.settingsTable.layouts[layoutName] = {
            point = cp.point,
            relativePoint = cp.relativePoint,
            relativeFrame = relativeFrameName,
            xOfs = cp.xOfs,
            yOfs = cp.yOfs,
            scale = cp.scale
        }
    end

    local function RevertPosition()
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
            FerrozEditModeLib:SetDirty()
            SnapshotCurrentPosition()
        end
    end)

    -- 2. Drag Logic
    frame:SetScript("OnDragStart", function(self) 
        if self.isEditing then self:StartMoving() end 
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        FerrozEditModeLib:SetDirty()
        SnapshotCurrentPosition()
    end)

    -- 3. Blizzard Handshake (EventRegistry)
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if InCombatLockdown() then return end
        FerrozEditModeLib:ApplyLayout(frame)
        frame.isEditing = true
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        SnapshotRevertPosition()
        if onEnter then onEnter(frame) end
    end)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if frame.isEditing then
            frame:StopMovingOrSizing()
        end
        frame.isEditing = false
        frame:EnableMouse(false)
        frame:SetMovable(false)
        
        if onExit then onExit(frame) end
    end)

    frame.SaveCurrentPosition = SaveCurrentPosition
    frame.RevertPosition = RevertPosition
    frame.SnapshotRevertPosition = SnapshotRevertPosition
    frame.SnapshotCurrentPosition = SnapshotCurrentPosition

    -- Add to the library's internal tracker
    table.insert(FerrozEditModeLib.registeredFrames, frame)

end

if not FerrozEditModeLib.HooksInitialized then
    hooksecurefunc(EditModeManagerFrame, "SelectLayout", function(self, layoutInfo)
        RunNextFrame(function()
            FerrozEditModeLib:Log("hooksecurefunc(EditModeManagerFrame, OnLayoutSelected")
            for _, f in ipairs(FerrozEditModeLib.registeredFrames or {}) do
                -- 1. Move frame to its position in the NEW layout
                if f.settingsTable then
                    FerrozEditModeLib:ApplyLayout(f)
                end

                -- 2. If we are in Edit Mode, take a fresh snapshot of the new layout
                -- Only do this if there isn't a pending unsaved session.
                if f.isEditing and not f.revertPositionState and f.SnapshotRevertPosition then
                    f:SnapshotRevertPosition()
                end
                
                -- 3. Trigger the optional callback
                if f.onLayoutSelectedCallback then
                    f.onLayoutSelectedCallback(f)
                end
            end
        end)
    end)

    hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
        FerrozEditModeLib:Log("Manager SaveLayouts detected!")
        RunNextFrame(function()
            for _, f in ipairs(FerrozEditModeLib.registeredFrames) do
                f:SaveCurrentPosition()      -- Save to its specific table
                f.revertPositionState = nil -- Clear the 'undo' memory
            end 
        end)
    end)

    -- This catches Golden Button AND the "Discard" button on the Popup
    hooksecurefunc(EditModeManagerFrame, "RevertAllChanges", function()
        FerrozEditModeLib:Log("Revert All changes")
        if EditModeManagerFrame.isSaving then return end 
    
        for _, f in ipairs(FerrozEditModeLib.registeredFrames or {}) do
            if f.revertPositionState and f.RevertPosition then
                f:RevertPosition()
                f.revertPositionState = nil -- Session ended by discard
            end
        end
    end)

    EditModeManagerFrame.RevertAllChangesButton:HookScript("OnClick", function()
        FerrozEditModeLib:Log("Physical Revert Button Clicked")
        for _, f in ipairs(FerrozEditModeLib.registeredFrames or {}) do
            if f.revertPositionState and f.RevertPosition then
                f:RevertPosition()
                f.revertPositionState = nil -- Session ended by discard
            end
        end
    end)

    FerrozEditModeLib.HooksInitialized = true
end