ier == "high" then selectedHigh=selectedHigh+1
        elseif server._primeHubTier == "mid" then selectedMid=selectedMid+1
        else selectedLow=selectedLow+1 end
    end
    hopDebug(string.format(
        "strategy=mixed-v51 queue=%d high=%d mid=%d low=%d selected=%d selectedH/M/L=%d/%d/%d pagesDesc=%d pagesAsc=%d rowsDesc=%d rowsAsc=%d added=%d cooldown=%ss",
        #queue, #high, #mid, #low, #result, selectedHigh, selectedMid, selectedLow,
        pagesDesc, pagesAsc, rowsDesc, rowsAsc, added, tostring(env.HopVisitedCooldown)
    ))
    return result
end

]====]
local OLD_REMEMBER=[====[        local currentJobId = tostring(game.JobId or "")
        if currentJobId ~= "" and not currentServerRemembered then
            if rememberVisitedServer(currentJobId) then
                AddLog("Current server " .. currentJobId .. " added to recent cooldown.", Color3.fromRGB(100, 200, 255))
            end
            currentServerRemembered = true
        end]====]
local NEW_REMEMBER=[====[        local currentJobId = tostring(game.JobId or "")
        if currentJobId ~= "" and not currentServerRemembered then
            local population = assessCurrentServerPopulation()
            local customCooldown = nil
            if population.botHeavy then
                customCooldown = tonumber(env.BotServerCooldown) or 14400
                AddLog(string.format(
                    "Bot-heavy server detected (%d/%d accounts <=30d). Extended revisit cooldown: %ds",
                    population.fresh30, population.total, customCooldown
                ), Color3.fromRGB(255, 180, 80))
            end
            if rememberVisitedServer(currentJobId, customCooldown) then
                AddLog("Current server " .. currentJobId .. " added to recent cooldown.", Color3.fromRGB(100, 200, 255))
            end
            currentServerRemembered = true
        end]====]
local OLD_SCAN=[====[executorLog("SCAN",string.format("scanner mode=%s allFruits=%s serverOnly=%s | persistent queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),tostring(env.OnlyServerSpawnedFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))]====]
local NEW_SCAN=[====[executorLog("SCAN",string.format("scanner mode=%s allFruits=%s dropFilter=OFF | strategy=mixed-v51 queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))]====]

local function replaceRange(src, firstAnchor, secondAnchor, replacement)
    local a=string.find(src,firstAnchor,1,true)
    if not a then error("[PrimeHub 5.1] patch anchor missing: "..tostring(firstAnchor)) end
    local b=string.find(src,secondAnchor,a,true)
    if not b then error("[PrimeHub 5.1] patch end anchor missing: "..tostring(secondAnchor)) end
    return string.sub(src,1,a-1)..replacement..string.sub(src,b)
end
local function replaceLiteral(src, oldText, newText, required)
    local a,b=string.find(src,oldText,1,true)
    if not a then
        if required then error("[PrimeHub 5.1] literal patch target missing") end
        return src,false
    end
    return string.sub(src,1,a-1)..newText..string.sub(src,b+1),true
end

local function patchPlain(src)
    -- Visible release is 5.1. PRIMEHUB_VERSION/buildId remain internally 5.0 so the
    -- already deployed license database accepts the same keys without migration.
    src=string.gsub(src,"PrimeHub 5%.0","PrimeHub 5.1")
    src=string.gsub(src,"BLOX FRUITS  •  5%.0","BLOX FRUITS  •  5.1")
    src=string.gsub(src,"Starting v5%.0","Starting v5.1")
    src=string.gsub(src,'"Build: primehub%-5%.0"','"Build: PrimeHub 5.1"')
    src=string.gsub(src,'primeHubVersion = PRIMEHUB_VERSION','primeHubVersion = "5.1"')

    src=replaceRange(src,"-- Stage 11 server-hop tuning.","local TargetFruits = {",NEW_CFG)
    src=replaceRange(src,"local function pruneVisitTimestamps(state)","local function findUnvisitedServer()",NEW_HOP)
    src=string.gsub(src,"elseif placeId == 4442272183 or placeId == 79091703265657 then",
        "elseif placeId == 4442272183 or placeId == 79091703265657 or placeId == 85211729168715 then",1)

    -- Remove the old player-drop rejection from isDroppedFruit.
    src=string.gsub(src,"    if env%.OnlyServerSpawnedFruits and isPlayerDroppedFruit%(tool%) then return false end\n","",1)
    src=select(1,replaceLiteral(src,OLD_REMEMBER,NEW_REMEMBER,true))
    src=select(1,replaceLiteral(src,OLD_SCAN,NEW_SCAN,false))

    -- Queue-on-teleport loads this local 5.1 patcher, not the unpatched old core.
    src=string.gsub(src,"PrimeHub_5_0_SOURCE%.lua",SELF_FILE)
    src=string.gsub(src,"PrimeHub_5_0_PROTECTED%.lua",SELF_FILE)
    return src
end

local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 5.1] loadstring unavailable") end
local patched=false
local function hookedLoadstring(code,chunkname)
    if type(code)=="string" then
        if string.find(code,"PrimeHub 5.0 protected runtime",1,true) then
            code=string.gsub(code,"PrimeHub_5_0_PROTECTED%.lua",SELF_FILE)
        elseif string.find(code,"PrimeHub 5.0 | Fruit Sniper",1,true) then
            code=patchPlain(code)
            patched=true
        end
    end
    return originalLoadstring(code,chunkname)
end

loadstring=hookedLoadstring
local resume=env.PrimeHubTeleportResume==true
local body=nil
if resume and type(isfile)=="function" and type(readfile)=="function" and isfile(OLD_LOCAL) then
    local ok,data=pcall(readfile,OLD_LOCAL)
    if ok and type(data)=="string" and #data>100 then body=data end
end
if not body then
    local ok,data=pcall(function() return game:HttpGet(OLD_URL,true) end)
    if not ok or type(data)~="string" or #data<100 then
        loadstring=originalLoadstring
        error("[PrimeHub 5.1] Could not download base protected core: "..tostring(data))
    end
    body=data
end
local fn,compileErr=originalLoadstring(body)
if not fn then loadstring=originalLoadstring; error("[PrimeHub 5.1] Base protected core compile failed: "..tostring(compileErr)) end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 5.1] Runtime failed: "..tostring(result)) end
if not patched then error("[PrimeHub 5.1] Runtime patch was not applied") end
return result
