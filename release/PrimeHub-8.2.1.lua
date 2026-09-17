-- PrimeHub 8.2.1 public compatibility assembler
-- Uses the immutable 8.2 chunks and applies a structural low-local-pressure patch before Luau compilation.
local BASE = "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/v8.2/"
local FILES = {
    "part01.txt",
    "part02.txt",
    "part03.txt",
    "part04.txt",
    "part05.txt",
    "part06.txt",
    "part07.txt",
    "part08.txt",
    "part09.txt",
    "part10.txt",
    "part11.txt",
    "part12.txt",
    "part13.txt",
    "part14.txt",
    "part15.txt",
    "part16.txt",
    "part17.txt",
    "part18.txt"
}

local parts = table.create and table.create(#FILES) or {}
local baseNonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
for i, name in ipairs(FILES) do
    local url = BASE .. name .. "?cb=" .. baseNonce .. "-" .. tostring(i)
    local ok, body = pcall(function() return game:HttpGet(url, false) end)
    if not ok or type(body) ~= "string" or #body < 100 then
        error("[PrimeHub 8.2.1] Could not download release chunk " .. name .. ": " .. tostring(body))
    end
    parts[i] = body
end

local source = table.concat(parts)
if #source < 230000 then
    error("[PrimeHub 8.2.1] Release assembly incomplete: " .. tostring(#source) .. " bytes")
end

local function replaceOnce(old, new)
    local s, e = string.find(source, old, 1, true)
    if not s then
        error("[PrimeHub 8.2.1] Compatibility patch target missing: " .. old)
    end
    source = string.sub(source, 1, s - 1) .. new .. string.sub(source, e + 1)
end

local function replaceAllPlain(old, new)
    local pos = 1
    local out = {}
    while true do
        local s, e = string.find(source, old, pos, true)
        if not s then
            out[#out + 1] = string.sub(source, pos)
            break
        end
        out[#out + 1] = string.sub(source, pos, s - 1)
        out[#out + 1] = new
        pos = e + 1
    end
    source = table.concat(out)
end

local function replaceIdentifier(old, new)
    local pos = 1
    local out = {}
    local function wordChar(ch)
        return ch ~= "" and string.match(ch, "[%w_]") ~= nil
    end
    while true do
        local s, e = string.find(source, old, pos, true)
        if not s then
            out[#out + 1] = string.sub(source, pos)
            break
        end
        local before = s > 1 and string.sub(source, s - 1, s - 1) or ""
        local after = e < #source and string.sub(source, e + 1, e + 1) or ""
        if wordChar(before) or before == "." or wordChar(after) then
            out[#out + 1] = string.sub(source, pos, e)
        else
            out[#out + 1] = string.sub(source, pos, s - 1)
            out[#out + 1] = new
        end
        pos = e + 1
    end
    source = table.concat(out)
end

-- Server-age/pre-spawn subsystem: remove 20 root-scope locals without changing behavior.
replaceOnce("local SERVER_AGE_CACHE_MAX_AGE = 36 * 60 * 60",
    "env.PrimeHubAge = env.PrimeHubAge or {}\nenv.PrimeHubAge.CACHE_MAX_AGE = 36 * 60 * 60")
replaceOnce("local SERVER_AGE_CACHE_MAX_ENTRIES = 5000", "env.PrimeHubAge.CACHE_MAX_ENTRIES = 5000")
replaceOnce("local serverAgeCache = {version=1, servers={}}", "env.PrimeHubAge.cache = env.PrimeHubAge.cache or {version=1, servers={}}")
replaceOnce("local serverAgeCacheLoaded = false", "env.PrimeHubAge.cacheLoaded = env.PrimeHubAge.cacheLoaded == true")
replaceOnce("local function loadServerAgeCache()", "env.PrimeHubAge.loadCache = function()")
replaceOnce("local function saveServerAgeCache()", "env.PrimeHubAge.saveCache = function()")
replaceOnce("local function findWorldTimeIn()", "env.PrimeHubAge.findWorldTimeIn = function()")
replaceOnce("local function currentServerTiming()", "env.PrimeHubAge.currentTiming = function()")
replaceOnce("local function formatHMS(seconds)", "env.PrimeHubAge.formatHMS = function(seconds)")
replaceOnce("local function formatMS(seconds)", "env.PrimeHubAge.formatMS = function(seconds)")
replaceOnce("local function learnCurrentServerAge()", "env.PrimeHubAge.learnCurrent = function()")
replaceOnce("local function refreshServerAgeQueueStats(queue)", "env.PrimeHubAge.refreshQueueStats = function(queue)")
replaceOnce("local SERVER_AGE_PRESPAWN_MIN = 20", "env.PrimeHubAge.PRESPAWN_MIN = 20")
replaceOnce("local SERVER_AGE_PRESPAWN_MAX = 35", "env.PrimeHubAge.PRESPAWN_MAX = 35")
replaceOnce("local SERVER_AGE_RAW_OBSERVER_INTERVAL = 45", "env.PrimeHubAge.RAW_OBSERVER_INTERVAL = 45")
replaceOnce("local serverAgeRawObserverBusy = false", "env.PrimeHubAge.rawObserverBusy = false")
replaceOnce("local function newServerAgeRawSnapshot()", "env.PrimeHubAge.newRawSnapshot = function()")
replaceOnce("local function observeServerAgeRawRow(snapshot, jobId, playing, maxPlayers, serverNow)",
    "env.PrimeHubAge.observeRawRow = function(snapshot, jobId, playing, maxPlayers, serverNow)")
replaceOnce("local function publishServerAgeRawSnapshot(snapshot, source)",
    "env.PrimeHubAge.publishRawSnapshot = function(snapshot, source)")
replaceOnce("local function runPassiveServerAgeRawObservation()",
    "env.PrimeHubAge.runPassiveRawObservation = function()")

local renames = {
    {"SERVER_AGE_CACHE_MAX_AGE", "env.PrimeHubAge.CACHE_MAX_AGE"},
    {"SERVER_AGE_CACHE_MAX_ENTRIES", "env.PrimeHubAge.CACHE_MAX_ENTRIES"},
    {"serverAgeCacheLoaded", "env.PrimeHubAge.cacheLoaded"},
    {"serverAgeCache", "env.PrimeHubAge.cache"},
    {"loadServerAgeCache", "env.PrimeHubAge.loadCache"},
    {"saveServerAgeCache", "env.PrimeHubAge.saveCache"},
    {"findWorldTimeIn", "env.PrimeHubAge.findWorldTimeIn"},
    {"currentServerTiming", "env.PrimeHubAge.currentTiming"},
    {"formatHMS", "env.PrimeHubAge.formatHMS"},
    {"formatMS", "env.PrimeHubAge.formatMS"},
    {"learnCurrentServerAge", "env.PrimeHubAge.learnCurrent"},
    {"refreshServerAgeQueueStats", "env.PrimeHubAge.refreshQueueStats"},
    {"SERVER_AGE_PRESPAWN_MIN", "env.PrimeHubAge.PRESPAWN_MIN"},
    {"SERVER_AGE_PRESPAWN_MAX", "env.PrimeHubAge.PRESPAWN_MAX"},
    {"SERVER_AGE_RAW_OBSERVER_INTERVAL", "env.PrimeHubAge.RAW_OBSERVER_INTERVAL"},
    {"serverAgeRawObserverBusy", "env.PrimeHubAge.rawObserverBusy"},
    {"newServerAgeRawSnapshot", "env.PrimeHubAge.newRawSnapshot"},
    {"observeServerAgeRawRow", "env.PrimeHubAge.observeRawRow"},
    {"publishServerAgeRawSnapshot", "env.PrimeHubAge.publishRawSnapshot"},
    {"runPassiveServerAgeRawObservation", "env.PrimeHubAge.runPassiveRawObservation"},
}
for _, pair in ipairs(renames) do replaceIdentifier(pair[1], pair[2]) end
replaceAllPlain("env.PrimeHubAge.env.PrimeHubAge.", "env.PrimeHubAge.")

-- ESP/runtime/UI helpers: another 13 root locals moved into existing env state tables.
replaceOnce("local function getESPHandle(child)", "env.PrimeHubESP = env.PrimeHubESP or {}\nenv.PrimeHubESP.getHandle = function(child)")
replaceOnce("local function destroyFruitESP()", "env.PrimeHubESP.destroy = function()")
replaceOnce("local function createFruitESP(fruit)", "env.PrimeHubESP.create = function(fruit)")
replaceOnce("local function fruitESPWorker()", "env.PrimeHubESP.worker = function()")
replaceAllPlain("getESPHandle(", "env.PrimeHubESP.getHandle(")
replaceAllPlain("destroyFruitESP(", "env.PrimeHubESP.destroy(")
replaceAllPlain("createFruitESP(", "env.PrimeHubESP.create(")
replaceAllPlain("task.spawn(fruitESPWorker)", "task.spawn(env.PrimeHubESP.worker)")
replaceAllPlain("env.PrimeHubESP.env.PrimeHubESP.", "env.PrimeHubESP.")

replaceOnce("local function startWorkers()", "env.PrimeHubRuntimeCore = env.PrimeHubRuntimeCore or {}\nenv.PrimeHubRuntimeCore.startWorkers = function()")
replaceOnce("local function initializeRuntime()", "env.PrimeHubRuntimeCore.initialize = function()")
replaceAllPlain("startWorkers()", "env.PrimeHubRuntimeCore.startWorkers()")
replaceAllPlain("initializeRuntime()", "env.PrimeHubRuntimeCore.initialize()")
replaceAllPlain("env.PrimeHubRuntimeCore.env.PrimeHubRuntimeCore.", "env.PrimeHubRuntimeCore.")

replaceOnce('local PRIMEHUB_ART_FILE = "PrimeHub_cat-girl.png"',
    'env.PrimeHubUIState = env.PrimeHubUIState or {}\nenv.PrimeHubUIState.artFile = "PrimeHub_cat-girl.png"')
replaceOnce('local PRIMEHUB_ART_URL = tostring(env.PrimeHubArtUrl or "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/assets/cat-girl.b64")',
    'env.PrimeHubUIState.artUrl = tostring(env.PrimeHubArtUrl or "https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/assets/cat-girl.b64")')
replaceOnce('local PRIMEHUB_ART_EMBEDDED_B64 = "" -- stripped to keep queued payload small',
    'env.PrimeHubUIState.artEmbeddedB64 = "" -- stripped to keep queued payload small')
replaceOnce("local function decodePrimeHubBase64(data)", "env.PrimeHubUIState.decodeBase64 = function(data)")
replaceOnce("local function ensurePrimeHubArtAsset()", "env.PrimeHubUIState.ensureArtAsset = function()")
replaceOnce("local gui = nil", "env.PrimeHubUIState.gui = nil")
replaceOnce("local function buildPrimeHubUI()", "env.PrimeHubUIState.build = function()")
replaceAllPlain("PRIMEHUB_ART_FILE", "env.PrimeHubUIState.artFile")
replaceAllPlain("PRIMEHUB_ART_URL", "env.PrimeHubUIState.artUrl")
replaceAllPlain("PRIMEHUB_ART_EMBEDDED_B64", "env.PrimeHubUIState.artEmbeddedB64")
replaceAllPlain("decodePrimeHubBase64(", "env.PrimeHubUIState.decodeBase64(")
replaceAllPlain("ensurePrimeHubArtAsset(", "env.PrimeHubUIState.ensureArtAsset(")
replaceAllPlain("buildPrimeHubUI()", "env.PrimeHubUIState.build()")
replaceAllPlain("env.PrimeHubUIState.env.PrimeHubUIState.", "env.PrimeHubUIState.")

-- `gui` is intentionally patched only in exact code fragments where it is the root UI state variable.
replaceAllPlain('gui = Instance.new("ScreenGui")', 'env.PrimeHubUIState.gui = Instance.new("ScreenGui")')
replaceAllPlain('gui.Name = "PrimeHubUI"', 'env.PrimeHubUIState.gui.Name = "PrimeHubUI"')
replaceAllPlain('gui.ResetOnSpawn = false', 'env.PrimeHubUIState.gui.ResetOnSpawn = false')
replaceAllPlain('gui.IgnoreGuiInset = true', 'env.PrimeHubUIState.gui.IgnoreGuiInset = true')
replaceAllPlain('gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling', 'env.PrimeHubUIState.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling')
replaceAllPlain('pcall(syn.protect_gui, gui)', 'pcall(syn.protect_gui, env.PrimeHubUIState.gui)')
replaceAllPlain('gui.Parent = guiParent', 'env.PrimeHubUIState.gui.Parent = guiParent')
replaceAllPlain('Instance.new("Frame", gui)', 'Instance.new("Frame", env.PrimeHubUIState.gui)')
replaceAllPlain('Instance.new("TextButton", gui)', 'Instance.new("TextButton", env.PrimeHubUIState.gui)')
replaceAllPlain('gui.Enabled=false', 'env.PrimeHubUIState.gui.Enabled=false')
replaceAllPlain('while gui and gui.Parent do', 'while env.PrimeHubUIState.gui and env.PrimeHubUIState.gui.Parent do')
replaceAllPlain('pcall(function() gui:Destroy() end)', 'pcall(function() env.PrimeHubUIState.gui:Destroy() end)')

replaceAllPlain('local PRIMEHUB_VERSION = "8.1"', 'local PRIMEHUB_VERSION = "8.2.1"')
replaceAllPlain('PrimeHub 8.1 DEV VISITED PRESPAWN PRIORITY FIX12A COMPILE-FIX loaded.',
    'PrimeHub 8.2.1 COMPAT LOW-LOCALS loaded.')
replaceAllPlain("[PrimeHub 8.1 LOWPOP 3-6 INSTANT R5]", "[PrimeHub 8.2.1]")
replaceAllPlain("[PrimeHub 8.1 TEST R5]", "[PrimeHub 8.2.1]")

local env = (type(getgenv) == "function" and getgenv()) or _G
env.PrimeHubPublicPayloadSource = source
local fn, err = loadstring(source)
if not fn then
    error("[PrimeHub 8.2.1] Release compile failed: " .. tostring(err))
end
return fn()
