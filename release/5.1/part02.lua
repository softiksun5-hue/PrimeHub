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
        local capacity = tonumber(server.maxPlayers) or 0
        local freeSlots = math.max(0, capacity - playing)
        if #id < 5 or id == currentJobId or visited[id] or capacity <= playing
            or freeSlots < minFreeSlots or playing < minPlayers or playing > maxPlayersWanted then
            return nil
        end
        local tier = playing >= 8 and "high" or (playing >= 5 and "mid" or "low")
        return {
            id=id, playing=playing, maxPlayers=capacity,
            _primeHubFreeSlots=freeSlots, _primeHubTier=tier,
        }
    end

    local high, mid, low, seen = {}, {}, {}, {}
    local function addServer(raw)
        local server = normalizeQueueEntry(raw)
        if not server or seen[server.id] then return false end
        seen[server.id] = true
        if server._primeHubTier == "high" then high[#high+1] = server
        elseif server._primeHubTier == "mid" then mid[#mid+1] = server
        else low[#low+1] = server end
        return true
    end

    for _, raw in ipairs(state.serverQueue) do addServer(raw) end

    local pagesDesc, pagesAsc, rowsDesc, rowsAsc = 0, 0, 0, 0
    local added = 0
    local function fetchOrder(sortOrder)
        local cursor = ""
        local dirPages = 0
        while dirPages < maxPages do
            local suffix = ""
            if cursor ~= "" then
                local encoded = cursor
                pcall(function() encoded = HttpService:UrlEncode(cursor) end)
                suffix = "&cursor=" .. encoded
            end
            local url = string.format(
                "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100%s",
                tostring(game.PlaceId), tostring(sortOrder), suffix
            )
            local body = httpGetBody(url)
            if not body then
                hopDebug("queue refill HTTP failed order=" .. tostring(sortOrder) .. " page=" .. tostring(dirPages + 1))
                break
            end
            local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
            if not ok or type(decoded) ~= "table" then
                hopDebug("queue refill JSON failed order=" .. tostring(sortOrder) .. " page=" .. tostring(dirPages + 1))
                break
            end
            dirPages = dirPages + 1
            local data = decoded.data or {}
            if sortOrder == "Desc" then pagesDesc=pagesDesc+1; rowsDesc=rowsDesc+#data
            else pagesAsc=pagesAsc+1; rowsAsc=rowsAsc+#data end
            for _, raw in ipairs(data) do if addServer(raw) then added = added + 1 end end
            cursor = tostring(decoded.nextPageCursor or "")
            if cursor == "" or cursor == "nil" then break end
        end
    end

    if (#high + #mid + #low) < refillThreshold or (#high + #mid + #low) < maxCandidates then
        -- Sample both extremes. Dedupe makes overlap harmless when the server pool is small.
        fetchOrder("Desc")
        fetchOrder("Asc")
        if added > 0 then
            shuffleServers(high); shuffleServers(mid); shuffleServers(low)
            state.serverQueueBuiltAt = os.time()
        end
    end

    -- Interleave 8-10 with 5-7. 2-4 only fill the remaining tail.
    local queue, hi, mi = {}, 1, 1
    while #queue < queueTarget and (hi <= #high or mi <= #mid) do
        if hi <= #high then queue[#queue+1]=high[hi]; hi=hi+1 end
        if #queue < queueTarget and mi <= #mid then queue[#queue+1]=mid[mi]; mi=mi+1 end
    end
    local li = 1
    while #queue < queueTarget and li <= #low do queue[#queue+1]=low[li]; li=li+1 end

    state.serverQueue = queue
    state.serverQueueStrategy = HOP_QUEUE_STRATEGY
    saveRuntimeStateImmediate(state)

    local result = {}
    for _, server in ipairs(queue) do
        if #result >= maxCandidates then break end
        result[#result+1] = server
    end

    local selectedHigh, selectedMid, selectedLow = 0, 0, 0
    for _, server in ipairs(result) do
        if server._primeHubT