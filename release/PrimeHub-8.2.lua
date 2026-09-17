-- PrimeHub 8.2 public release assembler
-- Public runtime assembled from the current PrimeHub 8.2 release chunks.
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/v8.2/"
local FILES = {
    "part01.txt", "part02.txt", "part03.txt", "part04.txt", "part05.txt", "part06.txt",
    "part07.txt", "part08.txt", "part09.txt", "part10.txt", "part11.txt", "part12.txt",
    "part13.txt", "part14.txt", "part15.txt", "part16.txt", "part17.txt", "part18.txt",
}

local parts = table.create and table.create(#FILES) or {}
local baseNonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))

for i, name in ipairs(FILES) do
    local url = BASE .. name .. "?cb=" .. baseNonce .. "-" .. tostring(i)
    local ok, body = pcall(function()
        return game:HttpGet(url, false)
    end)
    if not ok or type(body) ~= "string" or #body < 100 then
        error("[PrimeHub 8.2] Could not download release chunk " .. name .. ": " .. tostring(body))
    end
    parts[i] = body
end

local source = table.concat(parts)
if #source < 230000 then
    error("[PrimeHub 8.2] Release assembly incomplete: " .. tostring(#source) .. " bytes")
end

local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = source
local fn, err = loadstring(source)
if not fn then
    error("[PrimeHub 8.2] Release compile failed: " .. tostring(err))
end
return fn()
