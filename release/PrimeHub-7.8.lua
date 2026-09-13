-- PrimeHub 7.8 release bootstrap
-- Stable 7.2 + player-drop toggle + reliable teleport persistence.
-- The filter state is resumed through a dedicated PrimeHubResumeOnlyServerSpawnedFruits flag.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.2.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(source, oldText, newText, label)
    local a,b=string.find(source,oldText,1,true)
    if not a then error("[PrimeHub 7.8] patch target missing: "..tostring(label or oldText)) end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1)
end

local function tryReplaceOnce(source, oldText, newText)
    local a,b=string.find(source,oldText,1,true)
    if not a then return source,false end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1),true
end

local function replaceLineRange(source,startAnchor,endAnchor,replacement,label)
    local a=string.find(source,startAnchor,1,true)
    if not a then error("[PrimeHub 7.8] patch range start missing: "..tostring(label)) end
    local b=string.find(source,endAnchor,a,true)
    if not b then error("[PrimeHub 7.8] patch range end missing: "..tostring(label)) end
    local lineEnd=string.find(source,"\n",b,true)
    if lineEnd then lineEnd=lineEnd+1 else lineEnd=#source+1 end
    return string.sub(source,1,a-1)..replacement..string.sub(source,lineEnd)
end

local function patchRuntime78(code)
    -- Resume this setting exactly like AutoSniper/AutoHop/ESP.
    code=replaceOnce(
        code,
        "local __resumeFruitESP = env.PrimeHubResumeFruitESP == true\n",
        "local __resumeFruitESP = env.PrimeHubResumeFruitESP == true\nlocal __resumeOnlyServerSpawnedFruits = env.PrimeHubResumeOnlyServerSpawnedFruits == true\n",
        "resume server-only capture"
    )

    code=replaceOnce(
        code,
        "env.PrimeHubResumeFruitESP = nil\n",
        "env.PrimeHubResumeFruitESP = nil\nenv.PrimeHubResumeOnlyServerSpawnedFruits = nil\n",
        "resume server-only cleanup"
    )

    code=replaceOnce(
        code,
        "env.FruitESP = __resumeAutomation and __resumeFruitESP or false\n",
        "env.FruitESP = __resumeAutomation and __resumeFruitESP or false\nif __resumeAutomation then\n    env.OnlyServerSpawnedFruits = __resumeOnlyServerSpawnedFruits\nelse\n    env.OnlyServerSpawnedFruits = true\nend\n",
        "resume server-only apply"
    )

    -- Do not overwrite the resumed value later in scanner configuration.
    code=replaceOnce(
        code,
        "env.OnlyServerSpawnedFruits = false",
        "if env.OnlyServerSpawnedFruits == nil then env.OnlyServerSpawnedFruits = true end",
        "server-only config"
    )

    -- Critical behavior filter.
    code=replaceOnce(
        code,
        "            elseif isDroppedFruit(object) then",
        "            elseif isDroppedFruit(object) and ((not env.OnlyServerSpawnedFruits) or isWorldModel) then",
        "scanner target condition"
    )

    -- Real UI toggle.
    code=replaceLineRange(
        code,
        "    local serverOnlyRow=card(sniperPage",
        "    label(serverOnlyRow,\"ENABLED\"",
        "    local renderDroppedFruits=makeToggleRow(sniperPage,216,\"Player-dropped fruits\",\"ON = collect player drops. OFF = server WORLD_DROP only.\",function()return not env.OnlyServerSpawnedFruits end,function(v)env.OnlyServerSpawnedFruits=not v end)\n",
        "Player-dropped fruits UI"
    )

    -- Dedicated teleport-resume flag. Do not rely on an ordinary env field surviving teleport.
    code=replaceOnce(
        code,
        "__primeEnv.PrimeHubResumeFruitESP = %s\n\nlocal __base =",
        "__primeEnv.PrimeHubResumeFruitESP = %s\n__primeEnv.PrimeHubResumeOnlyServerSpawnedFruits = %s\n\nlocal __base =",
        "teleport resume server-only state"
    )

    code=replaceOnce(code,[======[
        tostring(env.AutoFruitSniper == true),
        tostring(env.AutoHop == true),
        tostring(env.FruitESP == true)
    )
]======],[======[
        tostring(env.AutoFruitSniper == true),
        tostring(env.AutoHop == true),
        tostring(env.FruitESP == true),
        tostring(env.OnlyServerSpawnedFruits == true)
    )
]======],"teleport resume format args")

    -- Diagnostics only: best effort, never abort runtime.
    code=select(1,tryReplaceOnce(code,[======[
            "[PrimeHub] PrimeHub 7.8 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
]======],[======[
            "[PrimeHub] PrimeHub 7.8 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s serverOnly=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true), tostring(env.OnlyServerSpawnedFruits == true)
]======]))

    code=select(1,tryReplaceOnce(code,[======[
            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets, "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]======],[======[
            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets,
            env.OnlyServerSpawnedFruits and "SERVER_ONLY" or "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]======]))

    code=select(1,tryReplaceOnce(
        code,
        "    AddLog(string.format(\"Automation: Sniper=%s | AutoHop=%s | ESP=%s\", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP)), THEME.muted)",
        "    AddLog(string.format(\"Automation: Sniper=%s | AutoHop=%s | ESP=%s | Drops=%s\", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP), env.OnlyServerSpawnedFruits and \"OFF\" or \"ON\"), THEME.muted)"
    ))

    code=select(1,tryReplaceOnce(
        code,
        "    executorLog(\"SCAN\",string.format(\"scanner mode=%s allFruits=%s dropFilter=OFF | strategy=mixed-v51 queue=%d cooldown=%ss\",env.ScanDescendants and \"descendants\" or \"top-level\",tostring(env.SniperAllFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))",
        "    executorLog(\"SCAN\",string.format(\"scanner mode=%s allFruits=%s dropFilter=%s | strategy=mixed-v51 queue=%d cooldown=%ss\",env.ScanDescendants and \"descendants\" or \"top-level\",tostring(env.SniperAllFruits),env.OnlyServerSpawnedFruits and \"SERVER_ONLY\" or \"OFF\",tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))"
    ))

    code=select(1,tryReplaceOnce(code,[======[
        onlyServerSpawnedFruits = false,
        dropFilter = false,
]======],[======[
        onlyServerSpawnedFruits = env.OnlyServerSpawnedFruits,
        dropFilter = env.OnlyServerSpawnedFruits,
]======]))

    return code
end

local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 7.8] loadstring unavailable") end
local patchedRuntimeSeen=false

local function isFinalRuntime(code)
    return type(code)=="string"
        and #code > 100000
        and string.find(code,"PrimeHub 7.8 | Fruit Sniper",1,true)
        and string.find(code,"local function scanWorkspaceForFruits",1,true)
        and string.find(code,"local function queueReloadAfterTeleport",1,true)
        and string.find(code,"local function makeToggleRow",1,true)
end

local function hookedLoadstring(code,chunkname)
    if isFinalRuntime(code) then
        code=patchRuntime78(code)
        patchedRuntimeSeen=true
    end
    return originalLoadstring(code,chunkname)
end
loadstring=hookedLoadstring

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    loadstring=originalLoadstring
    error("[PrimeHub 7.8] Could not download fresh 7.2 base: "..tostring(src))
end

src=string.gsub(src,"7%.2","7.8")
src=string.gsub(src,"PrimeHub_7_2_RELEASE%.lua","PrimeHub_7_8_RELEASE.lua")
src=string.gsub(src,"PrimeHub_7_2_PATCHED%.lua","PrimeHub_7_8_PATCHED.lua")

local fn,err=originalLoadstring(src)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 7.8] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 7.8] Runtime failed: "..tostring(result)) end
if not patchedRuntimeSeen then error("[PrimeHub 7.8] Final runtime was not patched") end
return result
