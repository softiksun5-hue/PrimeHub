-- PrimeHub 5.3 public loader
local URL = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.3.lua"
local ok, body = pcall(function() return game:HttpGet(URL, true) end)
if not ok or type(body) ~= "string" or #body < 100 then
    error("[PrimeHub 5.3] Could not download the protected release: " .. tostring(body))
end
local fn, err = loadstring(body)
if not fn then error("[PrimeHub 5.3] Release compile failed: " .. tostring(err)) end
return fn()
