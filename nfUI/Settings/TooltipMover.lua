-- A permanent invisible anchor gives tooltip placement a visible unlock handle.
local C=nfUIConfig
local anchor=CreateFrame("Frame","nfUITooltipAnchor",UIParent)
anchor:SetWidth(240);anchor:SetHeight(90);anchor:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-24,90)
anchor:EnableMouse(false);anchor:SetAlpha(0)
C.tooltipAnchor=anchor
if C.RegisterMover then C.RegisterMover("tooltip","Tooltip",anchor,"tooltip") end
local function Place(tooltip)
    tooltip:ClearAllPoints();tooltip:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT",0,0)
end
local originalDefault=GameTooltip_SetDefaultAnchor
GameTooltip_SetDefaultAnchor=function(tooltip,parent)
    if tooltip~=GameTooltip then if originalDefault then originalDefault(tooltip,parent) end;return end
    tooltip:SetOwner(parent,"ANCHOR_NONE");Place(tooltip);tooltip.default=1
end
if GameTooltip then
    local originalOwner=GameTooltip.SetOwner
    GameTooltip.SetOwner=function(self,owner,kind,x,y)
        originalOwner(self,owner,"ANCHOR_NONE",x,y);Place(self)
    end
    local originalShow=GameTooltip:GetScript("OnShow")
    GameTooltip:SetScript("OnShow",function() if originalShow then originalShow() end;Place(GameTooltip) end)
end
