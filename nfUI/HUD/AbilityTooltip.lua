-- Transform native ability lines into nfUI's compact section layout.
local C,W=nfUIConfig,nfUIWidgets
local headings={['Upgrades: ']={"Upgrades",{1,0.82,0.3}},['Your bonuses: ']={"Bonuses",{0.3,0.9,0.45}},['Talents: ']={"Talents",{0.35,0.75,1}}}
local schools={Holy={1,0.78,0.15},Fire={1,0.42,0.08},Frost={0.3,0.72,1},Nature={0.3,0.88,0.25},Shadow={0.66,0.38,1},Arcane={1,0.4,0.85}}
local neutral={0.7,0.72,0.76}
local function Clean(text)
    text=string.gsub(text or "","|c%x%x%x%x%x%x%x%x","")
    return (string.gsub(string.gsub(text,"|r",""),"^%s*(.-)%s*$","%1"))
end
local function Items(text)
    local result,first,depth={},1,0
    for index=1,string.len(text)+1 do
        local char=string.sub(text,index,index)
        if char=="(" then depth=depth+1 elseif char==")" then depth=math.max(0,depth-1) end
        if index>string.len(text) or (char=="," and depth==0) then
            local item=Clean(string.sub(text,first,index-1));if item~="" then table.insert(result,item) end
            first=index+1
        end
    end
    return result
end
local function Numbers(text)
    return string.gsub(text,"([%+%-]?%d[%d%.]*%%?)","|cffffffff%1|r")
end
function C.AbilityTooltipModel(lines)
    if table.getn(lines)<2 then return nil end
    local cast,recognized
    local title=Clean(lines[1].left)
    local rank=Clean(lines[1].right)
    if string.find(rank,"^Rank") then recognized=true end
    for index=2,table.getn(lines) do
        local left,right=Clean(lines[index].left),Clean(lines[index].right)
        if left=="Automatic" or left=="Passive" or string.find(string.lower(right),"cooldown",1,true) then cast=index;break end
    end
    if not cast then return nil end
    local blocks={};local details={}
    for index=cast+1,table.getn(lines) do
        for piece in string.gfind((lines[index].left or "").."\n","([^\n]*)\n") do
            local text=Clean(piece)
            local section
            for prefix,definition in pairs(headings) do
                if string.sub(text,1,string.len(prefix))==prefix then
                    section={title=definition[1],color=definition[2],items=Items(string.sub(text,string.len(prefix)+1))}
                    recognized=true;break
                end
            end
            if section then table.insert(blocks,section)
            elseif text~="" then
                if string.find(text,"chance to crit",1,true) then recognized=true end
                table.insert(details,{text=text,color=lines[index].color or neutral})
            end
        end
    end
    if not recognized then return nil end
    local tint={0.9,0.68,0.45}
    for _,detail in ipairs(details) do
        for word in string.gfind(detail.text,"%a+") do if schools[word] then tint=schools[word];break end end
    end
    local output={{left=title,right=rank,color=tint}}
    local stats={Clean(lines[cast].left)}
    for index=2,cast-1 do local value=Clean(lines[index].left);if value~="" then table.insert(stats,value) end end
    table.insert(output,{left=table.concat(stats," / "),right=Numbers(Clean(lines[cast].right)),color=neutral})
    for _,detail in ipairs(details) do table.insert(output,{left=Numbers(detail.text),color=detail.color,wrap=true}) end
    for _,section in ipairs(blocks) do
        table.insert(output,{left=section.title,color=section.color,separator=true})
        for _,text in ipairs(section.items) do
            local _,_,amount,label=string.find(text,"^([%+%-]?[%d%.]+%%?)%s+(.+)$")
            if amount then
                label=string.upper(string.sub(label,1,1))..string.sub(label,2)
                table.insert(output,{left="  "..label,right=amount,color=section.color})
            else table.insert(output,{left="  "..text,color=section.color,wrap=true}) end
        end
    end
    return output
end
local rules,lastSignature={},nil
local function ClearRules() for _,rule in ipairs(rules) do rule:Hide() end end
local function Snapshot()
    local lines,signature={},{}
    for index=1,GameTooltip:NumLines() do
        local left=getglobal("GameTooltipTextLeft"..index)
        local right=getglobal("GameTooltipTextRight"..index)
        local text=left and left:GetText() or ""
        local other=right and right:IsShown() and right:GetText() or ""
        local color={0.7,0.72,0.76};if left and left.GetTextColor then color={left:GetTextColor()} end
        table.insert(lines,{left=text,right=other,color=color})
        table.insert(signature,text or "");table.insert(signature,other or "")
    end
    return lines,table.concat(signature,"\001")
end
local function Render(model)
    ClearRules();GameTooltip:ClearLines()
    local count=0
    for _,line in ipairs(model) do
        local color=line.color
        if line.separator then
            GameTooltip:AddLine(" ");count=count+1
            local label=getglobal("GameTooltipTextLeft"..GameTooltip:NumLines())
            if label then
                local rule=rules[count]
                if not rule then rule=W.Fill(GameTooltip,{0.2,0.25,0.3,0.7},"ARTWORK");rules[count]=rule end
                rule:ClearAllPoints();rule:SetHeight(1)
                rule:SetPoint("LEFT",GameTooltip,"LEFT",10,0);rule:SetPoint("RIGHT",GameTooltip,"RIGHT",-10,0)
                rule:SetPoint("TOP",label,"TOP",0,-3);rule:Show()
            end
        end
        if line.right and line.right~="" then GameTooltip:AddDoubleLine(line.left,line.right,color[1],color[2],color[3],color[1],color[2],color[3])
        else GameTooltip:AddLine(line.left,color[1],color[2],color[3],line.wrap and true or false) end
    end
    GameTooltip:Show()
end
local observer=CreateFrame("Frame","nfUIAbilityObserver",UIParent)
observer:SetScript("OnUpdate",function()
    if not GameTooltip:IsVisible() then return end
    local success,lines,signature=pcall(Snapshot)
    if not success or signature==lastSignature then return end
    ClearRules();lastSignature=signature
    local model=C.AbilityTooltipModel(lines)
    if model then
        local rendered=pcall(Render,model)
        if rendered then local _,newSignature=Snapshot();lastSignature=newSignature end
    end
end)
local previous=GameTooltip:GetScript("OnHide")
GameTooltip:SetScript("OnHide",function() ClearRules();lastSignature=nil;if previous then previous() end end)
