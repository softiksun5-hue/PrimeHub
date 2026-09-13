-- PrimeHub 7.4 release bootstrap
-- Stable 7.2 + selectable player-drop collection.
-- OFF on "Player-dropped fruits" means strict WORLD_DROP-only collection.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.2.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(source,oldText,newText,label)
    local a,b=string.find(source,oldText,1,true)
    if not a then error("[PrimeHub 7.4] patch target missing: "..tostring(label or oldText)) end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1)
end

local function patchRuntime74(src)
    local old,new

    old=[==========[
local __resumeFruitESP = env.PrimeHubResumeFruitESP == true
env.PrimeHubTeleportResume = nil
env.PrimeHubResumeAutoFruitSniper = nil
env.PrimeHubResumeAutoHop = nil
env.PrimeHubResumeFruitESP = nil

env.AutoFruitSniper = __resumeAutomation and __resumeAutoFruitSniper or false
env.AutoHop = __resumeAutomation and __resumeAutoHop or false
env.FruitESP = __resumeAutomation and __resumeFruitESP or false
]==========]
    new=[==========[
local __resumeFruitESP = env.PrimeHubResumeFruitESP == true
local __resumeOnlyServerSpawnedFruits = env.PrimeHubResumeOnlyServerSpawnedFruits == true
env.PrimeHubTeleportResume = nil
env.PrimeHubResumeAutoFruitSniper = nil
env.PrimeHubResumeAutoHop = nil
env.PrimeHubResumeFruitESP = nil
env.PrimeHubResumeOnlyServerSpawnedFruits = nil

env.AutoFruitSniper = __resumeAutomation and __resumeAutoFruitSniper or false
env.AutoHop = __resumeAutomation and __resumeAutoHop or false
env.FruitESP = __resumeAutomation and __resumeFruitESP or false
env.OnlyServerSpawnedFruits = __resumeAutomation and __resumeOnlyServerSpawnedFruits or false
]==========]
    src=replaceOnce(src,old,new,"resume server-only toggle")

    src=replaceOnce(src,
        "env.OnlyServerSpawnedFruits = false",
        "if env.OnlyServerSpawnedFruits == nil then env.OnlyServerSpawnedFruits = false end",
        "server-only config")

    src=replaceOnce(src,
[==========[__primeEnv.PrimeHubResumeFruitESP = %s

local __base = ]==========],
[==========[__primeEnv.PrimeHubResumeFruitESP = %s
__primeEnv.PrimeHubResumeOnlyServerSpawnedFruits = %s

local __base = ]==========],
        "teleport state")

    old=[==========[        tostring(env.AutoFruitSniper == true),
        tostring(env.AutoHop == true),
        tostring(env.FruitESP == true)
    )]==========]
    new=[==========[        tostring(env.AutoFruitSniper == true),
        tostring(env.AutoHop == true),
        tostring(env.FruitESP == true),
        tostring(env.OnlyServerSpawnedFruits == true)
    )]==========]
    src=replaceOnce(src,old,new,"teleport format args")

    old=[==========[            "[PrimeHub] PrimeHub 7.4 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
]==========]
    new=[==========[            "[PrimeHub] PrimeHub 7.4 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s serverOnly=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true), tostring(env.OnlyServerSpawnedFruits == true)
]==========]
    src=replaceOnce(src,old,new,"teleport log")

    old=[==========[            elseif isDroppedFruit(object) then
                found[#found + 1] = object
                stats.targets = stats.targets + 1
                local resolvedName = fruitNameFromTool(object)
                if resolvedName and not isRecognizedFruitName(resolvedName) then
                    stats.unlistedTargets = stats.unlistedTargets + 1
                end
            end
]==========]
    new=[==========[            elseif isDroppedFruit(object) then
                local allowedByOrigin = (not env.OnlyServerSpawnedFruits) or isWorldModel
                if allowedByOrigin then
                    found[#found + 1] = object
                    stats.targets = stats.targets + 1
                    local resolvedName = fruitNameFromTool(object)
                    if resolvedName and not isRecognizedFruitName(resolvedName) then
                        stats.unlistedTargets = stats.unlistedTargets + 1
                    end
                end
            end
]==========]
    src=replaceOnce(src,old,new,"scanner origin filter")

    old=[==========[            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets, "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]==========]
    new=[==========[            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets,
            env.OnlyServerSpawnedFruits and "SERVER_ONLY" or "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]==========]
    src=replaceOnce(src,old,new,"scanner debug filter")

    old=[==========[    local renderAutoSniper=makeToggleRow(sniperPage,0,"Auto Fruit Sniper","Scans server-spawned fruit and collects it.",function()return env.AutoFruitSniper end,function(v)env.AutoFruitSniper=v end)
    local renderAutoHop=makeToggleRow(sniperPage,72,"Auto Server Hop","Moves through the persistent public-server queue.",function()return env.AutoHop end,function(v)env.AutoHop=v end)
    local renderEsp=makeToggleRow(sniperPage,144,"Fruit ESP","Highlights valid server-spawned fruit.",function()return env.FruitESP end,function(v)env.FruitESP=v;if not v then destroyFruitESP() end end)
    local serverOnlyRow=card(sniperPage,UDim2.new(1,0,0,62),UDim2.new(0,0,0,216))
    label(serverOnlyRow,"Server-spawn filter",UDim2.new(.7,0,0,20),UDim2.new(0,12,0,9),12,THEME.text,true)
    label(serverOnlyRow,"Player-dropped fruit is ignored.",UDim2.new(.7,0,0,16),UDim2.new(0,12,0,32),9,THEME.muted,false)
    label(serverOnlyRow,"ENABLED",UDim2.new(0,90,0,24),UDim2.new(1,-102,.5,-12),9,THEME.good,true,Enum.TextXAlignment.Center)
]==========]
    new=[==========[    local renderAutoSniper=makeToggleRow(sniperPage,0,"Auto Fruit Sniper","Scans valid fruit targets and collects them.",function()return env.AutoFruitSniper end,function(v)env.AutoFruitSniper=v end)
    local renderAutoHop=makeToggleRow(sniperPage,72,"Auto Server Hop","Moves through the persistent public-server queue.",function()return env.AutoHop end,function(v)env.AutoHop=v end)
    local renderEsp=makeToggleRow(sniperPage,144,"Fruit ESP","Highlights valid fruit targets.",function()return env.FruitESP end,function(v)env.FruitESP=v;if not v then destroyFruitESP() end end)
    local renderDroppedFruits=makeToggleRow(sniperPage,216,"Player-dropped fruits","ON = collect drops. OFF = server WORLD_DROP only.",function()return not env.OnlyServerSpawnedFruits end,function(v)env.OnlyServerSpawnedFruits=not v end)
]==========]
    src=replaceOnce(src,old,new,"UI drop toggle")

    old=[==========[    AddLog(string.format("Automation: Sniper=%s | AutoHop=%s | ESP=%s", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP)), THEME.muted)
]==========]
    new=[==========[    AddLog(string.format("Automation: Sniper=%s | AutoHop=%s | ESP=%s | Drops=%s", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP), env.OnlyServerSpawnedFruits and "OFF" or "ON"), THEME.muted)
]==========]
    src=replaceOnce(src,old,new,"startup toggle log")

    old=[==========[    executorLog("SCAN",string.format("scanner mode=%s allFruits=%s dropFilter=OFF | strategy=mixed-v51 queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))
]==========]
    new=[==========[    executorLog("SCAN",string.format("scanner mode=%s allFruits=%s dropFilter=%s | strategy=mixed-v51 queue=%d cooldown=%ss",env.ScanDescendants and "descendants" or "top-level",tostring(env.SniperAllFruits),env.OnlyServerSpawnedFruits and "SERVER_ONLY" or "OFF",tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))
]==========]
    src=replaceOnce(src,old,new,"startup scanner log")

    src=replaceOnce(src,
[==========[        onlyServerSpawnedFruits = false,
        dropFilter = false,
]==========],
[==========[        onlyServerSpawnedFruits = env.OnlyServerSpawnedFruits,
        dropFilter = env.OnlyServerSpawnedFruits,
]==========],
        "status values")

    return src
end

local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 7.4] loadstring unavailable") end
local finalPatched=false

local function hookedLoadstring(code,chunkname)
    if type(code)=="string" and #code > 100000 and string.find(code,"PrimeHub 7.4 | Fruit Sniper",1,true) and string.find(code,"local __resumeAutomation = env.PrimeHubTeleportResume == true",1,true) and string.find(code,"local function scanWorkspaceForFruits",1,true) then
        code=patchRuntime74(code)
        finalPatched=true
    end
    return originalLoadstring(code,chunkname)
end
loadstring=hookedLoadstring

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    loadstring=originalLoadstring
    error("[PrimeHub 7.4] Could not download fresh 7.2 base: "..tostring(src))
end

src=string.gsub(src,"7%.2","7.4")
src=string.gsub(src,"PrimeHub_7_2_RELEASE%.lua","PrimeHub_7_4_RELEASE.lua")
src=string.gsub(src,"PrimeHub_7_2_PATCHED%.lua","PrimeHub_7_4_PATCHED.lua")

local fn,err=originalLoadstring(src)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 7.4] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 7.4] Runtime failed: "..tostring(result)) end
if not finalPatched then error("[PrimeHub 7.4] Final runtime patch was not applied") end
return result