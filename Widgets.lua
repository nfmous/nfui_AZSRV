-- Shared drawing operations keep nfUI panels and HUD elements consistent.
nfUIWidgets={font="Fonts\\FRIZQT__.TTF",texture="Interface\\Buttons\\WHITE8X8"}
local W=nfUIWidgets
function W.Fill(parent,color,layer,inset)
    local texture=parent:CreateTexture(nil,layer or "BACKGROUND")
    texture:SetTexture(W.texture);texture:SetVertexColor(unpack(color))
    if inset then
        texture:SetPoint("TOPLEFT",parent,"TOPLEFT",inset,-inset)
        texture:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-inset,inset)
    else texture:SetAllPoints(parent) end
    return texture
end
function W.Label(parent,size,point,x,y,text,color)
    local label=parent:CreateFontString(nil,"OVERLAY")
    label:SetFont(W.font,size,"OUTLINE");label:SetPoint(point,parent,point,x or 0,y or 0)
    if text then label:SetText(text) end
    if color then label:SetTextColor(unpack(color)) end
    return label
end
function W.Bar(parent,width,height)
    local bar=CreateFrame("StatusBar",nil,parent)
    bar:SetHeight(height);bar:SetWidth(width);bar:SetMinMaxValues(0,1)
    bar:SetStatusBarTexture(W.texture)
    W.Fill(bar,{0,0,0,1},"BACKGROUND",-1)
    W.Fill(bar,{0.09,0.09,0.11,1},"BORDER")
    return bar
end
function W.HideNames(names)
    for _,name in ipairs(names) do local region=getglobal(name);if region then region:Hide() end end
end
