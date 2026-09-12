-- PrimeHub 6.2 release bootstrap
-- Fixes cross-sea stale server queues that could cause repeated teleport error 771.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.1.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 6.2] Could not download fresh 6.1 base: "..tostring(src))
end

src=string.gsub(src,"6%.1","6.2")

-- Extend the stable runtime patch with PlaceId-scoped server queues.
local marker="local ua=string.find(body,protocolNew,1,true)"
local queuePatch=[======[
uiPatch = uiPatch .. [===[
    local queueInitOld=[====[local function collectUnvisitedServers(maxCandidates)
    local state = loadRuntimeState()
    pruneVisitTimestamps(state)
    state.serverQueue = type(state.serverQueue) == "table" and state.serverQueue or {}
    state.serverQueueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0
    state.serverQueueStrategy = tostring(state.serverQueueStrategy or "")
]====]
    local queueInitNew=[====[local function collectUnvisitedServers(maxCandidates)
    local state = loadRuntimeState()
    pruneVisitTimestamps(state)
    state.serverQueue = type(state.serverQueue) == "table" and state.serverQueue or {}
    state.serverQueueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0
    state.serverQueueStrategy = tostring(state.serverQueueStrategy or "")
    state.serverQueuePlaceId = tostring(state.serverQueuePlaceId or "")
    local currentPlaceId = tostring(game.PlaceId or "")

    -- A JobId belongs to one PlaceId. Never reuse a queue built in another Sea.
    if state.serverQueuePlaceId ~= currentPlaceId then
        state.serverQueue = {}
        state.serverQueueBuiltAt = 0
        state.serverQueuePlaceId = currentPlaceId
        saveRuntimeStateImmediate(state)
        hopDebug("place changed -> server queue cleared for PlaceId=" .. currentPlaceId)
    end
]====]
    src=select(1,replaceLiteral(src,queueInitOld,queueInitNew,true))

    local queueSaveOld=[====[    state.serverQueue = queue
    state.serverQueueStrategy = HOP_QUEUE_STRATEGY
    saveRuntimeStateImmediate(state)]====]
    local queueSaveNew=[====[    state.serverQueue = queue
    state.serverQueueStrategy = HOP_QUEUE_STRATEGY
    state.serverQueuePlaceId = currentPlaceId
    saveRuntimeStateImmediate(state)]====]
    src=select(1,replaceLiteral(src,queueSaveOld,queueSaveNew,true))
]===]

]======]

local a,b=string.find(src,marker,1,true)
if not a then error("[PrimeHub 6.2] Queue scope patch insertion point missing") end
src=string.sub(src,1,a-1)..queuePatch..string.sub(src,a)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 6.2] Release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 6.2] Runtime failed: "..tostring(result)) end
return result
