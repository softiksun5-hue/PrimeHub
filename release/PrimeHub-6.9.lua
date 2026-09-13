-- PrimeHub 6.9 release bootstrap
-- Movement-only fix on top of 6.8:
-- keep controlled fruit flight, but disable character collisions only while travelling.
-- WORLD_DROP, fresh-remote serverhop and fresh server candidate logic are inherited from 6.8.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.8.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceRange(src, firstAnchor, secondAnchor, replacement)
    local a=string.find(src,firstAnchor,1,true)
    if not a then error("[PrimeHub 6.9] patch anchor missing: "..tostring(firstAnchor)) end
    local b=string.find(src,secondAnchor,a,true)
    if not b then error("[PrimeHub 6.9] patch end anchor missing: "..tostring(secondAnchor)) end
    return string.sub(src,1,a-1)..replacement..string.sub(src,b)
end

local function replaceOnce(src, old, new)
    local a,b=string.find(src,old,1,true)
    if not a then error("[PrimeHub 6.9] literal patch target missing: "..tostring(old)) end
    return string.sub(src,1,a-1)..new..string.sub(src,b+1)
end

local function patchRuntime69(src)
    -- Keep the original collision state of every character part. While flight is active,
    -- repeatedly force CanCollide=false so walls, mountains, trees and island meshes cannot
    -- stop the controlled BodyVelocity flight. Restore every part exactly to its old value.
    local cleanupNew=[====[
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

    if not keepNoclip then
        restoreFlightCollisions()
        env.ViajandoAteAFruta = false
    end
end

]====]
    src=replaceRange(src,"local function cleanupFlight()","local function applyFlight",cleanupNew)

    -- applyFlight runs every ~0.1s, so this also handles newly-added character/accessory parts
    -- or any local collision state that Roblox changes while we are travelling.
    local noclipOld=[====[    humanoid.PlatformStand = true

    local bv = root:FindFirstChild("PrimeHubSniperBV")
]====]
    local noclipNew=[====[    humanoid.PlatformStand = true
    enableFlightNoclip(character)

    local bv = root:FindFirstChild("PrimeHubSniperBV")
]====]
    src=replaceOnce(src,noclipOld,noclipNew)

    -- At the end of the long cruise, stop BodyVelocity/BodyGyro but KEEP noclip until the
    -- actual fruit touch/pickup finishes. Otherwise a fruit inside/behind island geometry can
    -- eject the character before the final <=8-stud contact correction.
    local betweenStagesOld=[====[                cleanupFlight()

                local endRoot = getPlayerRoot()
]====]
    local betweenStagesNew=[====[                cleanupFlight(true)

                local endRoot = getPlayerRoot()
]====]
    src=replaceOnce(src,betweenStagesOld,betweenStagesNew)

    return src
end

-- Promote the complete 6.8 release first. Its own fresh-remote teleport payload therefore
-- automatically points to 6.9 before the final runtime is built.
local originalLoadstring69=loadstring
if type(originalLoadstring69)~="function" then error("[PrimeHub 6.9] loadstring unavailable") end
local runtimePatched69=false

local function hookedLoadstring69(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 6.9 | Fruit Sniper",1,true) then
        code=patchRuntime69(code)
        runtimePatched69=true
    end
    return originalLoadstring69(code,chunkname)
end
loadstring=hookedLoadstring69

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    loadstring=originalLoadstring69
    error("[PrimeHub 6.9] Could not download fresh 6.8 base: "..tostring(src))
end

src=string.gsub(src,"6%.8","6.9")
src=string.gsub(src,"PrimeHub_6_8_RELEASE%.lua","PrimeHub_6_9_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_8_PATCHED%.lua","PrimeHub_6_9_PATCHED.lua")

local fn,err=originalLoadstring69(src)
if not fn then
    loadstring=originalLoadstring69
    error("[PrimeHub 6.9] Base compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring69
if not ok then error("[PrimeHub 6.9] Runtime failed: "..tostring(result)) end
if not runtimePatched69 then error("[PrimeHub 6.9] Final runtime patch was not applied") end

env.PrimeHubLocalPayloadFile="PrimeHub_6_9_RELEASE.lua"
return result
