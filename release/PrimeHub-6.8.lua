-- PrimeHub 6.8 release bootstrap
-- Critical movement fix:
-- 1) preserve 6.7 fresh-remote serverhop persistence (old 5.3 payload can never win),
-- 2) preserve fresh server candidate rebuilds,
-- 3) replace long-distance fruit CFrame teleport spam with controlled flight.
-- WORLD_DROP scanner/pickup/store logic is inherited unchanged from the proven 6.5 patch.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.5.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceRange(src, firstAnchor, secondAnchor, replacement)
    local a=string.find(src,firstAnchor,1,true)
    if not a then error("[PrimeHub 6.8] patch anchor missing: "..tostring(firstAnchor)) end
    local b=string.find(src,secondAnchor,a,true)
    if not b then error("[PrimeHub 6.8] patch end anchor missing: "..tostring(secondAnchor)) end
    return string.sub(src,1,a-1)..replacement..string.sub(src,b)
end

local function patchRuntime68(src)
    -- 6.7 persistence model: never queue the old local reload payload.
    -- Every hop downloads this exact current release fresh with executor HTTP cache disabled.
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

local __base = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.8.lua"
local __url = __base .. "?cb=" .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
local __ok, __src = pcall(function()
    return game:HttpGet(__url, false)
end)
if not __ok or type(__src) ~= "string" or #__src < 100 then
    error("[PRIMEHUB-BOOT 6.8] Could not download fresh release: " .. tostring(__src))
end
__primeEnv.PrimeHubPublicPayloadSource = __src
local __fn, __err = loadstring(__src)
if not __fn then
    error("[PRIMEHUB-BOOT 6.8] Release compile failed: " .. tostring(__err))
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
            "[PrimeHub] PrimeHub 6.8 FRESH REMOTE payload queued for teleport. resume sniper=%s hop=%s esp=%s",
            tostring(env.AutoFruitSniper == true), tostring(env.AutoHop == true), tostring(env.FruitESP == true)
        ))
        return true
    end
    AddLog("Failed to queue teleport payload: " .. tostring(err), Color3.fromRGB(255, 100, 100))
    return false
end

]====]
    src=replaceRange(src,"local function queueReloadAfterTeleport()","local function shortJobId()",queueNew)

    -- Preserve the 6.7 anti-771 behavior: do not reuse stale JobIds between hops.
    local collectAnchor="local function collectUnvisitedServers(maxCandidates)"
    local ca=string.find(src,collectAnchor,1,true)
    if not ca then error("[PrimeHub 6.8] collectUnvisitedServers anchor missing") end
    local visitedAnchor="    local visited = makeVisitedSet(state)"
    local va=string.find(src,visitedAnchor,ca,true)
    if not va then error("[PrimeHub 6.8] fresh queue insertion point missing") end
    local freshBlock=[====[    -- PrimeHub 6.8: never reuse stale JobIds between hops.
    state.serverQueue = {}
    state.serverQueueBuiltAt = 0
    state.serverQueuePlaceId = tostring(game.PlaceId or "")

]====]
    src=string.sub(src,1,va-1)..freshBlock..string.sub(src,va)

    -- Flight cleanup must only remove PrimeHub movers. The old cleanup forced every
    -- character BasePart to CanCollide=true even though flight never disabled collisions.
    local cleanupNew=[====[
local function cleanupFlight()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if root then
        local bv = root:FindFirstChild("PrimeHubSniperBV")
        if bv then pcall(function() bv:Destroy() end) end

        local bg = root:FindFirstChild("PrimeHubSniperBG")
        if bg then pcall(function() bg:Destroy() end) end

        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    env.ViajandoAteAFruta = false
end

]====]
    src=replaceRange(src,"local function cleanupFlight()","local function applyFlight",cleanupNew)

    -- Real long-distance flight: first climb vertically above the ocean, then cruise
    -- horizontally, and only descend when close to the fruit. Position is never snapped here.
    local flightNew=[====[
local function applyFlight(targetPosition, requestedSpeed)
    local root = getPlayerRoot()
    local character = LocalPlayer.Character
    if not root or not character then
        AddLog("Flight failed: root unavailable.", Color3.fromRGB(255, 100, 100))
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    humanoid.PlatformStand = true

    local bv = root:FindFirstChild("PrimeHubSniperBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "PrimeHubSniperBV"
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.P = 5000
        bv.Parent = root
    end

    local bg = root:FindFirstChild("PrimeHubSniperBG")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "PrimeHubSniperBG"
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.P = 3000
        bg.D = 500
        bg.Parent = root
    end

    local rootPos = root.Position
    local planarDelta = Vector3.new(targetPosition.X-rootPos.X,0,targetPosition.Z-rootPos.Z)
    local planarDistance = planarDelta.Magnitude
    local cruiseHeight = math.max(350, tonumber(env.FruitFlightCruiseHeight) or 350, targetPosition.Y + 80)

    local flightTarget = targetPosition
    if planarDistance > 200 then
        if rootPos.Y < cruiseHeight - 20 then
            -- Stage 1: climb straight up. Do not cut diagonally through the ocean.
            flightTarget = Vector3.new(rootPos.X, cruiseHeight, rootPos.Z)
        else
            -- Stage 2: cruise above the map/water.
            flightTarget = Vector3.new(targetPosition.X, cruiseHeight, targetPosition.Z)
        end
    end

    local delta = flightTarget - root.Position
    local distance = delta.Magnitude
    local direction = distance > 0.05 and delta.Unit or Vector3.zero
    local speed = math.max(50, tonumber(requestedSpeed) or tonumber(env.TweenSpeed) or 230)

    if distance > 60 then
        bv.Velocity = direction * speed
    elseif distance > 3 then
        local scaled = math.clamp((distance / 60) * speed, 15, speed)
        bv.Velocity = direction * scaled
    else
        bv.Velocity = Vector3.zero
    end

    local horizontalLook = Vector3.new(flightTarget.X, root.Position.Y, flightTarget.Z)
    if (horizontalLook-root.Position).Magnitude > 1 then
        local facing = CFrame.new(root.Position, horizontalLook)
        root.CFrame = facing -- rotation only; root.Position is unchanged
        bg.CFrame = facing
    else
        bg.CFrame = root.CFrame
    end
    return true
end

]====]
    src=replaceRange(src,"local function applyFlight(targetPosition, requestedSpeed)","local function moveTo(target, speed, timeoutSeconds)",flightNew)

    -- Long-distance pickup must FLY, not repeatedly assign HumanoidRootPart.CFrame.
    -- We travel at the configured sniper speed, cruise above water, then permit only a
    -- tiny final snap when already within 8 studs of the fruit for reliable touch pickup.
    local movementNew=[====[
        local beforePickup = snapshotHeldFruitTools()
        local tool = nil

        local pickupOffset = isServerWorldFruitModel(fruit) and 2 or (tonumber(env.FlyOffset) or 5)
        local flightSpeed = math.max(50, tonumber(env.TweenSpeed) or 230)

        local firstHandle = getDroppedFruitPart(fruit)
        local firstRoot = getPlayerRoot()
        if firstHandle and firstRoot then
            local firstTarget = firstHandle.Position + Vector3.new(0, pickupOffset, 0)
            local firstDistance = (firstRoot.Position - firstTarget).Magnitude

            if firstDistance > 8 then
                local flightTimeout = math.clamp((firstDistance / flightSpeed) + 15, 15, 120)
                executorLog("PICKUP", string.format(
                    "FLIGHT start distance=%.0f speed=%.0f timeout=%.1fs target=%s",
                    firstDistance, flightSpeed, flightTimeout, tostring(fruit.Name)
                ))

                env.ViajandoAteAFruta = true
                local flightDeadline = tick() + flightTimeout
                while runtimeActive() and tick() < flightDeadline and fruit.Parent do
                    local handle = getDroppedFruitPart(fruit)
                    local root = getPlayerRoot()
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if not handle or not root or not humanoid or humanoid.Health <= 0 then break end

                    local targetPosition = handle.Position + Vector3.new(0, pickupOffset, 0)
                    local remaining = (root.Position - targetPosition).Magnitude
                    if remaining <= 8 then break end

                    if not applyFlight(targetPosition, flightSpeed) then break end
                    task.wait(0.1)
                end
                cleanupFlight()

                local endRoot = getPlayerRoot()
                local endHandle = getDroppedFruitPart(fruit)
                if endRoot and endHandle then
                    local remaining = (endRoot.Position - (endHandle.Position + Vector3.new(0, pickupOffset, 0))).Magnitude
                    executorLog("PICKUP", string.format("FLIGHT end remaining=%.1f target=%s", remaining, tostring(fruit.Name)))
                end
            end
        end

        -- The old 2.5s deadline started before a 6000-stud trip could possibly finish.
        -- Start the pickup-contact timer only AFTER the flight stage.
        local deadline = tick() + 5.0

        while not tool and runtimeActive() and tick() < deadline do
            if not fruit.Parent then
                tool = findPickedUpTool(beforePickup, preferredName, expectedOriginal)
                if tool then break end
            end

            local handle = getDroppedFruitPart(fruit)
            local root = getPlayerRoot()
            if handle and root then
                local targetPosition = handle.Position + Vector3.new(0, pickupOffset, 0)
                local distance = (root.Position - targetPosition).Magnitude

                if distance <= 8 then
                    -- Tiny final contact correction only; never long-distance teleport.
                    root.CFrame = handle.CFrame + Vector3.new(0, pickupOffset, 0)
                    root.Velocity = Vector3.zero
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.RotVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                else
                    -- If server correction pushes us away, resume flight rather than snapping back.
                    applyFlight(targetPosition, flightSpeed)
                end
            elseif not root then
                AddLog("Flight/pickup failed: root unavailable.", Color3.fromRGB(255, 100, 100))
                break
            end

            task.wait(0.1)
            tool = findPickedUpTool(beforePickup, preferredName, expectedOriginal)
        end
        cleanupFlight()

]====]
    src=replaceRange(
        src,
        "        local beforePickup = snapshotHeldFruitTools()",
        "        if not tool then",
        movementNew
    )

    return src
end

-- 6.5 applies WORLD_DROP immediately before compiling the final readable runtime.
-- This outer hook receives that already-WORLD_DROP-patched runtime and adds only 6.7
-- persistence/fresh-server behavior plus the 6.8 movement fix.
local originalLoadstring68=loadstring
if type(originalLoadstring68)~="function" then error("[PrimeHub 6.8] loadstring unavailable") end
local runtimePatched68=false

local function hookedLoadstring68(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 6.8 | Fruit Sniper",1,true) then
        code=patchRuntime68(code)
        runtimePatched68=true
    end
    return originalLoadstring68(code,chunkname)
end
loadstring=hookedLoadstring68

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    loadstring=originalLoadstring68
    error("[PrimeHub 6.8] Could not download fresh 6.5 base: "..tostring(src))
end

-- Promote the proven 6.5 WORLD_DROP implementation to current public version.
src=string.gsub(src,"6%.5","6.8")
src=string.gsub(src,"PrimeHub_6_5_RELEASE%.lua","PrimeHub_6_8_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_5_PATCHED%.lua","PrimeHub_6_8_PATCHED.lua")

local fn,err=originalLoadstring68(src)
if not fn then
    loadstring=originalLoadstring68
    error("[PrimeHub 6.8] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring68
if not ok then error("[PrimeHub 6.8] Runtime failed: "..tostring(result)) end
if not runtimePatched68 then error("[PrimeHub 6.8] Final runtime patch was not applied") end

-- Compatibility diagnostic only. Server hops themselves always fetch fresh 6.8 remotely.
env.PrimeHubLocalPayloadFile="PrimeHub_6_8_RELEASE.lua"
return result
