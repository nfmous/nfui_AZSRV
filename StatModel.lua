-- Native stat fields mapped once for both character-stat views.
local C=nfUIConfig
local sections={}
local function Group(title,color,definitions)
    local rows={}
    for _,definition in ipairs(definitions) do
        local item=definition
        local format=function(stats)
            local value=stats[item[2]]
            if item[4]=="bonus" then value=value-1 elseif item[4]=="reduction" then value=1-value end
            if item[4]~="number" and item[4]~="yards" then value=value*100 end
            return string.format(item[3],value)
        end
        table.insert(rows,{item[1],format,item[5],item[6]})
    end
    table.insert(sections,{title=title,color=color,rows=rows})
end
Group("Offense",{1,0.45,0.25},{
    {"Damage","dmg","%+.0f%%","bonus","Damage increase from the current run's modifiers."},
    {"Crit","crit","%.1f%%","percent","Chance to deal a critical hit."},
    {"Crit Dmg","cm","%.0f%%","percent","Damage multiplier for critical hits."},
    {"Haste","cd","%+.0f%%","reduction","Reduction to ability cooldowns."},
    {"Echo","echo","%.0f%%","percent","Chance for an additional spell hit."}})
Group("Reach",{0.72,0.45,1},{
    {"Area","area","%+.0f%%","bonus","Increase to spell area and reach."},
    {"Targets","cnt","+%d","number","Additional enemies selected by an ability."},
    {"Pickup","pick","%.0f yd","yards","Radius for collecting experience and gold."}})
Group("Defense",{0.3,0.65,1},{
    {"Health","hp","%.0f","number","Maximum health."},
    {"Armor","arm","%.0f%%","percent","Incoming damage reduction."},
    {"Regen","reg","%.1f","number","Health restored per second."},
    {"Lifesteal","lch","%.1f%%","percent","Damage converted into healing."},
    {"Kill Heal","heal","%.0f","number","Health restored by each kill."},
    {"Thorns","thn","%.0f%%","percent","Melee damage returned to attackers."},
    {"Lives","liv","%d","number","Remaining revivals."}})
Group("Utility",{0.35,0.9,0.55},{
    {"Speed","spd","%+.0f%%","bonus","Movement speed increase."},
    {"Experience","xp","%+.0f%%","bonus","Additional experience earned."},
    {"Gold","gold","%+.0f%%","bonus","Additional gold earned."},
    {"Luck","luck","%+.0f%%","percent","Improved upgrade rarity."},
    {"Buff Power","bp","%+.0f%%","percent","Additional strength of temporary buffs."}})
Group("Damage over time",{0.25,0.85,0.85},{
    {"DoT Stacks","dots","%d","number","Maximum stacks of each periodic effect."},
    {"DoT Haste","doth","%+.0f%%","percent","Increase to periodic-effect tick rate."}})
local bonus={}
for _,item in ipairs({{"Vs Elites","big"},{"Execute","exe"},{"Vs Controlled","cc"},{"Vs Afflicted","dotd"},{"Shielded","shd"},{"Melee","auto"},{"Pet Damage","pet"}}) do
    table.insert(bonus,{item[1],item[2],"%+.0f%%","percent","Conditional damage increase: "..item[1]..".",item[2]})
end
Group("Bonus damage",{1,0.82,0},bonus)
C.CharacterStatSections=sections
function C.CharacterStatText(source,values,includeHidden)
    if not includeHidden and (source[1]=="Health" or source[1]=="Lives") then return nil end
    local data=type(values)=="table" and values or {}
    if source[4] and (type(data[source[4]])~="number" or data[source[4]]==0) then return nil end
    local valid=true
    local view=setmetatable({},{__index=function(_,field)
        if type(data[field])=="number" then return data[field] end
        valid=false;return 0
    end})
    local success,text=pcall(source[2],view)
    if not success or not valid then return "-" end
    local _,_,amount=string.find(text,"([%+%-]?%d+%.?%d*)")
    return tonumber(amount)~=0 and text or nil
end
