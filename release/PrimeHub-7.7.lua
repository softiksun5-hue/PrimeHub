-- PrimeHub 7.7 release bootstrap
-- Stable 7.2 + reliable Player-dropped fruits toggle.
-- Critical behavior patches are strict; cosmetic/debug patches are best-effort and can never abort runtime.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.2.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(source, oldText, newText, label)
    local a,b=string.find(source,oldText,1,true)
    if not a then error("[PrimeHub 7.7] patch target missing: "..tostring(label or oldText)) end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1)
end

local function tryReplaceOnce(source, oldText, newText)
    local a,b=string.find(source,oldText,1,true)
    if not a then return source,false end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1),true
end

local function replaceLineRange(source,startAnchor,endAnchor,replacement,label)
    local a=string.find(source,startAnchor,1,true)
    if not a then error("[PrimeHub 7.7] patch range start missing: "..tostring(label)) end
    local b=string.find(source,endAnchor,a,true)
    if not b then error("[PrimeHub 7.7] patch range end missing: "..tostring(label)) end
    local lineEnd=string.find(source,"\n",b,true)
    if lineEnd then lineEnd=lineEnd+1 else lineEnd=#source+1 end
    return string.sub(source,1,a-1)..replacement..string.sub(source,lineEnd)
end

local function patchRuntime77(code)
    -- 1) Strict server-only by default. User can opt player drops back in from the UI.
    code=replaceOnce(
        code,
        "env.OnlyServerSpawnedFruits = false",
        "if env.OnlyServerSpawnedFruits == nil then env.OnlyServerSpawnedFruits = true end",
        "server-only default"
    )

    -- 2) Critical behavior filter. Ordinary dropped Tool fruits cannot enter targets when OFF.
    code=replaceOnce(
        code,
        "            elseif isDroppedFruit(object) then",
        "            elseif isDroppedFruit(object) and ((not env.OnlyServerSpawnedFruits) or isWorldModel) then",
        "scanner target condition"
    )

    -- 3) Critical UI: replace the old static card with a real clickable toggle.
    code=replaceLineRange(
        code,
        "    local serverOnlyRow=card(sniperPage",
        "    label(serverOnlyRow,\"ENABLED\"",
        "    local renderDroppedFruits=makeToggleRow(sniperPage,216,\"Player-dropped fruits\",\"ON = collect player drops. OFF = server WORLD_DROP only.\",function()return not env.OnlyServerSpawnedFruits end,function(v)env.OnlyServerSpawnedFruits=not v end)\n",
        "Player-dropped fruits UI"
    )

    -- 4) Preserve the preference through queue_on_teleport. These targets are known-good in 7.2.
    code=replaceOnce(
        code,
        "__primeEnv.PrimeHubResumeFruitESP = %s\n\nlocal __base =",
        "__primeEnv.PrimeHubResumeFruitESP = %s\n__primeEnv.OnlyServerSpawnedFruits = %s\n\nlocal __base =",
        "teleport server-only state"
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
]======],"teleport format args")

    -- Everything below is diagnostics only. Never fail the whole script if text differs.
    code=select(1,tryReplaceOnce(code,[======[
            "[PrimeHub] PrimeHub 7.7 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
]======],[======[
            "[PrimeHub] PrimeHub 7.7 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s serverOnly=%s",
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
if type(originalLoadstring)~="function" then error("[PrimeHub 7.7] loadstring unavailable") end
local patchedRuntimeSeen=false

local function isFinalRuntime(code)
    return type(code)=="string"
        and #code > 100000
        and string.find(code,"PrimeHub 7.7 | Fruit Sniper",1,true)
        and string.find(code,"local function scanWorkspaceForFruits",1,true)
        and string.find(code,"local function queueReloadAfterTeleport",1,true)
        and string.find(code,"local function makeToggleRow",1,true)
end

local function hookedLoadstring(code,chunkname)
    if isFinalRuntime(code) then
        local alreadyPatched = string.find(code,"Player-dropped fruits",1,true)
            and string.find(code,"isDroppedFruit(object) and ((not env.OnlyServerSpawnedFruits) or isWorldModel)",1,true)
        if not alreadyPatched then code=patchRuntime77(code) end
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
    error("[PrimeHub 7.7] Could not download fresh 7.2 base: "..tostring(src))
end

-- Promote stable 7.2. Movement, noclip, WORLD_DROP, StoreFruit and fast server queue remain unchanged.
src=string.gsub(src,"7%.2","7.7")
src=string.gsub(src,"PrimeHub_7_2_RELEASE%.lua","PrimeHub_7_7_RELEASE.lua")
src=string.gsub(src,"PrimeHub_7_2_PATCHED%.lua","PrimeHub_7_7_PATCHED.lua")

local fn,err=originalLoadstring(src)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 7.7] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 7.7] Runtime failed: "..tostring(result)) end
if not patchedRuntimeSeen then error("[PrimeHub 7.7] Final runtime was not patched") end
return result
