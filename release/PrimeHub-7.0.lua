-- PrimeHub 7.0 release bootstrap
-- Serverhop latency fix on top of stable 6.9.
-- Keep a short-lived candidate queue across hops so transient empty Roblox server-list responses
-- do not stall hopping, while still expiring old JobIds quickly enough to avoid the old 771 problem.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.9.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(src,old,new,label)
    local a,b=string.find(src,old,1,true)
    if not a then error("[PrimeHub 7.0] patch target missing: "..tostring(label or old)) end
    return string.sub(src,1,a-1)..new..string.sub(src,b+1)
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 7.0] Could not download fresh 6.9 base: "..tostring(src))
end

-- Promote the complete proven 6.9 chain. This keeps WORLD_DROP, controlled noclip flight,
-- StoreFruit, fresh-remote teleport persistence and the PlaceId-scoped queue safeguards.
src=string.gsub(src,"6%.9","7.0")
src=string.gsub(src,"PrimeHub_6_9_RELEASE%.lua","PrimeHub_7_0_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_9_PATCHED%.lua","PrimeHub_7_0_PATCHED.lua")

-- 6.8/6.9 cleared the complete candidate queue on every collectUnvisitedServers() call.
-- That removed stale JobIds, but if Roblox temporarily returned zero server rows the script
-- had no fallback and retried for tens of seconds. 7.0 keeps only a SHORT 45-second queue.
-- A different PlaceId or an older queue is still discarded and rebuilt live.
local insertionAnchor="-- Extend 6.8's generated cleanup/flight code with a collision snapshot."
local ia=string.find(src,insertionAnchor,1,true)
if not ia then error("[PrimeHub 7.0] queue patch insertion anchor missing") end

local queuePatch=[======[
local queueFreshOld=[====[    local freshBlock=[====[    -- PrimeHub 7.0: never reuse stale JobIds between hops.
    state.serverQueue = {}
    state.serverQueueBuiltAt = 0
    state.serverQueuePlaceId = tostring(game.PlaceId or "")

]====]
]====]
local queueFreshNew=[====[    local freshBlock=[====[    -- PrimeHub 7.0: reuse only a very recent candidate list.
    -- This prevents transient empty server-list API responses from stalling serverhop,
    -- without bringing back the old long-lived stale queue / frequent 771 behavior.
    local currentQueuePlaceId = tostring(game.PlaceId or "")
    local queueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0
    local queueAge = queueBuiltAt > 0 and math.max(0, os.time() - queueBuiltAt) or math.huge
    local queueFreshTtl = math.max(15, tonumber(env.HopQueueFreshTtl) or 45)

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
]====]
local qa,qb=string.find(src,queueFreshOld,1,true)
if not qa then error("[PrimeHub 7.0] short-lived queue target missing") end
src=string.sub(src,1,qa-1)..queueFreshNew..string.sub(src,qb+1)

]======]

src=string.sub(src,1,ia-1)..queuePatch..string.sub(src,ia)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 7.0] Base compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 7.0] Runtime failed: "..tostring(result)) end
return result
