-- PrimeHub 5.9 release bootstrap
-- UI/public release = 5.9; license protocol version remains registered 5.0.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.8.lua"
local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=") .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end
local ok,src=pcall(function() return game:HttpGet(freshUrl(BASE_URL),false) end)
if not ok or type(src)~="string" or #src<100 then error("[PrimeHub 5.9] Could not download fresh 5.8 base: "..tostring(src)) end
src=string.gsub(src,"5%.8","5.9")

-- Inject license compatibility immediately after the stable 5.3 generator is promoted to 5.9.
local anchor='body=string.gsub(body,"5%.3","5.9")\n'
local injection=[[-- Keep license protocol/build registration separate from the visible release number.
body=string.gsub(body,'local PRIMEHUB_VERSION = "5%.9"','local PRIMEHUB_VERSION = "5.0"')
]]
local a,b=string.find(src,anchor,1,true)
if not a then error("[PrimeHub 5.9] License compatibility anchor missing") end
src=string.sub(src,1,b)..injection..string.sub(src,b+1)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 5.9] Release compile failed: "..tostring(err)) end
local okRun,result=pcall(fn)
if not okRun then error("[PrimeHub 5.9] Runtime failed: "..tostring(result)) end
return result
