-- PrimeHub 7.2 release bootstrap
-- Safe rebuild of the serverhop latency patch on top of stable 6.9.
-- Uses distinct long-string delimiter levels so generated source cannot terminate early.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.9.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 7.2] Could not download fresh 6.9 base: "..tostring(src))
end

-- Promote the complete proven 6.9 chain first.
src=string.gsub(src,"6%.9","7.2")
src=string.gsub(src,"PrimeHub_6_9_RELEASE%.lua","PrimeHub_7_2_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_9_PATCHED%.lua","PrimeHub_7_2_PATCHED.lua")

local insertionAnchor="-- Extend 6.8's generated cleanup/flight code with a collision snapshot."
local ia=string.find(src,insertionAnchor,1,true)
if not ia then error("[PrimeHub 7.2] queue patch insertion anchor missing") end

-- Delimiter hierarchy:
-- outer generated patch = 10 equals
-- old/new source literals = 8 equals
-- embedded freshBlock in 6.8 = 4 equals
local queuePatchCode=[==========[
local queueFreshOld=[========[
    local freshBlock=[====[    -- PrimeHub 7.2: never reuse stale JobIds between hops.
    state.serverQueue = {}
    state.serverQueueBuiltAt = 0
    state.serverQueuePlaceId = tostring(game.PlaceId or "")

]====]
]========]

local queueFreshNew=[========[
    local freshBlock=[====[    -- PrimeHub 7.2: reuse only a recent server queue.
    local currentQueuePlaceId = tostring(game.PlaceId or "")
    local queueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0
    local queueAge = queueBuiltAt > 0 and math.max(0, os.time() - queueBuiltAt) or math.huge
    local queueFreshTtl = math.max(30, tonumber(env.HopQueueFreshTtl) or 180)

    if tostring(state.serverQueuePlaceId or "") ~= currentQueuePlaceId or queueAge > queueFreshTtl then
        state.serverQueue = {}
        state.serverQueueBuiltAt = 0
    else
        hopDebug(string.format(
            "reusing recent server queue age=%ds size=%d ttl=%ds",
            math.floor(queueAge), #(state.serverQueue or {}), math.floor(queueFreshTtl)
        ))
    end
    state.serverQueuePlaceId = currentQueuePlaceId

]====]
]========]

local qfa,qfb=string.find(src,queueFreshOld,1,true)
if not qfa then error("[PrimeHub 7.2] short-lived queue target missing") end
src=string.sub(src,1,qfa-1)..queueFreshNew..string.sub(src,qfb+1)

]==========]

src=string.sub(src,1,ia-1)..queuePatchCode..string.sub(src,ia)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 7.2] Base compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 7.2] Runtime failed: "..tostring(result)) end
return result
