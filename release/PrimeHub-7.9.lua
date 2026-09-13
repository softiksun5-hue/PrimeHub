-- PrimeHub 7.9 release bootstrap
-- Stable 7.8 + duplicate queued-bootstrap guard per Roblox JobId.
-- Prevents a second queued payload in the same server from resetting automation flags.

local env = (type(getgenv) == "function" and getgenv()) or _G
local jobKey = tostring(game.PlaceId or "") .. ":" .. tostring(game.JobId or "")
local guardKey = "PrimeHub-7.9:" .. jobKey

if env.PrimeHubActiveBootstrapKey == guardKey then
    print("[PrimeHub 7.9] Duplicate queued bootstrap ignored for JobId=" .. tostring(game.JobId))
    return
end

env.PrimeHubActiveBootstrapKey = guardKey

local function clearGuard()
    if env.PrimeHubActiveBootstrapKey == guardKey then
        env.PrimeHubActiveBootstrapKey = nil
    end
end

local BASE_URL = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.8.lua"
local function freshUrl(url)
    return url .. (string.find(url, "?", 1, true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody, src = pcall(function()
    return game:HttpGet(freshUrl(BASE_URL), false)
end)
if not okBody or type(src) ~= "string" or #src < 100 then
    clearGuard()
    error("[PrimeHub 7.9] Could not download fresh 7.8 base: " .. tostring(src))
end

-- Promote the complete proven 7.8 chain, including its queued remote payloads.
src = string.gsub(src, "7%.8", "7.9")
src = string.gsub(src, "PrimeHub_7_8_RELEASE%.lua", "PrimeHub_7_9_RELEASE.lua")
src = string.gsub(src, "PrimeHub_7_8_PATCHED%.lua", "PrimeHub_7_9_PATCHED.lua")

local fn, err = loadstring(src)
if not fn then
    clearGuard()
    error("[PrimeHub 7.9] Base compile failed: " .. tostring(err))
end

local ok, result = pcall(fn)
if not ok then
    clearGuard()
    error("[PrimeHub 7.9] Runtime failed: " .. tostring(result))
end

return result
