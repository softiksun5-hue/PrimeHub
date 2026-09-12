-- PrimeHub 6.3 public loader
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.3.lua"
local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
local URL = BASE .. "?cb=" .. nonce
local ok, body = pcall(function() return game:HttpGet(URL, false) end)
if not ok or type(body) ~= "string" or #body < 100 then
    error("[PrimeHub 6.3] Could not download the fresh protected release: " .. tostring(body))
end
local fn, err = loadstring(body)
if not fn then error("[PrimeHub 6.3] Release compile failed: " .. tostring(err)) end
return fn()
