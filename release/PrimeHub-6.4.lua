-- PrimeHub 6.4 release bootstrap
-- Clean 6.2-based patch: detects current WORLD_DROP fruit Models without brittle full-text replacements.
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.2.lua"

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local okBody,body=pcall(function()
    return game:HttpGet(freshUrl(BASE_URL),false)
end)
if not okBody or type(body)~="string" or #body<100 then
    error("[PrimeHub 6.4] Could not download fresh 6.2 base: "..tostring(body))
end

-- Promote the already-working 6.2 bootstrap/runtime references to 6.4.
body=string.gsub(body,"6%.2","6.4")

-- Add the fruit-model patch to the transformed 6.2 bootstrap before it compiles 6.1.
local insertMarker="local fn,err=loadstring(src)"
local fruitInjection=[==========[
-- PrimeHub 6.4: append robust WORLD_DROP Model support to the readable runtime patch.
local __fruitMarker="local ua=string.find(body,protocolNew,1,true)"
local __fruitPatch=[========[
uiPatch = uiPatch .. [======[
    local partNew=[====[local function isServerWorldFruitModel(instance)
    if not instance or not instance.Parent or not instance:IsA("Model") then return false end
    if instance.Parent ~= workspace then return false end

    local rawName = tostring(instance.Name or "")
    local trimmedName = string.match(rawName, "^%s*(.-)%s*$") or rawName
    if string.lower(trimmedName) ~= "fruit" then return false end

    local handle = instance:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    local okTag, tagged = pcall(function()
        return game:GetService("CollectionService"):HasTag(instance, "WORLD_DROP")
    end)
    if okTag and tagged then return true end

    local visual = instance:FindFirstChild("Fruit")
    local animator = instance:FindFirstChild("FruitAnimator")
    return visual ~= nil and visual:IsA("Model") and animator ~= nil
end

local function getDroppedFruitPart(tool)
    if not tool or not tool.Parent then return nil end

    if isServerWorldFruitModel(tool) then
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle end
        return nil
    end

    if not tool:IsA("Tool") then return nil end
    local handle = tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle end
    if tool.Name == "Fruit " then
        local mesh = tool:FindFirstChildWhichIsA("MeshPart")
        if mesh then return mesh end
    end
    return nil
end

]====]
    src=replaceRange(src,"local function getDroppedFruitPart(tool)","local function scanOriginalName(tool)",partNew)

    local fruitNameNew=[====[local function fruitNameFromTool(tool)
    if not tool then return nil end
    if isServerWorldFruitModel(tool) then return "Fruit " end
    if not tool:IsA("Tool") then return nil end
    local name = tostring(tool.Name or "")
    if name == "Fruit " then return name end

    if looksLikeFruitName(name) then return name end

    local original = scanOriginalName(tool)
    if original and FruitStorageIdToName[original] then
        return FruitStorageIdToName[original]
    end

    if type(original) == "string" and original ~= "" then
        local left, right = string.match(original, "^(.+)%-(.+)$")
        if left and right and left == right then
            return left .. " Fruit"
        end
    end
    return nil
end

]====]
    src=replaceRange(src,"local function fruitNameFromTool(tool)","local function isInsidePlayerCharacter(instance)",fruitNameNew)

    local fruitChecksNew=[====[local function isFruitLikeTool(tool)
    if not tool then return false end
    if isServerWorldFruitModel(tool) then return true end
    if not tool:IsA("Tool") then return false end
    local name = tostring(tool.Name or "")
    if string.find(name, "Fruit", 1, true) then return true end
    if scanOriginalName(tool) then return true end
    if tool:FindFirstChild("EatRemote") then return true end
    return false
end

local function isDroppedFruit(tool)
    if not tool or not tool.Parent then return false end
    if isServerWorldFruitModel(tool) then
        return getDroppedFruitPart(tool) ~= nil
    end
    if not tool:IsA("Tool") then return false end
    if isInsidePlayerCharacter(tool) then return false end
    if not getDroppedFruitPart(tool) then return false end

    if tool.Name == "Fruit " then return true end

    if env.SniperAllFruits then
        return isFruitLikeTool(tool)
    end

    local resolved = fruitNameFromTool(tool)
    if not resolved then return false end
    return TargetFruitNames[resolved] == true
end

]====]
    src=replaceRange(src,"local function isFruitLikeTool(tool)","local lastScanSummaryJobId = nil",fruitChecksNew)

    local scanNew=[====[local function scanWorkspaceForFruits(debugTag)
    local found = {}
    local stats = {
        mode = env.ScanDescendants and "descendants" or "top-level",
        objects = 0,
        tools = 0,
        worldModels = 0,
        fruitLike = 0,
        playerDrops = 0,
        excludedHeld = 0,
        targets = 0,
        unlistedTargets = 0,
        names = {},
    }

    local objects = nil
    if env.ScanDescendants then
        local ok, descendants = pcall(function() return workspace:GetDescendants() end)
        objects = (ok and type(descendants) == "table") and descendants or workspace:GetChildren()
    else
        objects = workspace:GetChildren()
    end

    local nameSeen = {}
    for _, object in ipairs(objects) do
        stats.objects = stats.objects + 1
        local isTool = object:IsA("Tool")
        local isWorldModel = (not isTool) and object:IsA("Model") and isServerWorldFruitModel(object)
        if isTool or isWorldModel then
            if isTool then
                stats.tools = stats.tools + 1
            else
                stats.worldModels = stats.worldModels + 1
            end

            local fruitLike = isFruitLikeTool(object)
            if fruitLike then
                stats.fruitLike = stats.fruitLike + 1
                local original = scanOriginalName(object)
                local label = isWorldModel and "SERVER FRUIT{WORLD_DROP}" or tostring(object.Name)
                if original then label = label .. "{" .. original .. "}" end
                if not nameSeen[label] and #stats.names < env.ScanDebugNamesLimit then
                    nameSeen[label] = true
                    stats.names[#stats.names + 1] = label
                end
                if isPlayerDroppedFruit(object) then
                    stats.playerDrops = stats.playerDrops + 1
                end
            end

            if isTool and isInsidePlayerCharacter(object) then
                if fruitLike then stats.excludedHeld = stats.excludedHeld + 1 end
            elseif isDroppedFruit(object) then
                found[#found + 1] = object
                stats.targets = stats.targets + 1
                local resolvedName = fruitNameFromTool(object)
                if resolvedName and not isRecognizedFruitName(resolvedName) then
                    stats.unlistedTargets = stats.unlistedTargets + 1
                end
            end
        end
    end

    local fruitNames = {}
    for _, fruit in ipairs(found) do fruitNames[#fruitNames + 1] = tostring(fruit.Name) end
    table.sort(fruitNames)
    local signature = table.concat(fruitNames, "|")

    local now = tick()
    local shouldLog = env.ScanDebug and (
        debugTag ~= nil
        or tostring(game.JobId) ~= tostring(lastScanSummaryJobId)
        or signature ~= lastScanFruitSignature
        or (stats.targets > 0 and (now - lastScanLogAt) >= 3)
    )
    if shouldLog then
        executorLog("SCAN", string.format(
            "%s mode=%s objects=%d tools=%d worldModels=%d fruitLike=%d playerDrops=%d excludedHeld=%d targets=%d unlisted=%d dropFilter=%s allFruits=%s names=[%s]",
            tostring(debugTag or "scan"), stats.mode, stats.objects, stats.tools, stats.worldModels, stats.fruitLike,
            stats.playerDrops, stats.excludedHeld, stats.targets, stats.unlistedTargets, "OFF",
            tostring(env.SniperAllFruits), table.concat(stats.names, ", ")
        ))
        lastScanSummaryJobId = tostring(game.JobId)
        lastScanFruitSignature = signature
        lastScanLogAt = now
    end

    return found, stats
end

]====]
    src=replaceRange(src,"local function scanWorkspaceForFruits(debugTag)","local function isHeldFruitTool(item)",scanNew)

    local identityNew=[====[local function toolMatchesFruitIdentity(item, preferredName, expectedOriginal)
    if not item or not item:IsA("Tool") then return false end

    local identityKnown = (type(expectedOriginal) == "string" and expectedOriginal ~= "")
        or (type(preferredName) == "string" and preferredName ~= "")
    if not identityKnown and isHeldFruitTool(item) then
        return true
    end

    local original = scanOriginalName(item)
    if expectedOriginal and original == expectedOriginal then
        return true
    end

    if preferredName and tostring(item.Name) == tostring(preferredName) then
        return true
    end

    local preferredId = normalizeFruitStorageIdFromName(preferredName)
    if preferredId and original == preferredId then
        return true
    end

    return false
end

]====]
    src=replaceRange(src,"local function toolMatchesFruitIdentity(item, preferredName, expectedOriginal)","local function findPickedUpTool(excludeSet, preferredName, expectedOriginal)",identityNew)

    local pickupNew=[====[            local handle = getDroppedFruitPart(fruit)
            local root = getPlayerRoot()
            if handle and root then
                local pickupOffset = isServerWorldFruitModel(fruit) and 2 or (tonumber(env.FlyOffset) or 5)
                root.CFrame = handle.CFrame + Vector3.new(0, pickupOffset, 0)
                root.Velocity = Vector3.zero
                root.AssemblyLinearVelocity = Vector3.zero
                root.RotVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            elseif not root then
                AddLog("INSTA TP failed: root unavailable.", Color3.fromRGB(255, 100, 100))
                break
            end

]====]
    src=replaceRange(src,"            local handle = getDroppedFruitPart(fruit)","            task.wait(0.1)",pickupNew)

    local espNew=[====[local function createFruitESP(fruit)
    local handle = getESPHandle(fruit)
    if not handle or handle:FindFirstChild("PrimeHub_ESP") then return end

    local folder = Instance.new("Folder", handle)
    folder.Name = "PrimeHub_ESP"

    local billboard = Instance.new("BillboardGui", folder)
    billboard.Name = "FruitBillboard"
    billboard.Adornee = handle
    billboard.Size = UDim2.new(0, 140, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextStrokeTransparency = 0.4

    task.spawn(function()
        while runtimeActive() and env.FruitESP and label.Parent and handle.Parent do
            local root = getPlayerRoot()
            if root then
                local distance = math.floor((root.Position - handle.Position).Magnitude)
                local displayName = isServerWorldFruitModel(fruit) and "SERVER FRUIT" or tostring(fruit.Name)
                label.Text = displayName .. " (" .. tostring(distance) .. "m)"
            end
            task.wait(1)
        end
        if folder and folder.Parent then pcall(function() folder:Destroy() end) end
    end)
end

]====]
    src=replaceRange(src,"local function createFruitESP(fruit)","local function fruitESPWorker()",espNew)
]======]

local __fa=string.find(src,__fruitMarker,1,true)
if not __fa then error("[PrimeHub 6.4] Fruit patch insertion point missing") end
src=string.sub(src,1,__fa-1)..__fruitPatch..string.sub(src,__fa)
]==========]

local ia=string.find(body,insertMarker,1,true)
if not ia then error("[PrimeHub 6.4] 6.2 bootstrap insertion point missing") end
body=string.sub(body,1,ia-1)..fruitInjection..string.sub(body,ia)

local fn,err=loadstring(body)
if not fn then error("[PrimeHub 6.4] Base bootstrap compile failed: "..tostring(err)) end
local ok,result=pcall(fn)
if not ok then error("[PrimeHub 6.4] Runtime failed: "..tostring(result)) end
return result
