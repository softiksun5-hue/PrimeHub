-- PrimeHub 5.8 release bootstrap
-- Clean rebuild from stable 5.3 generator. Avoids 5.5/5.6 patch chain entirely.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.3.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,body=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(body)~="string" or #body<100 then
    error("[PrimeHub 5.8] Could not download fresh stable base: "..tostring(body))
end

-- Promote stable 5.3 generator to 5.8.
body=string.gsub(body,"5%.3","5.8")

-- Fix startup/serverhop page order inside the runtime generator.
local oldInit=[=[local initNew='    task.spawn(function() initializeLicense(); refreshLicenseUI(); if licenseState.active then switchPage("Dashboard") end end)\n    switchPage("License")']=]
local newInit=[=[local initNew='    switchPage("License")\n    task.spawn(function() initializeLicense(); refreshLicenseUI(); if licenseState.active then switchPage("Dashboard") end end)']=]
local ia,ib=string.find(body,oldInit,1,true)
if not ia then error("[PrimeHub 5.8] Dashboard generator target missing") end
body=string.sub(body,1,ia-1)..newInit..string.sub(body,ib+1)

-- Force the stable generator's nested protected-patcher fetch to bypass executor cache.
local oldFetch="game:HttpGet(BASE_URL,true)"
local newFetch="game:HttpGet(BASE_URL .. (string.find(BASE_URL, '?', 1, true) and '&cb=' or '?cb=') .. tostring(os.time()) .. '-' .. tostring(math.random(100000,999999)), false)"
local fa,fb=string.find(body,oldFetch,1,true)
if not fa then error("[PrimeHub 5.8] Fresh-fetch target missing") end
body=string.sub(body,1,fa-1)..newFetch..string.sub(body,fb+1)

-- Keep the current versioned local payload after every hop. This is the proven 5.4 persistence fix,
-- now applied directly to 5.8 instead of chaining through 5.4/5.5/5.6.
local anchor='    code=string.gsub(code,"Starting v5%.1","Starting v5.8")\n'
local injection=[=[    code=string.gsub(code,'local SELF_FILE="PrimeHub_5_8_PATCHED%.lua"','local SELF_FILE="PrimeHub_5_8_PATCHED.lua"\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
    code=string.gsub(code,'local ok,result=pcall%(fn%)','local ok,result=pcall(fn)\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
]=]
local aa,ab=string.find(body,anchor,1,true)
if not aa then error("[PrimeHub 5.8] Teleport persistence target missing") end
body=string.sub(body,1,ab)..injection..string.sub(body,ab+1)

-- Mark the current payload path early as well, so stale 5.6/5.7 pointers cannot win later.
env.PrimeHubLocalPayloadFile="PrimeHub_5_8_PATCHED.lua"

local fn,err=loadstring(body)
if not fn then error("[PrimeHub 5.8] Release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 5.8] Runtime failed: "..tostring(result)) end
return result
