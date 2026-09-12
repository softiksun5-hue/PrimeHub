-- PrimeHub 5.0 public loader
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/"
local PARTS = 8
local chunks = {}
for i = 1, PARTS do
    local url = BASE .. string.format("p%02d.txt", i)
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or type(body) ~= "string" or #body < 100 then
        error("[PrimeHub] Could not download payload part " .. tostring(i) .. ": " .. tostring(body))
    end
    chunks[i] = body
end
local source = table.concat(chunks)
local fn, err = loadstring(source)
if not fn then error("[PrimeHub] Protected payload compile failed: " .. tostring(err)) end
return fn()
