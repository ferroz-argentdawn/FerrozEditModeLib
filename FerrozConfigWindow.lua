local addonName, ns = ...
local lib = LibStub:GetLibrary("FerrozEditModeLib-1.0")

lib.CONFIG_FRAME_WIDTH = 400
lib.CONFIG_FRAME_HALF_WIDTH = lib.CONFIG_FRAME_WIDTH / 2
lib.CONFIG_FRAME_HEIGHT = 300
lib.CONFIG_FRAME_PADDING = 10
lib.CONFIG_EDIT_BOX_WIDTH = 145 --I think technically this gets ignored
lib.CONFIG_EDIT_BOX_HEIGHT = 26
lib.CONFIG_ROW_HEIGHT = 30
lib.CONFIG_ROW_LABEL_WIDTH = 45
lib.ANCHOR_POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
}
-- rounds toward zero regardless of positive or negative
function lib:RoundCoordinates(num)
    local val = (num > 0) and math.floor(num) or math.ceil(num)
    return tostring(val)
end

function lib:AddElementRow(container, content)
    container.nextIndex = (container.nextIndex or 0) + 1
    local row = CreateFrame("Frame", nil, container)
    row:SetSize(lib.CONFIG_FRAME_WIDTH, lib.CONFIG_ROW_HEIGHT)
    row.layoutIndex = container.nextIndex

    if content then
        content:SetParent(row)
        content:SetAllPoints(row)
    end
    return row
end

function lib:CreateLabelElementPair(container, labelText, element, width)
    local row = CreateFrame("Frame", nil, container)
    row:SetSize(width, lib.CONFIG_ROW_HEIGHT)
    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Label:SetSize(lib.CONFIG_ROW_LABEL_WIDTH, lib.CONFIG_ROW_HEIGHT)
    row.Label:SetPoint("LEFT", row, "LEFT", lib.CONFIG_FRAME_PADDING, 0)
    row.Label:SetText(labelText)
    row.Label:SetJustifyH("LEFT")
    if element then
        element:SetParent(row)
        element:ClearAllPoints()
        element:SetPoint("LEFT", row.Label, "RIGHT", lib.CONFIG_FRAME_PADDING, 0)
        element:SetPoint("RIGHT", row, "RIGHT", -lib.CONFIG_FRAME_PADDING, 0)
    end
    return row
end

function lib:AddLabelElementRow(container, labelText, element)
    local row = lib:CreateLabelElementPair(container, labelText, element, lib.CONFIG_FRAME_WIDTH)
    return lib:AddElementRow(container, row)
end
function lib:AddHR(container)
    local element = CreateFrame("Frame")
    element:SetSize(lib.CONFIG_FRAME_WIDTH, 1) 
    local texture = element:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    local r, g, b = lib.FERROZ_COLOR:GetRGB()
    texture:SetColorTexture(r, g, b, 0.4)
    local row = lib:AddElementRow(container, element)
    row:SetHeight(4) -- Give the HR row a smaller vertical footprint
    return row
end

function lib:GetOrCreateConfigFrame()
    if not self.configFrame then
        local f = CreateFrame("Frame", "FerrozEditConfigFrame", UIParent, "BackdropTemplate")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:SetFrameLevel(100)
        f:SetClampedToScreen(true)
        f:SetSize(lib.CONFIG_FRAME_WIDTH, lib.CONFIG_FRAME_HEIGHT)
        f:SetPoint("RIGHT", UIParent, "RIGHT", -100, 0)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8", -- A solid 1px-capable line
            tile = true, tileSize = 16, edgeSize = 1,    -- 1px edge for a modern look
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        f:SetBackdropBorderColor(0, 0, 0, 1) -- Pure black thin border
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.9) -- Dark grey satin feel
        --title
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", 0, -lib.CONFIG_FRAME_PADDING)
        f.title:SetText("Frame Settings")
        --close button
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
        --flex container, vertical layout
        f.flexContainer = CreateFrame("Frame", nil, f, "VerticalLayoutFrame")
        f.flexContainer.fixedWidth = lib.CONFIG_FRAME_WIDTH
        f.flexContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -f.title:GetHeight() - 2*lib.CONFIG_FRAME_PADDING)
        f.flexContainer:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -f.title:GetHeight() - 2*lib.CONFIG_FRAME_PADDING)
        f.flexContainer.spacing = 5

        --add standard elements
        f.widthControl = lib:CreateSliderRow(f.flexContainer, "Width", "width", lib.MIN_WIDTH, lib.MAX_WIDTH, lib.SIZE_STEP)
        f.heightControl = lib:CreateSliderRow(f.flexContainer, "Height", "height", lib.MIN_HEIGHT, lib.MAX_HEIGHT, lib.SIZE_STEP)
        f.scaleControl = lib:CreateSliderRow(f.flexContainer, "Scale", "scale", lib.MIN_SCALE, lib.MAX_SCALE, lib.SCALE_STEP)
        f.xControl,f.yControl = lib:CreateXYControls(f.flexContainer)
        f.sourceFrame, f.sourcePoint = lib:CreateFrameAnchorControls(f.flexContainer)
        f.relativeFrame, f.relativePoint = lib:CreateRelativeFrameAnchorControls(f.flexContainer)

        f.targetFrameFlexContainer = CreateFrame("Frame", nil, f.flexContainer, "VerticalLayoutFrame")
        f.flexContainer.nextIndex = (f.flexContainer.nextIndex or 0) + 1
        f.targetFrameFlexContainer.layoutIndex = f.flexContainer.nextIndex
        f.targetFrameFlexContainer:SetPoint("LEFT")
        f.targetFrameFlexContainer:SetPoint("RIGHT")
        f.revertBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.revertBtn:SetHeight(lib.CONFIG_EDIT_BOX_HEIGHT)
        f.revertBtn:SetText("Revert Changes")
        f.revertBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", lib.CONFIG_FRAME_PADDING , lib.CONFIG_FRAME_PADDING)
        f.revertBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -lib.CONFIG_FRAME_PADDING, lib.CONFIG_FRAME_PADDING)
        f.revertBtn:SetScript("OnClick", function() lib:RevertState(f.target) end)

        f.resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.resetBtn:SetHeight(lib.CONFIG_EDIT_BOX_HEIGHT)
        f.resetBtn:SetText("Reset to Default")
        f.resetBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -lib.CONFIG_FRAME_PADDING, lib.CONFIG_FRAME_PADDING)
        f.resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", lib.CONFIG_FRAME_PADDING, lib.CONFIG_FRAME_PADDING)
        f.resetBtn:SetScript("OnClick", function() lib:ResetState(f.target) end)
        f:Hide()
        self.configFrame = f
    end
    return self.configFrame
end
function lib:ShowConfigForFrame(targetFrame)
    --if not lib.DEBUG_MODE then return end
    local config = self:GetOrCreateConfigFrame()
    config.target = targetFrame
    config.title:SetText(targetFrame.systemName or "Frame Settings")
    --standard elements
    if targetFrame.workingState then
        local ws = targetFrame.workingState
        if config.widthControl then config.widthControl.slider:SetValue(ws.width or targetFrame:GetWidth()) end
        if config.heightControl then config.heightControl.slider:SetValue(ws.height or targetFrame:GetHeight()) end
        if config.scaleControl then config.scaleControl.slider:SetValue(ws.scale or 1) end
        if config.xControl then config.xControl:SetText(lib:RoundCoordinates(ws.xOfs)) end
        if config.yControl then config.yControl:SetText(lib:RoundCoordinates(ws.yOfs)) end
        if config.sourceFrame then config.sourceFrame:SetText(targetFrame:GetName() or "Unnamed") end
        if config.sourcePoint then config.sourcePoint:SetText(ws.point or "CENTER") end
        if config.relativeFrame then config.relativeFrame:SetText(ws.relativeTo or "UIParent") end
        if config.relativePoint then config.relativePoint:SetText(ws.relativePoint or "CENTER") end
    end
    --todo targetFrameFlexContainer if there is anything there 
    if targetFrame.isDirty then config.revertBtn:Enable() else config.revertBtn:Disable() end

    -- INTELLIGENT POSITIONING 
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local centerX, centerY = targetFrame:GetCenter()

    if centerX and centerY then
        config:ClearAllPoints()
        -- Determine Horizontal side (if on left, show on right)
        local point = (centerX > screenWidth / 2) and "RIGHT" or "LEFT"
        local relPoint = (point == "LEFT") and "RIGHT" or "LEFT"
        -- Determine Vertical side (if on top, show on bottom)
        local vPoint = (centerY > screenHeight / 2) and "TOP" or "BOTTOM"
        -- Combine them (e.g., "TOPLEFT")
        local finalPoint = vPoint .. point
        local finalRelPoint = vPoint .. relPoint
        -- Offset slightly (e.g., 10px away) so it doesn't touch the frame
        local xOfs = (point == "LEFT") and 10 or -10
        config:SetPoint(finalPoint, targetFrame, finalRelPoint, xOfs, 0)
    else
        -- Fallback if frame isn't rendered
        config:ClearAllPoints()
        config:SetPoint("CENTER", UIParent, "CENTER")
    end

    config:SetAlpha(0)
    config:Show()
    config.flexContainer:Layout()
    config:SetAlpha(1)
end
function lib:ClearConfigMenu()
    local config = self:GetOrCreateConfigFrame()
    config:Hide()
    config.target = nil
    config:SetParent(UIParent)
    config:SetFrameStrata("DIALOG")
    --todo unhook binding handlers
end

function lib:CreateSliderRow(container, label, key, minValue, maxValue, step, onUpdateCallback)
    local wrapper = CreateFrame("Frame")
    wrapper:SetSize(lib.CONFIG_FRAME_WIDTH-lib.CONFIG_FRAME_PADDING - lib.CONFIG_ROW_LABEL_WIDTH, lib.CONFIG_ROW_HEIGHT)
    --Edit Box
    local eb = CreateFrame("EditBox", nil, wrapper, "InputBoxTemplate")
    eb:SetSize(40, lib.CONFIG_ROW_HEIGHT)
    eb:SetPoint("RIGHT", wrapper, "RIGHT", 0, 0)
    eb:SetAutoFocus(false)
    --Slider
    local slider = CreateFrame("Slider", nil, wrapper, "MinimalSliderTemplate")
    slider:SetPoint("LEFT", wrapper, "LEFT", lib.CONFIG_FRAME_PADDING, 0)
    slider:SetPoint("RIGHT", eb, "LEFT", -lib.CONFIG_FRAME_PADDING, 0)
    --slider:SetWidth(140)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    --attach to wrapper so we can programatically access them later intelligently
    wrapper.slider = slider
    wrapper.editBox = eb
    
    -- Sync: Slider -> Proxy
    slider:SetScript("OnValueChanged", function(self, value)
        local formatStr = (step < 1) and "%.2f" or "%d"
        eb:SetText(string.format(formatStr, value))
        local config = lib:GetOrCreateConfigFrame()
        if config.target and config.target.workingState then
            config.target.workingState[key] = value
        end
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.min(maxValue, math.max(minValue, val))
            slider:SetValue(val)
        end
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        local value = slider:GetValue()
        local formatStr = (step < 1) and "%.2f" or "%d"
        self:SetText(string.format(formatStr, value))
    end)

    lib:AddLabelElementRow(container, label, wrapper)
    return wrapper
end

function lib:RefreshConfigUI(frame)
    local f = self.configFrame
    -- Check if we are actually looking at this frame right now
    if f and f:IsShown() and f.target == frame then
        local ws = frame.workingState
        -- Update Scale
        if f.scaleControl and ws.scale then
            f.scaleControl.slider:SetValue(ws.scale)
        end
        -- Update Width/Height if you have them
        if f.widthControl and ws.width then
            f.widthControl.slider:SetValue(ws.width)
        end
        if f.heightControl and ws.height then
            f.heightControl.slider:SetValue(ws.height)
        end
        if f.xControl and not f.xControl:HasFocus() then
            f.xControl:SetText(lib:RoundCoordinates(ws.xOfs or 0))
        end
        if f.yControl and not f.yControl:HasFocus() then
            f.yControl:SetText(lib:RoundCoordinates(ws.yOfs or 0))
        end
        f.sourceFrame:SetText(frame:GetName() or "Unnamed Frame")
        if f.sourcePoint then
            f.sourcePoint:SetText(ws.point or "CENTER")
        end

        f.relativeFrame:SetText(ws.relativeTo or "UIParent")
        if f.relativePoint then 
            f.relativePoint:SetText(ws.relativePoint or "CENTER")
        end

        if f.revertBtn then
            if frame.isDirty then
                f.revertBtn:Enable()
            else
                f.revertBtn:Disable()
            end
        end
    end
end

function lib:CreateXYControls(container)
    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetSize(lib.CONFIG_FRAME_WIDTH, lib.CONFIG_ROW_HEIGHT)
    --X
    local xBox = CreateFrame("EditBox", nil, wrapper, "InputBoxTemplate")
    xBox:SetSize(lib.CONFIG_EDIT_BOX_WIDTH, lib.CONFIG_ROW_HEIGHT)
    xBox:SetAutoFocus(false)
    local xPair = lib:CreateLabelElementPair(wrapper,"X",xBox,lib.CONFIG_FRAME_HALF_WIDTH)
    xPair:SetPoint("LEFT", wrapper, "LEFT", 0, 0)
    --Y
    local yBox = CreateFrame("EditBox", nil, wrapper, "InputBoxTemplate")
    yBox:SetSize(lib.CONFIG_EDIT_BOX_WIDTH, lib.CONFIG_ROW_HEIGHT)
    yBox:SetAutoFocus(false)
    local yPair = lib:CreateLabelElementPair(wrapper,"Y",yBox,lib.CONFIG_FRAME_HALF_WIDTH)
    yPair:SetPoint("LEFT", xPair, "RIGHT", 0, 0)
    --local scripts
    local function UpdateCoords()
        local config = lib:GetOrCreateConfigFrame()
        if config.target and config.target.workingState then
            config.target.workingState.xOfs = tonumber(xBox:GetText()) or 0
            config.target.workingState.yOfs = tonumber(yBox:GetText()) or 0
        end
    end
    local function OnCancel()
        local config = lib:GetOrCreateConfigFrame()
        if config.target then lib:RefreshConfigUI(config.target) end
    end
    --set Scripts
    xBox:SetScript("OnEnterPressed", function(self) UpdateCoords(); self:ClearFocus() end)
    yBox:SetScript("OnEnterPressed", function(self) UpdateCoords(); self:ClearFocus() end)
    xBox:SetScript("OnEditFocusLost", OnCancel)
    yBox:SetScript("OnEditFocusLost", OnCancel)

    lib:AddElementRow(container, wrapper)
    return xBox, yBox
end

function lib:CreateFrameAnchorControls(container)
    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetSize(lib.CONFIG_FRAME_WIDTH, lib.CONFIG_ROW_HEIGHT)

    -- Control 1: Read-only Frame Name
    local nameBox = CreateFrame("EditBox", nil, wrapper, "InputBoxTemplate")
    nameBox:SetSize(lib.CONFIG_EDIT_BOX_WIDTH, lib.CONFIG_EDIT_BOX_HEIGHT)
    nameBox:SetAutoFocus(false)
    nameBox:SetEnabled(false)
    nameBox:SetFontObject("GameFontDisable")
    nameBox:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)

    -- Control 2: Anchor Point Dropdown
    local pointDrop = lib:CreateAnchorDropdown(wrapper, "point")

    local namePair = lib:CreateLabelElementPair(wrapper, "Self", nameBox, lib.CONFIG_FRAME_HALF_WIDTH)
    local pointPair = lib:CreateLabelElementPair(wrapper, "Point", pointDrop, lib.CONFIG_FRAME_HALF_WIDTH)

    namePair:SetPoint("LEFT", wrapper, "LEFT", 0, 0)
    pointPair:SetPoint("LEFT", namePair, "RIGHT", 0, 0)

    lib:AddElementRow(container, wrapper)
    return nameBox, pointDrop
end

function lib:CreateRelativeFrameAnchorControls(container)
    local wrapper = CreateFrame("Frame", nil, container)
    wrapper:SetSize(lib.CONFIG_FRAME_WIDTH, lib.CONFIG_ROW_HEIGHT)

    -- Control 1: Relative To (The target frame name)
    local relToBox = CreateFrame("EditBox", nil, wrapper, "InputBoxTemplate")
    relToBox:SetSize(lib.CONFIG_EDIT_BOX_WIDTH, lib.CONFIG_EDIT_BOX_HEIGHT)
    relToBox:SetAutoFocus(false)
    relToBox:SetEnabled(false)
    relToBox:SetFontObject("GameFontDisable")
    relToBox:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)
    
    -- Control 2: Relative Point Dropdown
    local relPointDrop = lib:CreateAnchorDropdown(wrapper, "relativePoint")

    local toPair = lib:CreateLabelElementPair(wrapper, "To", relToBox, lib.CONFIG_FRAME_HALF_WIDTH)
    local relPointPair = lib:CreateLabelElementPair(wrapper, "At", relPointDrop, lib.CONFIG_FRAME_HALF_WIDTH)

    toPair:SetPoint("LEFT", wrapper, "LEFT", 0, 0)
    relPointPair:SetPoint("LEFT", toPair, "RIGHT", 0, 0)

    -- Input Logic for the "To" Box
    relToBox:SetScript("OnEnterPressed", function(self)
        local config = lib:GetOrCreateConfigFrame()
        if config.target and config.target.workingState then
            config.target.workingState.relativeTo = self:GetText()
        end
        self:ClearFocus()
    end)

    lib:AddElementRow(container, wrapper)
    return relToBox, relPointDrop
end

function lib:CreateAnchorDropdown(container, key)
    -- Creating a sleek, modern button instead of the old-style dropdown
    local dropdown = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    dropdown:SetSize(lib.CONFIG_EDIT_BOX_WIDTH, lib.CONFIG_EDIT_BOX_HEIGHT)
    dropdown:SetAutoFocus(false)
    dropdown:EnableMouse(false)
    dropdown:SetAutoFocus(false)
    
    local clicker = CreateFrame("Button", nil, dropdown)
    clicker:SetAllPoints(dropdown)
    clicker:EnableMouse(true)
    clicker:RegisterForClicks("LeftButtonUp")
    clicker:SetScript("OnClick", function()
        local library = lib
        MenuUtil.CreateContextMenu(dropdown, function(owner, rootDescription)
            rootDescription:CreateTitle("Select Anchor Point")
            for _, point in ipairs(library.ANCHOR_POINTS) do
                rootDescription:CreateButton(point, function()
                    dropdown:SetText(point) -- Uses EditBox:SetText
                    
                    local cfg = library:GetOrCreateConfigFrame()
                    if cfg and cfg.target and cfg.target.workingState then
                        cfg.target.workingState[key] = point
                    end
                end)
            end
        end)
    end)

    if dropdown.Left then dropdown.Left:SetAlpha(0.5) end

    return dropdown
end