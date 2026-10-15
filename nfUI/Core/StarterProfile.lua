-- Curated first-launch appearance; positions adapt to UIParent units, including UI scale.
function nfUIBuildStarterProfile(width,height)
    local fit=math.max(0.5,math.min(1,width/(4096/3),height/(2560/3)))
    local profile={
        action={["cooldownFont"]=16,["countFont"]=12,["gap"]=0,["hotkeyFont"]=8,["scale"]=1,["size"]=28},
        auras={["gap"]=3,["size"]=22,["stackFont"]=9,["timeFont"]=10},
        chat={["backdropOpacity"]=0,["editFont"]=13,["editScale"]=0.5,["font"]=13,["height"]=90,["tabFont"]=11,["width"]=325},
        compass=true,
        compassStyle={["anchor"]="TOP",["fullWidth"]=false,["height"]=6,["iconSize"]=22,["labelFont"]=14,["layoutVersion"]=2,["scale"]=1,["width"]=1365.333333},
        damageMode="sct",
        damageText=true,
        debuffs={["gap"]=3,["size"]=18,["stackFont"]=9},
        dpsCollapsed=false,
        dpsDisplay={["autoHeight"]=true,["autoWidth"]=true,["backdropOpacity"]=0.32,["height"]=225,["scale"]=0.7,["width"]=229},
        layout={["scale"]=1,["sectionGap"]=6,["x"]=0,["y"]=-150},
        micro={["scale"]=0.6},
        minimap={["feather"]=46,["scale"]=1.1,["size"]=155},
        moverGrid={["enabled"]=true,["size"]=4},
        nameplates={["abbreviate"]=true,["amount"]="10 max",["collision"]=true,["color"]={[1]=0.4,[2]=0,[3]=0.02352941176},["enabled"]=true,["healthFont"]=8,["healthText"]="Percentage",["height"]=9,["nameFont"]=8,["rankColors"]=false,["scale"]=1,["showNames"]=true,["stacking"]=true,["width"]=100},
        player={["healthArea"]="Middle",["height"]=16,["hideName"]=true,["nameFont"]=14,["portrait"]=36,["powerHeight"]=3,["scale"]=1,["valueFont"]=12,["width"]=195},
        playerStyle={["healthColor"]=true,["healthText"]="CurrentHP+%",["shieldFont"]=10,["shieldHeight"]=7,["showPortrait"]=false,["showShield"]=true},
        runCollapsed=true,
        runDisplay={["backdrop"]=false,["font"]=11,["height"]=320,["layoutVersion"]=1,["scale"]=0.8,["width"]=206},
        statsDisplay={["backdrop"]=false,["font"]=13,["headingFont"]=12,["headings"]=false,["height"]=283,["scale"]=0.75,["stat_Area"]=true,["stat_Armor"]=true,["stat_Buff Power"]=true,["stat_Crit"]=true,["stat_Crit Dmg"]=true,["stat_Damage"]=true,["stat_DoT Haste"]=true,["stat_DoT Stacks"]=true,["stat_Echo"]=true,["stat_Execute"]=true,["stat_Experience"]=true,["stat_Gold"]=true,["stat_Haste"]=true,["stat_Health"]=false,["stat_Kill Heal"]=true,["stat_Lifesteal"]=true,["stat_Lives"]=false,["stat_Luck"]=true,["stat_Melee"]=true,["stat_Pet Damage"]=true,["stat_Pickup"]=true,["stat_Regen"]=true,["stat_Shielded"]=true,["stat_Speed"]=true,["stat_Targets"]=true,["stat_Thorns"]=true,["stat_Vs Afflicted"]=true,["stat_Vs Controlled"]=true,["stat_Vs Elites"]=true,["valueFont"]=13,["width"]=160},
        target={["height"]=19,["nameFont"]=12,["portrait"]=36,["powerHeight"]=3,["scale"]=1,["valueFont"]=11,["width"]=150},
        targetStyle={["healthColor"]=true,["healthText"]="Percentage",["shieldFont"]=10,["shieldHeight"]=3,["showPortrait"]=true,["showShield"]=true},
        xp={["gap"]=0,["height"]=3,["width"]=194},
        sizeMatches={["compass"]={["width"]="runTimer"},["player"]={["width"]="actionBar"},["playerAuras"]={["width"]="actionBar"}},
    }
    local margin=4
    profile.starterPreset=1
    profile.runPanel=true
    profile.nameplatesMigrated=true
    profile.layout.scale=fit
    profile.minimap.scale=profile.minimap.scale*fit
    profile.statsDisplay.scale=math.max(0.5,profile.statsDisplay.scale*fit)
    profile.dpsDisplay.scale=math.max(0.5,profile.dpsDisplay.scale*fit)
    profile.runDisplay.scale=math.max(0.5,profile.runDisplay.scale*fit)
    profile.micro.scale=math.max(0.5,profile.micro.scale*fit)
    profile.chat.width=math.max(180,profile.chat.width*fit)
    profile.chat.height=math.max(60,profile.chat.height*fit)
    profile.compassStyle.width=width
    profile.compassStyle.fullWidth=true
    profile.elements={player={font=16},runCounters={scale=0.8*fit,width=216},runTimer={height=3,scale=1,width=width}}
    profile.settingsWindow={width=math.min(548.23,width),height=math.min(596.6,height)}
    local positions={}
    profile.positions=positions
    local function Clamp(value,maximum) return math.max(margin,math.min(math.max(margin,maximum-margin),value)) end
    local function Place(key,x,y,w,h)
        positions[key]={x=Clamp(x,width-w),y=Clamp(y,height-h)}
    end
    local function CenterX(x) return width/2+(x-2048/3)*fit end
    Place("actionBar",CenterX(586.667),184*fit,196*fit,28*fit)
    Place("player",CenterX(586),213*fit,196*fit,16*fit)
    Place("playerAuras",CenterX(586.667),156*fit,196*fit,22*fit)
    Place("xp",CenterX(587),181*fit,194,3)
    Place("target",CenterX(814.667),312*fit,187*fit,36*fit)
    Place("targetDebuffs",CenterX(896.518),298.667*fit,18*fit,18*fit)
    Place("characterStats",margin,92*fit,160*profile.statsDisplay.scale,283*profile.statsDisplay.scale)
    Place("chat1",6.667*fit,12*fit,profile.chat.width,profile.chat.height)
    Place("chatInput",27*fit,51*fit,325*0.5,20)
    local mapSize=profile.minimap.size*profile.minimap.scale
    Place("minimap",width-mapSize-margin,16*fit,mapSize,mapSize)
    local dpsScale=profile.dpsDisplay.scale
    Place("dpsMeter",width-254.667*fit,margin,math.max(112,profile.dpsDisplay.width)*dpsScale,profile.dpsDisplay.height*dpsScale)
    Place("runCounters",width-174.667*fit,margin,216*0.8*fit,24*0.8*fit)
    -- Run Stats stores its header's upper outside corner and expands upward.
    local runScale=profile.runDisplay.scale
    positions.runPanel={x=width-margin,y=math.min(height-288*runScale-margin,196*fit),runAnchor="TOPRIGHT"}
    positions.runPanel.y=math.max(32*runScale+margin,positions.runPanel.y)
    positions.runTimer={x=0,y=0}
    positions.compass={x=0,y=-12,centered=true}
    Place("tooltip",width-402.667*fit,28*fit,240,90)
    for index,key in ipairs({"CharacterMicroButton","TalentMicroButton","WorldMapMicroButton","MainMenuMicroButton","HelpMicroButton"}) do
        Place(key,margin+(index-1)*25*fit,height-32*fit,24*fit,28*fit)
    end
    for index,key in ipairs({"SpellbookMicroButton","QuestLogMicroButton","SocialsMicroButton"}) do
        Place(key,width-(4-index)*26*fit,margin,24*fit,28*fit)
    end
    return profile
end
