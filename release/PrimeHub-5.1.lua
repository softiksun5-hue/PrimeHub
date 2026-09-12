-- PrimeHub 5.1 protected release bootstrap
local BASE="https://raw.githubusercontent.com/softiksun5-hue/PrimeHub/main/release/5.1/"
local parts={}
for i=1,7 do
    local url=BASE..string.format("chunk%02d.txt",i)
    local ok,body=pcall(function() return game:HttpGet(url,true) end)
    if not ok or type(body)~="string" or #body==0 then
        error("[PrimeHub 5.1] Could not download patch chunk "..tostring(i)..": "..tostring(body))
    end
    parts[i]=body
end
local payload=table.concat(parts)
if #payload~=20373 then error("[PrimeHub 5.1] Patch size mismatch: "..tostring(#payload)) end
local a1,a2=1,0
for i=1,#payload do a1=(a1+string.byte(payload,i))%65521; a2=(a2+a1)%65521 end
if (a2*65536+a1)~=3237996658 then error("[PrimeHub 5.1] Patch integrity check failed") end
local env=(type(getgenv)=="function" and getgenv()) or _G
env.PrimeHub51PatchSource=payload
local fn,err=loadstring(payload)
if not fn then error("[PrimeHub 5.1] Patch compile failed: "..tostring(err)) end
return fn()
