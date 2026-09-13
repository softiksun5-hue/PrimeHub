-- PrimeHub 6.6 release bootstrap
-- Critical fix: WORLD_DROP support must survive every server hop.
-- The proven 6.5 scanner/pickup patch is reused unchanged; only teleport persistence is fixed here.
local env=(type(getgenv)=="function" and getgenv()) or _G
local SELF_FILE="PrimeHub_6_6_RELEASE.lua"
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.5.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

-- PrimeHub.lua puts the exact public 6.6 wrapper source here. Persist that exact wrapper.
-- The transformed 6.5 bootstrap below will also see this value and save the same file.
local publicSource=env.PrimeHubPublicPayloadSource
if type(publicSource)=="string" and #publicSource>100 and type(writefile)=="function" then
    pcall(writefile,SELF_FILE,publicSource)
end

-- Keep the desired payload explicit in the current environment too.
env.PrimeHubLocalPayloadFile=SELF_FILE

-- 6.5 exposed the real bug: its queued teleport code only *read* PrimeHubLocalPayloadFile
-- after teleport. On a fresh teleport VM that value can be absent, so the old runtime fallback
-- PrimeHub_5_3_PATCHED.lua won and WORLD_DROP support disappeared.
--
-- Wrap the executor's queue function so every PrimeHub teleport payload begins by restoring
-- the exact 6.6 local file path BEFORE the legacy reload payload reads it.
local FORCE_PREFIX=[=[
local __primePersistEnv = (type(getgenv) == "function" and getgenv()) or _G
__primePersistEnv.PrimeHubLocalPayloadFile = "PrimeHub_6_6_RELEASE.lua"
]=]

local function forcePayload(payload)
    payload=tostring(payload or "")
    if string.find(payload,'PrimeHubLocalPayloadFile = "PrimeHub_6_6_RELEASE.lua"',1,true) then
        return payload
    end
    return FORCE_PREFIX .. "\n" .. payload
end

local currentJob=tostring(game.JobId or "")
if env.PrimeHub66QueueWrappedJob~=currentJob then
    local wrapped=false

    if type(queue_on_teleport)=="function" then
        local original=queue_on_teleport
        queue_on_teleport=function(payload)
            return original(forcePayload(payload))
        end
        wrapped=true
    elseif type(queueonteleport)=="function" then
        local original=queueonteleport
        queueonteleport=function(payload)
            return original(forcePayload(payload))
        end
        wrapped=true
    elseif type(syn)=="table" and type(syn.queue_on_teleport)=="function" then
        local original=syn.queue_on_teleport
        syn.queue_on_teleport=function(payload)
            return original(forcePayload(payload))
        end
        wrapped=true
    elseif type(fluxus)=="table" and type(fluxus.queue_on_teleport)=="function" then
        local original=fluxus.queue_on_teleport
        fluxus.queue_on_teleport=function(payload)
            return original(forcePayload(payload))
        end
        wrapped=true
    end

    if wrapped then
        env.PrimeHub66QueueWrappedJob=currentJob
    end
end

-- Reuse the already proven 6.5 WORLD_DROP implementation and promote only its public version
-- and local filenames to 6.6. License protocol remains pinned to 5.0 inside the stable base.
local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 6.6] Could not download fresh 6.5 base: "..tostring(src))
end

src=string.gsub(src,"6%.5","6.6")
src=string.gsub(src,"PrimeHub_6_5_RELEASE%.lua","PrimeHub_6_6_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_5_PATCHED%.lua","PrimeHub_6_6_PATCHED.lua")

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 6.6] Base compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 6.6] Runtime failed: "..tostring(result)) end

-- Nested bootstraps may rewrite this during startup; force the public 6.6 wrapper again.
env.PrimeHubLocalPayloadFile=SELF_FILE
return result
