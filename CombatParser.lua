-- Native WoW 1.12 combat parsing adapted from Ryogin/NameplateSCT-Vanilla.
-- https://github.com/Ryogin/NameplateSCT-Vanilla
-- Original NameplateSCT copyright (c) 2020 Justwait, MIT License.
-- The full upstream license is retained with this addon.

local patternCache = {}

local function EscapePatternCharacter(character)
    if string.find(character, "[%^%$%(%)%.%[%]%*%-%+%?]") then
        return "%" .. character
    end
    return character
end

-- Derive patterns from the client's own localized combat strings. Positional
-- format arguments can appear in a different order in translated clients.
local function CompileGlobalPattern(globalName)
    if patternCache[globalName] ~= nil then
        return patternCache[globalName] or nil
    end

    local formatString = getglobal(globalName)
    if not formatString or formatString == "" then
        patternCache[globalName] = false
        return nil
    end

    local search = "^"
    local capturesByArgument = {}
    local captureCount = 0
    local index = 1
    local length = string.len(formatString)

    while index <= length do
        local character = string.sub(formatString, index, index)
        if character ~= "%" then
            search = search .. EscapePatternCharacter(character)
            index = index + 1
        elseif string.sub(formatString, index + 1, index + 1) == "%" then
            search = search .. "%%"
            index = index + 2
        else
            local ending = index + 1
            local formatCode = "%"
            local valueType = nil
            while ending <= length do
                local formatCharacter = string.sub(formatString, ending, ending)
                formatCode = formatCode .. formatCharacter
                if string.find(formatCharacter, "[cEefgGiouXxqsd]") then
                    valueType = formatCharacter
                    break
                end
                ending = ending + 1
            end

            if not valueType then
                search = search .. "%%"
                index = index + 1
            else
                captureCount = captureCount + 1
                local _, _, explicitPosition = string.find(formatCode, "(%d+)%$")
                local position = explicitPosition and tonumber(explicitPosition) or captureCount
                capturesByArgument[position] = captureCount
                -- The base client's unknown spell fallback can be an empty
                -- name; its damage still belongs in SCT with the fallback icon.
                search = search .. (valueType == "d" and "(%d+)" or "(.*)")
                index = ending + 1
            end
        end
    end

    local pattern = {search = search, capturesByArgument = capturesByArgument}
    patternCache[globalName] = pattern
    return pattern
end

local function CaptureGlobal(message, globalName, fields)
    local pattern = CompileGlobalPattern(globalName)
    if not pattern then return nil end

    local startPosition, _, first, second, third, fourth, fifth, sixth = string.find(message, pattern.search)
    if not startPosition then return nil end
    local captures = {first, second, third, fourth, fifth, sixth}
    local result = {}
    local index
    for index = 1, table.getn(fields) do
        local field = fields[index]
        local captureIndex = pattern.capturesByArgument[index] or index
        if field == "amount" then
            result.amount = tonumber(captures[captureIndex])
        else
            result[field] = captures[captureIndex]
        end
    end
    return result
end

-- PET combat categories are already restricted to units owned by the player.
-- Their wording uses OTHEROTHER rather than SELFOTHER, with the source first.
local function CaptureOutgoing(message, stem, fields, pet)
    if not pet then return CaptureGlobal(message, stem .. "SELFOTHER", fields) end
    local namedFields = {"sourceName"}
    local index
    for index = 1, table.getn(fields) do
        table.insert(namedFields, fields[index])
    end
    return CaptureGlobal(message, stem .. "OTHEROTHER", namedFields)
end

local function IsKnownOwnedSource(data)
    if not data or not data.sourceName or not UnitName then return nil end
    return data.sourceName == UnitName("player") or data.sourceName == UnitName("pet")
end

local function CanonicalSchool(localizedSchool)
    if not localizedSchool then return "Physical" end
    if SPELL_SCHOOL0_CAP and localizedSchool == SPELL_SCHOOL0_CAP then return "Physical" end
    if SPELL_SCHOOL1_CAP and localizedSchool == SPELL_SCHOOL1_CAP then return "Holy" end
    if SPELL_SCHOOL2_CAP and localizedSchool == SPELL_SCHOOL2_CAP then return "Fire" end
    if SPELL_SCHOOL3_CAP and localizedSchool == SPELL_SCHOOL3_CAP then return "Nature" end
    if SPELL_SCHOOL4_CAP and localizedSchool == SPELL_SCHOOL4_CAP then return "Frost" end
    if SPELL_SCHOOL5_CAP and localizedSchool == SPELL_SCHOOL5_CAP then return "Shadow" end
    if SPELL_SCHOOL6_CAP and localizedSchool == SPELL_SCHOOL6_CAP then return "Arcane" end
    return localizedSchool
end

local function Damage(data, damageType, critical, periodic, reflected)
    if not data or not data.amount or data.amount <= 0
        or not data.targetName or data.targetName == "" then return nil end
    data.kind = "damage"
    data.damageType = periodic and "periodic" or (reflected and "reflected" or damageType)
    data.school = CanonicalSchool(data.school)
    data.critical = critical and 1 or nil
    data.periodic = periodic and 1 or nil
    return data
end

local function Miss(data, result, damageType, periodic)
    if not data then return nil end
    data.kind = "miss"
    data.damageType = damageType
    data.text = result
    data.periodic = periodic and 1 or nil
    return data
end

local meleeMissPatterns = {
    {"MISSED", "MISS"},
    {"VSDODGE", "DODGE"},
    {"VSPARRY", "PARRY"},
    {"VSBLOCK", "BLOCK"},
    {"VSABSORB", "ABSORB"},
    {"VSRESIST", "RESIST"},
    {"VSIMMUNE", "IMMUNE"},
    {"VSEVADE", "EVADE"},
    {"VSDEFLECT", "DEFLECT"},
}

local spellMissPatterns = {
    {"SPELLMISS", "MISS", "spell"},
    {"SPELLDODGED", "DODGE", "ability"},
    {"SPELLPARRIED", "PARRY", "ability"},
    {"SPELLBLOCKED", "BLOCK", "ability"},
    {"SPELLRESIST", "RESIST", "spell"},
    {"SPELLLOGABSORB", "ABSORB", "spell"},
    {"SPELLIMMUNE", "IMMUNE", "spell"},
    {"SPELLREFLECT", "REFLECT", "spell"},
    {"SPELLEVADED", "EVADE", "ability"},
    {"SPELLDEFLECTED", "DEFLECT", "spell"},
}

local function ParseMeleeHit(message, pet)
    local data = CaptureOutgoing(message, "COMBATHIT", {"targetName", "amount"}, pet)
    if data then return Damage(data, "autoattack") end
    data = CaptureOutgoing(message, "COMBATHITCRIT", {"targetName", "amount"}, pet)
    if data then return Damage(data, "autoattack", 1) end
    data = CaptureOutgoing(message, "COMBATHITSCHOOL", {"targetName", "amount", "school"}, pet)
    if data then return Damage(data, "autoattack") end
    data = CaptureOutgoing(message, "COMBATHITCRITSCHOOL", {"targetName", "amount", "school"}, pet)
    if data then return Damage(data, "autoattack", 1) end
    return nil
end

local function ParseMeleeMiss(message, pet)
    local index
    for index = 1, table.getn(meleeMissPatterns) do
        local pattern = meleeMissPatterns[index]
        local data = CaptureOutgoing(message, pattern[1], {"targetName"}, pet)
        if data then return Miss(data, pattern[2], "autoattack") end
    end
    return nil
end

local function ParseSpell(message, pet)
    local data = CaptureOutgoing(message, "SPELLLOGCRIT", {"spell", "targetName", "amount"}, pet)
    if data then return Damage(data, "ability", 1) end
    data = CaptureOutgoing(message, "SPELLLOG", {"spell", "targetName", "amount"}, pet)
    if data then return Damage(data, "ability") end
    data = CaptureOutgoing(message, "SPELLLOGCRITSCHOOL", {"spell", "targetName", "amount", "school"}, pet)
    if data then return Damage(data, "spell", 1) end
    data = CaptureOutgoing(message, "SPELLLOGSCHOOL", {"spell", "targetName", "amount", "school"}, pet)
    if data then return Damage(data, "spell") end
    data = CaptureOutgoing(message, "SPELLSPLITDAMAGE", {"spell", "targetName", "amount"}, pet)
    if data then return Damage(data, "spell") end

    local index
    for index = 1, table.getn(spellMissPatterns) do
        local pattern = spellMissPatterns[index]
        data = CaptureOutgoing(message, pattern[1], {"spell", "targetName"}, pet)
        if data then return Miss(data, pattern[2], pattern[3]) end
    end
    -- These native immunity families put the target before the source.
    if pet then
        data = CaptureGlobal(message, "IMMUNESPELLOTHEROTHER", {"targetName", "sourceName", "spell"})
    else
        data = CaptureGlobal(message, "IMMUNESPELLSELFOTHER", {"targetName", "spell"})
    end
    if data then return Miss(data, "IMMUNE", "spell") end
    if pet then
        data = CaptureGlobal(message, "IMMUNEDAMAGECLASSOTHEROTHER", {"targetName", "sourceName", "school"})
    else
        data = CaptureGlobal(message, "IMMUNEDAMAGECLASSSELFOTHER", {"targetName", "school"})
    end
    if data then return Miss(data, "IMMUNE", "spell") end
    return nil
end

local function ParsePeriodic(message)
    -- Aura applications provide identity metadata for later periodic ticks.
    -- The stacked form must come first so its count is not part of the spell.
    local data = CaptureGlobal(message, "AURAAPPLICATIONADDEDOTHERHARMFUL", {"targetName", "spell", "stack"})
    if not data then
        data = CaptureGlobal(message, "AURAADDEDOTHERHARMFUL", {"targetName", "spell"})
    end
    if data then
        data.kind = "aura"
        return data
    end

    data = CaptureGlobal(message, "PERIODICAURADAMAGESELFOTHER", {"targetName", "amount", "school", "spell"})
    if data then return Damage(data, "spell", nil, 1) end
    -- Periodic categories describe the victim, so OTHEROTHER may be another
    -- player's damage. Require a known player/pet source in the sentence.
    data = CaptureGlobal(message, "PERIODICAURADAMAGEOTHEROTHER", {"targetName", "amount", "school", "sourceName", "spell"})
    if IsKnownOwnedSource(data) then
        return Damage(data, "spell", nil, 1)
    end
    data = CaptureGlobal(message, "SPELLLOGABSORBSELFOTHER", {"spell", "targetName"})
    if data then return Miss(data, "ABSORB", "periodic", 1) end
    return nil
end

function nfUIModules.tools.ParseNameplateCombatEvent(eventName, message)
    if type(message) ~= "string" or message == "" then return nil end
    if eventName == "CHAT_MSG_COMBAT_SELF_HITS" then
        return ParseMeleeHit(message)
    elseif eventName == "CHAT_MSG_COMBAT_PET_HITS" then
        return ParseMeleeHit(message, 1)
    elseif eventName == "CHAT_MSG_COMBAT_SELF_MISSES" then
        return ParseMeleeMiss(message)
    elseif eventName == "CHAT_MSG_COMBAT_PET_MISSES" then
        return ParseMeleeMiss(message, 1)
    elseif eventName == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        return ParseSpell(message)
    elseif eventName == "CHAT_MSG_SPELL_PET_DAMAGE" then
        return ParseSpell(message, 1)
    elseif eventName == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"
        or eventName == "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE" then
        return ParsePeriodic(message)
    elseif eventName == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"
        or eventName == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS" then
        -- Native shield messages do not identify the originating aura.
        local data = CaptureGlobal(message, "DAMAGESHIELDSELFOTHER", {"amount", "school", "targetName"})
        if data then return Damage(data, "reflected", nil, nil, 1) end
        data = CaptureGlobal(message, "DAMAGESHIELDOTHEROTHER", {"sourceName", "amount", "school", "targetName"})
        if IsKnownOwnedSource(data) then return Damage(data, "reflected", nil, nil, 1) end
        -- Native SPELLLOGMISS packets share the damageshield category.
        data = ParseSpell(message)
        if data then return data end
        data = ParseSpell(message, 1)
        if IsKnownOwnedSource(data) then return data end
    end
    return nil
end
