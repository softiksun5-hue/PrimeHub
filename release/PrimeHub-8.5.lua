-- PrimeHub 8.5 STABLE PUBLIC FIX4 BG-RESILIENT protected assembler
-- Encoded split release with integrity checks.
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/v8.5/"
local FILES = {"part01.txt","part02.txt"}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64MAP = {}
for i = 1, #B64 do B64MAP[string.byte(B64, i)] = i - 1 end

local function decodeBase64(data)
    data = tostring(data or "")
    local out, n = {}, 0
    local i, len = 1, #data
    while i <= len do
        local ca = string.byte(data, i); i += 1
        local cb = string.byte(data, i); i += 1
        local cc = string.byte(data, i); i += 1
        local cd = string.byte(data, i); i += 1
        if not ca or not cb then break end
        local a = B64MAP[ca]
        local b = B64MAP[cb]
        local c = cc and B64MAP[cc] or nil
        local d = cd and B64MAP[cd] or nil
        if a and b then
            n += 1; out[n] = string.char(a * 4 + math.floor(b / 16))
            if cc and cc ~= 61 and c then
                n += 1; out[n] = string.char((b % 16) * 16 + math.floor(c / 4))
                if cd and cd ~= 61 and d then
                    n += 1; out[n] = string.char((c % 4) * 64 + d)
                end
            end
        end
    end
    return table.concat(out)
end

local parts = table.create and table.create(#FILES) or {}
local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
for i, name in ipairs(FILES) do
    local url = BASE .. name .. "?cb=" .. nonce .. "-" .. tostring(i)
    local ok, body = pcall(function() return game:HttpGet(url, false) end)
    if (not ok) or type(body) ~= "string" or #body == 0 then
        ok, body = pcall(function() return game:HttpGet(url) end)
    end
    if not ok or type(body) ~= "string" or #body == 0 then
        error("[PrimeHub 8.5 FIX4] Could not download release chunk " .. name .. ": " .. tostring(body))
    end
    local decoded = decodeBase64(body)
    if type(decoded) ~= "string" or #decoded == 0 then
        error("[PrimeHub 8.5 FIX4] Could not decode release chunk " .. name)
    end
    parts[i] = decoded
end
local source = table.concat(parts)
if #source ~= 218987 then
    error("[PrimeHub 8.5 FIX4] Release assembly size mismatch: " .. tostring(#source) .. " != 218987")
end
local MOD = 65521
local a, s = 1, 0
for i = 1, #source do
    a = (a + string.byte(source, i)) % MOD
    s = (s + a) % MOD
end
local checksum = s * 65536 + a
if checksum ~= 231394168 then
    error("[PrimeHub 8.5 FIX4] Release checksum mismatch: " .. tostring(checksum))
end
if not string.find(source, "8.5-STABLE-PUBLIC-FIX4-BG-RESILIENT", 1, true) then
    error("[PrimeHub 8.5 FIX4] Release identity marker missing")
end
local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = source
local fn, err = loadstring(source)
if not fn then error("[PrimeHub 8.5 FIX4] Release compile failed: " .. tostring(err)) end
return fn()
