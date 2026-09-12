-- PrimeHub 5.4 release bootstrap
-- Fixes teleport persistence: the versioned patcher remains the active local payload after every hop.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.3.lua"
local okBody,body=pcall(function() return game:HttpGet(BASE_URL,true) end)
if not okBody or type(body)~="string" or #body<100 then
    error("[PrimeHub 5.4] Could not download 5.3 base release: "..tostring(body))
end

-- Promote all user-visible/current-release references from 5.3 to 5.4.
body=string.gsub(body,"5%.3","5.4")

-- 5.3 correctly built the patched runtime, but the protected 5.0 base could overwrite
-- PrimeHubLocalPayloadFile afterwards. On teleport that stale pointer could load 5.0 directly.
-- Inject two guards into the versioned patcher: one immediately after SELF_FILE exists,
-- and one after the protected core finishes booting.
local anchor='    code=string.gsub(code,"Starting v5%.1","Starting v5.4")\n'
local injection=[=[    code=string.gsub(code,'local SELF_FILE="PrimeHub_5_4_PATCHED%.lua"','local SELF_FILE="PrimeHub_5_4_PATCHED.lua"\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
    code=string.gsub(code,'local ok,result=pcall%(fn%)','local ok,result=pcall(fn)\nenv.PrimeHubLocalPayloadFile=SELF_FILE',1)
]=]
local a,b=string.find(body,anchor,1,true)
if not a then error("[PrimeHub 5.4] Teleport persistence patch anchor missing") end
body=string.sub(body,1,b)..injection..string.sub(body,b+1)

local fn,err=loadstring(body)
if not fn then error("[PrimeHub 5.4] Patched release compile failed: "..tostring(err)) end
return fn()
