-- PrimeHub 5.5 release bootstrap
-- Keeps 5.4 teleport persistence and fixes the UI race that could force License after a successful cached license check.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.4.lua"
local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 5.5] loadstring unavailable") end

local OLD_UI=[=[    task.spawn(function() initializeLicense(); refreshLicenseUI() end)
    switchPage("License")]=]
local NEW_UI=[=[    -- Start locked, then let the completed license check choose the final page.
    switchPage("License")
    task.spawn(function()
        initializeLicense()
        refreshLicenseUI()
    end)]=]

local patched=false
local function patchRuntime(code)
    local a,b=string.find(code,OLD_UI,1,true)
    if not a then return code,false end
    code=string.sub(code,1,a-1)..NEW_UI..string.sub(code,b+1)
    return code,true
end

local function hookedLoadstring(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 5.5 | Fruit Sniper",1,true) then
        local okPatch
        code,okPatch=patchRuntime(code)
        if not okPatch then error("[PrimeHub 5.5] Dashboard patch target missing") end
        patched=true
    end
    return originalLoadstring(code,chunkname)
end

loadstring=hookedLoadstring
local okBody,body=pcall(function() return game:HttpGet(BASE_URL,true) end)
if not okBody or type(body)~="string" or #body<100 then
    loadstring=originalLoadstring
    error("[PrimeHub 5.5] Could not download 5.4 base release: "..tostring(body))
end

-- Promote all current-release references while preserving the registered 5.0 license compatibility IDs.
body=string.gsub(body,"5%.4","5.5")
local fn,err=originalLoadstring(body)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 5.5] Patched release compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 5.5] Runtime failed: "..tostring(result)) end
if not patched then error("[PrimeHub 5.5] Dashboard-after-license patch was not applied") end
return result
