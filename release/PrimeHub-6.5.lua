-- PrimeHub 6.5 release bootstrap
-- Stable 6.2 base + direct final-runtime patch for current WORLD_DROP fruit Models.
-- This bootstrap persists itself locally so the exact same 6.5 patch survives server hops.
local env=(type(getgenv)=="function" and getgenv()) or _G
local BASE_URL="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/PrimeHub-6.2.lua"
local SELF_FILE="PrimeHub_6_5_RELEASE.lua"
local INNER_FILE="PrimeHub_6_5_PATCHED.lua"

-- PrimeHub.lua passes the exact downloaded public payload here. Save it so teleport reloads
-- this outer 6.5 bootstrap, rather than an older nested patcher that lacks WORLD_DROP support.
local selfSource=env.PrimeHubPublicPayloadSource
if type(selfSource)=="string" and #selfSource>100 and type(writefile)=="function" then
    pcall(writefile,SELF_FILE,selfSource)
end
env.PrimeHubPublicPayloadSource=nil

local function freshUrl(url)
    return url .. (string.find(url,"?",1,true) and "&cb=" or "?cb=")
        .. tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
end

local function replaceRange(src, firstAnchor, secondAnchor, replacement)
    local a=string.find(src,firstAnchor,1,true)
    if not a then error("[PrimeHub 6.5] patch anchor missing: "..tostring(firstAnchor)) end
    local b=string.find(src,secondAnchor,a,true)
    if not b then error("[PrimeHub 6.5] patch end anchor missing: "..tostring(secondAnchor)) end
    return string.sub(src,1,a-1)..replacement..string.sub(src,b)
end

local function patchRuntime(src)
    local partNew=[====[
local function isServerWorldFruitModel(instance)
    if not instance or not instance.Parent or not instance:IsA("Model") then return false end
    if instance.Parent ~= workspace then return false end

    local rawName=tostring(instance.Name or "")
    local trimmedName=string.match(rawName,"^%s*(.-)%s*$") or rawName
    if string.lower(trimmedName)~="fruit" then return false end

    local handle=instance:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    local okTag,tagged=pcall(function()
        return game:GetService("CollectionService"):HasTag(instance,"WORLD_DROP")
    end)
    if okTag and tagged then return true end

    -- Fallback if the WORLD_DROP tag replicates a moment later than the object itself.
    local visual=instance:FindFirstChild("Fruit")
    local animator=instance:FindFirstChild("FruitAnimator")
    return visual~=nil and visual:IsA("Model") and animator~=nil
end

local function getDroppedFruitPart(tool)
    if not tool or not tool.Parent then return nil end

    if isServerWorldFruitModel(tool) then
        local handle=tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle end
        return nil
    end

    if not tool:IsA("Tool") then return nil end
    local handle=tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle end
    if tool.Name=="Fruit " then
        local mesh=tool:FindFirstChildWhichIsA("MeshPart")
        if mesh then return mesh end
    end
    return nil
end

]====]
    src=replaceRange(src,"local function getDroppedFruitPart(tool)","local function scanOriginalName(tool)",partNew)

    local fruitNameNew=[====[
local function fruitNameFromTool(tool)
    if not tool then return nil end
    if isServerWorldFruitModel(tool) then return "Fruit " end
    if not tool:IsA("Tool") then return nil end
    local name=tostring(tool.Name or "")
    if name=="Fruit " then return name end
    if looksLikeFruitName(name) then return name end

    local original=scanOriginalName(tool)
    if original and FruitStorageIdToName[original] then
        return FruitStorageIdToName[original]
    end
    if type(original)=="string" and original~="" then
        local left,right=string.match(original,"^(.+)%-(.+)$")
        if left and right and left==right then return left.." Fruit" end
    end
    return nil
end

]====]
    src=replaceRange(src,"local function fruitNameFromTool(tool)","local function isInsidePlayerCharacter(instance)",fruitNameNew)

    local checksNew=[====[
local function isFruitLikeTool(tool)
    if not tool then return false end
    if isServerWorldFruitModel(tool) then return true end
    if not tool:IsA("Tool") then return false end
    local name=tostring(tool.Name or "")
    if string.find(name,"Fruit",1,true) then return true end
    if scanOriginalName(tool) then return true end
    if tool:FindFirstChild("EatRemote") then return true end
    return false
end

local function isDroppedFruit(tool)
    if not tool or not tool.Parent then return false end
    if isServerWorldFruitModel(tool) then
        return getDroppedFruitPart(tool)~=nil
    end
    if not tool:IsA("Tool") then return false end
    if isInsidePlayerCharacter(tool) then return false end
    if not getDroppedFruitPart(tool) then return false end
    if tool.Name=="Fruit " then return true end
    if env.SniperAllFruits then return isFruitLikeTool(tool) end
    local resolved=fruitNameFromTool(tool)
    if not resolved then return false end
    return TargetFruitNames[resolved]==true
end

]====]
    src=replaceRange(src,"local function isFruitLikeTool(tool)","local lastScanSummaryJobId = nil",checksNew)

    local scanNew=[====[
local function scanWorkspaceForFruits(debugTag)
    local found={}
    local stats={
        mode=env.ScanDescendants and "descendants" or "top-level",
        objects=0, tools=0, worldModels=0, fruitLike=0, playerDrops=0,
        excludedHeld=0, targets=0, unlistedTargets=0, names={},
    }

    local objects=nil
    if env.ScanDescendants then
        local ok,descendants=pcall(function() return workspace:GetDescendants() end)
        objects=(ok and type(descendants)=="table") and descendants or workspace:GetChildren()
    else
        objects=workspace:GetChildren()
    end

    local nameSeen={}
    for _,object in ipairs(objects) do
        stats.objects=stats.objects+1
        local isTool=object:IsA("Tool")
        local isWorldModel=(not isTool) and object:IsA("Model") and isServerWorldFruitModel(object)
        if isTool or isWorldModel then
            if isTool then stats.tools=stats.tools+1 else stats.worldModels=stats.worldModels+1 end
            local fruitLike=isFruitLikeTool(object)
            if fruitLike then
                stats.fruitLike=stats.fruitLike+1
                local original=scanOriginalName(object)
                local label=isWorldModel and "SERVER FRUIT{WORLD_DROP}" or tostring(object.Name)
                if original then label=label.."{"..original.."}" end
                if not nameSeen[label] and #stats.names<env.ScanDebugNamesLimit then
                    nameSeen[label]=true
                    stats.names[#stats.names+1]=label
                end
                if isPlayerDroppedFruit(object) then stats.playerDrops=stats.playerDrops+1 end
            end

            if isTool and isInsidePlayerCharacter(object) then
                if fruitLike then stats.excludedHeld=stats.excludedHeld+1 end
            elseif isDroppedFruit(object) then
                found[#found+1]=object
                stats.targets=stats.targets+1
                local resolvedName=fruitNameFromTool(object)
                if resolvedName and not isRecognizedFruitName(resolvedName) then
                    stats.unlistedTargets=stats.unlistedTargets+1
                end
            end
        end
    end

    local fruitNames={}
    for _,fruit in ipairs(found) do fruitNames[#fruitNames+1]=tostring(fruit.Name) end
    table.sort(fruitNames)
    local signature=table.concat(fruitNames,"|")

    local now=tick()
    local shouldLog=env.ScanDebug and (
        debugTag~=nil
        or tostring(game.JobId)~=tostring(lastScanSummaryJobId)
        or signature~=lastScanFruitSignature
        or (stats.targets>0 and (now-lastScanLogAt)>=3)
    )
    if shouldLog then
        executorLog("SCAN",string.format(
            "%s mode=%s objects=%d tools=%d worldModels=%d fruitLike=%d playerDrops=%d excludedHeld=%d targets=%d unlisted=%d dropFilter=%s allFruits=%s names=[%s]",
            tostring(debugTag or "scan"),stats.mode,stats.objects,stats.tools,stats.worldModels,stats.fruitLike,
            stats.playerDrops,stats.excludedHeld,stats.targets,stats.unlistedTargets,"OFF",
            tostring(env.SniperAllFruits),table.concat(stats.names,", ")
        ))
        lastScanSummaryJobId=tostring(game.JobId)
        lastScanFruitSignature=signature
        lastScanLogAt=now
    end
    return found,stats
end

]====]
    src=replaceRange(src,"local function scanWorkspaceForFruits(debugTag)","local function isHeldFruitTool(item)",scanNew)

    local identityNew=[====[
local function toolMatchesFruitIdentity(item, preferredName, expectedOriginal)
    if not item or not item:IsA("Tool") then return false end

    local identityKnown=(type(expectedOriginal)=="string" and expectedOriginal~="")
        or (type(preferredName)=="string" and preferredName~="")
    if not identityKnown and isHeldFruitTool(item) then return true end

    local original=scanOriginalName(item)
    if expectedOriginal and original==expectedOriginal then return true end
    if preferredName and tostring(item.Name)==tostring(preferredName) then return true end
    local preferredId=normalizeFruitStorageIdFromName(preferredName)
    if preferredId and original==preferredId then return true end
    return false
end

]====]
    src=replaceRange(src,"local function toolMatchesFruitIdentity(item, preferredName, expectedOriginal)","local function findPickedUpTool(excludeSet, preferredName, expectedOriginal)",identityNew)

    local pickupNew=[====[
            local handle = getDroppedFruitPart(fruit)
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

    local espNew=[====[
local function createFruitESP(fruit)
    local handle=getESPHandle(fruit)
    if not handle or handle:FindFirstChild("PrimeHub_ESP") then return end

    local folder=Instance.new("Folder",handle)
    folder.Name="PrimeHub_ESP"
    local billboard=Instance.new("BillboardGui",folder)
    billboard.Name="FruitBillboard"
    billboard.Adornee=handle
    billboard.Size=UDim2.new(0,140,0,40)
    billboard.StudsOffset=Vector3.new(0,2,0)
    billboard.AlwaysOnTop=true

    local label=Instance.new("TextLabel",billboard)
    label.Size=UDim2.new(1,0,1,0)
    label.BackgroundTransparency=1
    label.TextColor3=Color3.fromRGB(255,80,80)
    label.Font=Enum.Font.GothamBold
    label.TextSize=11
    label.TextStrokeTransparency=0.4

    task.spawn(function()
        while runtimeActive() and env.FruitESP and label.Parent and handle.Parent do
            local root=getPlayerRoot()
            if root then
                local distance=math.floor((root.Position-handle.Position).Magnitude)
                local displayName=isServerWorldFruitModel(fruit) and "SERVER FRUIT" or tostring(fruit.Name)
                label.Text=displayName.." ("..tostring(distance).."m)"
            end
            task.wait(1)
        end
        if folder and folder.Parent then pcall(function() folder:Destroy() end) end
    end)
end

]====]
    src=replaceRange(src,"local function createFruitESP(fruit)","local function fruitESPWorker()",espNew)
    return src
end

local originalLoadstring=loadstring
if type(originalLoadstring)~="function" then error("[PrimeHub 6.5] loadstring unavailable") end
local patched=false

local function hookedLoadstring(code,chunkname)
    if type(code)=="string" and string.find(code,"PrimeHub 6.5 | Fruit Sniper",1,true) then
        code=patchRuntime(code)
        patched=true
    end
    return originalLoadstring(code,chunkname)
end

loadstring=hookedLoadstring

-- On a PrimeHub-initiated server hop, prefer the already-saved inner 6.5 patcher.
-- The outer hook remains active, so WORLD_DROP support is reapplied to its final runtime.
local resume=env.PrimeHubTeleportResume==true
local body=nil
local bodyIsInner=false
if resume and type(isfile)=="function" and type(readfile)=="function" and isfile(INNER_FILE) then
    local okRead,data=pcall(readfile,INNER_FILE)
    if okRead and type(data)=="string" and #data>100 then
        body=data
        bodyIsInner=true
    end
end

if not body then
    local okBody,data=pcall(function() return game:HttpGet(freshUrl(BASE_URL),false) end)
    if not okBody or type(data)~="string" or #data<100 then
        loadstring=originalLoadstring
        error("[PrimeHub 6.5] Could not download fresh 6.2 base: "..tostring(data))
    end
    -- Let the proven 6.2 generator do licensing, Sea queue scoping and teleport state,
    -- but promote all of its current-version references to 6.5.
    body=string.gsub(data,"6%.2","6.5")
end

local fn,err=originalLoadstring(body)
if not fn then
    loadstring=originalLoadstring
    error("[PrimeHub 6.5] Base bootstrap compile failed: "..tostring(err))
end
local ok,result=pcall(fn)
loadstring=originalLoadstring
if not ok then error("[PrimeHub 6.5] Runtime failed: "..tostring(result)) end
if not patched then error("[PrimeHub 6.5] Final runtime patch was not applied") end

-- Critical persistence rule: after all nested bootstraps finish, force teleport reloads back
-- to this exact outer 6.5 release, which reapplies WORLD_DROP support on every server.
env.PrimeHubLocalPayloadFile=SELF_FILE
return result
