-- =====================================================================
-- Harvard Labs v3.0 — Fixed Boost + Anti-Early Replay + AutoMap & Hub
-- =====================================================================

local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"
local WRAPPER_URL  = nil -- Điền link raw nếu bạn upload file này lên GitHub, hoặc lưu file vào workspace với tên "boost_harvard_3.0.lua"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST               = 1.5,   -- Hệ số nhân tầm đánh / bán kính kỹ năng
    DETECT_ONLY         = false, -- Đổi mặc định thành false để tránh kẹt chiêu ở các map đầu (có thể bật lại trên Hub)
    DETECT_HOLD         = 0.35,  -- Thời gian giữ trạng thái đánh sau khi quái lệch tầm (giây)
    CACHE_HZ            = 15,    -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD            = true,  -- Hiển thị vòng tròn tầm đánh dưới chân

    -- Chống Replay sớm & Bảo vệ Drop sau khi giết Boss
    ANTI_EARLY_REPLAY   = true,  -- Khóa Replay/Queue khi Boss chưa chết & chưa nhận xong Drop
    LOOT_WAIT_TIME      = 6,     -- Số giây chờ nhận Drop sau khi Boss chết rồi mới Replay / Về sảnh
    USE_REPLAY_IN_DUNGEON = true,-- Bật Replay sau khi Boss chết + nhận xong Drop (nếu vẫn đủ Level)

    -- Tự chọn Map theo Level thấp nhất
    AUTO_MAP_BY_MIN_LVL = true,  -- Tự động chọn Map + Độ khó theo acc có Level thấp nhất
    ONLY_MY_ACCOUNT     = false, -- true = chỉ tính Level acc này; false = tính acc thấp nhất trong sảnh
    WHITELIST_ACCS      = {},    -- VD: {"AccChinh", "AccPhu1"} (Để trống {} sẽ quét toàn bộ người trong sảnh)
    ALLOW_GILDED_SKIES  = false, -- true = cho phép lên Gilded Skies (Lv.190+); false = dừng ở Northern Lands
    FORCE_HARDCORE      = false,
    FORCE_PRIVATE       = true,

    -- Auto Re-Execute & Auto Re-Hop
    AUTO_REEXECUTE      = true,  -- Tự chạy lại script khi chuyển giữa Lobby <-> Dungeon
    AUTO_REHOP          = true,  -- Tự kết nối lại khi mất kết nối / kẹt Lobby
    LOBBY_STUCK_TIMEOUT = 120,   -- Quá X giây kẹt ở Lobby không vào được Dungeon sẽ tự Re-hop

    -- Ghi đè nhanh cài đặt của script gốc (để nil nếu giữ mặc định):
    WALK_SPEED          = nil,
    BURST_SPEED         = nil,
    STREAMER            = nil,
}
-- =====================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

local LOBBY_PLACE_ID = 2414851778
local HUB_CFG_FILE   = "HarvardLabs/boost_hub_config.json"

local function loadHubConfig()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, HUB_CFG_FILE)
        if ok and exists then
            local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(HUB_CFG_FILE)) end)
            if ok2 and type(data) == "table" then
                for k, v in pairs(data) do
                    if CUSTOM[k] ~= nil then CUSTOM[k] = v end
                end
            end
        end
    end
end

local function saveHubConfig()
    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" and not isfolder("HarvardLabs") then
                pcall(makefolder, "HarvardLabs")
            end
            writefile(HUB_CFG_FILE, HttpService:JSONEncode({
                BOOST               = CUSTOM.BOOST,
                DETECT_ONLY         = CUSTOM.DETECT_ONLY,
                DRAW_HUD            = CUSTOM.DRAW_HUD,
                ANTI_EARLY_REPLAY   = CUSTOM.ANTI_EARLY_REPLAY,
                LOOT_WAIT_TIME      = CUSTOM.LOOT_WAIT_TIME,
                AUTO_MAP_BY_MIN_LVL = CUSTOM.AUTO_MAP_BY_MIN_LVL,
                ONLY_MY_ACCOUNT     = CUSTOM.ONLY_MY_ACCOUNT,
                ALLOW_GILDED_SKIES  = CUSTOM.ALLOW_GILDED_SKIES,
                AUTO_REEXECUTE      = CUSTOM.AUTO_REEXECUTE,
                AUTO_REHOP          = CUSTOM.AUTO_REHOP,
            }))
        end)
    end
end

loadHubConfig()

local DUNGEON_TIERS = {
    { map = "Desert Temple",     diff = "Easy",      req = 1   },
    { map = "Desert Temple",     diff = "Medium",    req = 5   },
    { map = "Desert Temple",     diff = "Hard",      req = 15  },
    { map = "Winter Outpost",    diff = "Easy",      req = 30  },
    { map = "Winter Outpost",    diff = "Medium",    req = 40  },
    { map = "Winter Outpost",    diff = "Hard",      req = 50  },
    { map = "Pirate Island",     diff = "Insane",    req = 60  },
    { map = "Pirate Island",     diff = "Nightmare", req = 65  },
    { map = "King's Castle",     diff = "Insane",    req = 70  },
    { map = "King's Castle",     diff = "Nightmare", req = 75  },
    { map = "The Underworld",    diff = "Insane",    req = 80  },
    { map = "The Underworld",    diff = "Nightmare", req = 85  },
    { map = "Samurai Palace",    diff = "Insane",    req = 90  },
    { map = "Samurai Palace",    diff = "Nightmare", req = 95  },
    { map = "The Canals",        diff = "Insane",    req = 100 },
    { map = "The Canals",        diff = "Nightmare", req = 105 },
    { map = "Ghastly Harbor",    diff = "Insane",    req = 110 },
    { map = "Ghastly Harbor",    diff = "Nightmare", req = 115 },
    { map = "Steampunk Sewers",  diff = "Insane",    req = 120 },
    { map = "Steampunk Sewers",  diff = "Nightmare", req = 125 },
    { map = "Orbital Outpost",   diff = "Insane",    req = 135 },
    { map = "Orbital Outpost",   diff = "Nightmare", req = 140 },
    { map = "Volcanic Chambers", diff = "Insane",    req = 150 },
    { map = "Volcanic Chambers", diff = "Nightmare", req = 155 },
    { map = "Aquatic Temple",    diff = "Insane",    req = 160 },
    { map = "Aquatic Temple",    diff = "Nightmare", req = 165 },
    { map = "Enchanted Forest",  diff = "Insane",    req = 170 },
    { map = "Enchanted Forest",  diff = "Nightmare", req = 175 },
    { map = "Northern Lands",    diff = "Insane",    req = 180 },
    { map = "Northern Lands",    diff = "Nightmare", req = 185 },
    { map = "Gilded Skies",      diff = "Insane",    req = 190, gs = true },
    { map = "Gilded Skies",      diff = "Nightmare", req = 195, gs = true },
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

-- 3. Kiểm tra trạng thái Lobby vs Trong Dungeon -----------------------
local function isInDungeon()
    if game.PlaceId ~= LOBBY_PLACE_ID then
        return true
    end
    return workspace:FindFirstChild("dungeon") ~= nil
end

-- 4. Áp dụng Boost Tầm Đánh Chuẩn (KHÔNG làm tăng khoảng cách đứng lùi)
-- Chỉ nhân tầm đánh/bán kính chiêu, giữ nguyên mobStandoff/bossStandoff để không bị đứng ngoài tầm ở map đầu!
local RANGE_KEYS = {
    "aoeRadius",
    "abilityRadius",
    "abilityRangeKnown",
    "aimReach",
    "attackRange",
    "castStartAt",
    "castProbe",
    "fieldReach",
}

local unboostedSnapshot = {}
local aoeKnownSnapshot  = {}

local function captureBaseAndBoost()
    for _, k in ipairs(RANGE_KEYS) do
        local v = CFG[k]
        if type(v) == "number" then
            -- Nếu CFG[k] vừa được nạp lại từ profile/config (khác với giá trị đã nhân trước đó), cập nhật lại gốc
            if not unboostedSnapshot[k] or math.abs(v - unboostedSnapshot[k] * CUSTOM.BOOST) > 0.01 then
                unboostedSnapshot[k] = v
            end
            CFG[k] = unboostedSnapshot[k] * CUSTOM.BOOST
        end
    end

    if type(CFG.aoeKnown) == "table" then
        for spell, entry in pairs(CFG.aoeKnown) do
            if type(entry) == "table" then
                aoeKnownSnapshot[spell] = aoeKnownSnapshot[spell] or {}
                for _, axis in ipairs({ "x", "z", "place" }) do
                    local val = entry[axis]
                    if type(val) == "number" then
                        local snap = aoeKnownSnapshot[spell][axis]
                        if not snap or math.abs(val - snap * CUSTOM.BOOST) > 0.01 then
                            aoeKnownSnapshot[spell][axis] = val
                        end
                        entry[axis] = aoeKnownSnapshot[spell][axis] * CUSTOM.BOOST
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

    -- Tăng thời gian chờ nhặt đồ của script gốc để không thoát sớm
    CFG.whLootWait = math.max(tonumber(CFG.whLootWait) or 3, CUSTOM.LOOT_WAIT_TIME)
    CFG.autoQueueReplayDelay = math.max(tonumber(CFG.autoQueueReplayDelay) or 2, CUSTOM.LOOT_WAIT_TIME)
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        for _, k in ipairs(RANGE_KEYS) do
            if context.PERSIST[i] == k then table.remove(context.PERSIST, i); break end
        end
    end
end

captureBaseAndBoost()

if type(context.applyClassProfile) == "function" then
    local orig = context.applyClassProfile
    context.applyClassProfile = function(...)
        table.clear(unboostedSnapshot)
        local ok = orig(...)
        if ok then captureBaseAndBoost() end
        return ok
    end
end

if type(context.loadConfig) == "function" then
    local orig = context.loadConfig
    context.loadConfig = function(...)
        table.clear(unboostedSnapshot)
        local ok = orig(...)
        if ok then captureBaseAndBoost() end
        return ok
    end
end

-- 5. Đọc Level thật (Vượt qua giả mạo "999" của Streamer Mode) --------
local realLevelCache = {}

local function parseCleanNumber(val)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        local cleaned = val:gsub(",", ""):match("%d+")
        return cleaned and tonumber(cleaned) or nil
    end
    return nil
end

local function getRealPlayerLevel(plr)
    if not plr then return nil end
    local fakeNum = tonumber(tostring(CFG.streamerLevelText or "999"):gsub(",", "")) or 999

    local ls = plr:FindFirstChild("leaderstats")
    local candidates = {
        ls and ls:FindFirstChild("Level"),
        ls and ls:FindFirstChild("level"),
        ls and ls:FindFirstChild("Lvl"),
        plr:FindFirstChild("level"),
        plr:FindFirstChild("Level"),
    }
    for _, obj in ipairs(candidates) do
        if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue")) then
            local n = parseCleanNumber(obj.Value)
            if n and n > 0 and n ~= fakeNum then
                realLevelCache[plr.UserId] = n
                return n
            end
        end
    end

    local char = plr.Character or workspace:FindFirstChild(plr.Name)
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local txt = desc.Text:gsub(",", "")
                local lvlMatch = txt:match("[Ll][Vv][Ll]?%.?%s*(%d+)") or txt:match("[Ll]evel:?%s*(%d+)")
                if lvlMatch then
                    local n = tonumber(lvlMatch)
                    if n and n > 0 and n ~= fakeNum then
                        realLevelCache[plr.UserId] = n
                        return n
                    end
                end
            end
        end
    end

    return realLevelCache[plr.UserId]
end

local function getLowestAccountLevel()
    local wasStreamerLvl = CFG.streamerLevel
    if wasStreamerLvl and not realLevelCache[LocalPlayer.UserId] then
        CFG.streamerLevel = false
    end

    local whitelist = {}
    local hasWhitelist = false
    if type(CUSTOM.WHITELIST_ACCS) == "table" and #CUSTOM.WHITELIST_ACCS > 0 then
        hasWhitelist = true
        for _, name in ipairs(CUSTOM.WHITELIST_ACCS) do
            whitelist[string.lower(name)] = true
        end
    end

    local minLvl = math.huge
    local minPlrName = LocalPlayer.Name

    if CUSTOM.ONLY_MY_ACCOUNT then
        local myLvl = getRealPlayerLevel(LocalPlayer)
        if myLvl and myLvl > 0 then minLvl = myLvl end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            local allow = true
            if hasWhitelist and plr ~= LocalPlayer and not whitelist[string.lower(plr.Name)] then
                allow = false
            end
            if allow then
                local lvl = getRealPlayerLevel(plr)
                if lvl and lvl > 0 and lvl < minLvl then
                    minLvl = lvl
                    minPlrName = plr.Name
                end
            end
        end
    end

    if wasStreamerLvl then CFG.streamerLevel = true end
    if minLvl == math.huge then minLvl = realLevelCache[LocalPlayer.UserId] or 1 end
    return minLvl, minPlrName
end

local function selectBestDungeonForLevel(lvl)
    local best = DUNGEON_TIERS[1]
    for _, tier in ipairs(DUNGEON_TIERS) do
        if not tier.gs or CUSTOM.ALLOW_GILDED_SKIES then
            if lvl >= tier.req then
                best = tier
            else
                break
            end
        end
    end
    return best.map, best.diff, best.req
end

-- 6. Quản lý Chống Replay Sớm (Đợi Boss chết + Nhặt Drop xong mới Replay)
local bossSeenInRun     = false
local bossKilledAt      = nil
local bossNameTracked   = nil
local currentMinLvl, currentMinOwner, currentMap, currentDiff, currentReq = 1, LocalPlayer.Name, CFG.autoQueueMap, CFG.autoQueueDifficulty, 1

local function checkBossAndDropState()
    if not isInDungeon() then
        bossSeenInRun   = false
        bossKilledAt    = nil
        bossNameTracked = nil
        return "LOBBY"
    end

    -- Quét trong context.RD.enemies và workspace.enemies xem Boss đã ra chưa và còn sống không
    local RD = context.RD
    local activeBossAlive = false

    if RD and type(RD.enemies) == "table" then
        for _, enemy in ipairs(RD.enemies) do
            if enemy.isBoss then
                bossSeenInRun = true
                bossNameTracked = enemy.name or (enemy.model and enemy.model.Name) or "Boss"
                if enemy.humanoid and enemy.humanoid.Health > 0 then
                    activeBossAlive = true
                end
            end
        end
    end

    -- Kiểm tra thêm trong folder enemies của workspace cho các map đầu
    local enemiesFolder = workspace:FindFirstChild("enemies") or (workspace:FindFirstChild("dungeon") and workspace.dungeon:FindFirstChild("enemies", true))
    if enemiesFolder then
        for _, child in ipairs(enemiesFolder:GetChildren()) do
            if child:IsA("Model") then
                local hum = child:FindFirstChildOfClass("Humanoid")
                local isBossModel = child:FindFirstChild("isBoss") ~= nil
                    or child:GetAttribute("isBoss") == true
                    or (hum and hum.MaxHealth > 2500 and #enemiesFolder:GetChildren() <= 3)
                if isBossModel then
                    bossSeenInRun = true
                    bossNameTracked = child.Name
                    if hum and hum.Health > 0 then
                        activeBossAlive = true
                    end
                end
            end
        end
    end

    -- Nếu context.RD.bossDown đã ghi nhận Boss bị hạ
    if RD and type(RD.bossDown) == "table" and next(RD.bossDown) ~= nil then
        bossSeenInRun = true
    end

    if bossSeenInRun and not activeBossAlive then
        if not bossKilledAt then
            bossKilledAt = os.clock()
            print(("[Boost][Boss] Đã tiêu diệt Boss (%s)! Đang chờ %.1fs để nhận Drop..."):format(tostring(bossNameTracked), CUSTOM.LOOT_WAIT_TIME))
        end
        local elapsed = os.clock() - bossKilledAt
        if elapsed >= CUSTOM.LOOT_WAIT_TIME then
            return "LOOT_DONE", elapsed
        else
            return "WAITING_DROP", CUSTOM.LOOT_WAIT_TIME - elapsed
        end
    end

    if bossSeenInRun and activeBossAlive then
        bossKilledAt = nil
        return "FIGHTING_BOSS"
    end

    return "CLEARING_MOBS"
end

local function updateQueueAndReplayLogic()
    local minLvl, ownerName = getLowestAccountLevel()
    local bestMap, bestDiff, reqLvl = selectBestDungeonForLevel(minLvl)
    currentMinLvl, currentMinOwner, currentMap, currentDiff, currentReq = minLvl, ownerName, bestMap, bestDiff, reqLvl

    if CUSTOM.AUTO_MAP_BY_MIN_LVL then
        CFG.autoQueueMap        = bestMap
        CFG.autoQueueDifficulty = bestDiff
        CFG.autoQueueMinLevel   = 0
        if CUSTOM.FORCE_HARDCORE ~= nil then CFG.autoQueueHardcore = CUSTOM.FORCE_HARDCORE end
        if CUSTOM.FORCE_PRIVATE  ~= nil then CFG.autoQueuePrivate  = CUSTOM.FORCE_PRIVATE  end
    end

    local runState, timerVal = checkBossAndDropState()

    if runState == "LOBBY" then
        -- Khi ở Lobby: Bật autoQueue để tạo phòng vào Dungeon
        CFG.autoQueue = true
        CFG.autoQueueReplay = false
    else
        -- Khi đang ở trong Dungeon:
        -- TẮT autoQueue của sảnh để tránh tự tạo phòng mới khi đang đánh!
        CFG.autoQueue = false

        if CUSTOM.ANTI_EARLY_REPLAY then
            if runState == "LOOT_DONE" then
                -- Boss đã chết & đã chờ đủ thời gian lấy Drop -> Cho phép Replay!
                CFG.autoQueueReplay = CUSTOM.USE_REPLAY_IN_DUNGEON
                CFG.autoQueueReplayDelay = 0.5
            else
                -- Chưa giết xong Boss hoặc đang chờ nhặt Drop -> KHÓA Replay!
                CFG.autoQueueReplay = false
            end
        end
    end

    return runState, timerVal
end

-- 7. Auto Re-Execute & Auto Re-Hop -----------------------------------
local function getQueueOnTeleport()
    return queue_on_teleport
        or (type(syn) == "table" and syn.queue_on_teleport)
        or (type(fluxus) == "table" and fluxus.queue_on_teleport)
        or (type(delta) == "table" and delta.queue_on_teleport)
        or (getgenv and (getgenv().queue_on_teleport or getgenv().queueonteleport))
end

local isTeleportQueued = false

local function registerAutoReExecute()
    if not CUSTOM.AUTO_REEXECUTE or isTeleportQueued then return false end
    local qFn = getQueueOnTeleport()
    if type(qFn) ~= "function" then return false end

    local payload
    if type(WRAPPER_URL) == "string" and #WRAPPER_URL > 10 then
        payload = ('repeat task.wait() until game:IsLoaded(); loadstring(game:HttpGet("%s"))()'):format(WRAPPER_URL)
    elseif type(isfile) == "function" and pcall(isfile, "boost_harvard_3.0.lua") and isfile("boost_harvard_3.0.lua") then
        payload = 'repeat task.wait() until game:IsLoaded(); loadstring(readfile("boost_harvard_3.0.lua"))()'
    else
        payload = ('repeat task.wait() until game:IsLoaded(); loadstring(game:HttpGet("%s"))()'):format(ORIGINAL_URL)
    end

    local ok = pcall(qFn, payload)
    if ok then isTeleportQueued = true end
    return ok
end

registerAutoReExecute()

LocalPlayer.OnTeleport:Connect(function()
    saveHubConfig()
    if CUSTOM.AUTO_REEXECUTE and not isTeleportQueued then
        registerAutoReExecute()
    end
end)

local function triggerRehop(reason)
    if not CUSTOM.AUTO_REHOP then return end
    warn("[Boost][AutoRehop] Đang Re-hop về Lobby. Lý do: " .. tostring(reason))
    saveHubConfig()
    registerAutoReExecute()
    task.spawn(function()
        while true do
            pcall(function()
                TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
            end)
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
                    triggerRehop("Mất kết nối / Kick (ErrorPrompt)")
                end
            end)
        end
    end)
end)

TeleportService.TeleportInitFailed:Connect(function(_, res, msg)
    if CUSTOM.AUTO_REHOP then
        warn("[Boost] Teleport lỗi (" .. tostring(res) .. "): " .. tostring(msg))
        task.wait(3)
        triggerRehop("TeleportInitFailed")
    end
end)

-- 8. Kiểm tra mục tiêu trong tầm đánh (Landing Detection) -------------
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

-- 9. Giao diện Mini-Hub Mở Rộng ---------------------------------------
local guiParent = (type(gethui) == "function" and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    local old = guiParent:FindFirstChild("HLBoostMiniHub")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HLBoostMiniHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 280, 0, 310)
mainFrame.Position = UDim2.new(0, 18, 0.5, -155)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 16, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(190, 35, 45)
stroke.Thickness = 1.5

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 18, 22)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Harvard v3.0 — Fix Boss Drop & AutoMap"
titleLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 26, 0, 22)
minBtn.Position = UDim2.new(1, -30, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 30)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 12
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -16, 1, -38)
contentFrame.Position = UDim2.new(0, 8, 0, 34)
contentFrame.BackgroundTransparency = 1

local infoLabel = Instance.new("TextLabel", contentFrame)
infoLabel.Size = UDim2.new(1, 0, 0, 48)
infoLabel.Position = UDim2.new(0, 0, 0, 0)
infoLabel.BackgroundColor3 = Color3.fromRGB(30, 24, 28)
infoLabel.TextColor3 = Color3.fromRGB(120, 240, 160)
infoLabel.Font = Enum.Font.GothamSemibold
infoLabel.TextSize = 11
infoLabel.TextWrapped = true
infoLabel.Text = "Đang kiểm tra trạng thái..."
Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 6)

local function createToggle(yOffset, text, key, onToggle)
    local btn = Instance.new("TextButton", contentFrame)
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.Position = UDim2.new(0, 0, 0, yOffset)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function refresh()
        local state = CUSTOM[key]
        btn.Text = ("%s: %s"):format(text, state and "BẬT (ON)" or "TẮT (OFF)")
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 110, 65) or Color3.fromRGB(45, 35, 40)
        btn.TextColor3 = state and Color3.fromRGB(235, 255, 240) or Color3.fromRGB(190, 175, 180)
    end

    btn.MouseButton1Click:Connect(function()
        CUSTOM[key] = not CUSTOM[key]
        refresh()
        saveHubConfig()
        if onToggle then onToggle(CUSTOM[key]) end
    end)

    refresh()
    return refresh
end

createToggle(54,  "Chống Replay sớm (Đợi Boss + Drop)", "ANTI_EARLY_REPLAY")
createToggle(86,  "Tự chọn Map theo Min Lvl", "AUTO_MAP_BY_MIN_LVL")
createToggle(118, "Chế độ quét (Bật = Chỉ mình / Tắt = Cả sảnh)", "ONLY_MY_ACCOUNT")
createToggle(150, "Auto Re-Execute (Qua màn)", "AUTO_REEXECUTE", function(v)
    if v then registerAutoReExecute() end
end)
createToggle(182, "Auto Re-Hop (Chống kẹt/Disconnect)", "AUTO_REHOP")
createToggle(214, "Chặn đánh ngoài tầm (Detect Gate)", "DETECT_ONLY")

local rehopNowBtn = Instance.new("TextButton", contentFrame)
rehopNowBtn.Size = UDim2.new(1, 0, 0, 24)
rehopNowBtn.Position = UDim2.new(0, 0, 0, 246)
rehopNowBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 50)
rehopNowBtn.TextColor3 = Color3.fromRGB(255, 240, 240)
rehopNowBtn.Font = Enum.Font.GothamBold
rehopNowBtn.TextSize = 11
rehopNowBtn.Text = "Re-Hop Về Sảnh Ngay Lập Tức"
Instance.new("UICorner", rehopNowBtn).CornerRadius = UDim.new(0, 6)
rehopNowBtn.MouseButton1Click:Connect(function()
    CUSTOM.AUTO_REHOP = true
    triggerRehop("Người dùng bấm Re-Hop thủ công trên Hub")
end)

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    contentFrame.Visible = not minimized
    mainFrame.Size = minimized and UDim2.new(0, 280, 0, 30) or UDim2.new(0, 280, 0, 310)
    minBtn.Text = minimized and "+" or "—"
end)

-- 10. Vòng lặp kiểm soát trạng thái & HUD -----------------------------
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
    local lobbyStart = os.clock()
    while not RT.destroyed do
        local runState, timerVal = updateQueueAndReplayLogic()
        local stateStr = runState
        if runState == "WAITING_DROP" then
            stateStr = ("Chờ lấy Drop (%.1fs)..."):format(timerVal or 0)
        elseif runState == "CLEARING_MOBS" then
            stateStr = "Đang dọn quái (Khóa Replay)"
        elseif runState == "FIGHTING_BOSS" then
            stateStr = "Đang đánh Boss (Khóa Replay)"
        elseif runState == "LOOT_DONE" then
            stateStr = "Đã lấy Drop -> Cho phép Replay!"
        elseif runState == "LOBBY" then
            stateStr = "Đang ở Sảnh -> Tự tìm trận"
        end

        infoLabel.Text = ("Min Lvl: %d (%s)\nMap: %s [%s - Req %d]\nTrạng thái: %s"):format(
            currentMinLvl,
            tostring(currentMinOwner):sub(1, 12),
            tostring(CFG.autoQueueMap),
            tostring(CFG.autoQueueDifficulty),
            currentReq,
            stateStr
        )

        if runState == "LOBBY" and CUSTOM.AUTO_REHOP and CUSTOM.LOBBY_STUCK_TIMEOUT then
            if os.clock() - lobbyStart > CUSTOM.LOBBY_STUCK_TIMEOUT then
                triggerRehop("Kẹt ở Lobby quá " .. tostring(CUSTOM.LOBBY_STUCK_TIMEOUT) .. "s")
                break
            end
        else
            lobbyStart = os.clock()
        end

        task.wait(0.5)
    end
end)

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

print("[Boost] Đã tải bản Fix Boss Drop & AutoMap thành công!")
