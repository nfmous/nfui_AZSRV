-- Right-click a mover for precise screen position and element dimensions.
local C=nfUIConfig
local panel,entry
local sliders={}
local syncing=false
local FLAT="Interface\\ChatFrame\\ChatFrameBackground"
local function Label(parent,text,x,y)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",12)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); f:SetText(text)
    return f
end
local function Elements()
    local db=C.Settings()
    if type(db.elements)~="table" then db.elements={} end
    return db.elements
end
local function ReadPosition()
    local db=C.Settings()
    return db.positions and db.positions[entry.key] or {x=0,y=0}
end
local function RootUnit() return entry and (entry.key=="player" or entry.key=="target") end
local function GetValue(field)
    local object=entry.object
    local db=C.Settings()
    if field=="x" or field=="y" then return ReadPosition()[field] or 0 end
    if entry.key=="runPanel" then return db.runDisplay[field] or 11 end
    if entry.key=="dpsMeter" then return db.dpsDisplay[field] or 11 end
    if RootUnit() and (field=="width" or field=="height") then return db[entry.key][field] end
    if field=="font" then
        if not object.GetFont then return 12 end
        local _,size=object:GetFont()
        return size or 12
    end
    if field=="scale" then return object.GetScale and object:GetScale() or 1 end
    return field=="width" and object:GetWidth() or object:GetHeight()
end
local function Refresh()
    if not entry then return end
    syncing=true
    panel.title:SetText(entry.label.." - fine adjustments")
    for _,item in ipairs(sliders) do
        local value=GetValue(item.field)
        item.label:SetText(RootUnit() and item.field=="width" and "Health / power width" or item.caption)
        local lo,hi,step=item.lo,item.hi,item.step
        if entry.key=="runPanel" and item.field~="x" and item.field~="y" then
            lo,hi,step=C.Range("runDisplay",item.field)
        elseif (RootUnit() or entry.key=="xp" or entry.key=="compass" or entry.key=="characterStats" or entry.key=="runPanel") and (item.field=="width" or item.field=="height") then
            lo,hi,step=C.Range(RootUnit() and entry.key or entry.key=="compass" and "compassStyle" or entry.key=="characterStats" and "statsDisplay" or entry.key=="runPanel" and "runDisplay" or "xp",item.field)
        end
        item.currentLo=lo;item.currentHi=hi;item.currentStep=step
        item.slider:SetMinMaxValues(lo,hi);item.slider:SetValueStep(step)
        getglobal(item.slider:GetName().."Low"):SetText(tostring(lo))
        getglobal(item.slider:GetName().."High"):SetText(tostring(hi))
        item.slider:SetValue(value)
        item.value:RefreshNumber()
        if item.field=="scale" and not entry.object.SetScale then item:Hide()
        elseif item.field=="font" and entry.key~="runPanel" and not entry.object.SetFont then item:Hide()
        else item:Show() end
    end
    if RootUnit() then panel.appearance:Show() else panel.appearance:Hide() end
    syncing=false
end
local function SetValue(field,value)
    local db=C.Settings()
    C.SaveElement(entry.object)
    if field=="x" or field=="y" then
        db.positions[entry.key][field]=value
    elseif entry.key=="dpsMeter" then
        local lo,hi=C.Range("dpsDisplay",field)
        db.dpsDisplay[field]=math.max(lo,math.min(hi,value))
    elseif entry.key=="runPanel" then
        local lo,hi=C.Range("runDisplay",field)
        db.runDisplay[field]=math.max(lo,math.min(hi,value))
    elseif entry.key=="characterStats" and (field=="width" or field=="height" or field=="scale" or field=="font") then
        local lo,hi=C.Range("statsDisplay",field)
        db.statsDisplay[field]=math.max(lo,math.min(hi,value))
    elseif entry.key=="compass" and (field=="width" or field=="height" or field=="scale") then
        local lo,hi=C.Range("compassStyle",field)
        db.compassStyle[field]=math.max(lo,math.min(hi,value))
        if field=="width" then db.compassStyle.fullWidth=false end
    elseif RootUnit() and (field=="width" or field=="height") then
        local lo,hi=C.Range(entry.key,field)
        db[entry.key][field]=math.max(lo,math.min(hi,value))
    elseif RootUnit() and field=="scale" then
        db[entry.key].scale=value/db.layout.scale
    elseif entry.key=="actionBar" then
        if field=="scale" then db.action.scale=value/db.layout.scale
        elseif field=="height" then db.action.size=math.max(16,math.min(72,value))
        elseif field=="width" then
            db.action.size=math.max(16,math.min(72,(value-(table.getn(C.buttonIDs)-1)*db.action.gap)/table.getn(C.buttonIDs)))
        end
    elseif entry.key=="xp" and (field=="width" or field=="height") then
        local lo,hi=C.Range("xp",field)
        db.xp[field]=math.max(lo,math.min(hi,value))
    else
        local settings=Elements()[entry.key] or {}
        Elements()[entry.key]=settings
        settings[field]=value
    end
    C.Apply(); Refresh()
end
function C.ApplyElementSizes(item)
    local data=Elements()[item.key]
    if not data then return end
    local object=item.object
    if data.scale and object.SetScale then object:SetScale(data.scale) end
    local collapsed=item.key=="runPanel" and C.Settings().runCollapsed~=false
    if data.width and not collapsed then object:SetWidth(data.width) end
    if data.height and not collapsed then object:SetHeight(data.height) end
    if data.font and object.SetFont and object.GetFont then
        local path,_,flags=object:GetFont()
        local size=data.font
        if C.UnitTextSize and (item.category=="player" or item.category=="target") then size=C.UnitTextSize(object,size) end
        object:SetFont(path or "Fonts\\FRIZQT__.TTF",size,flags)
    end
end
function C.ClearElementSizes(category)
    for _,item in ipairs(C.moverRegistry) do
        if not category or item.category==category then Elements()[item.key]=nil end
    end
end
local function Build()
    if panel then return end
    panel=CreateFrame("Frame","nfUIFineAdjustments",UIParent)
    panel:Hide(); panel:SetWidth(410); panel:SetHeight(440)
    panel:SetPoint("RIGHT",UIParent,"RIGHT",-35,0)
    panel:SetFrameStrata("FULLSCREEN_DIALOG"); panel:SetFrameLevel(100); panel:EnableMouse(true)
    panel:SetBackdrop({bgFile=FLAT,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
    panel:SetBackdropColor(0.04,0.07,0.1,0.98)
    panel.title=Label(panel,"",14,-14)
    local fields={
        {"x","Horizontal position",-2000,5000,1},
        {"y","Vertical position",-2000,5000,1},
        {"width","Width",1,1800,1},
        {"height","Height",1,600,1},
        {"scale","Scale",0.25,3,0.05},
        {"font","Font size",8,32,1}
    }
    for i,field in ipairs(fields) do
        local item=CreateFrame("Frame","nfUIFineRow"..i,panel)
        item.field=field[1]; item.step=field[5]; item.lo=field[3]; item.hi=field[4]; item.caption=field[2]
        item:SetWidth(376); item:SetHeight(51)
        item:SetPoint("TOPLEFT",panel,"TOPLEFT",16,-48-(i-1)*53)
        item.label=Label(item,field[2],0,0)
        item.value=C.CreateNumberInput("nfUIFineInput"..i,item,76,20,{
            get=function() return GetValue(item.field) end,
            percent=function() return item.field=="scale" end,
            range=function() return item.currentLo or item.lo,item.currentHi or item.hi,item.currentStep or item.step end,
            set=function(value) SetValue(item.field,value) end})
        item.value:SetPoint("TOPRIGHT",item,"TOPRIGHT",-24,4)
        local function Nudge(direction)
            if not entry then return end
            if item.value.editing then item.value:CommitNumber() end
            C.CancelNumberInputs()
            local lo,hi=item.currentLo or item.lo,item.currentHi or item.hi
            -- Scale is displayed as a percentage: one click is one percentage point.
            local increment=item.field=="scale" and 0.01 or 1
            SetValue(item.field,math.max(lo,math.min(hi,GetValue(item.field)+direction*increment)))
        end
        item.minus=CreateFrame("Button","nfUIFineMinus"..i,item,"UIPanelButtonTemplate")
        item.minus:SetWidth(20);item.minus:SetHeight(20);item.minus:SetText("-")
        item.minus:SetPoint("RIGHT",item.value,"LEFT",-4,0)
        item.minus:SetScript("OnClick",function() Nudge(-1) end)
        item.plus=CreateFrame("Button","nfUIFinePlus"..i,item,"UIPanelButtonTemplate")
        item.plus:SetWidth(20);item.plus:SetHeight(20);item.plus:SetText("+")
        item.plus:SetPoint("LEFT",item.value,"RIGHT",4,0)
        item.plus:SetScript("OnClick",function() Nudge(1) end)
        item.slider=CreateFrame("Slider","nfUIFineSlider"..i,item,"OptionsSliderTemplate")
        item.slider:SetWidth(364); item.slider:SetHeight(16)
        item.slider:SetPoint("TOPLEFT",item,"TOPLEFT",0,-20)
        item.slider:SetMinMaxValues(field[3],field[4]); item.slider:SetValueStep(field[5])
        getglobal(item.slider:GetName().."Text"):SetText("")
        getglobal(item.slider:GetName().."Low"):SetText(tostring(field[3]))
        getglobal(item.slider:GetName().."High"):SetText(tostring(field[4]))
        item.slider:SetScript("OnValueChanged",function()
            if syncing or not entry then return end
            C.CancelNumberInputs()
            local step=item.currentStep or item.step
            local value=math.floor(this:GetValue()/step+0.5)*step
            SetValue(item.field,value)
        end)
        table.insert(sliders,item)
    end
    local done=CreateFrame("Button","nfUIFineDone",panel,"UIPanelButtonTemplate")
    done:SetWidth(90); done:SetHeight(24); done:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-16,14)
    done:SetText("Done"); done:SetScript("OnClick",function() panel:Hide() end)
    panel.appearance=CreateFrame("Button","nfUIFineAppearance",panel,"UIPanelButtonTemplate")
    panel.appearance:SetWidth(160); panel.appearance:SetHeight(24)
    panel.appearance:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",16,14)
    panel.appearance:SetText("Frame settings")
    panel.appearance:SetScript("OnClick",function()
        local category=entry.key.."Style"
        panel:Hide(); C.ToggleMovers(false); C.OpenCategory(category)
    end)
    table.insert(UISpecialFrames,"nfUIFineAdjustments")
    C.finePanel=panel
end
function C.ShowFineAdjustments(item)
    Build(); C.CancelNumberInputs(); entry=item; C.SaveElement(item.object); Refresh(); panel:Show()
end
