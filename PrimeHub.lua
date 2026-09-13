-- PrimeHub 7.2 public loader
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-7.2.lua"
local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
local URL = BASE .. "?cb=" .. nonce
local ok, body = pcall(function() return game:HttpGet(URL, false) end)
if not ok or type(body) ~= "string" or #body < 100 then
    error("[PrimeHub 7.2] Could not download the fresh protected release: " .. tostring(body))
end
local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = body
local fn, err = loadstring(body)
if not fn then error("[PrimeHub 7.2] Release compile failed: " .. tostring(err)) end
return fn()
