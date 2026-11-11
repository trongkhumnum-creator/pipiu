-- =====================================================================
-- Harvard Labs v3.0 — Clean Minimal Wrapper (100% Native Core Intact)
-- =====================================================================

local WRAPPER_SOURCE = [=====[
local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST        = 1.5,    -- Hệ số nhân tầm đánh / bán kính kỹ năng (mặc định 1.5)
    DETECT_ONLY  = true,   -- Chỉ tung chiêu khi quái nằm trong tầm trúng
    DETECT_HOLD  = 0.2,    -- Thời gian giữ trạng thái sẵn sàng đánh sau khi quái lệch tầm (giây)
    CACHE_HZ     = 15,     -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD     = true,   -- Hiển thị vòng tròn tầm đánh dưới chân

    -- Tính năng bổ sung (Không can thiệp vào combat của script gốc):
    AUTO_REEXECUTE = true, -- Tự chạy lại script khi chuyển giữa Sảnh <-> Dungeon
    AUTO_REHOP     = true, -- Tự kết nối lại khi bị văng / mất kết nối

    -- Ghi đè nhanh cài đặt của script gốc (để nil nếu muốn giữ mặc định):
    WALK_SPEED   = nil,
    BURST_SPEED  = nil,
    STREAMER     = nil,
    AUTO_QUEUE   = true,
}
-- =====================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local CoreGui         = game:GetService("CoreGui")
local LocalPlayer     = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

local STATE_FILE    = "HarvardLabs/wrapper_state.json"
local AUTOEXEC_PATH = "HarvardLabs/autoexec_boost_wrapper.lua"

local wrapperState = {
    reExecute      = CUSTOM.AUTO_REEXECUTE,
    autoRehop      = CUSTOM.AUTO_REHOP,
    drawHud        = CUSTOM.DRAW_HUD,
    lobbyPlaceId   = nil,
    enteredTierIdx = nil,
    partyLevels    = {},
}

if type(isfile) == "function" and type(readfile) == "function" then
    local ok, exists = pcall(isfile, STATE_FILE)
    if ok and exists then
        local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(STATE_FILE)) end)
        if ok2 and type(data) == "table" then
            if type(data.reExecute) == "boolean"    then wrapperState.reExecute = data.reExecute; CUSTOM.AUTO_REEXECUTE = data.reExecute end
            if type(data.autoRehop) == "boolean"    then wrapperState.autoRehop = data.autoRehop; CUSTOM.AUTO_REHOP = data.autoRehop end
            if type(data.drawHud) == "boolean"      then wrapperState.drawHud = data.drawHud; CUSTOM.DRAW_HUD = data.drawHud end
            if type(data.lobbyPlaceId) == "number"  then wrapperState.lobbyPlaceId = data.lobbyPlaceId end
            if type(data.enteredTierIdx) == "number"then wrapperState.enteredTierIdx = data.enteredTierIdx end
            if type(data.partyLevels) == "table"    then wrapperState.partyLevels = data.partyLevels end
        end
    end
end

local function saveWrapperState()
    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" and not isfolder("HarvardLabs") then
                pcall(makefolder, "HarvardLabs")
            end
            wrapperState.reExecute = CUSTOM.AUTO_REEXECUTE
            wrapperState.autoRehop = CUSTOM.AUTO_REHOP
            wrapperState.drawHud   = CUSTOM.DRAW_HUD
            writefile(STATE_FILE, HttpService:JSONEncode(wrapperState))
        end)
    end
end

-- Quét Level thật của các nhân vật trước khi Streamer Mode của script gốc kịp ẩn thành 999
local preScanLevels = {}
local function readRawLevel(plr)
    if not plr then return nil end
    local ls = plr:FindFirstChild("leaderstats")
    local obj = (ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("level") or ls:FindFirstChild("Lvl")))
        or plr:FindFirstChild("level") or plr:FindFirstChild("Level")
    if obj then
        local n = tonumber(tostring(obj.Value):gsub(",", ""):match("%d+"))
        if n and n > 0 and n ~= 999 and n < 500 then
            preScanLevels[plr.UserId] = n
            return n
        end
    end
    local char = plr.Character or workspace:FindFirstChild(plr.Name)
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("TextLabel") and string.lower(desc.Name):find("level") then
                local n = tonumber(desc.Text:gsub(",", ""):match("%d+"))
                if n and n > 0 and n ~= 999 and n < 500 then
                    preScanLevels[plr.UserId] = n
                    return n
                end
            end
        end
    end
    return preScanLevels[plr.UserId]
end

for _, plr in ipairs(Players:GetPlayers()) do
    readRawLevel(plr)
end

-- 1. Tải và khởi chạy script gốc nguyên bản 100% ----------------------
local function fetchURL(url)
    if type(httpget) == "function" then
        local ok, res = pcall(httpget, url)
        if ok and type(res) == "string" and #res > 1000 then return res end
    end
    if type(game.HttpGet) == "function" then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" and #res > 1000 then return res end
    end
    local req = (type(syn) == "table" and syn.request) or request or http_request
    if type(req) == "function" then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and res and type(res.Body) == "string" and #res.Body > 1000 then
            return res.Body
        end
    end
    return nil
end

local source = fetchURL(ORIGINAL_URL)
if not source then
    error("[Boost] Không thể tải script gốc. Hãy kiểm tra lại ORIGINAL_URL hoặc quyền HTTP của Executor.")
end

local chunk, err = loadstring(source, "=HarvardOriginal")
if not chunk then error("[Boost] Lỗi biên dịch script gốc: " .. tostring(err)) end
chunk()

-- 2. Tìm bảng context đang chạy trong bộ nhớ --------------------------
local context
for _ = 1, 100 do
    for _, v in ipairs(getgc(true)) do
        if type(v) == "table"
            and type(rawget(v, "CFG")) == "table"
            and type(rawget(v, "RT"))  == "table"
            and type(v.CFG.aoeRadius)  == "number"
            and type(v.RT.farmEnabled) == "boolean"
        then
            context = v; break
        end
    end
    if context then break end
    task.wait(0.1)
end
if not context then error("[Boost] Không tìm thấy context trong getgc") end

local CFG, RT = context.CFG, context.RT
_G = _G or {}; getgenv = getgenv or function() return _G end

-- 3. Áp dụng tùy chỉnh tầm đánh (Chống nhân chồng nhiều lần) ----------
local KEYS = {
    "aoeRadius", "aoeDistance",
    "abilityRadius", "abilityRangeKnown",
    "aimReach", "attackRange",
    "castStartAt", "castProbe", "rangeMargin",
    "mobStandoff", "rangedStandoff",
    "bossStandoff", "mageStandoff",
    "odinIdleR", "hubKeepOut",
    "fieldReach", "fanRadius",
}

local baseCFG = {}
local baseAoeKnown = {}

local function captureBaseCFG()
    for _, k in ipairs(KEYS) do
        if type(CFG[k]) == "number" then baseCFG[k] = CFG[k] end
    end
    if type(CFG.aoeKnown) == "table" then
        for spell, entry in pairs(CFG.aoeKnown) do
            if type(entry) == "table" then
                baseAoeKnown[spell] = { x = entry.x, z = entry.z, place = entry.place }
            end
        end
    end
end

captureBaseCFG()

local function applyCustomSettings()
    for _, k in ipairs(KEYS) do
        if type(baseCFG[k]) == "number" then
            CFG[k] = baseCFG[k] * CUSTOM.BOOST
        end
    end
    if type(CFG.aoeKnown) == "table" then
        for spell, entry in pairs(CFG.aoeKnown) do
            local b = baseAoeKnown[spell]
            if type(entry) == "table" and b then
                for _, axis in ipairs({ "x", "z", "place" }) do
                    if type(b[axis]) == "number" then
                        entry[axis] = b[axis] * CUSTOM.BOOST
                    end
                end
            end
        end
    end

    if CUSTOM.WALK_SPEED then
        CFG.tweenWalk = CUSTOM.WALK_SPEED
        CFG.speedNormal = CUSTOM.WALK_SPEED
    end
    if CUSTOM.BURST_SPEED then
        CFG.burstMax = CUSTOM.BURST_SPEED
        CFG.tweenSprint = CUSTOM.BURST_SPEED
        CFG.tweenSlam = CUSTOM.BURST_SPEED
        CFG.speedBurst = CUSTOM.BURST_SPEED
    end
    if CUSTOM.STREAMER ~= nil then CFG.streamer = CUSTOM.STREAMER end
    if CUSTOM.AUTO_QUEUE ~= nil then CFG.autoQueue = CUSTOM.AUTO_QUEUE end

    -- Tắt giả số 999 trên bảng xếp hạng để đọc đúng Level của các acc trong Party
    CFG.streamerLevel       = false
    CFG.streamerOthers      = false
    CFG.streamerLeaderboard = false
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        for _, k in ipairs(KEYS) do
            if context.PERSIST[i] == k then table.remove(context.PERSIST, i); break end
        end
    end
end

applyCustomSettings()

if type(context.applyClassProfile) == "function" then
    local orig = context.applyClassProfile
    context.applyClassProfile = function(...)
        local ok = orig(...)
        if ok then
            captureBaseCFG()
            applyCustomSettings()
        end
        return ok
    end
end
if type(context.loadConfig) == "function" then
    local orig = context.loadConfig
    context.loadConfig = function(...)
        local ok = orig(...)
        if ok then
            applyCustomSettings()
        end
        return ok
    end
end

-- 4. Kiểm tra mục tiêu trong tầm đánh (Giữ nguyên nguyên bản) ---------
local cacheAt, cacheOK, cacheTgt = 0, false, nil
local lastHitAt, lastTgt = 0, nil

local function detectNow()
    if type(context.engageReady) ~= "function" or type(context.canHit) ~= "function" then
        return true, nil
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local RD  = context.RD
    if not hrp or not RD or not RD.enemies then return false, nil end
    local pos = hrp.Position
    local best, bestD = nil, math.huge
    for _, enemy in ipairs(RD.enemies) do
        if enemy.root and enemy.root.Parent
            and enemy.humanoid and enemy.humanoid.Health > 0
            and enemy.x and enemy.z then
            local d = (enemy.x - pos.X)^2 + (enemy.z - pos.Z)^2
            if d < bestD then
                local inReach, covered = false, false
                pcall(function() inReach = context.engageReady(pos, enemy) end)
                if inReach then
                    pcall(function() covered = context.canHit(pos, enemy) end)
                    if covered then best, bestD = enemy, d end
                end
            end
        end
    end
    return best ~= nil, best
end

local function detection()
    local now = os.clock()
    if now - cacheAt < 1 / CUSTOM.CACHE_HZ then return cacheOK, cacheTgt end
    cacheAt = now
    local ok, t = detectNow()
    if ok then lastHitAt, lastTgt = now, t
    elseif now - lastHitAt < CUSTOM.DETECT_HOLD then ok, t = true, lastTgt end
    cacheOK, cacheTgt = ok, t
    return ok, t
end

local function detectionRange()
    local reach = (context.fireReach and context.fireReach()) or 40
    local rad = 0
    if context.aoeLanding then
        local ok, _, r = pcall(context.aoeLanding)
        if ok and type(r) == "number" then rad = r end
    end
    return reach + rad
end

-- 5. Chặn tung chiêu khi chưa tới tầm (Giữ nguyên logic gốc của bạn) ---
local function gate(fn)
    if type(fn) ~= "function" then return fn end
    return function(slot, ...)
        if not fn(slot, ...) then return false end
        if not CUSTOM.DETECT_ONLY then return true end
        if context.isBuffSlot and context.isBuffSlot(slot) then return true end
        return (detection())
    end
end
if type(context.gsSlotReady) == "function" then context.gsSlotReady = gate(context.gsSlotReady) end
if type(context.slotReady) == "function" then context.slotReady = gate(context.slotReady) end

-- 6. Tự chọn Map & Độ khó theo Party Min Level & Chống Replay sớm -----
local DUNGEON_TIERS = {
    { idx = 1,  map = "Desert Temple",     diff = "Easy",      req = 1   },
    { idx = 2,  map = "Desert Temple",     diff = "Medium",    req = 6   },
    { idx = 3,  map = "Desert Temple",     diff = "Hard",      req = 12  },
    { idx = 4,  map = "Desert Temple",     diff = "Insane",    req = 20  },
    { idx = 5,  map = "Desert Temple",     diff = "Nightmare", req = 27  },
    { idx = 6,  map = "Winter Outpost",    diff = "Easy",      req = 33  },
    { idx = 7,  map = "Winter Outpost",    diff = "Medium",    req = 40  },
    { idx = 8,  map = "Winter Outpost",    diff = "Hard",      req = 45  },
    { idx = 9,  map = "Winter Outpost",    diff = "Insane",    req = 50  },
    { idx = 10, map = "Winter Outpost",    diff = "Nightmare", req = 55  },
    { idx = 11, map = "Pirate Island",     diff = "Insane",    req = 60  },
    { idx = 12, map = "Pirate Island",     diff = "Nightmare", req = 65  },
    { idx = 13, map = "King's Castle",     diff = "Insane",    req = 70  },
    { idx = 14, map = "King's Castle",     diff = "Nightmare", req = 75  },
    { idx = 15, map = "The Underworld",    diff = "Insane",    req = 80  },
    { idx = 16, map = "The Underworld",    diff = "Nightmare", req = 85  },
    { idx = 17, map = "Samurai Palace",    diff = "Insane",    req = 90  },
    { idx = 18, map = "Samurai Palace",    diff = "Nightmare", req = 95  },
    { idx = 19, map = "The Canals",        diff = "Insane",    req = 100 },
    { idx = 20, map = "The Canals",        diff = "Nightmare", req = 105 },
    { idx = 21, map = "Ghastly Harbor",    diff = "Insane",    req = 110 },
    { idx = 22, map = "Ghastly Harbor",    diff = "Nightmare", req = 115 },
    { idx = 23, map = "Steampunk Sewers",  diff = "Insane",    req = 120 },
    { idx = 24, map = "Steampunk Sewers",  diff = "Nightmare", req = 125 },
    { idx = 25, map = "Orbital Outpost",   diff = "Insane",    req = 135 },
    { idx = 26, map = "Orbital Outpost",   diff = "Nightmare", req = 140 },
    { idx = 27, map = "Volcanic Chambers", diff = "Insane",    req = 150 },
    { idx = 28, map = "Volcanic Chambers", diff = "Nightmare", req = 155 },
    { idx = 29, map = "Aquatic Temple",    diff = "Insane",    req = 160 },
    { idx = 30, map = "Aquatic Temple",    diff = "Nightmare", req = 165 },
    { idx = 31, map = "Enchanted Forest",  diff = "Insane",    req = 170 },
    { idx = 32, map = "Enchanted Forest",  diff = "Nightmare", req = 175 },
    { idx = 33, map = "Northern Lands",    diff = "Insane",    req = 180 },
    { idx = 34, map = "Northern Lands",    diff = "Nightmare", req = 185 },
    { idx = 35, map = "Gilded Skies",      diff = "Insane",    req = 190 },
    { idx = 36, map = "Gilded Skies",      diff = "Nightmare", req = 195 },
}

local function isLobbyPlace()
    return workspace:FindFirstChild("Lobby") ~= nil
end

if isLobbyPlace() and wrapperState.lobbyPlaceId ~= game.PlaceId then
    wrapperState.lobbyPlaceId = game.PlaceId
    saveWrapperState()
end

local function getTierForLevel(lvl)
    local best = DUNGEON_TIERS[1]
    for _, t in ipairs(DUNGEON_TIERS) do
        if lvl >= t.req then best = t else break end
    end
    return best
end

local function getPartyMinLevel()
    local now = os.time()
    wrapperState.partyLevels = type(wrapperState.partyLevels) == "table" and wrapperState.partyLevels or {}

    local myLvl = readRawLevel(LocalPlayer) or 1
    wrapperState.partyLevels[string.lower(LocalPlayer.Name)] = { name = LocalPlayer.Name, lvl = myLvl, ts = now }

    if not isLobbyPlace() then
        -- Khi đang ở trong Dungeon, tất cả người chơi trong server đều thuộc Party của bạn
        for _, plr in ipairs(Players:GetPlayers()) do
            local l = readRawLevel(plr)
            if l and l > 0 then
                wrapperState.partyLevels[string.lower(plr.Name)] = { name = plr.Name, lvl = l, ts = now }
            end
        end
    else
        -- Khi ở Sảnh: cập nhật Level của các thành viên Party đã biết hoặc acc được khai báo trong CFG.carryName
        local carryName = string.lower(tostring(CFG.carryName or ""))
        for _, plr in ipairs(Players:GetPlayers()) do
            local k = string.lower(plr.Name)
            local known = wrapperState.partyLevels[k] and (now - (tonumber(wrapperState.partyLevels[k].ts) or 0) < 900)
            if known or (carryName ~= "" and carryName:find(k, 1, true)) then
                local l = readRawLevel(plr)
                if l and l > 0 then
                    wrapperState.partyLevels[k] = { name = plr.Name, lvl = l, ts = now }
                end
            end
        end
    end

    local minLvl, minOwner = math.huge, LocalPlayer.Name
    for k, info in pairs(wrapperState.partyLevels) do
        if type(info) == "table" and tonumber(info.lvl) and (now - (tonumber(info.ts) or 0) < 900) then
            if info.lvl < minLvl then
                minLvl = info.lvl
                minOwner = info.name or k
            end
        end
    end

    -- Nếu chưa có lịch sử Party từ Dungeon, quét toàn bộ người chơi hiện có
    if minLvl == math.huge or minLvl == myLvl then
        for _, plr in ipairs(Players:GetPlayers()) do
            local l = readRawLevel(plr)
            if l and l > 0 and l < minLvl then
                minLvl = l
                minOwner = plr.Name
            end
        end
    end

    if minLvl == math.huge then minLvl = myLvl end
    return minLvl, minOwner
end

-- 7. Auto Re-Execute & Auto Re-Hop -----------------------------------
local function registerAutoReExecute()
    if not CUSTOM.AUTO_REEXECUTE then return end
    local qFn = queue_on_teleport
        or (type(syn) == "table" and syn.queue_on_teleport)
        or (type(fluxus) == "table" and fluxus.queue_on_teleport)
        or (type(delta) == "table" and delta.queue_on_teleport)
        or (getgenv and (getgenv().queue_on_teleport or getgenv().queueonteleport))
    if type(qFn) ~= "function" or getgenv().HL_TeleportQueued then return end

    local loaderCode
    if type(isfile) == "function" and pcall(isfile, AUTOEXEC_PATH) and isfile(AUTOEXEC_PATH) then
        loaderCode = ('repeat task.wait() until game:IsLoaded(); loadstring(readfile(%q))()'):format(AUTOEXEC_PATH)
    elseif type(getgenv().HL_FullWrapperFileContent) == "string" then
        loaderCode = getgenv().HL_FullWrapperFileContent
    end
    if loaderCode and pcall(qFn, loaderCode) then
        getgenv().HL_TeleportQueued = true
    end
end

registerAutoReExecute()

LocalPlayer.OnTeleport:Connect(function()
    saveWrapperState()
    if type(context.saveConfig) == "function" then pcall(context.saveConfig) end
    registerAutoReExecute()
end)

local isTeleportingToLobby = false
local function teleportPartyToLobby(reason)
    if isTeleportingToLobby then return end
    isTeleportingToLobby = true
    warn("[Boost] Đang đưa Party về Sảnh: " .. tostring(reason))
    saveWrapperState()
    if type(context.saveConfig) == "function" then pcall(context.saveConfig) end
    registerAutoReExecute()

    task.spawn(function()
        while true do
            if wrapperState.lobbyPlaceId then
                pcall(function()
                    TeleportService:Teleport(wrapperState.lobbyPlaceId, LocalPlayer)
                end)
            end
            task.wait(4)
        end
    end)
end

task.spawn(function()
    pcall(function()
        local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 10)
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" and CUSTOM.AUTO_REHOP then
                    teleportPartyToLobby("Mất kết nối (ErrorPrompt)")
                end
            end)
        end
    end)
end)

-- 8. Hiển thị vòng HUD & Mục cài đặt trong Hub Harvard Labs -----------
local status = { range = detectionRange(), canFire = false, target = nil, at = os.clock() }
getgenv().HLBoostStatus  = status
getgenv().HLBoostRange   = detectionRange
getgenv().HLBoostCanFire = detection

local hudPart
local function updateHudPartVisibility()
    if not CUSTOM.DRAW_HUD then
        if hudPart then pcall(function() hudPart.Transparency = 1 end) end
        return
    end
    pcall(function()
        local folder = workspace:FindFirstChild("HLBoostHUD")
        if not folder then
            folder = Instance.new("Folder"); folder.Name = "HLBoostHUD"; folder.Parent = workspace
        end
        hudPart = folder:FindFirstChild("detectRange")
        if not hudPart then
            hudPart = Instance.new("Part")
            hudPart.Name, hudPart.Anchored       = "detectRange", true
            hudPart.CanCollide, hudPart.CanQuery = false, false
            hudPart.CanTouch, hudPart.CastShadow = false, false
            hudPart.Material, hudPart.Shape      = Enum.Material.Neon, Enum.PartType.Cylinder
            hudPart.Color, hudPart.Transparency  = Color3.fromRGB(80, 200, 255), 0.88
            hudPart.Size, hudPart.Parent         = Vector3.new(0.1, 2, 2), folder
        else
            hudPart.Transparency = 0.88
        end
    end)
end

updateHudPartVisibility()

-- Chèn mục điều khiển nhỏ gọn vào đầu danh sách trong cửa sổ Harvard Labs
local hubStatusText = nil
local cardInjected  = false

local function tryInjectNativeCard()
    if cardInjected then return end
    local roots = {}
    if type(gethui) == "function" then pcall(function() roots[#roots + 1] = gethui() end) end
    roots[#roots + 1] = CoreGui
    roots[#roots + 1] = LocalPlayer:FindFirstChild("PlayerGui")

    local targetScroll = nil
    for _, root in ipairs(roots) do
        if root then
            for _, gui in ipairs(root:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local foundHarvard = false
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and (string.lower(d.Text or "") == "harvard labs" or string.lower(d.Text or ""):find("c84b", 1, true)) then
                            foundHarvard = true; break
                        end
                    end
                    if foundHarvard then
                        local bestArea = 0
                        for _, d in ipairs(gui:GetDescendants()) do
                            if d:IsA("ScrollingFrame") and d.AbsoluteSize.X > 350 then
                                local a = d.AbsoluteSize.X * d.AbsoluteSize.Y
                                if a > bestArea then bestArea = a; targetScroll = d end
                            end
                        end
                    end
                end
            end
        end
    end
    if not targetScroll then return end
    cardInjected = true

    local old = targetScroll:FindFirstChild("HLNativeBoostSection")
    if old then old:Destroy() end

    local card = Instance.new("Frame")
    card.Name = "HLNativeBoostSection"
    card.Size = UDim2.new(1, 0, 0, 175)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    card.BorderSizePixel = 0
    card.LayoutOrder = -9999
    card.Parent = targetScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", card); st.Color = Color3.fromRGB(40, 40, 46); st.Thickness = 1

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -28, 0, 28)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "AutoMap Party & Re-Execute (Tích hợp Harvard Labs)"
    title.TextColor3 = Color3.fromRGB(235, 65, 45)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left

    local statusLbl = Instance.new("TextLabel", card)
    statusLbl.Size = UDim2.new(1, -28, 0, 32)
    statusLbl.Position = UDim2.new(0, 14, 0, 32)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 11
    statusLbl.TextWrapped = true
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Text = "Đang kiểm tra Level Party..."
    hubStatusText = statusLbl

    local function makeToggleRow(yPos, text, key, cb)
        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(1, -28, 0, 30)
        btn.Position = UDim2.new(0, 14, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        local lbl = Instance.new("TextLabel", btn)
        lbl.Size = UDim2.new(1, -65, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local pill = Instance.new("Frame", btn)
        pill.Size = UDim2.new(0, 36, 0, 18)
        pill.Position = UDim2.new(1, -46, 0.5, -9)
        pill.BorderSizePixel = 0
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", pill)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.BorderSizePixel = 0
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function refresh()
            local on = CUSTOM[key]
            pill.BackgroundColor3 = on and Color3.fromRGB(230, 55, 35) or Color3.fromRGB(48, 48, 54)
            knob.Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            knob.BackgroundColor3 = on and Color3.fromRGB(18, 18, 20) or Color3.fromRGB(145, 145, 155)
        end

        btn.MouseButton1Click:Connect(function()
            CUSTOM[key] = not CUSTOM[key]
            refresh()
            saveWrapperState()
            if cb then cb(CUSTOM[key]) end
        end)
        refresh()
    end

    makeToggleRow(68,  "Auto Re-Execute (Tự chạy lại khi qua màn)", "AUTO_REEXECUTE", function(v)
        if v then registerAutoReExecute() end
    end)
    makeToggleRow(102, "Auto Re-Hop (Tự về Sảnh khi mất kết nối)", "AUTO_REHOP")
    makeToggleRow(136, "Hiển thị vòng tầm đánh dưới chân (HUD)", "DRAW_HUD", function()
        updateHudPartVisibility()
    end)
end

-- Luồng nhẹ kiểm tra Level Party & Chuyển Map (Chỉ cập nhật khi có thay đổi, không ép mỗi frame)
task.spawn(function()
    local bossSeen = false
    local bossDefeatedAt = nil

    while not RT.destroyed do
        tryInjectNativeCard()

        local minLvl, minOwner = getPartyMinLevel()
        local targetTier = getTierForLevel(minLvl)

        -- Chỉ cập nhật CFG và lưu khi Map hoặc Độ khó mục tiêu thực sự thay đổi
        if CFG.autoQueueMap ~= targetTier.map or CFG.autoQueueDifficulty ~= targetTier.diff then
            CFG.autoQueueMap        = targetTier.map
            CFG.autoQueueDifficulty = targetTier.diff
            CFG.autoQueueMinLevel   = 0
            if type(context.saveConfig) == "function" then pcall(context.saveConfig) end
            if type(context.refreshAll) == "function" then pcall(context.refreshAll) end
        end

        if isLobbyPlace() then
            bossSeen = false
            bossDefeatedAt = nil
            wrapperState.enteredTierIdx = targetTier.idx
            saveWrapperState()
            if hubStatusText then
                hubStatusText.Text = ("Sảnh | Party Min Lvl: %d (%s) -> Tự vào: %s [%s - Req Lv.%d]")
                    :format(minLvl, tostring(minOwner), targetTier.map, targetTier.diff, targetTier.req)
            end
        else
            if not wrapperState.enteredTierIdx or targetTier.idx < wrapperState.enteredTierIdx then
                wrapperState.enteredTierIdx = targetTier.idx
            end

            -- Kiểm tra Boss trong context.RD.enemies của script gốc
            local RD = context.RD
            local bossAlive = false
            if RD and type(RD.enemies) == "table" then
                for _, e in ipairs(RD.enemies) do
                    if e.isBoss then
                        bossSeen = true
                        if e.humanoid and e.humanoid.Health > 0 then
                            bossAlive = true
                        end
                    end
                end
            end
            if RD and type(RD.bossDown) == "table" and next(RD.bossDown) ~= nil then
                bossSeen = true
            end

            local needUpgradeMap = targetTier.idx > (wrapperState.enteredTierIdx or targetTier.idx)

            if bossSeen and not bossAlive then
                if not bossDefeatedAt then bossDefeatedAt = os.clock() end
                local waited = os.clock() - bossDefeatedAt
                if waited >= 4.5 then
                    if needUpgradeMap then
                        -- Đã giết Boss, nhận xong Drop VÀ đủ req lvl lên Độ khó / Map mới -> Đưa cả Party về Sảnh!
                        CFG.autoQueueReplay = false
                        teleportPartyToLobby(("Đủ Req Lv.%d -> Chuyển sang %s [%s]"):format(targetTier.req, targetTier.map, targetTier.diff))
                        break
                    else
                        -- Chưa lên mốc mới -> Mở lại Replay tự nhiên của Harvard Labs
                        CFG.autoQueueReplay = true
                    end
                else
                    CFG.autoQueueReplay = false
                end
            else
                -- Khi Boss chưa xuất hiện hoặc chưa chết -> Tắt Replay để không bị Replay sớm ở các map đầu
                CFG.autoQueueReplay = false
            end

            if hubStatusText then
                hubStatusText.Text = ("Dungeon | Party Min Lvl: %d (%s) -> Mục tiêu: %s [%s - Req Lv.%d]%s")
                    :format(minLvl, tostring(minOwner), targetTier.map, targetTier.diff, targetTier.req,
                        needUpgradeMap and " (Xong Boss sẽ về Sảnh lên Map)" or "")
            end
        end

        task.wait(1)
    end
end)

-- Vòng lặp cập nhật vị trí vòng tròn HUD (Giữ nguyên nguyên bản)
task.spawn(function()
    while not RT.destroyed do
        task.wait(0.1)
        local ok, target = detection()
        local range = detectionRange()
        status.at, status.range = os.clock(), range
        status.canFire, status.target = ok, target
        if CUSTOM.DRAW_HUD and hudPart and hudPart.Parent then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = range * 2
                hudPart.Size   = Vector3.new(0.1, d, d)
                hudPart.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
                hudPart.Color  = ok and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(80, 200, 255)
            end
        end
    end
end)

print(("[Boost] Đã tải | x%.2f | Detection: %s | Tầm: ~%.0f studs")
    :format(CUSTOM.BOOST, CUSTOM.DETECT_ONLY and "ON" or "OFF", detectionRange()))
]=====]

local fullSelfFile = "local WRAPPER_SOURCE = [=====[" .. WRAPPER_SOURCE .. "]=====]\n"
    .. [[
getgenv().HL_FullWrapperFileContent = "local WRAPPER_SOURCE = [=====[" .. WRAPPER_SOURCE .. "]=====]\n" .. "loadstring(WRAPPER_SOURCE, '=HLBoostWrapper')()"
if type(writefile) == "function" then
    pcall(function()
        if type(isfolder) == "function" and not isfolder("HarvardLabs") then pcall(makefolder, "HarvardLabs") end
        writefile("HarvardLabs/autoexec_boost_wrapper.lua", getgenv().HL_FullWrapperFileContent)
        writefile("boost_harvard_3.0.lua", getgenv().HL_FullWrapperFileContent)
    end)
end
loadstring(WRAPPER_SOURCE, "=HLBoostWrapper")()
]]

getgenv().HL_FullWrapperFileContent = fullSelfFile

if type(writefile) == "function" then
    pcall(function()
        if type(isfolder) == "function" and not isfolder("HarvardLabs") then
            pcall(makefolder, "HarvardLabs")
        end
        writefile("HarvardLabs/autoexec_boost_wrapper.lua", fullSelfFile)
        writefile("boost_harvard_3.0.lua", fullSelfFile)
    end)
end

local fn, compileErr = loadstring(WRAPPER_SOURCE, "=HLBoostWrapper")
if not fn then
    error("[Boost Wrapper] Lỗi khởi tạo: " .. tostring(compileErr))
end
fn()
