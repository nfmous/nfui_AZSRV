-- Borderless feathered minimap and hover zoom; preserve nfUI mover anchors.
local C=nfUIConfig
local installed=false
local appliedMask
C.defaults.minimap.feather=12
local range=C.Range
C.Range=function(category,key)
    if category=="minimap" and key=="feather" then return 0,50,1 end
    return range(category,key)
end
function C.ApplyMapFeather()
    if not Minimap then return end
    local amount=math.max(0,math.min(50,math.floor(C.Settings().minimap.feather+0.5)))
    local path=amount==0 and "Interface\\Buttons\\WHITE8X8" or "Interface\\AddOns\\nfUI\\Resources\\media\\tex\\minimap\\feather-"..amount..".tga"
    if path~=appliedMask then Minimap:SetMaskTexture(path);appliedMask=path end
end
local function Install()
    if installed or not Minimap then return end
    installed=true
    C.ApplyMapFeather()
    if MinimapCluster then MinimapCluster:EnableMouse(false) end
    for _,name in ipairs({"MinimapBorder","MinimapBorderTop","MinimapToggleButton","GameTimeFrame"}) do
        local frame=getglobal(name); if frame then frame:Hide() end
    end
    -- The minimap has no header strip or clock.
    if MinimapZoneTextButton then MinimapZoneTextButton:Hide() end
    if MinimapZoneText then MinimapZoneText:Hide() end
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel",function()
        local levels=Minimap:GetZoomLevels()
        Minimap:SetZoom(math.max(0,math.min(levels-1,Minimap:GetZoom()+(arg1>0 and 1 or -1))))
    end)
    local function ZoomButtons(shown)
        for _,button in ipairs({MinimapZoomIn,MinimapZoomOut}) do
            if button then if shown then button:Show() else button:Hide() end end
        end
    end
    ZoomButtons(false)
    local hoverAge=0
    local hover=CreateFrame("Frame","nfUIMapHover",UIParent)
    hover:SetScript("OnUpdate",function()
        hoverAge=hoverAge+(arg1 or 0);if hoverAge<0.05 then return end;hoverAge=0
        local over=Minimap:IsVisible() and MouseIsOver and (MouseIsOver(Minimap)
            or (MinimapZoomIn and MinimapZoomIn:IsShown() and MouseIsOver(MinimapZoomIn))
            or (MinimapZoomOut and MinimapZoomOut:IsShown() and MouseIsOver(MinimapZoomOut)))
        ZoomButtons(over)
    end)
    if MinimapZoomIn then
        MinimapZoomIn:ClearAllPoints(); MinimapZoomIn:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",0,20)
    end
    if MinimapZoomOut then
        MinimapZoomOut:ClearAllPoints(); MinimapZoomOut:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",0,0)
    end
    if Minimap.nfuiBorder then Minimap.nfuiBorder:Hide() end
    C.mapStrip=nil
end
local loader=CreateFrame("Frame","nfUIMapLoader",UIParent)
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent",Install)
Install()
