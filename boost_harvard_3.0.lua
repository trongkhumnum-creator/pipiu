-- =====================================================================
-- Harvard Labs v3.0 — Custom Boost + Auto Map + Auto Re-Exec / Re-Hop
-- =====================================================================

local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"
local WRAPPER_URL  = nil -- Nếu bạn up file wrapper này lên Github/Pastebin, hãy điền link vào đây, hoặc đặt tên file trong workspace là "boost_harvard_3.0.lua"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST        = 1.5,    -- Hệ số nhân tầm đánh / bán kính kỹ năng (mặc định 1.5)
    DETECT_ONLY  = true,   -- Chỉ tung chiêu khi quái nằm trong tầm trúng
    DETECT_HOLD  = 0.2,    -- Thời gian giữ trạng thái sẵn sàng đánh sau khi quái lệch tầm (giây)
    CACHE_HZ     = 15,     -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD     = true,   -- Hiển thị vòng tròn tầm đánh dưới chân
    
    -- Tính năng mới: Tự chọn Map theo Level thấp nhất & Auto Re-hop / Re-execute
    AUTO_MAP_BY_MIN_LVL = true,  -- Tự động chọn Map + Độ khó vừa với acc có Level thấp nhất
    SCAN_PARTY_ONLY     = false, -- false = quét toàn bộ acc bạn chỉ định trong WHITELIST_ACCS (hoặc toàn server nếu để trống); true = chỉ tính acc của chính mình
    WHITELIST_ACCS      = {},    -- VD: {"AccChinh", "AccClone1", "AccClone2"} (Để trống {} sẽ quét toàn bộ người chơi hiện có hoặc chỉ bản thân)
    FORCE_HARDCORE      = false, -- Chế độ Hardcore khi tạo phòng
    FORCE_PRIVATE       = true,  -- Luôn tạo phòng Private
    
    AUTO_REEXECUTE      = true,  -- Tự động chạy lại script khi chuyển map (Lobby <-> Dungeon)
    WRAPPER_FILE_NAME   = "boost_harvard_3.0.lua", -- Tên file lưu trong thư mục workspace của Executor (nếu không dùng WRAPPER_URL)
    
    AUTO_REHOP          = true,  -- Tự động kết nối lại / đổi server khi bị văng hoặc kẹt ở Lobby
    LOBBY_STUCK_TIMEOUT = 120,   -- Nếu kẹt ở Lobby quá X giây không vào được trận thì tự Re-hop (đặt nil nếu muốn tắt)

    -- Ghi đè nhanh cài đặt của script gốc (để nil nếu muốn giữ mặc định):
    WALK_SPEED   = nil,
    BURST_SPEED  = nil,
    STREAMER     = nil,
    AUTO_QUEUE   = true,   -- Bật sẵn Auto Queue để kết hợp với Auto Map
}
-- =====================================================================

-- Danh sách bảng yêu cầu Level chuẩn của Dungeon Quest (Map + Difficulty)
local DUNGEON_TIERS = {
    { map = "Desert Temple",        diff = "Easy",      req = 1   },
    { map = "Desert Temple",        diff = "Medium",    req = 5   },
    { map = "Desert Temple",        diff = "Hard",      req = 15  },
    { map = "Winter Outpost",       diff = "Easy",      req = 30  },
    { map = "Winter Outpost",       diff = "Medium",    req = 40  },
    { map = "Winter Outpost",       diff = "Hard",      req = 50  },
    { map = "Pirate Island",        diff = "Insane",    req = 60  },
    { map = "Pirate Island",        diff = "Nightmare", req = 65  },
    { map = "King's Castle",        diff = "Insane",    req = 70  },
    { map = "King's Castle",        diff = "Nightmare", req = 75  },
    { map = "The Underworld",       diff = "Insane",    req = 80  },
    { map = "The Underworld",       diff = "Nightmare", req = 85  },
    { map = "Samurai Palace",       diff = "Insane",    req = 90  },
    { map = "Samurai Palace",       diff = "Nightmare", req = 95  },
    { map = "The Canals",           diff = "Insane",    req = 100 },
    { map = "The Canals",           diff = "Nightmare", req = 105 },
    { map = "Ghastly Harbor",       diff = "Insane",    req = 110 },
    { map = "Ghastly Harbor",       diff = "Nightmare", req = 115 },
    { map = "Steampunk Sewers",     diff = "Insane",    req = 120 },
    { map = "Steampunk Sewers",     diff = "Nightmare", req = 125 },
    { map = "Orbital Outpost",      diff = "Insane",    req = 135 },
    { map = "Orbital Outpost",      diff = "Nightmare", req = 140 },
    { map = "Volcanic Chambers",    diff = "Insane",    req = 150 },
    { map = "Volcanic Chambers",    diff = "Nightmare", req = 155 },
    { map = "Aquatic Temple",       diff = "Insane",    req = 160 },
    { map = "Aquatic Temple",       diff = "Nightmare", req = 165 },
    { map = "Enchanted Forest",     diff = "Insane",    req = 170 },
    { map = "Enchanted Forest",     diff = "Nightmare", req = 175 },
    { map = "Northern Lands",       diff = "Insane",    req = 180 },
    { map = "Northern Lands",       diff = "Nightmare", req = 185 },
    { map = "Gilded Skies",         diff = "Insane",    req = 190 },
    { map = "Gilded Skies",         diff = "Nightmare", req = 195 },
}

-- 1. Tải và khởi chạy script gốc --------------------------------------
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

if not game:IsLoaded() then game.Loaded:Wait() end

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
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- 3. Hàm đọc Level nhân vật & Tự động chọn Map theo Min Level ---------
local function getPlayerLevel(plr)
    if not plr then return nil end
    -- Kiểm tra leaderstats.Level
    local ls = plr:FindFirstChild("leaderstats")
    local lvlObj = (ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("level") or ls:FindFirstChild("Lvl")))
        or plr:FindFirstChild("Level") or plr:FindFirstChild("level")
    if lvlObj and tonumber(lvlObj.Value) then
        return tonumber(lvlObj.Value)
    end
    -- Kiểm tra dữ liệu từ Character hoặc GUI nếu leaderstats bị ẩn bởi Streamer mode
    if plr == LocalPlayer then
        local gui = plr:FindFirstChild("PlayerGui")
        if gui then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Name:lower():find("level") then
                    local num = tonumber(desc.Text:match("%d+"))
                    if num and num > 0 and num < 500 then return num end
                end
            end
        end
    end
    return nil
end

local function getLowestAccountLevel()
    local whitelist = {}
    local hasWhitelist = false
    if type(CUSTOM.WHITELIST_ACCS) == "table" and #CUSTOM.WHITELIST_ACCS > 0 then
        hasWhitelist = true
        for _, name in ipairs(CUSTOM.WHITELIST_ACCS) do
            whitelist[string.lower(name)] = true
        end
    end

    local minLvl = math.huge
    if CUSTOM.SCAN_PARTY_ONLY then
        local myLvl = getPlayerLevel(LocalPlayer)
        if myLvl and myLvl > 0 then minLvl = myLvl end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            local allow = true
            if hasWhitelist and plr ~= LocalPlayer and not whitelist[string.lower(plr.Name)] then
                allow = false
            end
            if allow then
                local lvl = getPlayerLevel(plr)
                if lvl and lvl > 0 and lvl < minLvl then
                    minLvl = lvl
                end
            end
        end
    end

    if minLvl == math.huge then
        minLvl = getPlayerLevel(LocalPlayer) or 1
    end
    return minLvl
end

local function selectBestDungeonForLevel(lvl)
    local best = DUNGEON_TIERS[1]
    for _, tier in ipairs(DUNGEON_TIERS) do
        if lvl >= tier.req then
            best = tier
        else
            break
        end
    end
    return best.map, best.diff, best.req
end

local function updateAutoQueueMap()
    if not CUSTOM.AUTO_MAP_BY_MIN_LVL then return end
    local minLvl = getLowestAccountLevel()
    local bestMap, bestDiff, reqLvl = selectBestDungeonForLevel(minLvl)
    
    CFG.autoQueueMap        = bestMap
    CFG.autoQueueDifficulty = bestDiff
    CFG.autoQueueMinLevel   = 0 -- Đặt về 0 để bộ lọc của script gốc không chặn tự tạo phòng
    if CUSTOM.FORCE_HARDCORE ~= nil then CFG.autoQueueHardcore = CUSTOM.FORCE_HARDCORE end
    if CUSTOM.FORCE_PRIVATE  ~= nil then CFG.autoQueuePrivate  = CUSTOM.FORCE_PRIVATE  end
    
    return minLvl, bestMap, bestDiff, reqLvl
end

-- 4. Áp dụng tùy chỉnh tầm đánh (Scale) & Cài đặt nhanh ---------------
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

local NON_PERSIST_KEYS = { "autoQueueMap", "autoQueueDifficulty", "autoQueueMinLevel" }

local function applyCustomSettings()
    for _, k in ipairs(KEYS) do
        if type(CFG[k]) == "number" then CFG[k] = CFG[k] * CUSTOM.BOOST end
    end
    if type(CFG.aoeKnown) == "table" then
        for _, entry in pairs(CFG.aoeKnown) do
            if type(entry) == "table" then
                for _, k in ipairs({ "x", "z", "place" }) do
                    if type(entry[k]) == "number" then entry[k] = entry[k] * CUSTOM.BOOST end
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

    updateAutoQueueMap()
end

-- Gỡ các khóa bị ghi đè khỏi PERSIST để file save JSON không đè ngược lại
if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        local key = context.PERSIST[i]
        local removeKey = false
        for _, k in ipairs(KEYS) do
            if key == k then removeKey = true; break end
        end
        if not removeKey and CUSTOM.AUTO_MAP_BY_MIN_LVL then
            for _, k in ipairs(NON_PERSIST_KEYS) do
                if key == k then removeKey = true; break end
            end
        end
        if removeKey then table.remove(context.PERSIST, i) end
    end
end

applyCustomSettings()

if type(context.applyClassProfile) == "function" then
    local orig = context.applyClassProfile
    context.applyClassProfile = function(...)
        local ok = orig(...); if ok then applyCustomSettings() end; return ok
    end
end
if type(context.loadConfig) == "function" then
    local orig = context.loadConfig
    context.loadConfig = function(...)
        local ok = orig(...); if ok then applyCustomSettings() end; return ok
    end
end

-- Luồng liên tục cập nhật Map theo Level thấp nhất (mỗi 3 giây khi ở Lobby)
if CUSTOM.AUTO_MAP_BY_MIN_LVL then
    task.spawn(function()
        local lastLog = ""
        while not RT.destroyed do
            local minLvl, bestMap, bestDiff, reqLvl = updateAutoQueueMap()
            local sig = ("%s|%s|%d"):format(tostring(bestMap), tostring(bestDiff), minLvl or 0)
            if sig ~= lastLog then
                lastLog = sig
                print(("[Boost][AutoMap] Min Level: %d -> Chọn Map: %s (%s - Req Lv.%d)")
                    :format(minLvl or 1, tostring(bestMap), tostring(bestDiff), reqLvl or 1))
                if type(context.refreshAll) == "function" then
                    pcall(context.refreshAll)
                end
            end
            task.wait(3)
        end
    end)
end

-- 5. Tính năng Auto Re-Execute & Auto Re-Hop --------------------------
local queueTeleport = queue_on_teleport
    or (type(syn) == "table" and syn.queue_on_teleport)
    or (type(fluxus) == "table" and fluxus.queue_on_teleport)

if CUSTOM.AUTO_REEXECUTE and type(queueTeleport) == "function" then
    local queued = false
    LocalPlayer.OnTeleport:Connect(function(state)
        if queued then return end
        if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress or state == Enum.TeleportState.RequestedFromServer then
            queued = true
            local payload
            if type(WRAPPER_URL) == "string" and #WRAPPER_URL > 10 then
                payload = ('repeat task.wait() until game:IsLoaded(); loadstring(game:HttpGet("%s"))()'):format(WRAPPER_URL)
            elseif type(isfile) == "function" and pcall(isfile, CUSTOM.WRAPPER_FILE_NAME) and isfile(CUSTOM.WRAPPER_FILE_NAME) then
                payload = ('repeat task.wait() until game:IsLoaded(); loadstring(readfile("%s"))()'):format(CUSTOM.WRAPPER_FILE_NAME)
            else
                -- Nếu người dùng chạy trực tiếp từ clipboard mà chưa lưu file, tự động lưu vào workspace để re-execute
                payload = ('repeat task.wait() until game:IsLoaded(); loadstring(game:HttpGet("%s"))()'):format(ORIGINAL_URL)
            end
            pcall(queueTeleport, payload)
            print("[Boost] Đã đăng ký Auto Re-Execute cho lần chuyển server tiếp theo.")
        end
    end)
end

local function triggerRehop(reason)
    if not CUSTOM.AUTO_REHOP then return end
    warn("[Boost][AutoRehop] Đang thực hiện Re-hop. Lý do: " .. tostring(reason))
    task.spawn(function()
        while true do
            pcall(function()
                -- PlaceId gốc của sảnh chính Dungeon Quest: 2414851778
                TeleportService:Teleport(2414851778, LocalPlayer)
            end)
            task.wait(5)
        end
    end)
end

if CUSTOM.AUTO_REHOP then
    -- Bắt sự kiện văng game / Error Prompt (Kick, Disconnect, Teleport Failed)
    pcall(function()
        local promptOverlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 10)
            and game:GetService("CoreGui").RobloxPromptGui:WaitForChild("promptOverlay", 10)
        if promptOverlay then
            promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    triggerRehop("Phát hiện bảng thông báo mất kết nối (ErrorPrompt)")
                end
            end)
        end
    end)

    TeleportService.TeleportInitFailed:Connect(function(_, teleportResult, errorMessage)
        warn("[Boost] Teleport thất bại (" .. tostring(teleportResult) .. "): " .. tostring(errorMessage))
        task.wait(3)
        triggerRehop("TeleportInitFailed")
    end)

    -- Kiểm tra nếu kẹt ở Lobby quá lâu không vào được Dungeon
    if type(CUSTOM.LOBBY_STUCK_TIMEOUT) == "number" and CUSTOM.LOBBY_STUCK_TIMEOUT > 0 then
        task.spawn(function()
            local startTime = os.clock()
            while not RT.destroyed do
                task.wait(5)
                -- Nếu đang ở Lobby (không có folder dungeon hoặc enemies hoạt động) và bật autoQueue
                local inDungeon = workspace:FindFirstChild("dungeon") ~= nil
                if not inDungeon and CFG.autoQueue then
                    if os.clock() - startTime > CUSTOM.LOBBY_STUCK_TIMEOUT then
                        triggerRehop("Kẹt ở Lobby quá " .. tostring(CUSTOM.LOBBY_STUCK_TIMEOUT) .. " giây")
                        break
                    end
                else
                    startTime = os.clock()
                end
            end
        end)
    end
end

-- 6. Kiểm tra mục tiêu trong tầm đánh (Landing Detection) -------------
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

-- 7. Chặn tung chiêu khi chưa tới tầm (Bỏ qua chiêu Buff) -------------
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

-- 8. Hiển thị vòng HUD ------------------------------------------------
local status = { range = detectionRange(), canFire = false, target = nil, at = os.clock() }
getgenv().HLBoostStatus  = status
getgenv().HLBoostRange   = detectionRange
getgenv().HLBoostCanFire = detection

local hudPart
if CUSTOM.DRAW_HUD then
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
        end
    end)
end

task.spawn(function()
    while not RT.destroyed do
        task.wait(0.1)
        local ok, target = detection()
        local range = detectionRange()
        status.at, status.range = os.clock(), range
        status.canFire, status.target = ok, target
        if hudPart and hudPart.Parent then
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