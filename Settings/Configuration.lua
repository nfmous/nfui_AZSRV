-- nfUI configuration: the original compact layout, adjustable live.
local C=nfUIConfig
local FLAT="Interface\\ChatFrame\\ChatFrameBackground"
local FONT="Fonts\\FRIZQT__.TTF"
local categories={
    {key="layout",title="Overall layout",description="Overall scale. Use Movers to position each element independently.",
        fields={{"scale","Overall scale"}}},
    {key="player",title="Player frame",description="Player size, text placement, health formatting, portrait, colors and shields.",
        fields={{"scale","Frame scale"},{"width","Health / power width"},{"height","Frame height"},{"portrait","Portrait size"},{"powerHeight","Power bar height"},{"nameFont","Name font"},{"valueFont","Health font"},{"hideName","Hide Name","check"},{"healthArea","Health display area","select"},{"showPortrait","Show portrait","check"},{"healthText","Health text","select"},{"healthColor","Color health by injury","check"},{"showShield","Show shields","check"},{"shieldHeight","Shield strip height"},{"shieldFont","Shield text font"}}},
    {key="target",title="Target frame",description="Target size, text, health formatting, portrait, colors and shields.",
        fields={{"scale","Frame scale"},{"width","Health / power width"},{"height","Frame height"},{"portrait","Portrait size"},{"powerHeight","Power bar height"},{"nameFont","Name font"},{"valueFont","Health font"},{"showPortrait","Show portrait","check"},{"healthText","Health text","select"},{"healthColor","Color health by injury","check"},{"showShield","Show shields","check"},{"shieldHeight","Shield strip height"},{"shieldFont","Shield text font"}}},
    {key="action",title="Action buttons",description="Buttons 1 to 6 and =, including bonus/stance actions.",
        fields={{"scale","Bar scale"},{"size","Button size"},{"gap","Button spacing"},{"hotkeyFont","Keybind font"},{"cooldownFont","Cooldown numbers"},{"countFont","Item count font"}}},
    {key="auras",title="Player auras",description="Buff and debuff icons above the player frame.",
        fields={{"size","Icon size"},{"gap","Icon spacing"},{"timeFont","Duration font"},{"stackFont","Stack count font"}}},
    {key="debuffs",title="Target debuffs",description="Debuff icons above the target frame.",
        fields={{"size","Icon size"},{"gap","Icon spacing"},{"stackFont","Stack count font"}}},
    {key="xp",title="Experience bar",description="Independent experience strip width and height.",
        fields={{"width","Strip width"},{"height","Strip height"},{"gap","Space below row"}}},
    {key="minimap",title="Minimap",description="Borderless minimap with adjustable edge feathering.",
        fields={{"size","Map size"},{"scale","Map scale"},{"feather","Edge feathering (%)"}}},
    {key="chat",title="Chat",description="Chat window dimensions and text sizes.",
        fields={{"width","Chat width"},{"height","Chat height"},{"font","Message font"},{"tabFont","Tab font"},{"editScale","Input box scale"},{"editFont","Input box font"},{"backdropOpacity","Backdrop opacity"}}},
    {key="nameplates",title="Nameplates",description="Enemy plate visibility, collision, stacking, colors and text.",
        fields={{"enabled","Nameplates enable","check"},{"amount","Nameplate amount","select"},{"collision","Nameplate collision","check"},{"stacking","Nameplate stacking","check"},{"scale","Scale"},{"height","Height"},{"width","Width"},{"color","Bar color","color"},{"rankColors","Use rank colors","check"},{"showNames","Show names","check"},{"abbreviate","Abbreviate names","check"},{"nameFont","Name font size"},{"healthFont","Health font size"},{"healthText","Health text","select"}}},
    {key="micro",title="Micro buttons",description="Scale the fading buttons in the bottom-right corner.",
        fields={{"scale","Button scale"}}},
    {key="compassStyle",title="Compass",description="Heading strip and detected map markers.",
        fields={{"width","Strip width"},{"height","Strip height"},{"anchor","Anchor position","select"},{"scale","Strip scale"},{"fullWidth","Full screen width","check"},{"iconSize","Icon size"},{"labelFont","Label size"},{"compass","Show compass","check","root"}}},
    {key="statsDisplay",title="Character stats",description="Persistent live character stats. Use Movers to position it.",
        fields={{"width","Panel width"},{"height","Panel height"},{"scale","Panel scale"},{"font","Label font size"},{"valueFont","Value font size"},{"headingFont","Heading font size"},{"backdrop","Show backdrop","check"},{"headings","Show headings","check"}}},
    {key="dpsDisplay",title="DPS Meter",description="Automatic dimensions fit the current damage-source entries.",
        fields={{"backdropOpacity","Backdrop opacity"},{"autoWidth","Fit width to entries","check"},{"autoHeight","Fit height to entries","check"},{"width","Expanded width"},{"height","Expanded height"},{"scale","Panel scale"},{"dpsCollapsed","Expanded","check","root",true}}},
    {key="runDisplay",title="Run Stats",description="Upward-opening panel with a fixed bottom header and saved placement.",
        fields={{"width","Expanded width"},{"height","Expanded height"},{"scale","Panel scale"},{"font","Text size"},{"backdrop","Show backdrop","check"},{"runPanel","Show Run Stats","check","root"},{"runCollapsed","Expanded","check","root",true},{"resetRun","Reset local run tracking","action"}}},
    {key="combatText",title="Combat text",description="Choose one damage-text renderer.",
        fields={{"damageMode","Damage text mode","select","root"}}}
}
local selected=categories[1]
local function SettingsCategory(key)
    if selected.key=="player" or selected.key=="target" then
        local style=selected.key.."Style"
        if C.defaults[style][key]~=nil then return style end
    end
    return selected.key
end
local function SelectedField(key)
    for _,field in ipairs(selected.fields) do if field[1]==key then return field end end
end
local function SelectedSettings(key)
    local field=SelectedField(key)
    return field and field[4]=="root" and C.Settings() or C.Settings()[SettingsCategory(key)]
end
local function ReadValue(key)
    local value=SelectedSettings(key)[key]
    local field=SelectedField(key)
    if field and field[5] then return not value end
    return value
end
local function WriteValue(key,value)
    local field=SelectedField(key)
    if field and field[5] then value=not value end
    if key=="damageMode" then C.SetDamageMode(value)
    elseif key=="runCollapsed" then C.SetRunCollapsed(value)
    elseif key=="dpsCollapsed" then C.SetDPSCollapsed(value)
    else SelectedSettings(key)[key]=value end
end
local damageModes={"sct","quick","default","off"}
local damageLabels={sct="Icon combat text",quick="Compact damage labels",default="Native damage text",off="Disabled"}
local function ChoiceLabel(key,value)
    if key=="damageMode" then return damageLabels[value] end
    if key=="anchor" then return value=="TOP" and "Top Center" or "Bottom Center" end
    return value
end

local panel,content,rows,contentScroll
local resize
local rowCount=7
local scrollOffset=0
local buttons={}
local refreshing=false

local function Text(parent,text,x,y,size,color)
    local label=parent:CreateFontString(nil,"OVERLAY")
    label:SetFont(FONT,size or 12)
    if label.SetNonSpaceWrap then label:SetNonSpaceWrap(false) end
    label:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    label:SetText(text)
    if color then label:SetTextColor(color[1],color[2],color[3]) else label:SetTextColor(0.85,0.87,0.9) end
    return label
end

local function Flat(parent,r,g,b,a)
    local fill=parent:CreateTexture(nil,"BACKGROUND")
    fill:SetTexture(FLAT); fill:SetVertexColor(r,g,b,a or 1); fill:SetAllPoints(parent)
    return fill
end

local function Button(name,parent,text,x,y,width,callback)
    local button=CreateFrame("Button",name,parent)
    button:SetWidth(width); button:SetHeight(28)
    button:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    button.back=Flat(button,0.13,0.15,0.19)
    button.label=Text(button,text,10,-7,12)
    button.SetText=function(self,value) self.label:SetText(value) end
    button:SetHighlightTexture(FLAT)
    local highlight=button:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(0.15,0.6,0.8,0.25) end
    button:SetScript("OnClick",callback)
    return button
end

local function Format(key,value)
    if key=="scale" or key=="editScale" or key=="backdropOpacity" then return math.floor(value*100+0.5).."%" end
    return tostring(math.floor(value+0.5)).." px"
end

function C.Refresh()
    if not panel then return end
    refreshing=true
    local db=C.Settings()
    content.title:SetText(selected.title)
    content.description:SetText(selected.description)
    for key,button in pairs(buttons) do
        if key==selected.key then
            button.back:SetVertexColor(0.08,0.35,0.46,1)
            button.label:SetTextColor(0.35,0.85,1)
        else
            button.back:SetVertexColor(0.10,0.12,0.15,1)
            button.label:SetTextColor(0.8,0.82,0.85)
        end
    end
    content:SetHeight(math.max(435,60+table.getn(selected.fields)*49))
    scrollOffset=math.min(scrollOffset,math.max(0,content:GetHeight()-contentScroll:GetHeight()/0.7))
    contentScroll:SetVerticalScroll(scrollOffset*0.7)
    for i=1,rowCount do
        local row=rows[i]
        local field=selected.fields[i]
        if field then
            local key=field[1]
            row.key=key
            local lo,hi,step=C.Range(SettingsCategory(key),key)
            row.label:SetText(field[2])
            row.check:Hide(); row.choice:Hide(); row.menu:Hide(); row.slider:Hide(); row.value:Hide();row.color:Hide();row.action:Hide()
            if field[3]=="action" then
                row.action:SetText("Reset tracking");row.action:Show()
            elseif field[3]=="check" then
                row.check:SetChecked(ReadValue(key)); row.check:Show()
            elseif field[3]=="select" then
                row.choiceValues=key=="damageMode" and damageModes or key=="amount" and {"Target","All","5 max","10 max"} or key=="anchor" and {"BOTTOM","TOP"} or key=="healthArea" and {"Left","Middle","Right"} or {"Percentage","CurrentHP+%","Numerical"}
                row.choice:SetText(ChoiceLabel(key,ReadValue(key))); row.choice:Show()
                row.menu:SetHeight(table.getn(row.choiceValues)*31+6)
                for index,item in ipairs(row.choiceItems) do
                    local value=row.choiceValues[index]
                    if value then item:SetText(ChoiceLabel(key,value)); item:Show() else item:Hide() end
                end
            elseif field[3]=="color" then
                local color=db[SettingsCategory(key)][key]
                row.color.back:SetVertexColor(color[1],color[2],color[3],1);row.color:Show()
            else
            row.slider:Show(); row.value:Show()
            row.slider:SetMinMaxValues(lo,hi); row.slider:SetValueStep(step)
            row.slider:SetValue(db[SettingsCategory(key)][key])
            row.value:RefreshNumber()
            getglobal(row.slider:GetName().."Low"):SetText(Format(key,lo))
            getglobal(row.slider:GetName().."High"):SetText(Format(key,hi))
            end
            row:Show()
        else row:Hide(); row.menu:Hide() end
    end
    refreshing=false
end

local function EditLayout()
    if C.ToggleMovers then
        panel:Hide()
        C.ToggleMovers()
    end
end

local function Build()
    if panel then return end
    rows={}
    for _,category in ipairs(categories) do
        if category.key=="statsDisplay" and C.CharacterStatSections then
            for _,section in ipairs(C.CharacterStatSections) do
                for _,source in ipairs(section.rows) do
                    table.insert(category.fields,{C.StatSettingKey(source),source[1],"check"})
                end
            end
        end
        rowCount=math.max(rowCount,table.getn(category.fields))
    end
    panel=CreateFrame("Frame","nfUISettings",UIParent)
    local window=C.Settings().settingsWindow or {width=594.1,height=555}
    panel:Hide(); panel:SetWidth(window.width); panel:SetHeight(window.height)
    panel:SetPoint("CENTER",UIParent,"CENTER",0,40)
    panel:SetFrameStrata("DIALOG"); panel:SetMovable(true); panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    Flat(panel,0.055,0.065,0.085)
    panel:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
        insets={left=2,right=2,top=2,bottom=2}})
    panel:SetBackdropBorderColor(0.16,0.2,0.26,1)
    local body=CreateFrame("Frame","nfUISettingsBody",panel)
    body:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0);body:SetWidth(594.1);body:SetHeight(555)
    local header=CreateFrame("Frame","nfUISettingsHeader",body)
    header:SetWidth(590.1); header:SetHeight(48); header:SetPoint("TOP",body,"TOP",0,-2)
    Flat(header,0.085,0.11,0.15)
    Text(header,"nfUI",18,-12,20,{0.3,0.82,1})
    Text(header,"CONFIGURATION",170,-18,11)
    header:EnableMouse(true)
    header:SetScript("OnMouseDown",function() panel:StartMoving() end)
    header:SetScript("OnMouseUp",function() panel:StopMovingOrSizing() end)
    local sidebarScroll=CreateFrame("ScrollFrame","nfUISettingsSidebarScroll",body)
    sidebarScroll:SetWidth(165);sidebarScroll:SetHeight(439);sidebarScroll:SetPoint("TOPLEFT",body,"TOPLEFT",12,-61)
    local sidebar=CreateFrame("Frame",nil,sidebarScroll)
    sidebar:SetWidth(165); sidebar:SetHeight(439)
    sidebar:SetHeight(table.getn(categories)*28+10);sidebarScroll:SetScrollChild(sidebar)
    local sideOffset=0
    sidebarScroll:EnableMouseWheel(true)
    sidebarScroll:SetScript("OnMouseWheel",function()
        sideOffset=math.max(0,math.min(math.max(0,sidebar:GetHeight()-sidebarScroll:GetHeight()),sideOffset-(arg1 or 0)*28))
        sidebarScroll:SetVerticalScroll(sideOffset)
    end)
    Flat(sidebar,0.075,0.085,0.11)
    for i,category in ipairs(categories) do
        local choice=category
        buttons[choice.key]=Button("nfUISettingsCategory"..i,sidebar,choice.title,4,-5-(i-1)*28,157,
            function() C.CancelNumberInputs(); selected=choice;scrollOffset=0;C.Refresh() end)
    end
    contentScroll=CreateFrame("ScrollFrame","nfUISettingsScroll",body)
    contentScroll:SetWidth(387.1);contentScroll:SetHeight(435);contentScroll:SetPoint("TOPLEFT",body,"TOPLEFT",192,-64)
    contentScroll:EnableMouseWheel(true)
    contentScroll:SetScript("OnMouseWheel",function()
        scrollOffset=math.max(0,math.min(math.max(0,content:GetHeight()-contentScroll:GetHeight()/0.7),scrollOffset-(arg1 or 0)*49))
        contentScroll:SetVerticalScroll(scrollOffset*0.7)
    end)
    content=CreateFrame("Frame",nil,contentScroll)
    content:SetScale(0.7)
    content:SetWidth(553);content:SetHeight(445);content:SetPoint("TOPLEFT",contentScroll,"TOPLEFT",0,0)
    contentScroll:SetScrollChild(content)
    content.title=Text(content,"",0,0,17,{0.93,0.94,0.96})
    content.description=Text(content,"",0,-27,11)
    content.description:SetWidth(535);content.description:SetHeight(16)
    for i=1,rowCount do
        local option=CreateFrame("Frame","nfUISettingsOption"..i,content)
        rows[i]=option
        option:SetWidth(535); option:SetHeight(48)
        option:SetPoint("TOPLEFT",content,"TOPLEFT",0,-60-(i-1)*49)
        option.label=Text(option,"",0,0,12)
        option.value=C.CreateNumberInput("nfUISettingsInput"..i,option,86,20,{
            get=function() return SelectedSettings(option.key)[option.key] end,
            percent=function() return option.key=="scale" or option.key=="editScale" or option.key=="backdropOpacity" end,
            range=function() return C.Range(SettingsCategory(option.key),option.key) end,
            set=function(value)
                SelectedSettings(option.key)[option.key]=value
                if selected.key=="compassStyle" and option.key=="width" then C.Settings().compassStyle.fullWidth=false end
                C.Apply(); C.Refresh()
            end})
        option.value:SetPoint("TOPRIGHT",option,"TOPRIGHT",0,4)
        local slider=CreateFrame("Slider","nfUISettingsSlider"..i,option,"OptionsSliderTemplate")
        option.slider=slider
        slider:SetWidth(510); slider:SetHeight(16)
        slider:SetPoint("TOPLEFT",option,"TOPLEFT",2,-20)
        getglobal(slider:GetName().."Text"):SetText("")
        option.check=CreateFrame("CheckButton","nfUISettingsCheck"..i,option,"UICheckButtonTemplate")
        option.check:SetWidth(24); option.check:SetHeight(24)
        option.check:SetPoint("TOPRIGHT",option,"TOPRIGHT",-15,0)
        option.check:SetScript("OnClick",function()
            if refreshing or not option.key then return end
            WriteValue(option.key,this:GetChecked() and true or false)
            if selected.key=="nameplates" then
                local settings=C.Settings().nameplates
                if option.key=="stacking" and settings.stacking then settings.collision=true end
                if option.key=="collision" and not settings.collision then settings.stacking=false end
            end
            C.Apply(); C.Refresh()
        end)
        option.action=Button("nfUISettingsAction"..i,option,"",235,0,275,function()
            if option.key=="resetRun" then nfUI_ResetRun();C.Refresh() end
        end)
        option.choice=Button("nfUISettingsChoice"..i,option,"",235,0,275,function()
            if option.menu:IsShown() then option.menu:Hide() else option.menu:Show() end
        end)
        option.menu=CreateFrame("Frame","nfUISettingsChoiceMenu"..i,option)
        option.menu:SetWidth(275); option.menu:SetHeight(100)
        option.menu:SetPoint("TOPLEFT",option.choice,"BOTTOMLEFT",0,0)
        option.menu:SetFrameStrata("FULLSCREEN_DIALOG")
        option.menu:SetFrameLevel(option:GetFrameLevel()+20)
        Flat(option.menu,0.06,0.09,0.13)
        option.choiceItems={}
        for index,value in ipairs({"Percentage","CurrentHP+%","Numerical","10 max"}) do
            local choiceIndex=index
            option.choiceItems[index]=Button("nfUISettingsChoice"..i.."Item"..index,option.menu,value,3,-3-(index-1)*31,269,function()
                WriteValue(option.key,option.choiceValues[choiceIndex])
                if selected.key=="player" and option.key=="healthArea" then
                    local positions=C.Settings().positions
                    if positions then positions.playerValue=nil;positions.playerName=nil end
                end
                if selected.key=="compassStyle" and option.key=="anchor" then
                    local db=C.Settings(); if db.positions then db.positions.compass=nil end
                end
                C.Apply(); C.Refresh(); option.menu:Hide()
            end)
        end
        option.color=Button("nfUISettingsColor"..i,option,"Choose color",235,0,275,function()
            if not ColorPickerFrame then return end
            local category,key=SettingsCategory(option.key),option.key
            local old=C.Settings()[category][key];local previous={old[1],old[2],old[3]}
            local previousRank=category=="nameplates" and C.Settings().nameplates.rankColors
            local function Commit(color)
                C.Settings()[category][key]={color[1],color[2],color[3]}
                if category=="nameplates" then C.Settings().nameplates.rankColors=false end
                C.Apply();C.Refresh()
            end
            ColorPickerFrame:Hide();ColorPickerFrame.hasOpacity=false
            ColorPickerFrame.func=function() local r,g,b=ColorPickerFrame:GetColorRGB();Commit({r,g,b}) end
            ColorPickerFrame.cancelFunc=function()
                Commit(previous)
                if category=="nameplates" then C.Settings().nameplates.rankColors=previousRank;C.Apply();C.Refresh() end
            end
            ColorPickerFrame:SetColorRGB(previous[1],previous[2],previous[3]);ColorPickerFrame:Show()
        end)
        option.menu:Hide()

        slider:SetScript("OnValueChanged",function()
            if refreshing then return end
            C.CancelNumberInputs()
            local key=option.key
            if not key then return end
            local lo,hi,step=C.Range(SettingsCategory(key),key)
            local value=this:GetValue()
            value=lo+math.floor((value-lo)/step+0.5)*step
            value=math.max(lo,math.min(hi,value))
            SelectedSettings(key)[key]=value
            if selected.key=="compassStyle" and key=="width" then C.Settings().compassStyle.fullWidth=false end
            C.Apply(); C.Refresh()
        end)
    end
    local footer=CreateFrame("Frame",nil,body)
    footer:SetScale(570.1/736)
    footer:SetWidth(736); footer:SetHeight(40); footer:SetPoint("BOTTOM",body,"BOTTOM",0,10)
    Flat(footer,0.075,0.085,0.11)
    Button("nfUISettingsMove",footer,"Movers",7,-6,115,EditLayout)
    Button("nfUISettingsReset",footer,"Reset section",130,-6,124,function()
        if selected.key=="compassStyle" then C.Settings().compass=true
        elseif selected.key=="runDisplay" then C.Settings().runPanel=true;C.SetRunCollapsed(true)
        elseif selected.key=="dpsDisplay" then C.SetDPSCollapsed(true)
        elseif selected.key=="combatText" then C.SetDamageMode("sct") end
        C.Reset(selected.key);C.Refresh()
    end)
    Button("nfUISettingsResetAll",footer,"Reset all",262,-6,105,function()
        C.Settings().compass=true;C.Settings().runPanel=true
        C.SetRunCollapsed(true);C.SetDPSCollapsed(true);C.SetDamageMode("sct")
        C.Reset();C.Refresh()
    end)
    Button("nfUISettingsDone",footer,"Done",625,-6,100,function() panel:Hide() end)
    Text(footer,"Saved automatically",381,-13,10)
    local function LayoutWindow()
        local factor=panel:GetWidth()/594.1
        body:SetScale(factor);body:SetHeight(panel:GetHeight()/factor)
        contentScroll:SetHeight(math.max(60,body:GetHeight()-120))
        sidebarScroll:SetHeight(math.max(60,body:GetHeight()-116))
        sideOffset=math.min(sideOffset,math.max(0,sidebar:GetHeight()-sidebarScroll:GetHeight()));sidebarScroll:SetVerticalScroll(sideOffset)
        scrollOffset=math.min(scrollOffset,math.max(0,content:GetHeight()-contentScroll:GetHeight()/0.7));contentScroll:SetVerticalScroll(scrollOffset*0.7)
    end
    C.ResizeSettings=function(width,height)
        panel:SetWidth(math.max(480,math.min(UIParent:GetWidth(),width)))
        panel:SetHeight(math.max(320,math.min(UIParent:GetHeight(),height)))
        C.Settings().settingsWindow={width=panel:GetWidth(),height=panel:GetHeight()}
        LayoutWindow()
    end
    local grip=CreateFrame("Button","nfUISettingsResizeGrip",panel)
    grip:SetWidth(24);grip:SetHeight(24);grip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-2,2)
    grip:SetFrameLevel(panel:GetFrameLevel()+30)
    local mark=grip:CreateFontString(nil,"OVERLAY");mark:SetFont(FONT,12);mark:SetText("///");mark:SetPoint("CENTER",grip,"CENTER",0,0);mark:SetTextColor(0.3,0.82,1)
    grip:SetScript("OnMouseDown",function()
        if arg1~="LeftButton" then return end
        C.CancelNumberInputs()
        local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
        local left,top=panel:GetLeft(),panel:GetTop()
        if left and top then panel:ClearAllPoints();panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top) end
        resize={x=x,y=y,width=panel:GetWidth(),height=panel:GetHeight(),scale=scale}
    end)
    grip:SetScript("OnMouseUp",function() resize=nil end)
    grip:SetScript("OnEnter",function() GameTooltip:SetOwner(grip,"ANCHOR_TOP");GameTooltip:AddLine("Drag to resize settings",0.3,0.82,1);GameTooltip:Show() end)
    grip:SetScript("OnLeave",function() GameTooltip:Hide() end)
    panel:SetScript("OnUpdate",function()
        if not resize then return end
        local x,y=GetCursorPosition()
        C.ResizeSettings(resize.width+(x-resize.x)/resize.scale,resize.height-(y-resize.y)/resize.scale)
    end)
    LayoutWindow()
    panel:SetScript("OnShow",function() C.Apply(); C.Refresh() end)
    panel:SetScript("OnHide",function()
        resize=nil
        for _,option in ipairs(rows) do option.menu:Hide() end
    end)
    table.insert(UISpecialFrames,"nfUISettings")
    C.panel=panel
    C.SelectedCategory=function() return selected.key end
end

function C.Toggle()
    Build()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

SLASH_NFUI1="/nfui"
SlashCmdList["NFUI"]=C.Toggle


function C.OpenCategory(key)
    if key=="playerStyle" then key="player" elseif key=="targetStyle" then key="target" end
    Build()
    C.CancelNumberInputs();scrollOffset=0
    for _,category in ipairs(categories) do if category.key==key then selected=category end end
    panel:Show(); C.Refresh()
end
