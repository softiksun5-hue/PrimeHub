-- PrimeHub 7.6 release bootstrap
-- Stable 7.2 + reliable Player-dropped fruits toggle.
-- This patch only touches the final readable runtime and uses small structural edits.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.2.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(source, oldText, newText, label)
    local a,b=string.find(source,oldText,1,true)
    if not a then error("[PrimeHub 7.6] patch target missing: "..tostring(label or oldText)) end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1)
end

local function replaceLineRange(source,startAnchor,endAnchor,replacement,label)
    local a=string.find(source,startAnchor,1,true)
    if not a then error("[PrimeHub 7.6] patch range start missing: "..tostring(label)) end
    local b=string.find(source,endAnchor,a,true)
    if not b then error("[PrimeHub 7.6] patch range end missing: "..tostring(label)) end
    local lineEnd=string.find(source,"\n",b,true)
    if lineEnd then lineEnd=lineEnd+1 else lineEnd=#source+1 end
    return string.sub(source,1,a-1)..replacement..string.sub(source,lineEnd)
end

local function patchRuntime76(code)
    -- Fresh/manual launch defaults to strict server-spawn mode. The UI can opt player drops back in.
    code=replaceOnce(
        code,
        "env.OnlyServerSpawnedFruits = false",
        "if env.OnlyServerSpawnedFruits == nil then env.OnlyServerSpawnedFruits = true end",
        "server-only default"
    )

    -- Crucial filter: when SERVER_ONLY is enabled, ordinary world Tool fruits never enter targets.
    -- WORLD_DROP server fruits are Models, so isWorldModel is true only for those targets.
    code=replaceOnce(
        code,
        "            elseif isDroppedFruit(object) then",
        "            elseif isDroppedFruit(object) and ((not env.OnlyServerSpawnedFruits) or isWorldModel) then",
        "scanner target condition"
    )

    -- Replace the old static 'Server-spawn filter ENABLED' card with a real clickable toggle.
    code=replaceLineRange(
        code,
        "    local serverOnlyRow=card(sniperPage",
        "    label(serverOnlyRow,\"ENABLED\"",
        "    local renderDroppedFruits=makeToggleRow(sniperPage,216,\"Player-dropped fruits\",\"ON = collect player drops. OFF = server WORLD_DROP only.\",function()return not env.OnlyServerSpawnedFruits end,function(v)env.OnlyServerSpawnedFruits=not v end)\n",
        "Player-dropped fruits UI"
    )

    -- Carry the preference through queue_on_teleport without touching the proven automation resume block.
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

    code=replaceOnce(code,[======[
            "[PrimeHub] PrimeHub 7.6 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
]======],[======[
            "[PrimeHub] PrimeHub 7.6 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s serverOnly=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true), tostring(env.OnlyServerSpawnedFruits == true)
]======],"teleport log")

    -- Make realtime debug visibly prove whether the filter is active.
    code=replaceOnce(code,[======[
            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets, "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]======],[======[
            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets,
            env.OnlyServerSpawnedFruits and "SERVER_ONLY" or "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
]======],"scanner debug filter")

    code=replaceOnce(
        code,
        "    AddLog(string.format(\"Automation: Sniper=%s | AutoHop=%s | ESP=%s\", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP)), THEME.muted)",
        "    AddLog(string.format(\"Automation: Sniper=%s | AutoHop=%s | ESP=%s | Drops=%s\", tostring(env.AutoFruitSniper), tostring(env.AutoHop), tostring(env.FruitESP), env.OnlyServerSpawnedFruits and \"OFF\" or \"ON\"), THEME.muted)",
        "startup drops log"
    )

    code=replaceOnce(
        code,
        "    executorLog(\"SCAN\",string.format(\"scanner mode=%s allFruits=%s dropFilter=OFF | strategy=mixed-v51 queue=%d cooldown=%ss\",env.ScanDescendants and \"descendants\" or \"top-level\",tostring(env.SniperAllFruits),tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))",
        "    executorLog(\"SCAN\",string.format(\"scanner mode=%s allFruits=%s dropFilter=%s | strategy=mixed-v51 queue=%d cooldown=%ss\",env.ScanDescendants and \"descendants\" or \"top-level\",tostring(env.SniperAllFruits),env.OnlyServerSpawnedFruits and \"SERVER_ONLY\" or \"OFF\",tonumber(env.HopQueueTarget) or 200,tostring(env.HopVisitedCooldown)))",
        "startup scanner filter log"
    )

    code=replaceOnce(code,[======[
        onlyServerSpawnedFruits = false,
        dropFilter = false,
]======],[======[
        onlyServerSpawnedFruits = env.OnlyServerSpawnedFruits,
        dropFilter = env.OnlyServerSpawnedFruits,
]======],"status filter values")

    return code
end

local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 7.6] loadstring unavailable") end
local patchedRuntimeSeen=false

local function isFinalRuntime(code)
    return type(code)=="string"
        and #code > 100000
        and string.find(code,"PrimeHub 7.6 | Fruit Sniper",1,true)
        and string.find(code,"local function scanWorkspaceForFruits",1,true)
        and string.find(code,"local function queueReloadAfterTeleport",1,true)
        and string.find(code,"local function makeToggleRow",1,true)
end

local function hookedLoadstring(code,chunkname)
    if isFinalRuntime(code) then
        local alreadyPatched = string.find(code,"Player-dropped fruits",1,true)
            and string.find(code,"isDroppedFruit(object) and ((not env.OnlyServerSpawnedFruits) or isWorldModel)",1,true)
        if not alreadyPatched then
            code=patchRuntime76(code)
        end
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
    error("[PrimeHub 7.6] Could not download fresh 7.2 base: "..tostring(src))
end

-- Promote the proven 7.2 chain first; movement, noclip, WORLD_DROP and fast queue reuse stay unchanged.
src=string.gsub(src,"7%.2","7.6")
src=string.gsub(src,"PrimeHub_7_2_RELEASE%.lua","PrimeHub_7_6_RELEASE.lua")
src=string.gsub(src,"PrimeHub_7_2_PATCHED%.lua","PrimeHub_7_6_PATCHED.lua")

local fn,err=originalLoadstring(src)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 7.6] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 7.6] Runtime failed: "..tostring(result)) end
if not patchedRuntimeSeen then error("[PrimeHub 7.6] Final runtime was not patched") end
return result
