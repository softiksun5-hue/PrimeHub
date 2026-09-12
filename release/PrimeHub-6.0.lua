-- PrimeHub 6.0 release bootstrap
-- Shows real license lifetime in UI; technical lease remains internal.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-5.8.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 6.0] Could not download fresh stable base: "..tostring(src))
end

-- Promote current public/runtime references to 6.0.
src=string.gsub(src,"5%.8","6.0")

-- Inject changes into the stable 5.3 runtime generator before it is compiled.
local anchor='body=string.gsub(body,"5%.3","6.0")\n'
local injection=[====[
-- Keep the public/runtime version separate from the registered license protocol version.
local protocolOld=[==[    src=string.gsub(src,'local PRIMEHUB_VERSION = "5.0"','local PRIMEHUB_VERSION = "6.0"',1)]==]
local protocolNew=[==[    src=string.gsub(src,'local PRIMEHUB_VERSION = "5.0"','local PRIMEHUB_VERSION = "6.0"\nlocal PRIMEHUB_LICENSE_VERSION = "5.0"',1)
    src=string.gsub(src,'version = PRIMEHUB_VERSION,','version = PRIMEHUB_LICENSE_VERSION,')]==]
local pa,pb=string.find(body,protocolOld,1,true)
if not pa then error("[PrimeHub 6.0] License protocol generator target missing") end
body=string.sub(body,1,pa-1)..protocolNew..string.sub(body,pb+1)

-- Add real license lifetime rendering to the final readable runtime.
local uiPatch=[===[
    local licenseInfoOld=[====[    local licenseInfo=card(licensePage,UDim2.new(1,0,0,88),UDim2.new(0,0,0,190))
    local licenseBuild=label(licenseInfo,"Build: PrimeHub 6.0",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,10),9,THEME.muted,true)
    local licenseDevice=label(licenseInfo,"Device: --",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,34),9,THEME.muted,false)
    local licenseExpiry=label(licenseInfo,"Lease: --",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,58),9,THEME.muted,false)]====]
    local licenseInfoNew=[====[    local licenseInfo=card(licensePage,UDim2.new(1,0,0,112),UDim2.new(0,0,0,190))
    local licenseBuild=label(licenseInfo,"Build: PrimeHub 6.0",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,10),9,THEME.muted,true)
    local licenseDevice=label(licenseInfo,"Device: --",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,34),9,THEME.muted,false)
    local licenseExpiry=label(licenseInfo,"License: --",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,58),9,THEME.muted,false)
    local licenseRemaining=label(licenseInfo,"Time left: --",UDim2.new(1,-20,0,18),UDim2.new(0,12,0,82),9,THEME.muted,false)]====]
    src=select(1,replaceLiteral(src,licenseInfoOld,licenseInfoNew,true))

    local lifetimeOld=[====[        if licenseState.installationId then licenseDevice.Text="Device: "..string.sub(tostring(licenseState.installationId),1,28) end
        if (tonumber(licenseState.leaseExpiresAt) or 0)>0 then licenseExpiry.Text="Lease until: "..os.date("%H:%M:%S",licenseState.leaseExpiresAt) else licenseExpiry.Text="Lease: --" end
        if on then]====]
    local lifetimeNew=[====[        if licenseState.installationId then licenseDevice.Text="Device: "..string.sub(tostring(licenseState.installationId),1,28) end
        local licenseExp=tonumber(licenseState.licenseExpiresAt) or 0
        if on then
            if licenseExp>0 then
                local remaining=math.max(0,licenseExp-os.time())
                local days=math.floor(remaining/86400)
                local hours=math.floor((remaining%86400)/3600)
                local minutes=math.floor((remaining%3600)/60)
                licenseExpiry.Text="Expires: "..os.date("%d %b %Y",licenseExp)
                if days>0 then
                    licenseRemaining.Text=string.format("Time left: %dd %dh",days,hours)
                elseif hours>0 then
                    licenseRemaining.Text=string.format("Time left: %dh %dm",hours,minutes)
                else
                    licenseRemaining.Text=string.format("Time left: %dm",minutes)
                end
            else
                licenseExpiry.Text="License: FOREVER"
                licenseRemaining.Text="Time left: Unlimited"
            end
        else
            licenseExpiry.Text="License: --"
            licenseRemaining.Text="Time left: --"
        end
        if on then]====]
    src=select(1,replaceLiteral(src,lifetimeOld,lifetimeNew,true))
    src=string.gsub(src,'licenseLeaseExpiresAt = licenseState.leaseExpiresAt,','licenseExpiresAt = licenseState.licenseExpiresAt,',1)
]===]

local ua=string.find(body,protocolNew,1,true)
if not ua then error("[PrimeHub 6.0] License UI generator insertion point missing") end
body=string.sub(body,1,ua-1)..uiPatch..body:sub(ua)
]====]

local a,b=string.find(src,anchor,1,true)
if not a then error("[PrimeHub 6.0] Stable generator anchor missing") end
src=string.sub(src,1,b)..injection..string.sub(src,b+1)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 6.0] Release compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 6.0] Runtime failed: "..tostring(result)) end
return result
