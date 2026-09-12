-- PrimeHub 5.1 protected patch release
-- Applies the 5.1 delta in memory over the existing encrypted 5.0 production core.
local env=(type(getgenv)=="function" and getgenv()) or _G
local RELEASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.1.lua"
local OLD_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.0.lua"
local OLD_LOCAL="PrimeHub_5_0_PROTECTED.lua"
local SELF_FILE="PrimeHub_5_1_PATCHED.lua"

-- Save this versioned patcher locally so server hops do not need GitHub again.
local selfSource=env.PrimeHub51PatchSource
if (type(selfSource)~="string" or #selfSource<100) and type(game.HttpGet)=="function" then
    local ok,data=pcall(function() return game:HttpGet(RELEASE_URL,true) end)
    if ok and type(data)=="string" and #data>100 then selfSource=data end
end
if type(selfSource)=="string" and #selfSource>100 and type(writefile)=="function" then
    pcall(writefile,SELF_FILE,selfSource)
end
env.PrimeHub51PatchSource=nil

-- Filter explicitly OFF. Held fruits are still excluded, but world fruits are never
-- rejected just because DroppedBy/DroppedByUserId exists.
env.OnlyServerSpawnedFruits=false
env.BotServerScreening=true
env.BotServerCooldown=14400

local NEW_CFG=[====[-- PrimeHub 5.1 server-hop tuning. Mixed discovery samples both ends of the
-- Roblox public-server list, then interleaves populated and medium servers.
env.HopMinFreeSlots = tonumber(env.HopMinFreeSlots) or 1
env.HopAttemptLimit = tonumber(env.HopAttemptLimit) or 6
env.HopRetryDelay = tonumber(env.HopRetryDelay) or 0.75
env.HopFailureWindow = tonumber(env.HopFailureWindow) or 3
env.InitialHopAfterScan = env.InitialHopAfterScan ~= false
env.SuppressTeleportErrorPrompt = false
env.PrimeHubDebug = env.PrimeHubDebug ~= false
env.HopPreferNativeBrowser = env.HopPreferNativeBrowser ~= false

env.AutoHopInterval = tonumber(env.AutoHopInterval) or 15
env.PostFruitHopDelay = tonumber(env.PostFruitHopDelay) or 3
env.HopVisitedCooldown = tonumber(env.HopVisitedCooldown) or 2400
if env.HopVisitedCooldown == 3600 then env.HopVisitedCooldown = 2400 end
env.HopNoCandidateDelay = tonumber(env.HopNoCandidateDelay) or 2
env.HopQueueTarget = math.max(50, tonumber(env.HopQueueTarget) or 200)
env.HopQueueRefillThreshold = math.max(5, tonumber(env.HopQueueRefillThreshold) or 20)
env.HopQueueMaxPages = math.max(2, tonumber(env.HopQueueMaxPages) or 10)

-- 2-10 remain eligible. 8-10 are deliberately retained, but they are no longer
-- consumed as one giant Desc-only block. 5-7 are mixed with them; 2-4 are fallback.
env.HopQueueMinPlayers = math.max(2, tonumber(env.HopQueueMinPlayers) or 2)
env.HopQueueMaxPlayers = math.max(env.HopQueueMinPlayers, tonumber(env.HopQueueMaxPlayers) or 10)
env.HopPreferredMinPlayers = math.max(env.HopQueueMinPlayers, tonumber(env.HopPreferredMinPlayers) or 5)
env.HopPreferredMaxPlayers = math.min(env.HopQueueMaxPlayers, math.max(env.HopPreferredMinPlayers, tonumber(env.HopPreferredMaxPlayers) or 10))
env.HopPreferredPlayers = tonumber(env.HopPreferredPlayers) or 9
env.HopMinPlayers = env.HopQueueMinPlayers
env.HopMaxPlayers = env.HopQueueMaxPlayers

-- Conservative autoreg-farm detector. It never skips a fruit that is already visible;
-- it only gives an obviously bot-heavy JobId a longer revisit cooldown after scanning.
env.BotServerScreening = env.BotServerScreening ~= false
env.BotServerCooldown = math.max(tonumber(env.HopVisitedCooldown) or 2400, tonumber(env.BotServerCooldown) or 14400)

-- PrimeHub 5.1 scanner: NO player-drop/server-only filter. Every world fruit-like Tool
-- is eligible as long as it is not currently held inside a player character.
env.ScanDescendants = env.ScanDescendants ~= false
env.ScanDebug = env.ScanDebug ~= false
env.ScanDebugNamesLimit = math.max(1, tonumber(env.ScanDebugNamesLimit) or 12)
env.OnlyServerSpawnedFruits = false
if env.SniperAllFruits == nil then env.SniperAllFruits = true end

-- Automatically join a team only when a target fruit is present.
env.AutoTeam = env.AutoTeam ~= false
env.PreferredTeam = (env.PreferredTeam == "Marines" and "Marines") or "Pirates"
env.TeamReadyTimeout = tonumber(env.TeamReadyTimeout) or 10
env.TeamRetryDelay = tonumber(env.TeamRetryDelay) or 0.75

]====]
local NEW_HOP=[====[local HOP_QUEUE_STRATEGY = "mixed-v51"

local function pruneVisitTimestamps(state)
    state.serverVisits = type(state.serverVisits) == "table" and state.serverVisits or {}
    state.serverBlockedUntil = type(state.serverBlockedUntil) == "table" and state.serverBlockedUntil or {}
    local now = os.time()
    local cooldown = math.max(30, tonumber(env.HopVisitedCooldown) or 600)
    local botCooldown = math.max(cooldown, tonumber(env.BotServerCooldown) or cooldown)
    local keepFor = math.max(cooldown * 2, botCooldown * 2)
    for id, ts in pairs(state.serverVisits) do
        ts = tonumber(ts) or 0
        if ts <= 0 or (now - ts) > keepFor then
            state.serverVisits[id] = nil
        end
    end
    for id, untilTs in pairs(state.serverBlockedUntil) do
        untilTs = tonumber(untilTs) or 0
        if untilTs <= now then state.serverBlockedUntil[id] = nil end
    end
end

local function assessCurrentServerPopulation()
    local info = {total=0, fresh7=0, fresh30=0, old180=0, botHeavy=false}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            info.total = info.total + 1
            local age = tonumber(player.AccountAge) or -1
            if age >= 0 and age <= 7 then info.fresh7 = info.fresh7 + 1 end
            if age >= 0 and age <= 30 then info.fresh30 = info.fresh30 + 1 end
            if age >= 180 then info.old180 = info.old180 + 1 end
        end
    end
    local suspiciousNeeded = math.max(3, math.ceil(info.total * 0.60))
    info.botHeavy = env.BotServerScreening == true
        and getCurrentSea() ~= "Sea 1"
        and info.total >= 4
        and info.fresh30 >= suspiciousNeeded
        and info.fresh7 >= 2
    hopDebug(string.format(
        "population total=%d fresh7=%d fresh30=%d old180=%d botHeavy=%s",
        info.total, info.fresh7, info.fresh30, info.old180, tostring(info.botHeavy)
    ))
    return info
end

local function rememberVisitedServer(serverId, customCooldown)
    if serverId == nil or tostring(serverId) == "" then return false end
    serverId = tostring(serverId)

    local state = loadRuntimeState()
    pruneVisitTimestamps(state)

    local now = os.time()
    local normalCooldown = math.max(30, tonumber(env.HopVisitedCooldown) or 600)
    local effectiveCooldown = math.max(normalCooldown, tonumber(customCooldown) or normalCooldown)
    state.serverVisits[serverId] = now
    state.serverBlockedUntil = type(state.serverBlockedUntil) == "table" and state.serverBlockedUntil or {}
    if effectiveCooldown > normalCooldown then
        state.serverBlockedUntil[serverId] = now + effectiveCooldown
    end

    local exists = false
    for _, knownId in ipairs(state.servers) do
        if tostring(knownId) == serverId then exists = true break end
    end
    if not exists then table.insert(state.servers, serverId) end
    while #state.servers > 500 do table.remove(state.servers, 1) end

    state.hops = hopCount
    state.fruits = fruitCount
    state.speed = tonumber(env.TweenSpeed) or 230
    saveRuntimeState(state)
    print(string.format("[HOP] Server %s cooldown until +%ss.", serverId, tostring(math.floor(effectiveCooldown))))
    return true
end

local function makeVisitedSet(state)
    local visited = {}
    state.serverVisits = type(state.serverVisits) == "table" and state.serverVisits or {}
    state.serverBlockedUntil = type(state.serverBlockedUntil) == "table" and state.serverBlockedUntil or {}
    local now = os.time()
    local cooldown = math.max(30, tonumber(env.HopVisitedCooldown) or 600)
    for id, ts in pairs(state.serverVisits) do
        ts = tonumber(ts) or 0
        if ts > 0 and (now - ts) < cooldown then visited[tostring(id)] = true end
    end
    for id, untilTs in pairs(state.serverBlockedUntil) do
        if (tonumber(untilTs) or 0) > now then visited[tostring(id)] = true end
    end
    return visited
end

local function shuffleServers(list)
    local rng = Random.new()
    for i = #list, 2, -1 do
        local j = rng:NextInteger(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function collectUnvisitedServers(maxCandidates)
    local state = loadRuntimeState()
    pruneVisitTimestamps(state)
    state.serverQueue = type(state.serverQueue) == "table" and state.serverQueue or {}
    state.serverQueueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0
    state.serverQueueStrategy = tostring(state.serverQueueStrategy or "")

    -- 5.0 queues were Desc-biased. Drop them exactly once on the 5.1 strategy upgrade.
    if state.serverQueueStrategy ~= HOP_QUEUE_STRATEGY then
        state.serverQueue = {}
        state.serverQueueBuiltAt = 0
        state.serverQueueStrategy = HOP_QUEUE_STRATEGY
        saveRuntimeStateImmediate(state)
        hopDebug("queue strategy changed -> mixed-v51; legacy queue cleared")
    end

    local visited = makeVisitedSet(state)
    local currentJobId = tostring(game.JobId or "")
    local minFreeSlots = math.max(1, tonumber(env.HopMinFreeSlots) or 1)
    local minPlayers = math.max(2, tonumber(env.HopQueueMinPlayers) or 2)
    local maxPlayersWanted = math.max(minPlayers, tonumber(env.HopQueueMaxPlayers) or 10)
    local queueTarget = math.max(50, tonumber(env.HopQueueTarget) or 200)
    local refillThreshold = math.max(5, tonumber(env.HopQueueRefillThreshold) or 20)
    local maxPages = math.max(2, tonumber(env.HopQueueMaxPages) or 10)
    maxCandidates = math.max(1, tonumber(maxCandidates) or tonumber(env.HopAttemptLimit) or 6)

    local function normalizeQueueEntry(server)
        if type(server) ~= "table" then return nil end
        local id = tostring(server.id or "")
        local playing = tonumber(server.playing) or 0
     