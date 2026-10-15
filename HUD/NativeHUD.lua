-- Azeroth Survivors 0.87.0+ supplies these APIs before addon initialization.
-- The clock, encounters and run counters are owned by the game; this module draws them.
nfUIModules:NewMod("RunTimers", 5, function()
    local path = nfUIModules:GetInfoOrCons("tex") .. "timer\\"
    local BAR_WIDTH = 280
    local ROW_HEIGHT = 48
    local PHASES = {
        ready = true, playing = true, choosing = true,
        paused = true, dead = true, victory = true,
    }

    local function IsNumber(value)
        return type(value) == "number" and value >= 0 and value - value == 0
    end

    local function Clock(seconds)
        seconds = math.floor(seconds)
        return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
    end

    local function Read(name)
        if type(getglobal(name)) ~= "function" then return nil end
        local ok, value = pcall(getglobal(name))
        if ok then return value end
        return nil
    end

    local function RunLength()
        local maximum = Read("AZS_GetRunLength")
        if IsNumber(maximum) and maximum > 0 then return maximum end
        -- ReloadUI creates fresh Lua tables, but AZSZONE is only sent once
        -- per run. The recurring AZSRUN line carries the same native final-
        -- boss time in fin, so no guessed duration or local clock is needed.
        local state = AZS_RUN
        if type(state) == "table" and IsNumber(state.fin) and state.fin > 0 then return state.fin end
        return nil
    end

    -- nfUI's flat strip: a shared flat strip for run indicators.
    local function Pill(name, fillName)
        local frame=CreateFrame("Frame",name,UIParent)
        frame:SetWidth(BAR_WIDTH);frame:SetHeight(fillName=="FillYellow" and 24 or 4)
        frame:SetFrameStrata("HIGH");frame:EnableMouse(false)
        local background=frame:CreateTexture(nil,"BACKGROUND")
        background:SetTexture("Interface\\Buttons\\WHITE8X8");background:SetAllPoints(frame)
        background:SetVertexColor(0.05,0.05,0.07,0.95)
        local bar=CreateFrame("StatusBar",nil,frame)
        bar:SetAllPoints(frame);bar:SetWidth(BAR_WIDTH);bar:SetHeight(frame:GetHeight())
        bar:SetMinMaxValues(0,1)
        bar:SetStatusBarTexture(fillName=="FillBlue" and path.."RunGradient.tga" or "Interface\\Buttons\\WHITE8X8")
        bar:SetValue(0)
        local overlay=CreateFrame("Frame",nil,frame)
        overlay:SetAllPoints(frame);overlay:SetFrameLevel(bar:GetFrameLevel()+1)
        local text=overlay:CreateFontString(nil,"OVERLAY")
        text:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        text:SetPoint("BOTTOM",frame,"TOP",0,4);text:SetTextColor(0.9,0.9,0.9)
        frame:Hide()
        return frame,bar,text,overlay
    end

    local run, runBar, runText, overlay = Pill("nfUIModules_RunTimerPill", "FillBlue")
    run:SetPoint("TOP", UIParent, "TOP", 0, -38)
    local tally, tallyBar, tallyTitle, tallyOverlay = Pill("nfUIModules_RunTallyPill", "FillYellow")
    tallyBar:SetValue(1)
    tallyBar:SetAlpha(0)
    tallyTitle:Hide()
    local tallyFields = {}
    local fieldWidth = BAR_WIDTH / 3
    local counters = {
        {key = "kills", label = "Enemies killed", icon = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"},
        {key = "gold", label = "Gold", icon = "Interface\\Icons\\INV_Misc_Coin_01"},
        {key = "chest", label = "Next cache cost (gold)", icon = "Interface\\Icons\\INV_Crate_01"},
    }
    for index, counter in ipairs(counters) do
        local field = CreateFrame("Frame", nil, tallyOverlay)
        field:SetWidth(fieldWidth)
        field:SetHeight(20)
        field:SetPoint("LEFT", tally, "LEFT", 8 + (index - 1) * fieldWidth, 0)
        field:EnableMouse(true)

        local icon = field:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(counter.icon)
        icon:SetTexCoord(0.07,0.93,0.07,0.93)
        icon:SetWidth(18)
        icon:SetHeight(18)
        icon:SetPoint("LEFT", field, "LEFT", 5, 0)

        local text = field:CreateFontString(nil, "OVERLAY")
        text:SetFont("DEFAULT", 12, "OUTLINE")
        text:SetTextColor(1, 0.88, 0.55)
        text:SetWidth(fieldWidth - 48)
        text:SetHeight(18)
        text:SetPoint("CENTER", field, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        local entry = {key = counter.key, label = counter.label, text = text, frame = field}
        table.insert(tallyFields, entry)
        field:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine(entry.label, 1, 0.82, 0)
            GameTooltip:AddLine(entry.text:GetText() or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        field:SetScript("OnLeave", function() GameTooltip:Hide() end)
        field:SetScript("OnHide", function()
            if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
        end)

        if index > 1 then
            local divider = tallyOverlay:CreateTexture(nil, "ARTWORK")
            divider:SetTexture("Interface\\Buttons\\WHITE8X8")
            divider:SetVertexColor(0.9, 0.7, 0.3, 0.6)
            divider:SetWidth(1)
            divider:SetHeight(15)
            divider:SetPoint("LEFT", field, "LEFT", 0, 0)
        end
    end

    -- Independent counter widget. The legacy function name is retained for Apply callers.
    tally:SetPoint("BOTTOM",UIParent,"BOTTOM",0,70)
    local counterLayoutKey
    function nfUIModules.AttachRunTally()
        local width,height=tally:GetWidth(),tally:GetHeight()
        local key=width..":"..height
        if counterLayoutKey~=key then
            counterLayoutKey=key
            local sectionWidth=math.max(1,(width-16)/table.getn(tallyFields))
            for index,entry in ipairs(tallyFields) do
                entry.frame:SetWidth(sectionWidth);entry.frame:SetHeight(height)
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("LEFT",tally,"LEFT",8+(index-1)*sectionWidth,0)
                entry.text:SetWidth(math.max(1,sectionWidth-32))
                entry.text:ClearAllPoints();entry.text:SetPoint("RIGHT",entry.frame,"RIGHT",-4,0)
                entry.text:SetJustifyH("RIGHT")
            end
        end
        return true
    end
    nfUIModules.tally=tally
    nfUIModules.tallyFields=tallyFields
    nfUIModules.AttachRunTally()

    local markers = {}
    local activeRows = {}
    local spareRows = {}
    local createdRows = 0
    local nativeParts = {}
    local inWorld = true
    local pollAge = 0
    local refreshRows = true
    local previousTime
    local previousZone

    local function Shown(value)
        if value == true or value == 1 or value == "1" then return true end
        if value == false or value == 0 or value == "0" then return false end
        return nil
    end

    local function TakeOver(part)
        if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return false end
        local ok, value = pcall(AZS_IsHudShown, part)
        if not ok then return false end
        local shown = Shown(value)
        if shown == nil then return false end
        if not nativeParts[part] then nativeParts[part] = {shown = shown} end
        if shown then
            ok = pcall(AZS_SetHudShown, part, false)
            if not ok then return false end
            local checked, now = pcall(AZS_IsHudShown, part)
            return checked and Shown(now) == false
        end
        return true
    end

    local function Restore(part)
        local original = nativeParts[part]
        if not original or type(AZS_SetHudShown) ~= "function" then return end
        if pcall(AZS_SetHudShown, part, original.shown) then nativeParts[part] = nil end
    end

    local function ClearTally()
        tally:Hide()
        for _, field in ipairs(tallyFields) do field.text:SetText("") end
        Restore("tally")
    end

    local function UpdateTally()
        local state = AZS_RUN
        -- Zero is a valid counter or free cache. Missing fields must not be
        -- replaced by invented values while the native overlay is hidden.
        if type(state) ~= "table" or not IsNumber(state.kills)
            or not IsNumber(state.gold) or not IsNumber(state.chest) then
            ClearTally()
            return
        end
        if not nfUIModules.AttachRunTally() then
            ClearTally()
            return
        end
        for _, field in ipairs(tallyFields) do
            field.text:SetText(tostring(math.floor(state[field.key])))
        end
        tally:Show()
        if not TakeOver("tally") then ClearTally() end
    end

    local function Retire(row)
        row.frame:Hide()
        row.name:SetText("")
        row.health:SetText("")
        row.bar:SetValue(0)
        table.insert(spareRows, row)
    end

    local function ClearRows()
        for key, row in pairs(activeRows) do
            Retire(row)
            activeRows[key] = nil
        end
    end

    local function ReleaseClock()
        run:Hide()
        for _, marker in ipairs(markers) do marker:Hide() end
        Restore("clock")
    end

    local function ReleaseHUD()
        ReleaseClock()
        ClearTally()
        ClearRows()
        Restore("bosses")
        previousTime = nil
        previousZone = nil
        refreshRows = true
    end

    local function UpdateMarkers(maximum)
        local times = {}
        local schedule = AZS_SCHEDULE
        if type(schedule) == "table" then
            -- The complete schedule retains markers for bosses already up/dead.
            for _, entry in ipairs(schedule) do
                if type(entry) == "table" and IsNumber(entry.at) and entry.at > 0 and entry.at <= maximum then
                    table.insert(times, entry.at)
                end
            end
        end
        for index, at in ipairs(times) do
            local marker = markers[index]
            if not marker then
                marker = overlay:CreateTexture(nil, "ARTWORK")
                marker:SetTexture("Interface\\Buttons\\WHITE8X8")
                marker:SetVertexColor(0.9, 0.95, 0.9, 1)
                marker:SetWidth(1)
                marker:SetHeight(runBar:GetHeight()+4)
                markers[index] = marker
            end
            marker:ClearAllPoints()
            if at == maximum then
                marker:SetPoint("RIGHT", runBar, "RIGHT", 0, 0)
            else
                marker:SetPoint("CENTER", runBar, "LEFT", runBar:GetWidth() * at / maximum, 0)
            end
            marker:Show()
        end
        for index = table.getn(times) + 1, table.getn(markers) do markers[index]:Hide() end
    end

    local function EncounterRows()
        -- The API initializes its unit table to {} in each new Lua VM.
        -- Until an actual unit snapshot arrives after /reload, an empty
        -- getter result does not mean the native encounters disappeared.
        if not IsNumber(AZS_UNITS_UPDATED) then return nil end
        local bosses = Read("AZS_GetBosses")
        local guardians = Read("AZS_GetGuardians")
        -- The native "bosses" part includes guardians. Only awake guardians
        -- are fighting; the full list also includes sleeping lairs on the map.
        if type(bosses) ~= "table" or type(guardians) ~= "table" then return nil end
        local entries = {}
        local seen = {}
        local function Append(list, kind)
            for _, entry in ipairs(list) do
                if type(entry) ~= "table" then return false end
                -- Getter flags are booleans; also accept the native 1 form.
                -- Lua considers 0 truthy, so do not test awake by truthiness.
                local engaged = kind ~= "guardian" or entry.awake == true or entry.awake == 1
                if engaged then
                    if not IsNumber(entry.id) or entry.id ~= math.floor(entry.id)
                        or type(entry.name) ~= "string" or entry.name == ""
                        or not IsNumber(entry.hp) or not IsNumber(entry.hpm) or entry.hpm <= 0 then
                        return false
                    end
                    local key = kind .. ":" .. tostring(entry.id)
                    if seen[key] then return false end
                    seen[key] = true
                    table.insert(entries, {key = key, name = entry.name, hp = entry.hp, maximum = entry.hpm})
                end
            end
            return true
        end
        if not Append(bosses, "boss") or not Append(guardians, "guardian") then return nil end
        return entries, seen
    end

    local function NewRow()
        local row = table.remove(spareRows)
        if row then return row end
        createdRows = createdRows + 1
        local frame, bar, name, rowOverlay = Pill("nfUIModules_BossHealthPill" .. tostring(createdRows), "FillWhite")
        bar:SetStatusBarColor(0.86, 0.12, 0.1, 1)
        name:SetFont("DEFAULT", 12, "OUTLINE")
        name:SetWidth(BAR_WIDTH)
        local health = rowOverlay:CreateFontString(nil, "OVERLAY")
        health:SetFont("DEFAULT", 12, "OUTLINE")
        health:SetPoint("CENTER", frame, "CENTER", 0, 0)
        health:SetTextColor(1, 1, 1)
        return {frame = frame, bar = bar, name = name, health = health}
    end

    local function UpdateRows()
        local entries, seen = EncounterRows()
        if not entries then
            ClearRows()
            Restore("bosses")
            return
        end
        for key, row in pairs(activeRows) do
            if not seen[key] then
                Retire(row)
                activeRows[key] = nil
            end
        end
        for index, entry in ipairs(entries) do
            local row = activeRows[entry.key]
            if not row then
                row = NewRow()
                activeRows[entry.key] = row
            end
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOP", run, "BOTTOM", 0, -24 - (index - 1) * ROW_HEIGHT)
            row.bar:SetValue(math.min(1, entry.hp / entry.maximum))
            row.name:SetText(nfUI_AbbreviateName(entry.name))
            row.health:SetText(tostring(math.floor(entry.hp)) .. " / " .. tostring(math.floor(entry.maximum)))
            row.frame:Show()
        end
        if not TakeOver("bosses") then
            ClearRows()
            Restore("bosses")
        end
    end

    local function Update()
        if not inWorld then
            ReleaseHUD()
            return
        end
        -- Out-of-run tables can retain the previous run. Phase must be read
        -- first; no old table values or invented clocks may stand in for it.
        local phase = Read("AZS_GetPhase")
        if not PHASES[phase] then
            ReleaseHUD()
            return
        end
        local seconds = Read("AZS_GetRunTime")
        local maximum = RunLength()
        local zone = type(AZS_ZONE) == "table" and AZS_ZONE.zone or nil
        if previousZone ~= zone or (previousTime and IsNumber(seconds) and seconds < previousTime) then
            ClearRows()
            refreshRows = true
        end
        previousZone = zone
        if IsNumber(seconds) then previousTime = seconds end
        if IsNumber(seconds) and maximum then
            runBar:SetMinMaxValues(0, maximum)
            runBar:SetValue(math.min(maximum, seconds))
            runText:SetText("Run: " .. Clock(seconds) .. " / " .. Clock(maximum))
            run:Show()
            if not TakeOver("clock") then ReleaseClock() end
        else
            ReleaseClock()
        end
        -- A missing zone/clock snapshot must not block valid counters or
        -- encounter lists from reconnecting to their own native HUD parts.
        if refreshRows then
            refreshRows = false
            UpdateTally()
            if run:IsShown() then UpdateMarkers(maximum) end
            UpdateRows()
        end
    end

    local reader = CreateFrame("Frame", "nfUIModules_NativeHUDReader", UIParent)
    reader:RegisterEvent("CHAT_MSG_ADDON")
    reader:RegisterEvent("PLAYER_ENTERING_WORLD")
    reader:RegisterEvent("PLAYER_LEAVING_WORLD")
    reader:RegisterEvent("PLAYER_LOGOUT")
    reader:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            ReleaseHUD()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            refreshRows = true
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 ~= "AZSZONE" and arg1 ~= "AZSRUN" and arg1 ~= "AZSBOSSES" and arg1 ~= "AZSUNITS" then return end
            refreshRows = true
        end
        Update()
    end)
    reader:SetScript("OnUpdate", function()
        -- This accumulator only limits list/marker refreshes. The displayed
        -- clock always comes directly from AZS_GetRunTime(), including pauses.
        pollAge = pollAge + (tonumber(arg1) or 0)
        if pollAge >= 0.1 then
            pollAge = 0
            refreshRows = true
        end
        Update()
    end)
    if nfUIConfig.RegisterMover then
        nfUIConfig.RegisterMover("runTimer","Run timer",run,"runTimer")
        local counterMover=nfUIConfig.RegisterMover("runCounters","Kills / Gold / Cache",tally,"runCounters")
        if counterMover then counterMover.extra=function() nfUIModules.AttachRunTally() end end
    end
    nfUIModules.RefreshNativeHUD=Update
    Update()
end)
