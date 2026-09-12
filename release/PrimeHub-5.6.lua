-- PrimeHub 5.6 release bootstrap
-- Forces fresh public release downloads so executors cannot reuse a stale cached version.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.5.lua"
local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 5.6] loadstring unavailable") end

local function freshUrl(url)
    local nonce=tostring(os.time()).."-"..tostring(math.random(100000,999999))
    return url..(string.find(url,"?",1,true) and "&cb=" or "?cb=")..nonce
end

local okBody,body=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(body)~="string" or #body<100 then
    error("[PrimeHub 5.6] Could not download fresh 5.5 base release: "..tostring(body))
end

-- Promote the current release to 5.6 while keeping the existing 5.0 license compatibility IDs.
body=string.gsub(body,"5%.5","5.6")

-- Any nested PrimeHub release fetch inside this bootstrap must also bypass executor cache.
body=string.gsub(
    body,
    "game:HttpGet%(BASE_URL,true%)",
    "game:HttpGet(BASE_URL .. (string.find(BASE_URL, '?', 1, true) and '&cb=' or '?cb=') .. tostring(os.time()) .. '-' .. tostring(math.random(100000,999999)), false)"
)

local fn,err=originalLoadstring(body)
if not fn then error("[PrimeHub 5.6] Fresh release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 5.6] Runtime failed: "..tostring(result)) end
return result
