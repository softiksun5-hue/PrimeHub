-- PrimeHub 5.7 release bootstrap
-- Clean rebuild from the stable 5.3 generator: fixes the Dashboard startup race,
-- preserves versioned teleport reload, and bypasses stale executor HTTP cache.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.3.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,body=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(body)~="string" or #body<100 then
    error("[PrimeHub 5.7] Could not download fresh stable base: "..tostring(body))
end

-- Promote the stable generator to the current release.
body=string.gsub(body,"5%.3","5.7")

-- 5.7: the 5.3 generator had the right Dashboard decision but the wrong order:
-- its spawned license check could finish before the following switchPage("License").
local oldInit=[=[local initNew='    task.spawn(function() initializeLicense(); refreshLicenseUI(); if licenseState.active then switchPage("Dashboard") end end)\n    switchPage("License")']=]
local newInit=[=[local initNew='    switchPage("License")\n    task.spawn(function() initializeLicense(); refreshLicenseUI(); if licenseState.active then switchPage("Dashboard") end end)']=]
local ia,ib=string.find(body,oldInit,1,true)
if not ia then error("[PrimeHub 5.7] Dashboard generator target missing") end
body=string.sub(body,1,ia-1)..newInit..string.sub(body,ib+1)

-- The stable generator fetches the 5.1 protected patcher. Force that fetch fresh too.
local oldFetch="game:HttpGet(BASE_URL,true)"
local newFetch="game:HttpGet(BASE_URL .. (string.find(BASE_URL, '?', 1, true) and '&cb=' or '?cb=') .. tostring(os.time()) .. '-' .. tostring(math.random(100000,999999)), false)"
local fa,fb=string.find(body,oldFetch,1,true)
if not fa then error("[PrimeHub 5.7] Fresh-fetch target missing") end
body=string.sub(body,1,fa-1)..newFetch..string.sub(body,fb+1)

-- Preserve the current version after every server hop. The protected 5.0 core may
-- overwrite PrimeHubLocalPayloadFile, so restore the pointer both before and after it runs.
local anchor='    code=string.gsub(code,"Starting v5%.1","Starting v5.7")\n'
local injection=[=[    code=string.gsub(code,'local SELF_FILE="PrimeHub_5_7_PATCHED%.lua"','local SELF_FILE="PrimeHub_5_7_PATCHED.lua"\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
    code=string.gsub(code,'local ok,result=pcall%(fn%)','local ok,result=pcall(fn)\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
]=]
local aa,ab=string.find(body,anchor,1,true)
if not aa then error("[PrimeHub 5.7] Teleport persistence target missing") end
body=string.sub(body,1,ab)..injection..string.sub(body,ab+1)

local fn,err=loadstring(body)
if not fn then error("[PrimeHub 5.7] Release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 5.7] Runtime failed: "..tostring(result)) end
return result
