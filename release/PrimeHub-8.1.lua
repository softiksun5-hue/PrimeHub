-- PrimeHub 8.1 public release assembler
-- Stable production runtime tested over 700+ server hops.
-- The production runtime is split only to keep the GitHub release manageable.
-- After the first launch PrimeHub carries the exact assembled runtime through queue_on_teleport.
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/v8.1/"
local FILES = {
    "part01.txt", "part02.txt", "part03.txt", "part04.txt", "part05.txt",
    "part06.txt", "part07.txt", "part08.txt", "part09.txt", "part10.txt",
    "part11a.txt", "part11b.txt", "part11c.txt",
    "part12a.txt", "part12b.txt", "part12c.txt",
    "part13a.txt", "part13b.txt",
}

local parts = table.create and table.create(#FILES) or {}
local baseNonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))

for i, name in ipairs(FILES) do
    local url = BASE .. name .. "?cb=" .. baseNonce .. "-" .. tostring(i)
    local ok, body = pcall(function()
        return game:HttpGet(url, false)
    end)
    if not ok or type(body) ~= "string" or #body < 100 then
        error("[PrimeHub 8.1] Could not download release chunk " .. name .. ": " .. tostring(body))
    end
    parts[i] = body
end

local source = table.concat(parts)
if #source < 180000 then
    error("[PrimeHub 8.1] Release assembly incomplete: " .. tostring(#source) .. " bytes")
end

local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = source
local fn, err = loadstring(source)
if not fn then
    error("[PrimeHub 8.1] Release compile failed: " .. tostring(err))
end
return fn()
