-- PrimeHub 6.9 release bootstrap
-- Movement-only fix on top of 6.8: controlled fruit flight now uses temporary noclip.
-- The 6.8 bootstrap itself is patched before execution, avoiding another runtime-hook layer.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.8.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(src,old,new,label)
    local a,b=string.find(src,old,1,true)
    if not a then error("[PrimeHub 6.9] patch target missing: "..tostring(label or old)) end
    return string.sub(src,1,a-1)..new..string.sub(src,b+1)
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 6.9] Could not download fresh 6.8 base: "..tostring(src))
end

-- Promote the complete, already-working 6.8 chain first. This automatically keeps the
-- fresh-remote teleport loader, WORLD_DROP patch and anti-stale-server behavior on 6.9.
src=string.gsub(src,"6%.8","6.9")
src=string.gsub(src,"PrimeHub_6_8_RELEASE%.lua","PrimeHub_6_9_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_8_PATCHED%.lua","PrimeHub_6_9_PATCHED.lua")

-- Extend 6.8's generated cleanup/flight code with a collision snapshot.
-- Only character BaseParts are touched, and every original CanCollide value is restored.
local cleanupHeadOld=[====[    local cleanupNew=[====[
local function cleanupFlight()
]====]
local cleanupHeadNew=[====[    local cleanupNew=[====[
local flightCollisionState = setmetatable({}, {__mode="k"})

local function enableFlightNoclip(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if flightCollisionState[part] == nil then
                flightCollisionState[part] = part.CanCollide
            end
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

local function restoreFlightCollisions()
    for part, oldCanCollide in pairs(flightCollisionState) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = oldCanCollide
            end)
        end
        flightCollisionState[part] = nil
    end
end

local function cleanupFlight(keepNoclip)
]====]
src=replaceOnce(src,cleanupHeadOld,cleanupHeadNew,"cleanup head")

local cleanupTailOld=[====[    env.ViajandoAteAFruta = false
end

]====]
local cleanupTailNew=[====[    if not keepNoclip then
        restoreFlightCollisions()
        env.ViajandoAteAFruta = false
    end
end

]====]
-- The first occurrence after cleanupHead is the 6.8 cleanupNew body.
local cleanupStart=string.find(src,"local flightCollisionState = setmetatable",1,true)
if not cleanupStart then error("[PrimeHub 6.9] cleanup body start missing") end
local ta,tb=string.find(src,cleanupTailOld,cleanupStart,true)
if not ta then error("[PrimeHub 6.9] cleanup tail missing") end
src=string.sub(src,1,ta-1)..cleanupTailNew..string.sub(src,tb+1)

-- applyFlight executes every ~0.1s, so collision is continuously suppressed during travel,
-- including accessories/parts that appear after the flight started.
local flightNoclipOld=[====[    humanoid.PlatformStand = true

    local bv = root:FindFirstChild("PrimeHubSniperBV")
]====]
local flightNoclipNew=[====[    humanoid.PlatformStand = true
    enableFlightNoclip(character)

    local bv = root:FindFirstChild("PrimeHubSniperBV")
]====]
src=replaceOnce(src,flightNoclipOld,flightNoclipNew,"applyFlight noclip")

-- Do not restore collisions between the long cruise and the final fruit touch. A fruit can
-- sit inside/behind island geometry, and restoring collision here would immediately eject us.
local stageOld=[====[                cleanupFlight()

                local endRoot = getPlayerRoot()
]====]
local stageNew=[====[                cleanupFlight(true)

                local endRoot = getPlayerRoot()
]====]
src=replaceOnce(src,stageOld,stageNew,"between flight and pickup")

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 6.9] Base compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 6.9] Runtime failed: "..tostring(result)) end
return result
