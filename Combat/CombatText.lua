-- Nameplate discovery and combat-text motion adapted from
-- Ryogin/NameplateSCT-Vanilla v0.5.0b-test (https://github.com/Ryogin/NameplateSCT-Vanilla).
-- Original NameplateSCT copyright (c) 2020 Justwait, MIT License.
-- See Resources/licenses/NameplateSCT-LICENSE.txt for the full upstream notice.

nfUIModules:NewMod("NameplateCombatText", 6, function()
    local ParseCombatEvent = T.ParseNameplateCombatEvent
    local BORDER = "Interface\\Tooltips\\Nameplate-Border"
    local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
    local ATTACK_ICON = "Interface\\Icons\\INV_Sword_04"
    local TEXT_DURATION = 1.45
    local EVENT_SETTLE = 0.08
    local EVENT_FALLBACK_DELAY = 0.16
    local RECENT_PLATE_TIME = 0.65
    local LOSS_TIME = 0.25
    local SCHOOL_COLORS = {
        Physical = {1, 1, 1},
        Holy = {1, 0.90, 0.50},
        Fire = {1, 0.45, 0.15},
        Nature = {0.30, 1, 0.30},
        Frost = {0.40, 0.75, 1},
        Shadow = {0.75, 0.45, 1},
        Arcane = {1, 0.50, 1},
    }
    local COMBAT_EVENTS = {
        "CHAT_MSG_COMBAT_SELF_HITS",
        "CHAT_MSG_COMBAT_SELF_MISSES",
        "CHAT_MSG_COMBAT_PET_HITS",
        "CHAT_MSG_COMBAT_PET_MISSES",
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PET_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
        "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
        "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
    }

    local plates = {}
    local origins = {}
    local activeTexts = {}
    local textPool = {}
    local pending = {}
    local spellTextures = {}
    local missingSpellTextures = {}
    local discoveredChildren = 0
    local arcDirection = 1
    local sctMode = nfUIDB.damageMode == "sct" and "on" or "off"
    -- V controls custom SCT visibility without changing the selected mode.
    -- Natural plate retirement must never truncate a killing-blow animation.
    -- Respect the native saved V state even when this addon initializes after
    -- FrameXML has already shown/hidden its nameplates.
    local enemyPlatesEnabled = NAMEPLATES_ON and true or false

    local function CustomEnabled()
        return sctMode == "on" and enemyPlatesEnabled
    end

    local function ReleaseText(index)
        local text = table.remove(activeTexts, index)
        text.holder:Hide()
        text.visual:Hide()
        text.label:SetText("")
        text.label:Hide()
        text.icon:SetTexture(nil)
        text.icon:Hide()
        text.holder:ClearAllPoints()
        text.origin = nil
        table.insert(textPool, text)
    end

    local function ResetDisplay()
        local index
        for index = table.getn(activeTexts), 1, -1 do ReleaseText(index) end
        pending = {}
        origins = {}
        local _, data
        for _, data in pairs(plates) do data.origin = nil end
        discoveredChildren = 0
    end

    local function IsShownEnemy(plate, data)
        if not CustomEnabled() or not plate:IsShown() then return false end
        if plate.IsVisible and not plate:IsVisible() then return false end
        if not data.bar or not data.bar.GetStatusBarColor then return false end
        local red, green, blue = data.bar:GetStatusBarColor()
        if not red or not green or not blue then return false end
        -- Ignore the green/blue friendly plates enabled by Shift-V.
        if green > red + 0.1 and green > blue + 0.1 then return false end
        if blue > red + 0.1 and blue > green + 0.1 then return false end
        return true
    end

    local function SamplePosition(plate, origin)
        local x, y = plate:GetCenter()
        if not x or not y then return end
        if plate.GetTop then y = plate:GetTop() or y end
        local rootScale = WorldFrame:GetEffectiveScale() or 1
        local plateScale = plate:GetEffectiveScale() or rootScale
        local ratio = plateScale / rootScale
        origin.x = x * ratio - (WorldFrame:GetLeft() or 0)
        origin.y = y * ratio - (WorldFrame:GetBottom() or 0)
    end

    local function SampleHealth(data, origin, now)
        if not data.bar.GetValue or not data.bar.GetMinMaxValues then return end
        local minimum, maximum = data.bar:GetMinMaxValues()
        local value = data.bar:GetValue()
        if not maximum or not minimum or not value or maximum <= minimum then return end
        value = math.max(minimum, math.min(value, maximum))
        if origin.health and origin.maximum == maximum and origin.minimum == minimum then
            local lost = origin.health - value
            if lost > 0 then
                local remaining = 0
                if origin.lossAt and now - origin.lossAt <= LOSS_TIME then
                    remaining = origin.lossRemaining or 0
                end
                origin.lossRemaining = remaining + lost
                origin.lossAt = now
            end
        else
            origin.lossRemaining = 0
            origin.lossAt = nil
        end
        origin.health = value
        origin.minimum = minimum
        origin.maximum = maximum
        -- Original Vanilla can expose percentage-only enemy bars. Do not
        -- equate their 0..100 losses to absolute combat-log damage amounts.
        origin.absoluteHealth = maximum - minimum > 100
    end

    local function RetirePlate(plate)
        local data = plates[plate]
        local origin = data and data.origin
        if not origin then return end
        -- Preserve the last valid coordinates/name/health, before the client
        -- resets or reuses this frame. Active text keeps this incarnation.
        origin.live = false
        origin.hiddenAt = GetTime()
        data.origin = nil
    end

    local function RefreshPlate(plate, data, now)
        if not IsShownEnemy(plate, data) then
            RetirePlate(plate)
            return
        end
        local name = data.nameRegion and data.nameRegion:GetText()
        if not name or name == "" then
            RetirePlate(plate)
            return
        end
        local origin = data.origin
        if origin and origin.name ~= name then
            RetirePlate(plate)
            origin = nil
        end
        if not origin then
            -- A new table for each visibility cycle prevents recycled plates
            -- from moving an old enemy's text onto their new occupant.
            origin = {name = name, live = true, lastSeen = now}
            data.origin = origin
            table.insert(origins, origin)
        end
        origin.lastSeen = now
        SamplePosition(plate, origin)
        SampleHealth(data, origin, now)
    end

    local function DiscoverPlate(plate, now)
        if not plate or not plate.GetRegions or plates[plate] then return end
        local border, glow, name, level, skull, raid = plate:GetRegions()
        local regions = {border, glow, name, level, skull, raid}
        local hasBorder = false
        local index
        for index = 1, table.getn(regions) do
            local region = regions[index]
            if region and region.GetObjectType and region:GetObjectType() == "Texture"
                and region.GetTexture and region:GetTexture() == BORDER then
                hasBorder = true
                break
            end
        end
        if not hasBorder and not plate.nfUIPlateOverlay then return end
        if not name or not name.GetObjectType or name:GetObjectType() ~= "FontString" then
            name = nil
            for index = 1, table.getn(regions) do
                local region = regions[index]
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    local value = region:GetText()
                    if value and value ~= "" and value ~= "??" and not string.find(value, "^%d+$") then
                        name = region
                        break
                    end
                end
            end
        end
        local children = {plate:GetChildren()}
        local bar
        for index = 1, table.getn(children) do
            if children[index].GetObjectType and children[index]:GetObjectType() == "StatusBar" then
                bar = children[index]
                break
            end
        end
        if plate.nfUIPlateOverlay then
            name = plate.nfUIPlateOverlay.stock.name
            bar = plate.nfUIPlateOverlay.stock.health
        end
        if not name or not bar then return end
        local data = {nameRegion = name, bar = bar}
        plates[plate] = data
        HookScript(plate, "OnHide", function() RetirePlate(plate) end)
        HookScript(plate, "OnShow", function()
            RetirePlate(plate)
            RefreshPlate(plate, data, GetTime())
        end)
        HookScript(bar, "OnValueChanged", function()
            RefreshPlate(plate, data, GetTime())
        end)
        RefreshPlate(plate, data, now)
    end

    local function ScanPlates(force)
        if not CustomEnabled() or not WorldFrame then return end
        local now = GetTime()
        local count = WorldFrame:GetNumChildren() or 0
        if count < discoveredChildren then discoveredChildren = 0 end
        if force or count > discoveredChildren then
            local children = {WorldFrame:GetChildren()}
            local first = force and 1 or discoveredChildren + 1
            local index
            for index = first, count do DiscoverPlate(children[index], now) end
            discoveredChildren = count
        end
        -- Snapshot on every frame, rather than every tenth of a second: a
        -- one-shot enemy can disappear between two of the old scans.
        local plate, data
        for plate, data in pairs(plates) do RefreshPlate(plate, data, now) end
        local index
        for index = table.getn(origins), 1, -1 do
            local origin = origins[index]
            if not origin.live and now - (origin.hiddenAt or origin.lastSeen) > RECENT_PLATE_TIME then
                table.remove(origins, index)
            end
        end
    end

    local function UseLoss(origin, info)
        if info.kind ~= "damage" then return end
        if origin.absoluteHealth then
            origin.lossRemaining = math.max(0, (origin.lossRemaining or 0) - info.amount)
        end
        -- Percentage bars cannot be consumed by absolute amounts. Their loss
        -- remains timing evidence for the whole short combat-message burst.
    end

    local function ResolveOrigin(info, now, allowFallback)
        local candidates = {}
        local losses = {}
        local exact = {}
        local index
        for index = 1, table.getn(origins) do
            local origin = origins[index]
            if origin.name == info.targetName and origin.x and origin.y
                and (origin.live or now - (origin.hiddenAt or origin.lastSeen) <= RECENT_PLATE_TIME) then
                table.insert(candidates, origin)
                if info.kind == "damage" and origin.lossAt and now - origin.lossAt <= LOSS_TIME
                    and (origin.lossRemaining or 0) > 0 then
                    table.insert(losses, origin)
                    if origin.absoluteHealth then
                        local remaining = origin.lossRemaining
                        local lethal = origin.health <= origin.minimum and info.amount >= remaining
                        if math.abs(remaining - info.amount) < 0.5 or lethal then
                            table.insert(exact, origin)
                        end
                    end
                end
            end
        end
        local origin
        if table.getn(exact) == 1 then origin = exact[1]
        elseif table.getn(losses) == 1 then origin = losses[1]
        elseif table.getn(candidates) == 1 then origin = candidates[1] end
        if origin then
            UseLoss(origin, info)
            return origin.x, origin.y, origin
        end
        if not allowFallback then return nil end
        -- The 1.12 chat API has no destination GUID. Keep every event visible,
        -- even when it cannot distinguish identical names or no plate was
        -- rendered before a lethal hit. A shared origin avoids claiming
        -- an arbitrary enemy is the exact destination.
        local shared = table.getn(losses) > 0 and losses or candidates
        local total = table.getn(shared)
        if total > 0 then
            local x, y = 0, 0
            for index = 1, total do
                x = x + shared[index].x
                y = y + shared[index].y
            end
            return x / total, y / total, nil
        end
        return WorldFrame:GetWidth() * 0.5, WorldFrame:GetHeight() * 0.58, nil
    end

    local function RebuildSpellTextures(keepMisses)
        spellTextures = {}
        if not keepMisses then missingSpellTextures = {} end
        local book = BOOKTYPE_SPELL or "spell"
        local tab
        for tab = 1, GetNumSpellTabs() or 0 do
            local _, _, offset, count = GetSpellTabInfo(tab)
            local index
            for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name = GetSpellName(index, book)
                local texture = GetSpellTexture(index, book)
                if name and texture then spellTextures[name] = texture end
            end
        end
    end

    local function CombatIcon(info)
        if info.spell and info.spell ~= "" then
            local texture = spellTextures[info.spell]
            if not texture and not missingSpellTextures[info.spell] then
                RebuildSpellTextures(true)
                texture = spellTextures[info.spell]
                missingSpellTextures[info.spell] = not texture
            end
            return texture or FALLBACK_ICON
        end
        if info.damageType == "autoattack" then
            return GetInventoryItemTexture("player", 16) or ATTACK_ICON
        end
        return FALLBACK_ICON
    end

    local function AcquireText()
        -- All accepted hits get their full lifetime, even in a large AoE pack.
        -- The pool grows to peak concurrency; active entries are never evicted.
        local text = table.remove(textPool)
        if not text then
            local holder = CreateFrame("Frame", nil, WorldFrame)
            holder:Hide()
            holder:SetWidth(1)
            holder:SetHeight(1)
            holder:SetFrameStrata("HIGH")
            holder:EnableMouse(false)
            local visual = CreateFrame("Frame", nil, holder)
            visual:SetWidth(240)
            visual:SetHeight(60)
            visual:SetPoint("CENTER", holder, "CENTER", 0, 0)
            visual:EnableMouse(false)
            local label = visual:CreateFontString(nil, "OVERLAY")
            label:SetFont("DEFAULT", 18, "OUTLINE")
            label:SetShadowOffset(1, -1)
            label:SetPoint("CENTER", visual, "CENTER", 0, 0)
            local icon = visual:CreateTexture(nil, "OVERLAY")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetPoint("RIGHT", label, "LEFT", -3, 0)
            icon:SetWidth(18)
            icon:SetHeight(18)
            -- SCT contains only the hit and its icon. Repeating the enemy's
            -- name here made fallback hits grow another name during crit pop.
            text = {holder = holder, visual = visual, label = label, icon = icon}
        end
        return text
    end

    local function DisplayDamage(info, x, y, origin)
        local value = info.text or info.amount
        if not value then return end
        local text = AcquireText()
        text.origin = origin
        text.x, text.y = x, y
        text.started = GetTime()
        text.impact = info.critical or info.kind == "miss"
        text.sizeScale = info.critical and 1.5 or 1
        text.arcX = arcDirection * math.random(36, 64)
        text.launch = math.random(105, 130)
        text.gravity = text.launch + 65
        arcDirection = -arcDirection
        local color = SCHOOL_COLORS[info.school]
        if info.kind == "miss" or not color then color = {1, 0.82, 0} end
        text.label:SetText(tostring(value))
        text.label:SetTextColor(color[1], color[2], color[3])
        text.label:Show()
        local texture=CombatIcon(info)
        if type(texture)=="string" and not string.find(string.lower(texture),"inv_misc_questionmark",1,true) then
            text.icon:SetTexture(texture);text.icon:Show()
        else
            text.icon:SetTexture(nil);text.icon:Hide()
        end
        text.visual:SetScale(text.sizeScale * (text.impact and 0.5 or 1))
        text.visual:Show()
        text.holder:SetAlpha(1)
        text.holder:ClearAllPoints()
        text.holder:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y + 12)
        text.holder:Show()
        table.insert(activeTexts, text)
    end

    local function UpdatePending(now)
        local index = 1
        while index <= table.getn(pending) do
            local entry = pending[index]
            local age = now - entry.time
            if age >= EVENT_SETTLE then
                local x, y, origin = ResolveOrigin(entry.info, now, age >= EVENT_FALLBACK_DELAY)
                if x and y then
                    DisplayDamage(entry.info, x, y, origin)
                    table.remove(pending, index)
                else
                    index = index + 1
                end
            else
                index = index + 1
            end
        end
    end

    local function UpdateTexts(now)
        local index
        for index = table.getn(activeTexts), 1, -1 do
            local text = activeTexts[index]
            local progress = (now - text.started) / TEXT_DURATION
            if progress >= 1 then
                ReleaseText(index)
            else
                -- While live, follow this exact plate incarnation. Once it
                -- retires, its stored position remains and the arc keeps going.
                if text.origin then text.x, text.y = text.origin.x, text.origin.y end
                local x = text.x + text.arcX * progress
                local y = text.y + 12 + text.launch * progress - text.gravity * progress * progress
                text.holder:ClearAllPoints()
                text.holder:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y)
                local scale = text.sizeScale
                if text.impact and progress < 1 / 6 then
                    local pop = progress * 6
                    if pop < 0.5 then
                        scale = scale * (0.5 + 1.5 * (1 - math.pow(1 - pop * 2, 5)))
                    else
                        scale = scale * (2 - math.pow((pop - 0.5) * 2, 5))
                    end
                end
                -- Only the inner visual scales: its world-space origin stays
                -- fixed during crit pop, including after the mob has died.
                text.visual:SetScale(scale)
                local alpha = 1
                if progress > 0.68 then alpha = (1 - progress) / 0.32 end
                text.holder:SetAlpha(alpha)
            end
        end
    end

    local function HandleCombatEvent(eventName, message)
        if not CustomEnabled() then return end
        ScanPlates(false)
        local info = ParseCombatEvent(eventName, message)
        if not info or info.kind == "aura" or not info.targetName or info.targetName == "" then return end
        table.insert(pending, {info = info, time = GetTime()})
    end

    local function ApplyDamageMode()
        local nativeDamage = nfUIDB.damageMode == "default" and "1" or "0"
        if GetCVar("CombatDamage") ~= nativeDamage then SetCVar("CombatDamage", nativeDamage) end
    end

    local function SelectMode(mode)
        sctMode = mode
        nfUIDB.damageMode = mode == "on" and "sct" or mode == "default" and "default" or "off"
        nfUIDB.damageText = mode ~= "off"
        if nfUIConfig.ApplyDamageText then nfUIConfig.ApplyDamageText() end
        -- Drop both active and queued custom hits immediately when changing
        -- modes, so switching to vanilla never produces overlapping displays.
        ResetDisplay()
        ApplyDamageMode()
        if sctMode == "on" then
            RebuildSpellTextures()
            ScanPlates(true)
        end
    end

    local frame = CreateFrame("Frame", "nfUIModules_NameplateCombatText")
    local index
    for index = 1, table.getn(COMBAT_EVENTS) do frame:RegisterEvent(COMBAT_EVENTS[index]) end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("CVAR_UPDATE")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            ResetDisplay()
            ApplyDamageMode()
            if sctMode == "on" then RebuildSpellTextures() end
            if CustomEnabled() then ScanPlates(true) end
        elseif event == "SPELLS_CHANGED" then
            if sctMode == "on" then RebuildSpellTextures() end
        elseif event == "PLAYER_TARGET_CHANGED" then
            if CustomEnabled() then ScanPlates(true) end
        elseif event == "CVAR_UPDATE" then
            ApplyDamageMode()
        else
            HandleCombatEvent(event, arg1)
        end
    end)
    frame:SetScript("OnUpdate", function()
        if not CustomEnabled() then return end
        ScanPlates(false)
        local now = GetTime()
        UpdatePending(now)
        UpdateTexts(now)
    end)

    hooksecurefunc("HideNameplates", function()
        enemyPlatesEnabled = false
        ResetDisplay()
    end)
    hooksecurefunc("ShowNameplates", function()
        enemyPlatesEnabled = true
        ScanPlates(true)
    end)

    nfUIModules.SelectDamageMode = SelectMode
    ApplyDamageMode()
    RebuildSpellTextures()
    ScanPlates(true)
end)
