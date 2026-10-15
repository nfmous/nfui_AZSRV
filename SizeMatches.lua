-- Directed, persistent links use rendered dimensions so differently scaled movers match.
local C=nfUIConfig
local menu,pending
local function Links()
    local db=C.Settings();if type(db.sizeMatches)~="table" then db.sizeMatches={} end
    return db.sizeMatches
end
local function Entries()
    local map={};for _,entry in ipairs(C.moverRegistry) do map[entry.key]=entry end;return map
end
function C.SetSizeMatch(follower,source,axis)
    if axis~="width" and axis~="height" then return false end
    local entries=Entries();if not entries[follower] or not entries[source] then return false end
    local links=Links();local seen={[follower]=true};local key=source
    while key do
        if seen[key] then return false end;seen[key]=true
        key=links[key] and links[key][axis]
    end
    links[follower]=links[follower] or {};links[follower][axis]=source
    C.ApplyPositions();return true
end
function C.ApplySizeMatches()
    if not next(Links()) then return end
    local entries,links=Entries(),Links()
    for _,axis in ipairs({"width","height"}) do
        local done,visiting={},{}
        local function Apply(key)
            if done[key] or visiting[key] then return end
            visiting[key]=true
            local source=links[key] and links[key][axis]
            local item,target=entries[key],entries[source]
            if item and target then
                Apply(source)
                local object,other=item.object,target.object
                local getter=axis=="width" and "GetWidth" or "GetHeight"
                local setter=axis=="width" and "SetWidth" or "SetHeight"
                local size=other[getter](other)*C.RegionEffectiveScale(other)/C.RegionEffectiveScale(object)
                if size>0 and size==size and size-size==0 then
                    if object[getter](object)~=size then object[setter](object,size) end
                    if object==C.player or object==C.target then
                        if axis=="width" then
                            local style=C.Settings()[object.unit.."Style"]
                            local width=math.max(1,size-(style.showPortrait and object.portrait:GetWidth()+1 or 0))
                            object.health:SetWidth(width);object.power:SetWidth(width);object.shield:SetWidth(width)
                            object.name:SetWidth(math.max(1,width*0.5-5))
                        else object.health:SetHeight(math.max(1,size-object.power:GetHeight()-1)) end
                    end
                    if object==C.row then
                        local gap=C.Settings().action.gap
                        local slotWidth=math.max(1,(object:GetWidth()-(table.getn(C.slots)-1)*gap)/table.getn(C.slots))
                        for index,slot in ipairs(C.slots) do
                            if axis=="width" then
                                slot:SetWidth(slotWidth)
                                if not C.Settings().positions["action"..C.buttonIDs[index]] then
                                    slot:ClearAllPoints();slot:SetPoint("LEFT",object,"LEFT",(index-1)*(slotWidth+gap),0)
                                end
                            else slot:SetHeight(size) end
                            local slotEntry=entries["action"..C.buttonIDs[index]]
                            if slotEntry and slotEntry.extra then slotEntry.extra(slot) end
                        end
                    end
                    if object==C.compassFrame and C.LayoutCompass then C.LayoutCompass()
                    elseif object==C.runFrame and C.LayoutRunPanel then C.LayoutRunPanel()
                    elseif object==C.statsFrame and C.LayoutStats then C.LayoutStats()
                    end
                    if item.extra then item.extra(object) end
                end
            end
            visiting[key]=nil;done[key]=true
        end
        for key in pairs(links) do Apply(key) end
    end
end
function C.MatchedDimension(key,axis,fallback)
    local source=Links()[key] and Links()[key][axis]
    if not source then return fallback end
    local entries=Entries();local item,target=entries[key],entries[source]
    if not item or not target then return fallback end
    local getter=axis=="width" and "GetWidth" or "GetHeight"
    local size=target.object[getter](target.object)*C.RegionEffectiveScale(target.object)/C.RegionEffectiveScale(item.object)
    return size>0 and size==size and size-size==0 and size or fallback
end
function C.SelectSizeMatch(item)
    if not pending then return false end
    if C.SetSizeMatch(pending.key,item.key,pending.axis) then
        pending=nil;menu:Hide()
    else menu.title:SetText("Choose another element (no loops)") end
    return true
end
function C.CancelSizeMatch()
    pending=nil;if menu then menu:Hide() end
end
function C.ShowMoverMenu(item)
    C.CancelSizeMatch()
    if C.finePanel then C.finePanel:Hide() end
    if not menu then
        menu=CreateFrame("Frame","nfUIMoverMenu",UIParent)
        menu:SetWidth(220);menu:SetHeight(178);menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetFrameLevel(150)
        menu:EnableMouse(true);menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        menu:SetBackdropColor(0.04,0.07,0.1,0.98)
        menu.title=menu:CreateFontString(nil,"OVERLAY");menu.title:SetFont("Fonts\\FRIZQT__.TTF",11)
        menu.title:SetPoint("TOP",menu,"TOP",0,-8);menu.title:SetWidth(208);menu.title:SetHeight(28)
        local function Button(text,index,callback)
            local button=CreateFrame("Button","nfUIMoverMenuButton"..index,menu,"UIPanelButtonTemplate")
            button:SetWidth(204);button:SetHeight(24);button:SetPoint("TOPLEFT",menu,"TOPLEFT",8,-38-(index-1)*27)
            button:SetText(text);button:SetScript("OnClick",callback)
        end
        for index,axis in ipairs({"width","height"}) do
            local dimension=axis
            Button(index==1 and "Width Match" or "Height Match",index,function()
                pending={key=menu.item.key,axis=dimension}
                menu.title:SetText("Click the element to follow")
            end)
        end
        Button("Adjustments",3,function() local selected=menu.item;C.CancelSizeMatch();C.ShowFineAdjustments(selected) end)
        Button("Clear size matches",4,function() Links()[menu.item.key]=nil;C.CancelSizeMatch();C.Apply() end)
        Button("Cancel",5,C.CancelSizeMatch)
        table.insert(UISpecialFrames,"nfUIMoverMenu")
        menu:SetScript("OnHide",function() pending=nil end)
        C.moverMenu=menu
    end
    menu.item=item;menu.title:SetText(item.label)
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    menu:ClearAllPoints();menu:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",math.max(0,math.min(UIParent:GetWidth()-220,x/scale)),math.max(0,math.min(UIParent:GetHeight()-178,y/scale)))
    menu:Show()
end
