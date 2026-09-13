-- PrimeHub 7.1 release bootstrap
-- Fixes the 7.0 bootstrap syntax error and keeps a short-lived server candidate queue.
-- Built on stable 6.9; WORLD_DROP, noclip flight, pickup/store and fresh remote reload stay unchanged.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.9.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceOnce(source, oldText, newText, label)
    local a,b=string.find(source,oldText,1,true)
    if not a then error("[PrimeHub 7.1] patch target missing: "..tostring(label or oldText)) end
    return string.sub(source,1,a-1)..newText..string.sub(source,b+1)
end

local okBody,src=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(src)~="string" or #src<100 then
    error("[PrimeHub 7.1] Could not download fresh 6.9 base: "..tostring(src))
end

-- Promote the complete proven 6.9 chain first.
src=string.gsub(src,"6%.9","7.1")
src=string.gsub(src,"PrimeHub_6_9_RELEASE%.lua","PrimeHub_7_1_RELEASE.lua")
src=string.gsub(src,"PrimeHub_6_9_PATCHED%.lua","PrimeHub_7_1_PATCHED.lua")

-- Insert a source-level patch into the promoted 6.9 wrapper. This uses ordinary quoted
-- strings only; unlike 7.0 there are no nested long-string delimiters to break compilation.
local insertionAnchor="-- Extend 6.8's generated cleanup/flight code with a collision snapshot."
local ia=string.find(src,insertionAnchor,1,true)
if not ia then error("[PrimeHub 7.1] queue patch insertion anchor missing") end

local queuePatchCode =
    "local queueFreshOld = '    local freshBlock=[====[    -- PrimeHub 7.1: never reuse stale JobIds between hops.\\n' ..\\n" ..
    "    '    state.serverQueue = {}\\n' ..\\n" ..
    "    '    state.serverQueueBuiltAt = 0\\n' ..\\n" ..
    "    '    state.serverQueuePlaceId = tostring(game.PlaceId or \\\"\\\")\\n\\n' ..\\n" ..
    "    ']====]\\n'\\n" ..
    "local queueFreshNew = '    local freshBlock=[====[    -- PrimeHub 7.1: keep only a short-lived server queue.\\n' ..\\n" ..
    "    '    local currentQueuePlaceId = tostring(game.PlaceId or \\\"\\\")\\n' ..\\n" ..
    "    '    local queueBuiltAt = tonumber(state.serverQueueBuiltAt) or 0\\n' ..\\n" ..
    "    '    local queueAge = queueBuiltAt > 0 and math.max(0, os.time() - queueBuiltAt) or math.huge\\n' ..\\n" ..
    "    '    local queueFreshTtl = math.max(30, tonumber(env.HopQueueFreshTtl) or 180)\\n\\n' ..\\n" ..
    "    '    if tostring(state.serverQueuePlaceId or \\\"\\\") ~= currentQueuePlaceId or queueAge > queueFreshTtl then\\n' ..\\n" ..
    "    '        state.serverQueue = {}\\n' ..\\n" ..
    "    '        state.serverQueueBuiltAt = 0\\n' ..\\n" ..
    "    '    else\\n' ..\\n" ..
    "    '        hopDebug(string.format(\\\"reusing recent server queue age=%ds size=%d ttl=%ds\\\", math.floor(queueAge), #(state.serverQueue or {}), math.floor(queueFreshTtl)))\\n' ..\\n" ..
    "    '    end\\n' ..\\n" ..
    "    '    state.serverQueuePlaceId = currentQueuePlaceId\\n\\n' ..\\n" ..
    "    ']====]\\n'\\n" ..
    "local qfa,qfb=string.find(src,queueFreshOld,1,true)\\n" ..
    "if not qfa then error(\\\"[PrimeHub 7.1] short-lived queue target missing\\\") end\\n" ..
    "src=string.sub(src,1,qfa-1)..queueFreshNew..string.sub(src,qfb+1)\\n\\n"

src=string.sub(src,1,ia-1)..queuePatchCode..string.sub(src,ia)

local fn,err=loadstring(src)
if not fn then error("[PrimeHub 7.1] Base compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 7.1] Runtime failed: "..tostring(result)) end
return result
