-- =====================================================================
-- Harvard Labs v3.0 — DQ Reborn Edition (Integrated Hub + AutoSkill + AutoMap)
-- =====================================================================

local WRAPPER_SOURCE = [=====[
local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST                 = 1.5,   -- Hệ số nhân tầm đánh / bán kính kỹ năng
    DETECT_ONLY           = false, -- Để false để không chặn chiêu Q/E ở các map đầu
    DETECT_HOLD           = 0.35,  -- Thời gian giữ trạng thái đánh sau khi quái lệch tầm
    CACHE_HZ              = 15,    -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD              = true,  -- Hiển thị vòng tròn tầm đánh dưới chân

    -- 1. Auto Skill cho Dungeon Quest Reborn
    UNLOCK_ALL_SKILLS     = true,  -- Bỏ qua điều kiện đòi Buff Inner Focus/Rage của script gốc
    AUTO_SKILL_ASSIST     = true,  -- Tự động kích hoạt Q / E & Vũ khí khi có quái trong tầm

    -- 2. Chống Replay sớm & Bảo vệ Drop Boss
    ANTI_EARLY_REPLAY     = true,  -- Khóa Replay khi Boss chưa chết & chưa nhận xong Drop
    LOOT_WAIT_TIME        = 6,     -- Số giây chờ nhận Drop sau khi Boss chết

    -- 3. Tự chọn Map theo Level thấp nhất
    AUTO_MAP_BY_MIN_LVL   = true,  -- Tự động chọn Map + Độ khó theo acc có Level thấp nhất
    ONLY_MY_ACCOUNT       = false, -- true = chỉ tính Level acc này; false = tính acc thấp nhất trong sảnh
    WHITELIST_ACCS        = {},    -- VD: {"AccChinh", "AccPhu1"} (Để trống {} sẽ quét toàn bộ người trong sảnh)
    ALLOW_GILDED_SKIES    = true,  -- Cho phép lên Gilded Skies ở Lv.190+
    FORCE_HARDCORE        = false,
    FORCE_PRIVATE         = true,

    -- 4. Auto Re-Execute & Auto Re-Hop (Chuẩn PlaceId của DQ Reborn)
    AUTO_REEXECUTE        = true,
    AUTO_REHOP            = true,
    LOBBY_STUCK_TIMEOUT   = 90,
    REBORN_LOBBY_ID       = nil,   -- Tự động lưu PlaceId Sảnh của Dungeon Quest Reborn
}
-- =====================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TeleportService     = game:GetService("TeleportService")
local AssetService        = game:GetService("AssetService")
local HttpService         = game:GetService("HttpService")
local CoreGui             = game:GetService("CoreGui")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

local HUB_CFG_FILE  = "HarvardLabs/reborn_hub_config.json"
local AUTOEXEC_PATH = "HarvardLabs/autoexec_boost_wrapper.lua"

-- Nạp cấu hình đã lưu
if type(isfile) == "function" and type(readfile) == "function" then
    local ok, exists = pcall(isfile, HUB_CFG_FILE)
    if ok and exists then
        local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(HUB_CFG_FILE)) end)
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                if CUSTOM[k] ~= nil or k == "REBORN_LOBBY_ID" then CUSTOM[k] = v end
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
                UNLOCK_ALL_SKILLS   = CUSTOM.UNLOCK_ALL_SKILLS,
                AUTO_SKILL_ASSIST   = CUSTOM.AUTO_SKILL_ASSIST,
                ANTI_EARLY_REPLAY   = CUSTOM.ANTI_EARLY_REPLAY,
                LOOT_WAIT_TIME      = CUSTOM.LOOT_WAIT_TIME,
                AUTO_MAP_BY_MIN_LVL = CUSTOM.AUTO_MAP_BY_MIN_LVL,
                ONLY_MY_ACCOUNT     = CUSTOM.ONLY_MY_ACCOUNT,
                ALLOW_GILDED_SKIES  = CUSTOM.ALLOW_GILDED_SKIES,
                AUTO_REEXECUTE      = CUSTOM.AUTO_REEXECUTE,
                AUTO_REHOP          = CUSTOM.AUTO_REHOP,
                REBORN_LOBBY_ID     = CUSTOM.REBORN_LOBBY_ID,
            }))
        end)
    end
end

-- =====================================================================
-- 1. TỰ ĐỘNG XÁC ĐỊNH PLACE ID SẢNH CỦA DUNGEON QUEST REBORN
-- =====================================================================
local function isInDungeon()
    if workspace:FindFirstChild("dungeon") ~= nil then return true end
    if workspace:FindFirstChild("Lobby") ~= nil then return false end
    if CUSTOM.REBORN_LOBBY_ID and game.PlaceId == CUSTOM.REBORN_LOBBY_ID then return false end
    return workspace:FindFirstChild("enemies") ~= nil
end

local function resolveRebornLobbyPlaceId()
    -- Nếu đang đứng ở Sảnh, lưu ngay PlaceId hiện tại làm Sảnh chuẩn của DQ Reborn
    if not isInDungeon() then
        if CUSTOM.REBORN_LOBBY_ID ~= game.PlaceId then
            CUSTOM.REBORN_LOBBY_ID = game.PlaceId
            saveHubConfig()
        end
        return CUSTOM.REBORN_LOBBY_ID
    end

    -- Nếu đã lưu từ trước (và không phải ID 2414851778 của DQ cũ)
    if type(CUSTOM.REBORN_LOBBY_ID) == "number" and CUSTOM.REBORN_LOBBY_ID > 0 and CUSTOM.REBORN_LOBBY_ID ~= 2414851778 then
        return CUSTOM.REBORN_LOBBY_ID
    end

    -- Tự động dò PlaceId gốc (Lobby) của Universe Dungeon Quest Reborn thông qua AssetService
    local ok, pages = pcall(function() return AssetService:GetGamePlacesAsync() end)
    if ok and pages then
        local okPage, list = pcall(function() return pages:GetCurrentPage() end)
        if okPage and type(list) == "table" then
            local fallbackId = nil
            for _, placeInfo in ipairs(list) do
                local pName = string.lower(tostring(placeInfo.Name or ""))
                local pId   = tonumber(placeInfo.PlaceId)
                if pId and pId ~= 2414851778 then
                    if not fallbackId then fallbackId = pId end
                    if pName:find("lobby") or pName:find("reborn") or pName:find("dungeon quest") or pId ~= game.PlaceId then
                        CUSTOM.REBORN_LOBBY_ID = pId
                        saveHubConfig()
                        return pId
                    end
                end
            end
            if fallbackId then
                CUSTOM.REBORN_LOBBY_ID = fallbackId
                saveHubConfig()
                return fallbackId
            end
        end
    end

    return game.PlaceId
end

task.spawn(resolveRebornLobbyPlaceId)

-- =====================================================================
-- 2. ĐỌC LEVEL THẬT TRƯỚC KHI HARVARD LABS GHI ĐÈ "999"
-- =====================================================================
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

getgenv().HL_RealLevels = getgenv().HL_RealLevels or {}
local realLevelCache = getgenv().HL_RealLevels

local function parseLevelValue(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then
        local clean = v:gsub(",", ""):match("(%d+)")
        return clean and tonumber(clean) or nil
    end
    return nil
end

local function readPlayerLevelRaw(plr)
    if not plr then return nil end
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local lvlObj = ls:FindFirstChild("Level") or ls:FindFirstChild("level") or ls:FindFirstChild("Lvl")
        if lvlObj then
            local n = parseLevelValue(lvlObj.Value)
            if n and n > 0 and n ~= 999 then
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
                local m = txt:match("[Ll][Vv][Ll]?%.?%s*(%d+)") or txt:match("[Ll]evel:?%s*(%d+)") or txt:match("^(%d+)$")
                if m then
                    local n = tonumber(m)
                    if n and n > 0 and n ~= 999 and n < 500 then
                        realLevelCache[plr.UserId] = n
                        return n
                    end
                end
            end
        end
    end
    return realLevelCache[plr.UserId]
end

for _, plr in ipairs(Players:GetPlayers()) do
    readPlayerLevelRaw(plr)
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
    local minOwner = LocalPlayer.Name

    if CUSTOM.ONLY_MY_ACCOUNT then
        local l = readPlayerLevelRaw(LocalPlayer)
        if l and l > 0 then minLvl = l end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            local allow = true
            if hasWhitelist and plr ~= LocalPlayer and not whitelist[string.lower(plr.Name)] then
                allow = false
            end
            if allow then
                local l = readPlayerLevelRaw(plr)
                if l and l > 0 and l < minLvl then
                    minLvl = l
                    minOwner = plr.Name
                end
            end
        end
    end

    if minLvl == math.huge then
        minLvl = realLevelCache[LocalPlayer.UserId] or 1
    end
    return minLvl, minOwner
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

-- =====================================================================
-- 3. TẢI VÀ KHỞI CHẠY HARVARD LABS GỐC
-- =====================================================================
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

-- =====================================================================
-- 4. KHÔI PHỤC PROFILE CHUẨN & MỞ KHÓA AUTO SKILL CHO DQ REBORN
-- =====================================================================
if type(context.autoClass) == "function" then pcall(context.autoClass, true) end
if type(context.applyClassProfile) == "function" then
    pcall(context.applyClassProfile, CFG.classProfile or "mage", true)
end

local KEYS = {
    "aoeRadius",
    "abilityRadius", "abilityRangeKnown",
    "aimReach", "attackRange",
    "castStartAt", "castProbe", "rangeMargin",
    "fieldReach", "fanRadius",
}

local baseValues = {}
for _, k in ipairs(KEYS) do
    if type(CFG[k]) == "number" then baseValues[k] = CFG[k] end
end
local baseAoeKnown = {}
if type(CFG.aoeKnown) == "table" then
    for spell, entry in pairs(CFG.aoeKnown) do
        if type(entry) == "table" then
            baseAoeKnown[spell] = { x = entry.x, z = entry.z, place = entry.place }
        end
    end
end

local function applySkillAndBoostSettings()
    CFG.streamerLevel = false
    CFG.aoeDistance   = 0
    CFG.autoQ         = true
    CFG.autoE         = true
    CFG.autoAttack    = true
    RT.farmEnabled    = true

    if CUSTOM.UNLOCK_ALL_SKILLS then
        CFG.mobAttackNeedsBuff   = false
        CFG.attackNeedsBuffUp    = false
        CFG.buffHolderCheck      = false
        CFG.buffSpeedCheck       = false
        CFG.attackOnlyWithSpeed  = false
        CFG.firstCastWholeStrict = false
        CFG.groupFirstWhole      = false
        CFG.firstHitWhole        = false
        CFG.fireOnFullCover      = false
        CFG.strikeWaitReady      = false
        CFG.groupArriveReady     = false
    end

    for _, k in ipairs(KEYS) do
        if type(baseValues[k]) == "number" then
            CFG[k] = baseValues[k] * CUSTOM.BOOST
        end
    end
    if type(CFG.aoeKnown) == "table" then
        for spell, entry in pairs(CFG.aoeKnown) do
            local b = baseAoeKnown[spell]
            if type(entry) == "table" and b then
                if type(b.x) == "number" then entry.x = b.x * CUSTOM.BOOST end
                if type(b.z) == "number" then entry.z = b.z * CUSTOM.BOOST end
                if type(b.place) == "number" then entry.place = b.place * CUSTOM.BOOST end
            end
        end
    end
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        local k = context.PERSIST[i]
        if k == "aoeDistance" or k == "streamerLevel" or k == "autoQueueMap" or k == "autoQueueDifficulty" or k == "autoQueueReplay" then
            table.remove(context.PERSIST, i)
        else
            for _, rk in ipairs(KEYS) do
                if k == rk then table.remove(context.PERSIST, i); break end
            end
        end
    end
end

applySkillAndBoostSettings()

if type(context.applyClassProfile) == "function" then
    local orig = context.applyClassProfile
    context.applyClassProfile = function(...)
        local ok = orig(...)
        if ok then
            for _, k in ipairs(KEYS) do
                if type(CFG[k]) == "number" then baseValues[k] = CFG[k] end
            end
            applySkillAndBoostSettings()
        end
        return ok
    end
end
if type(context.loadConfig) == "function" then
    local orig = context.loadConfig
    context.loadConfig = function(...)
        local ok = orig(...)
        if ok then applySkillAndBoostSettings() end
        return ok
    end
end

-- =====================================================================
-- 5. QUÉT QUÁI MỌI MAP & TRỢ LỰC TUNG CHIÊU Q/E TRONG DQ REBORN
-- =====================================================================
local cacheAt, cacheOK, cacheTgt = 0, false, nil
local lastHitAt, lastTgt = 0, nil

local function detectionRange()
    local reach = (context.fireReach and context.fireReach()) or 50
    local rad = 0
    if context.aoeLanding then
        local ok, _, r = pcall(context.aoeLanding)
        if ok and type(r) == "number" then rad = r end
    end
    return math.max(reach + rad, 55)
end

local function findNearestLivingEnemy()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, nil end
    local pos = hrp.Position
    local maxR = detectionRange()
    local maxRSq = maxR * maxR

    local best, bestD = nil, math.huge
    local RD = context.RD

    -- 1) Kiểm tra trong context.RD.enemies của Harvard Labs
    if RD and type(RD.enemies) == "table" then
        for _, enemy in ipairs(RD.enemies) do
            if enemy.root and enemy.root.Parent
                and enemy.humanoid and enemy.humanoid.Health > 0
                and enemy.x and enemy.z then
                local d = (enemy.x - pos.X)^2 + (enemy.z - pos.Z)^2
                if d < bestD and d <= maxRSq then
                    best, bestD = enemy, d
                end
            end
        end
    end

    -- 2) Quét dự phòng trực tiếp trong workspace.enemies và workspace.dungeon cho các map đầu của DQ Reborn
    if not best then
        local containers = {
            workspace:FindFirstChild("enemies"),
            workspace:FindFirstChild("dungeon"),
        }
        for _, folder in ipairs(containers) do
            if folder then
                for _, desc in ipairs(folder:GetDescendants()) do
                    if desc:IsA("Humanoid") and desc.Health > 0 then
                        local model = desc.Parent
                        if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
                            local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                            if r then
                                local d = (r.Position.X - pos.X)^2 + (r.Position.Z - pos.Z)^2
                                if d < bestD and d <= maxRSq then
                                    best, bestD = { root = r, humanoid = desc, x = r.Position.X, z = r.Position.Z, model = model }, d
                                end
                            end
                        end
                    end
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
    local ok, t = findNearestLivingEnemy()
    if ok then lastHitAt, lastTgt = now, t
    elseif now - lastHitAt < CUSTOM.DETECT_HOLD then ok, t = true, lastTgt end
    cacheOK, cacheTgt = ok, t
    return ok, t
end

local function gate(fn)
    if type(fn) ~= "function" then return fn end
    return function(slot, ...)
        if CUSTOM.UNLOCK_ALL_SKILLS and not CUSTOM.DETECT_ONLY then
            return true
        end
        if not fn(slot, ...) then return false end
        if not CUSTOM.DETECT_ONLY then return true end
        if context.isBuffSlot and context.isBuffSlot(slot) then return true end
        return (detection())
    end
end
if type(context.gsSlotReady) == "function" then context.gsSlotReady = gate(context.gsSlotReady) end
if type(context.slotReady) == "function" then context.slotReady = gate(context.slotReady) end

-- Luồng kích hoạt Q / E & Tool trực tiếp cho Dungeon Quest Reborn
task.spawn(function()
    while not RT.destroyed do
        task.wait(0.22)
        if CUSTOM.AUTO_SKILL_ASSIST and RT.farmEnabled and isInDungeon() then
            local hasTarget, tgt = detection()
            if hasTarget and tgt then
                local now = os.clock()
                -- Bấm Q & E nếu script gốc chưa kích hoạt
                if CFG.autoQ and (now - (tonumber(RT.lastQ) or 0) > 0.7) then
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                    end)
                end
                if CFG.autoE and (now - (tonumber(RT.lastE) or 0) > 0.7) then
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end)
                end
                -- Kích hoạt Remote hoặc Event nằm trong các Ability Tool trong Backpack / Character (nếu DQ Reborn dùng Tool Event)
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        for _, child in ipairs(char:GetChildren()) do
                            if child:IsA("Tool") then
                                child:Activate()
                            end
                        end
                    end
                end)
            end
        end
    end
end)

-- =====================================================================
-- 6. KIỂM SOÁT BOSS DROP & AUTO MAP THEO MIN LEVEL
-- =====================================================================
local bossSpawnedInRun = false
local bossDeadAt       = nil
local bossTrackedName  = nil
local currentMinLvl, currentMinOwner = getLowestAccountLevel()
local currentMap, currentDiff, currentReq = selectBestDungeonForLevel(currentMinLvl)
local currentRunState  = "LOBBY"
local currentDropTimer = 0

local function evaluateDungeonBossState()
    if not isInDungeon() then
        bossSpawnedInRun = false
        bossDeadAt       = nil
        bossTrackedName  = nil
        return "LOBBY", 0
    end

    local dungeonFolder = workspace:FindFirstChild("dungeon")
    local bossRoom = dungeonFolder and (dungeonFolder:FindFirstChild("bossRoom") or dungeonFolder:FindFirstChild("BossRoom"))
    local RD = context.RD
    local bossAlive = false

    if RD and type(RD.enemies) == "table" then
        for _, e in ipairs(RD.enemies) do
            if e.isBoss then
                bossSpawnedInRun = true
                bossTrackedName = e.name or (e.model and e.model.Name) or "Boss"
                if e.humanoid and e.humanoid.Health > 0 then
                    bossAlive = true
                end
            end
        end
    end

    if RD and type(RD.bossDown) == "table" and next(RD.bossDown) ~= nil then
        bossSpawnedInRun = true
    end

    local containers = {
        workspace:FindFirstChild("enemies"),
        dungeonFolder and dungeonFolder:FindFirstChild("enemies", true),
        bossRoom,
    }
    for _, folder in ipairs(containers) do
        if folder then
            for _, m in ipairs(folder:GetDescendants()) do
                if m:IsA("Model") then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hum and not Players:GetPlayerFromCharacter(m) then
                        local isBoss = m:FindFirstChild("isBoss") ~= nil or m:GetAttribute("isBoss") == true or folder == bossRoom
                        if not isBoss and bossRoom and hrp then
                            local brPos = bossRoom:GetPivot().Position
                            if (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(brPos.X, 0, brPos.Z)).Magnitude < 140 then
                                isBoss = true
                            end
                        end
                        if isBoss then
                            bossSpawnedInRun = true
                            bossTrackedName = m.Name
                            if hum.Health > 0 then
                                bossAlive = true
                            end
                        end
                    end
                end
            end
        end
    end

    if bossSpawnedInRun and not bossAlive then
        if not bossDeadAt then
            bossDeadAt = os.clock()
        end
        local elapsed = os.clock() - bossDeadAt
        if elapsed >= CUSTOM.LOOT_WAIT_TIME then
            return "LOOT_DONE", elapsed
        else
            return "WAITING_DROP", CUSTOM.LOOT_WAIT_TIME - elapsed
        end
    end

    if bossSpawnedInRun and bossAlive then
        bossDeadAt = nil
        return "FIGHTING_BOSS", 0
    end

    return "CLEARING_MOBS", 0
end

local hbConn
hbConn = RunService.Heartbeat:Connect(function()
    if RT.destroyed then
        if hbConn then hbConn:Disconnect() end
        return
    end

    CFG.streamerLevel = false
    if CUSTOM.AUTO_MAP_BY_MIN_LVL then
        CFG.autoQueueMap        = currentMap
        CFG.autoQueueDifficulty = currentDiff
        CFG.autoQueueMinLevel   = 0
        CFG.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
        CFG.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
        CFG.autoStartDungeon    = true
    end

    if currentRunState == "LOBBY" then
        CFG.autoQueue       = true
        CFG.autoQueueReplay = false
    else
        CFG.autoQueue = false
        if CUSTOM.ANTI_EARLY_REPLAY then
            if currentRunState == "LOOT_DONE" then
                CFG.autoQueueReplay      = true
                CFG.autoQueueReplayDelay = 0.5
            else
                CFG.autoQueueReplay      = false
                CFG.autoQueueReplayDelay = 9999
            end
        end
    end
end)

-- =====================================================================
-- 7. AUTO RE-EXECUTE & RE-HOP CHUẨN DUNGEON QUEST REBORN
-- =====================================================================
local function registerAutoReExecute()
    if not CUSTOM.AUTO_REEXECUTE then return false end
    local qFn = queue_on_teleport
        or (type(syn) == "table" and syn.queue_on_teleport)
        or (type(fluxus) == "table" and fluxus.queue_on_teleport)
        or (type(delta) == "table" and delta.queue_on_teleport)
        or (getgenv and (getgenv().queue_on_teleport or getgenv().queueonteleport))

    if type(qFn) ~= "function" then return false end
    if getgenv().HL_TeleportQueued then return true end

    local loaderCode
    if type(isfile) == "function" and pcall(isfile, AUTOEXEC_PATH) and isfile(AUTOEXEC_PATH) then
        loaderCode = ('repeat task.wait() until game:IsLoaded(); loadstring(readfile(%q))()'):format(AUTOEXEC_PATH)
    elseif type(getgenv().HL_FullWrapperFileContent) == "string" then
        loaderCode = getgenv().HL_FullWrapperFileContent
    end

    if loaderCode and pcall(qFn, loaderCode) then
        getgenv().HL_TeleportQueued = true
        return true
    end
    return false
end

registerAutoReExecute()

LocalPlayer.OnTeleport:Connect(function()
    saveHubConfig()
    registerAutoReExecute()
end)

local function triggerRehop(reason)
    if not CUSTOM.AUTO_REHOP then return end
    local targetLobbyId = resolveRebornLobbyPlaceId()
    warn(("[Boost][DQ Reborn Re-Hop] Đang chuyển tới Sảnh DQ Reborn (PlaceId: %s) | Lý do: %s"):format(tostring(targetLobbyId), tostring(reason)))
    saveHubConfig()
    registerAutoReExecute()

    task.spawn(function()
        -- Thử gọi Remote về sảnh của game trước nếu đang ở trong Dungeon
        if isInDungeon() then
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("remotes")
                local leaveRem = remotes and (remotes:FindFirstChild("leaveDungeon") or remotes:FindFirstChild("returnToLobby"))
                if leaveRem and leaveRem:IsA("RemoteEvent") then
                    leaveRem:FireServer()
                end
            end)
        end
        while true do
            pcall(function()
                TeleportService:Teleport(targetLobbyId, LocalPlayer)
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
                    triggerRehop("Mất kết nối (ErrorPrompt)")
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

-- =====================================================================
-- 8. TÍCH HỢP TRỰC TIẾP VÀO HUB CÓ SẴN CỦA HARVARD LABS (RIGHTSHIFT)
-- =====================================================================
local function findHarvardHubMainFrame()
    -- 1) Kiểm tra trong bảng context.UI của Harvard Labs
    if type(context.UI) == "table" then
        for _, v in pairs(context.UI) do
            if typeof(v) == "Instance" then
                if v:IsA("Frame") and v.AbsoluteSize.X > 280 and v.AbsoluteSize.Y > 200 then
                    return v
                elseif v:IsA("ScreenGui") then
                    for _, child in ipairs(v:GetChildren()) do
                        if child:IsA("Frame") and child.AbsoluteSize.X > 280 and child.AbsoluteSize.Y > 200 then
                            return child
                        end
                    end
                end
            end
        end
    end

    -- 2) Quét trong gethui(), CoreGui và PlayerGui tìm ScreenGui có tiêu đề "Harvard" hoặc "v3.0"
    local roots = {}
    if type(gethui) == "function" then pcall(function() roots[#roots + 1] = gethui() end) end
    roots[#roots + 1] = CoreGui
    roots[#roots + 1] = LocalPlayer:FindFirstChild("PlayerGui")

    for _, root in ipairs(roots) do
        if root then
            for _, gui in ipairs(root:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name ~= "HLBoostIntegrated" then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local t = string.lower(desc.Text or "")
                            if t:find("harvard") or t:find("v3.0") or t:find("c84b") then
                                -- Tìm Frame gốc lớn nhất chứa TextLabel này
                                local topFrame = desc:FindFirstAncestorWhichIsA("Frame")
                                while topFrame and topFrame.Parent and topFrame.Parent:IsA("Frame") do
                                    topFrame = topFrame.Parent
                                end
                                if topFrame then return topFrame end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local harvardWindow = nil
for _ = 1, 30 do
    harvardWindow = findHarvardHubMainFrame()
    if harvardWindow then break end
    task.wait(0.1)
end

-- Dọn bản cũ nếu có
if harvardWindow then
    local old = harvardWindow:FindFirstChild("HLRebornIntegratedPanel")
    if old then old:Destroy() end
end

local guiParent = (type(gethui) == "function" and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    local old = guiParent:FindFirstChild("HLBoostMiniHub")
    if old then old:Destroy() end
    local old2 = guiParent:FindFirstChild("HLBoostIntegrated")
    if old2 then old2:Destroy() end
end)

-- Nếu tìm thấy cửa sổ chính của Harvard Labs -> Gắn trực tiếp làm nhánh mở rộng liền khối bên cạnh Hub gốc!
-- Khi bấm RightShift đóng/mở hoặc kéo cửa sổ Harvard Labs, nhánh này tự động đi theo 100%!
local panelParent
if harvardWindow then
    panelParent = harvardWindow
else
    local fallbackGui = Instance.new("ScreenGui")
    fallbackGui.Name = "HLBoostIntegrated"
    fallbackGui.ResetOnSpawn = false
    fallbackGui.Parent = guiParent
    panelParent = fallbackGui
end

local extFrame = Instance.new("Frame")
extFrame.Name = "HLRebornIntegratedPanel"
if harvardWindow then
    -- Gắn liền sát cạnh phải của cửa sổ Harvard Labs
    extFrame.Size = UDim2.new(0, 260, 1, 0)
    extFrame.Position = UDim2.new(1, 6, 0, 0)
else
    extFrame.Size = UDim2.new(0, 260, 0, 310)
    extFrame.Position = UDim2.new(0, 18, 0.5, -155)
    extFrame.Active = true
end
extFrame.BackgroundColor3 = Color3.fromRGB(18, 12, 14)
extFrame.BorderSizePixel = 0
extFrame.Parent = panelParent
Instance.new("UICorner", extFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", extFrame)
stroke.Color = Color3.fromRGB(185, 30, 40)
stroke.Thickness = 1.5

local header = Instance.new("Frame", extFrame)
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(35, 14, 18)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local headerTitle = Instance.new("TextLabel", header)
headerTitle.Size = UDim2.new(1, -16, 1, 0)
headerTitle.Position = UDim2.new(0, 10, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "DQ Reborn — Mở Rộng (Gắn liền Hub)"
headerTitle.TextColor3 = Color3.fromRGB(255, 225, 225)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 11
headerTitle.TextXAlignment = Enum.TextXAlignment.Left

local body = Instance.new("ScrollingFrame", extFrame)
body.Size = UDim2.new(1, -14, 1, -36)
body.Position = UDim2.new(0, 7, 0, 32)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.CanvasSize = UDim2.new(0, 0, 0, 290)

local infoBox = Instance.new("TextLabel", body)
infoBox.Size = UDim2.new(1, 0, 0, 54)
infoBox.Position = UDim2.new(0, 0, 0, 0)
infoBox.BackgroundColor3 = Color3.fromRGB(28, 18, 22)
infoBox.TextColor3 = Color3.fromRGB(125, 245, 165)
infoBox.Font = Enum.Font.GothamSemibold
infoBox.TextSize = 11
infoBox.TextWrapped = true
infoBox.Text = "Đang đồng bộ DQ Reborn..."
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 6)

local function addHubToggle(yPos, label, key, callback)
    local btn = Instance.new("TextButton", body)
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function syncVisual()
        local on = CUSTOM[key]
        btn.Text = ("%s: %s"):format(label, on and "BẬT" or "TẮT")
        btn.BackgroundColor3 = on and Color3.fromRGB(145, 28, 38) or Color3.fromRGB(38, 26, 30)
        btn.TextColor3 = on and Color3.fromRGB(255, 245, 245) or Color3.fromRGB(175, 160, 165)
    end

    btn.MouseButton1Click:Connect(function()
        CUSTOM[key] = not CUSTOM[key]
        syncVisual()
        saveHubConfig()
        applySkillAndBoostSettings()
        if callback then callback(CUSTOM[key]) end
    end)

    syncVisual()
end

addHubToggle(60,  "Auto Skill Q/E (DQ Reborn)", "AUTO_SKILL_ASSIST")
addHubToggle(92,  "Chống Replay Sớm (Đợi Drop Boss)", "ANTI_EARLY_REPLAY")
addHubToggle(124, "Tự Chọn Map Theo Min Lvl", "AUTO_MAP_BY_MIN_LVL")
addHubToggle(156, "Quét Level (Bật = Chỉ mình / Tắt = Sảnh)", "ONLY_MY_ACCOUNT")
addHubToggle(188, "Auto Re-Execute Khi Qua Màn", "AUTO_REEXECUTE", function(v)
    if v then registerAutoReExecute() end
end)
addHubToggle(220, "Auto Re-Hop (Chuẩn DQ Reborn)", "AUTO_REHOP")

local rehopBtn = Instance.new("TextButton", body)
rehopBtn.Size = UDim2.new(1, 0, 0, 26)
rehopBtn.Position = UDim2.new(0, 0, 0, 254)
rehopBtn.BackgroundColor3 = Color3.fromRGB(95, 22, 30)
rehopBtn.TextColor3 = Color3.fromRGB(255, 235, 235)
rehopBtn.Font = Enum.Font.GothamBold
rehopBtn.TextSize = 11
rehopBtn.Text = "Re-Hop Sảnh DQ Reborn Ngay"
Instance.new("UICorner", rehopBtn).CornerRadius = UDim.new(0, 6)
rehopBtn.MouseButton1Click:Connect(function()
    CUSTOM.AUTO_REHOP = true
    triggerRehop("Bấm Re-Hop thủ công trên Hub")
end)

-- Đồng bộ phím tắt đóng/mở (RightShift) nếu dùng ở chế độ dự phòng
if not harvardWindow then
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if not gpe and inp.KeyCode.Name == tostring(CFG.menuKey or "RightShift") then
            extFrame.Visible = not extFrame.Visible
        end
    end)
end

-- =====================================================================
-- 9. VÒNG LẶP CẬP NHẬT TRẠNG THÁI & VÒNG TRÒN HUD
-- =====================================================================
task.spawn(function()
    local lobbyStart = os.clock()
    local lastSyncedMap = ""
    while not RT.destroyed do
        -- Nếu cửa sổ Harvard Labs được tạo trễ, tự động gắn vào ngay khi tìm thấy
        if not harvardWindow or not harvardWindow.Parent then
            local found = findHarvardHubMainFrame()
            if found then
                harvardWindow = found
                extFrame.Parent = harvardWindow
                extFrame.Size = UDim2.new(0, 260, 1, 0)
                extFrame.Position = UDim2.new(1, 6, 0, 0)
            end
        end

        local minLvl, ownerName = getLowestAccountLevel()
        local bestMap, bestDiff, reqLvl = selectBestDungeonForLevel(minLvl)
        local mapChanged = (bestMap ~= currentMap) or (bestDiff ~= currentDiff)
        currentMinLvl, currentMinOwner, currentMap, currentDiff, currentReq = minLvl, ownerName, bestMap, bestDiff, reqLvl

        if CUSTOM.AUTO_MAP_BY_MIN_LVL then
            local sig = bestMap .. "|" .. bestDiff
            if sig ~= lastSyncedMap then
                lastSyncedMap = sig
                CFG.autoQueueMap        = bestMap
                CFG.autoQueueDifficulty = bestDiff
                if type(context.refreshAll) == "function" then
                    pcall(context.refreshAll)
                end
            end
        end

        currentRunState, currentDropTimer = evaluateDungeonBossState()
        local statusStr = currentRunState

        if currentRunState == "LOBBY" then
            resolveRebornLobbyPlaceId()
            statusStr = "Sảnh DQ Reborn -> Map: " .. tostring(currentMap)
            if CUSTOM.AUTO_REHOP and CUSTOM.LOBBY_STUCK_TIMEOUT then
                if os.clock() - lobbyStart > CUSTOM.LOBBY_STUCK_TIMEOUT then
                    triggerRehop("Kẹt ở Sảnh quá " .. tostring(CUSTOM.LOBBY_STUCK_TIMEOUT) .. "s")
                    break
                end
            end
        else
            lobbyStart = os.clock()
            if currentRunState == "LOOT_DONE" then
                if CUSTOM.AUTO_MAP_BY_MIN_LVL and mapChanged then
                    statusStr = "Đủ Lv lên Map mới -> Về Sảnh!"
                    triggerRehop("Đủ Level chuyển sang Map mới: " .. tostring(bestMap))
                    break
                else
                    statusStr = "Đã lấy Drop -> Cho phép Replay!"
                end
            elseif currentRunState == "WAITING_DROP" then
                statusStr = ("Boss chết! Chờ Drop (%.1fs)..."):format(currentDropTimer or 0)
            elseif currentRunState == "FIGHTING_BOSS" then
                statusStr = "Đang đánh Boss (Khóa Replay)"
            else
                statusStr = "Đang dọn quái (Khóa Replay)"
            end
        end

        infoBox.Text = ("Min Lvl: %d (%s) | LobbyID: %s\nMap: %s [%s - Req %d]\n%s"):format(
            currentMinLvl,
            tostring(currentMinOwner):sub(1, 10),
            tostring(CUSTOM.REBORN_LOBBY_ID or game.PlaceId),
            tostring(CFG.autoQueueMap),
            tostring(CFG.autoQueueDifficulty),
            currentReq,
            statusStr
        )

        task.wait(0.5)
    end
end)

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

print(("[Boost DQ Reborn] Đã gắn vào Hub gốc | Lobby PlaceId: %s | Min Lvl: %d -> %s (%s)")
    :format(tostring(CUSTOM.REBORN_LOBBY_ID or game.PlaceId), currentMinLvl, tostring(currentMap), tostring(currentDiff)))
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
