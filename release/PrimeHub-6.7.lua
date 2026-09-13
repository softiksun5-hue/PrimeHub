-- PrimeHub 6.7 release bootstrap
-- Critical fixes only:
-- 1) every server hop queues a fresh remote 6.7 reload (old 5.3 local payload can never win),
-- 2) server candidates are rebuilt from the live Roblox server list on every hop to reduce 771.
-- WORLD_DROP scanner/pickup/store logic is inherited unchanged from the proven 6.5 patch.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.5.lua"
local RELEASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.7.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceRange(src, firstAnchor, secondAnchor, replacement)
    local a=string.find(src,firstAnchor,1,true)
    if not a then error("[PrimeHub 6.7] patch anchor missing: "..tostring(firstAnchor)) end
    local b=string.find(src,secondAnchor,a,true)
    if not b then error("[PrimeHub 6.7] patch end anchor missing: "..tostring(secondAnchor)) end
    return string.sub(src,1,a-1)..replacement..string.sub(src,b)
end

local function patchRuntime67(src)
    -- Completely replace the legacy local-file teleport reload. The executor receives ONLY
    -- this fresh 6.7 remote loader, so PrimeHub_5_3_PATCHED.lua is never executed again.
    local queueNew=[====[
local function queueReloadAfterTeleport()
    local queueFn = getQueueOnTeleport()
    if not queueFn then
        AddLog("queue_on_teleport unavailable; script will not auto-reload after hop.", Color3.fromRGB(255, 200, 0))
        return false
    end

    local teleportPayload = string.format([==[
local __primeEnv = (type(getgenv) == "function" and getgenv()) or _G
__primeEnv.PrimeHubTeleportResume = true
__primeEnv.PrimeHubResumeAutoFruitSniper = %s
__primeEnv.PrimeHubResumeAutoHop = %s
__primeEnv.PrimeHubResumeFruitESP = %s

local __base = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.7.lua"
local __url = __base .. "?cb=" .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
local __ok, __src = pcall(function()
    return game:HttpGet(__url, false)
end)
if not __ok or type(__src) ~= "string" or #__src < 100 then
    error("[PRIMEHUB-BOOT 6.7] Could not download fresh release: " .. tostring(__src))
end
__primeEnv.PrimeHubPublicPayloadSource = __src
local __fn, __err = loadstring(__src)
if not __fn then
    error("[PRIMEHUB-BOOT 6.7] Release compile failed: " .. tostring(__err))
end
return __fn()
]==],
        tostring(env.AutoFruitSniper == true),
        tostring(env.AutoHop == true),
        tostring(env.FruitESP == true)
    )

    local ok, err = pcall(queueFn, teleportPayload)
    if ok then
        print(string.format(
            "[PrimeHub] PrimeHub 6.7 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
        ))
        return true
    end
    AddLog("Failed to queue teleport payload: " .. tostring(err), Color3.fromRGB(255, 100, 100))
    return false
end

]====]
    src=replaceRange(src,"local function queueReloadAfterTeleport()","local function shortJobId()",queueNew)

    -- 6.2 already scopes queues by PlaceId. 6.7 additionally refuses to trust old JobIds
    -- from a previous hop. Clear the candidate cache immediately before candidate selection,
    -- forcing collectUnvisitedServers() to fetch the live Roblox server list every time.
    local collectAnchor="local function collectUnvisitedServers(maxCandidates)"
    local ca=string.find(src,collectAnchor,1,true)
    if not ca then error("[PrimeHub 6.7] collectUnvisitedServers anchor missing") end
    local visitedAnchor="    local visited = makeVisitedSet(state)"
    local va=string.find(src,visitedAnchor,ca,true)
    if not va then error("[PrimeHub 6.7] fresh queue insertion point missing") end
    local freshBlock=[====[    -- PrimeHub 6.7: never reuse stale JobIds between hops.
    state.serverQueue = {}
    state.serverQueueBuiltAt = 0
    state.serverQueuePlaceId = tostring(game.PlaceId or "")

]====]
    src=string.sub(src,1,va-1)..freshBlock..string.sub(src,va)
    return src
end

-- 6.5 applies the proven WORLD_DROP patch immediately before compiling the final runtime.
-- Put our hook underneath it: 6.5 patches WORLD_DROP first, then this hook patches only
-- teleport persistence + fresh server candidates.
local originalLoadstring67=loadstring
if type(originalLoadstring67)~="function" then error("[PrimeHub 6.7] loadstring unavailable") end
local runtimePatched67=false

local function hookedLoadstring67(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 6.7 | Fruit Sniper",1,true) then
        code=patchRuntime67(code)
        runtimePatched67=true
    end
    return originalLoadstring67(code,chunkname)
end
loadstring=hookedLoadstring67

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    loadstring=originalLoadstring67
    error("[PrimeHub 6.7] Could not download fresh 6.5 base: "..tostring(src))
end

-- Promote the proven 6.5 WORLD_DROP implementation to the current public version.
src=string.gsub(src,"6%.5","6.7")
src=string.gsub(src,"PrimeHub_6_5_RELEASE%.lua","PrimeHub_6_7_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_5_PATCHED%.lua","PrimeHub_6_7_PATCHED.lua")

local fn,err=originalLoadstring67(src)
if not fn then
    loadstring=originalLoadstring67
    error("[PrimeHub 6.7] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring67
if not ok then error("[PrimeHub 6.7] Runtime failed: "..tostring(result)) end
if not runtimePatched67 then error("[PrimeHub 6.7] Final runtime patch was not applied") end

-- Kept only for compatibility with old diagnostics. 6.7 server hops no longer load this path.
env.PrimeHubLocalPayloadFile="PrimeHub_6_7_RELEASE.lua"
return result
