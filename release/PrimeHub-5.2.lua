-- PrimeHub 5.2 release bootstrap
-- 5.2 patches the proven 5.1 release before it reaches the protected 5.0 core.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.1.lua"
local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 5.2] loadstring unavailable") end

local NEW_SEA=[====[local SEA_PLACE_IDS = {
    ["Sea 1"] = {
        [2753915549] = true,
        [85211729168715] = true,
    },
    ["Sea 2"] = {
        [4442272183] = true,
        [79091703265657] = true,
    },
    ["Sea 3"] = {
        [7449423635] = true,
        [7449925010] = true,
        [100117331123089] = true,
    },
}

local function mapHasAny(names)
    local map = workspace:FindFirstChild("Map")
    if not map then return false end
    for _, name in ipairs(names) do
        if map:FindFirstChild(name, true) then return true end
    end
    return false
end

local function getCurrentSea()
    local placeId = tonumber(game.PlaceId)
    for sea, ids in pairs(SEA_PLACE_IDS) do
        if ids[placeId] then return sea end
    end

    -- Fallback for a future Blox Fruits update with a new PlaceId.
    if mapHasAny({"Castle on the Sea", "Castle On The Sea", "Hydra Island", "Hydra", "Floating Turtle", "Turtle"}) then
        return "Sea 3"
    end
    if mapHasAny({"Cafe", "Kingdom of Rose", "Dressrosa", "Green Zone", "Cursed Ship"}) then
        return "Sea 2"
    end
    if mapHasAny({"Middle Town", "Jungle", "Marine Fortress", "MarineFord", "Fountain City", "Skylands"}) then
        return "Sea 1"
    end
    return "Unknown"
end

]====]

local function literalReplace(src,old,new,required)
    local a,b=string.find(src,old,1,true)
    if not a then
        if required then error("[PrimeHub 5.2] patch target missing") end
        return src,false
    end
    return string.sub(src,1,a-1)..new..string.sub(src,b+1),true
end

local function patch51(code)
    -- Save/reload this exact patched 5.2 patcher across server hops.
    code=string.gsub(code,"PrimeHub 5%.1","PrimeHub 5.2")
    code=string.gsub(code,"PrimeHub%-5%.1%.lua","PrimeHub-5.2.lua")
    code=string.gsub(code,"PrimeHub_5_1_PATCHED%.lua","PrimeHub_5_2_PATCHED.lua")
    code=string.gsub(code,"BLOX FRUITS  •  5%.1","BLOX FRUITS  •  5.2")
    code=string.gsub(code,"Starting v5%.1","Starting v5.2")

    local botOld=[=[    local suspiciousNeeded = math.max(3, math.ceil(info.total * 0.60))
    info.botHeavy = env.BotServerScreening == true
        and getCurrentSea() ~= "Sea 1"]=]
    local botNew=[=[    local suspiciousNeeded = math.max(3, math.ceil(info.total * 0.60))
    local currentSea = getCurrentSea()
    info.botHeavy = env.BotServerScreening == true
        and (currentSea == "Sea 2" or currentSea == "Sea 3")]=]
    code=select(1,literalReplace(code,botOld,botNew,true))

    local marker="local function replaceRange(src, firstAnchor, secondAnchor, replacement)"
    code=select(1,literalReplace(code,marker,"local NEW_SEA_DETECTOR="..string.format("%q",NEW_SEA).."\n"..marker,true))

    local wrong=[=[    src=replaceRange(src,"local function pruneVisitTimestamps(state)","local function findUnvisitedServer()",NEW_HOP)
    src=string.gsub(src,"elseif placeId == 4442272183 or placeId == 79091703265657 then",
        "elseif placeId == 4442272183 or placeId == 79091703265657 or placeId == 85211729168715 then",1)]=]
    local fixed=[=[    src=replaceRange(src,"local function pruneVisitTimestamps(state)","local function findUnvisitedServer()",NEW_HOP)
    src=replaceRange(src,"local function getCurrentSea()","local function getSafeZone()",NEW_SEA_DETECTOR)]=]
    code=select(1,literalReplace(code,wrong,fixed,true))

    local scanOld='executorLog("SCAN",string.format("scanner mode=%s allFruits=%s dropFilter=OFF | strategy=mixed-v51 queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))'
    local scanNew='executorLog("SCAN",string.format("scanner mode=%s allFruits=%s dropFilter=OFF | sea=%s strategy=mixed-v51 queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),tostring(getCurrentSea()),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))'
    code=select(1,literalReplace(code,scanOld,scanNew,false))
    return code
end

local intercepted=false
local function hookedLoadstring(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 5.1 protected patch release",1,true) then
        code=patch51(code)
        -- The inner patcher writes this value to its local SELF_FILE.
        env.PrimeHub51PatchSource=code
        intercepted=true
    end
    return originalLoadstring(code,chunkname)
end

loadstring=hookedLoadstring
local okBody,body=pcall(function() return game:HttpGet(BASE_URL,true) end)
if not okBody or type(body)~="string" or #body<100 then
    loadstring=originalLoadstring
    error("[PrimeHub 5.2] Could not download 5.1 base release: "..tostring(body))
end
local fn,err=originalLoadstring(body)
if not fn then loadstring=originalLoadstring; error("[PrimeHub 5.2] Base release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 5.2] Runtime failed: "..tostring(result)) end
if not intercepted then error("[PrimeHub 5.2] Sea-detection patch was not applied") end
return result
