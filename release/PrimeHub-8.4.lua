-- PrimeHub 8.4 public stable assembler
-- Exact FIXPICKUPCOUNT payload split into immutable release chunks.
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/v8.4/"
local FILES = {
    "part01.txt",
    "part02.txt",
    "part03.txt",
    "part04.txt",
    "part05.txt",
    "part06.txt",
    "part07.txt",
    "part08.txt",
    "part09.txt",
    "part10.txt",
    "part11.txt",
    "part12.txt",
    "part13.txt",
    "part14.txt",
    "part15.txt",
    "part16.txt",
    "part17.txt",
    "part18.txt",
    "part19.txt",
    "part20.txt",
    "part21.txt",
    "part22.txt",
    "part23.txt",
    "part24.txt",
    "part25.txt",
    "part26.txt",
    "part27.txt",
    "part28.txt",
    "part29.txt",
    "part30.txt",
    "part31.txt",
    "part32.txt",
    "part33.txt",
    "part34.txt",
    "part35.txt"
}

local parts = table.create and table.create(#FILES) or {}
local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
for i, name in ipairs(FILES) do
    local url = BASE .. name .. "?cb=" .. nonce .. "-" .. tostring(i)
    local ok, body = pcall(function() return game:HttpGet(url, false) end)
    if not ok or type(body) ~= "string" or #body == 0 then
        error("[PrimeHub 8.4] Could not download release chunk " .. name .. ": " .. tostring(body))
    end
    parts[i] = body
end

local source = table.concat(parts)
if #source ~= 191045 then
    error("[PrimeHub 8.4] Release assembly size mismatch: " .. tostring(#source) .. " != 191045")
end

local MOD = 65521
local a, s = 1, 0
for i = 1, #source do
    a = (a + string.byte(source, i)) % MOD
    s = (s + a) % MOD
end
local adler = s * 65536 + a
if adler ~= 1005029465 then
    error("[PrimeHub 8.4] Release checksum mismatch: " .. tostring(adler))
end

if not string.find(source, "FIXPICKUPCOUNT", 1, true) then
    error("[PrimeHub 8.4] Release identity marker missing")
end

local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = source
local fn, err = loadstring(source)
if not fn then
    error("[PrimeHub 8.4] Release compile failed: " .. tostring(err))
end
return fn()
