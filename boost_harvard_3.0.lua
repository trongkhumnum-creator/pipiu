-- =====================================================================
-- Harvard Labs v3.0 — DQ Reborn (In-Hub Integration + True MinLvl + AutoMap)
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

    -- 3. Tự chọn Map & Độ khó theo Level thấp nhất (Mặc định quét TẤT CẢ acc)
    AUTO_MAP_BY_MIN_LVL   = true,  -- Tự động nâng Độ khó & Map theo acc có Level thấp nhất
    ONLY_MY_ACCOUNT       = false, -- Luôn tắt mặc định để lấy Level của acc thấp nhất trong phòng/sảnh
    WHITELIST_ACCS        = {},    -- Nếu muốn chỉ định tên acc phụ, điền vào đây VD: {"AccPhu1", "AccPhu2"}
    ALLOW_GILDED_SKIES    = true,  -- Cho phép lên Gilded Skies ở Lv.190+
    FORCE_HARDCORE        = false,
    FORCE_PRIVATE         = true,

    -- 4. Auto Re-Execute, Auto Save & Auto Re-Hop
    AUTO_REEXECUTE        = true,
    AUTO_REHOP            = true,
    LOBBY_STUCK_TIMEOUT   = 120,
    REBORN_LOBBY_ID       = nil,
    SAVED_MAP             = nil,
    SAVED_DIFF            = nil,
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
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

local HUB_CFG_FILE  = "HarvardLabs/reborn_hub_config.json"
local AUTOEXEC_PATH = "HarvardLabs/autoexec_boost_wrapper.lua"

if type(isfile) == "function" and type(readfile) == "function" then
    local ok, exists = pcall(isfile, HUB_CFG_FILE)
    if ok and exists then
        local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(HUB_CFG_FILE)) end)
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                if CUSTOM[k] ~= nil or k == "REBORN_LOBBY_ID" or k == "SAVED_MAP" or k == "SAVED_DIFF" then
                    CUSTOM[k] = v
                end
            end
            if data.CFG_SCHEMA_VER ~= 3 then
                CUSTOM.ONLY_MY_ACCOUNT = false
            end
        end
    end
end

local contextRef = nil

-- Hàm lưu đồng bộ cả cấu hình mở rộng lẫn file release_<UserId>.json của Harvard Labs
local function saveAllSettings(targetMap, targetDiff)
    if targetMap then CUSTOM.SAVED_MAP = targetMap end
    if targetDiff then CUSTOM.SAVED_DIFF = targetDiff end

    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" then
                if not isfolder("HarvardLabs") then pcall(makefolder, "HarvardLabs") end
                if not isfolder("HarvardLabs/configs") then pcall(makefolder, "HarvardLabs/configs") end
            end

            writefile(HUB_CFG_FILE, HttpService:JSONEncode({
                CFG_SCHEMA_VER      = 3,
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
                FORCE_HARDCORE      = CUSTOM.FORCE_HARDCORE,
                FORCE_PRIVATE       = CUSTOM.FORCE_PRIVATE,
                AUTO_REEXECUTE      = CUSTOM.AUTO_REEXECUTE,
                AUTO_REHOP          = CUSTOM.AUTO_REHOP,
                REBORN_LOBBY_ID     = CUSTOM.REBORN_LOBBY_ID,
                SAVED_MAP           = CUSTOM.SAVED_MAP,
                SAVED_DIFF          = CUSTOM.SAVED_DIFF,
            }))

            if contextRef and type(contextRef.saveConfig) == "function" then
                pcall(contextRef.saveConfig)
            end

            local uid = tonumber(LocalPlayer.UserId) or 0
            local cfgPath = ("HarvardLabs/configs/release_%s.json"):format(uid > 0 and tostring(uid) or "unknown")
            local decoded = {}
            if type(isfile) == "function" and isfile(cfgPath) and type(readfile) == "function" then
                local ok, res = pcall(function() return HttpService:JSONDecode(readfile(cfgPath)) end)
                if ok and type(res) == "table" then decoded = res end
            end
            -- Tắt hoàn toàn việc giả Level 999 trên bảng tên & Leaderboard để đọc đúng Level của mọi acc phụ!
            decoded.streamerLevel       = false
            decoded.streamerOthers      = false
            decoded.streamerLeaderboard = false
            decoded.modDetect           = false
            decoded.modKick             = false
            if CUSTOM.AUTO_MAP_BY_MIN_LVL and CUSTOM.SAVED_MAP and CUSTOM.SAVED_DIFF then
                decoded.autoQueue           = true
                decoded.autoQueueMap        = CUSTOM.SAVED_MAP
                decoded.autoQueueDifficulty = CUSTOM.SAVED_DIFF
                decoded.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
                decoded.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
                decoded.autoStartDungeon    = true
            end
            writefile(cfgPath, HttpService:JSONEncode(decoded))
        end)
    end
end

-- =====================================================================
-- 1. NHẬN DIỆN CHÍNH XÁC SẢNH (LOBBY) VS TRONG DUNGEON (ĐÃ BỎ WORKSPACE.MAP)
-- =====================================================================
local function isInDungeon()
    -- Nếu có thư mục Lobby trong Workspace -> Chắc chắn 100% đang ở Sảnh!
    if workspace:FindFirstChild("Lobby") ~= nil then
        return false
    end
    -- Nếu có thư mục dungeon -> Chắc chắn 100% đang ở trong Dungeon!
    if workspace:FindFirstChild("dungeon") ~= nil then
        return true
    end
    -- Nếu đã biết PlaceId của Sảnh:
    if type(CUSTOM.REBORN_LOBBY_ID) == "number" and CUSTOM.REBORN_LOBBY_ID > 0 then
        return game.PlaceId ~= CUSTOM.REBORN_LOBBY_ID
    end
    -- Kiểm tra xem trong workspace.enemies có quái thật có Humanoid đang sống không
    local ef = workspace:FindFirstChild("enemies")
    if ef and #ef:GetChildren() > 0 then
        return true
    end
    return false
end

local function resolveRebornLobbyPlaceId()
    if workspace:FindFirstChild("Lobby") ~= nil or not isInDungeon() then
        if CUSTOM.REBORN_LOBBY_ID ~= game.PlaceId then
            CUSTOM.REBORN_LOBBY_ID = game.PlaceId
            saveAllSettings()
        end
        return CUSTOM.REBORN_LOBBY_ID
    end

    if type(CUSTOM.REBORN_LOBBY_ID) == "number" and CUSTOM.REBORN_LOBBY_ID > 0 and CUSTOM.REBORN_LOBBY_ID ~= 2414851778 then
        return CUSTOM.REBORN_LOBBY_ID
    end

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
                    if pName:find("lobby") or (pId ~= game.PlaceId and (pName:find("reborn") or pName:find("dungeon quest"))) then
                        CUSTOM.REBORN_LOBBY_ID = pId
                        saveAllSettings()
                        return pId
                    end
                end
            end
            if fallbackId then
                CUSTOM.REBORN_LOBBY_ID = fallbackId
                saveAllSettings()
                return fallbackId
            end
        end
    end
    return nil
end

task.spawn(resolveRebornLobbyPlaceId)

-- =====================================================================
-- 2. BẢNG TIER MAP & ĐỌC LEVEL THẬT CỦA MỌI ACCOUNT TRONG SẢNH / PHÒNG
-- =====================================================================
local DUNGEON_TIERS = {
    -- Desert Temple (5 Độ khó: 1, 6, 12, 20, 27)
    { idx = 1,  map = "Desert Temple",     diff = "Easy",      req = 1   },
    { idx = 2,  map = "Desert Temple",     diff = "Medium",    req = 6   },
    { idx = 3,  map = "Desert Temple",     diff = "Hard",      req = 12  },
    { idx = 4,  map = "Desert Temple",     diff = "Insane",    req = 20  },
    { idx = 5,  map = "Desert Temple",     diff = "Nightmare", req = 27  },

    -- Winter Outpost (5 Độ khó: 33, 40, 45, 50, 55)
    { idx = 6,  map = "Winter Outpost",    diff = "Easy",      req = 33  },
    { idx = 7,  map = "Winter Outpost",    diff = "Medium",    req = 40  },
    { idx = 8,  map = "Winter Outpost",    diff = "Hard",      req = 45  },
    { idx = 9,  map = "Winter Outpost",    diff = "Insane",    req = 50  },
    { idx = 10, map = "Winter Outpost",    diff = "Nightmare", req = 55  },

    -- Các map tiếp theo (Insane & Nightmare cách nhau 5 cấp)
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
    { idx = 35, map = "Gilded Skies",      diff = "Insane",    req = 190, gs = true },
    { idx = 36, map = "Gilded Skies",      diff = "Nightmare", req = 195, gs = true },
}

getgenv().HL_RealLevels = getgenv().HL_RealLevels or {}
local realLevelCache = getgenv().HL_RealLevels

local function extractValidLevel(raw)
    if type(raw) == "number" then
        if raw > 0 and raw ~= 999 and raw < 500 then return math.floor(raw) end
        return nil
    end
    if type(raw) == "string" then
        local clean = raw:gsub(",", "")
        -- Ưu tiên chuỗi có chữ Lv / Level phía trước
        local m = clean:match("[Ll][Vv][Ll]?%.?%s*:?%s*(%d+)")
            or clean:match("[Ll]evel%s*:?%s*(%d+)")
            or clean:match("^%s*(%d+)%s*$")
        if m then
            local n = tonumber(m)
            if n and n > 0 and n ~= 999 and n < 500 then return n end
        end
    end
    return nil
end

local function readPlayerLevelRaw(plr)
    if not plr then return nil end

    -- 1. Đọc từ mọi ValueObject bên trong leaderstats hoặc trực tiếp dưới Player
    local containers = {
        plr:FindFirstChild("leaderstats"),
        plr:FindFirstChild("Data"),
        plr:FindFirstChild("PlayerData"),
        plr:FindFirstChild("Stats"),
        plr:FindFirstChild("stats"),
        plr,
    }
    for _, folder in ipairs(containers) do
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("ValueBase") then
                    local cname = string.lower(child.Name)
                    if cname == "level" or cname == "lvl" or cname == "lv" then
                        local n = extractValidLevel(child.Value)
                        if n then
                            realLevelCache[plr.UserId] = n
                            return n
                        end
                    end
                end
            end
        end
    end

    -- 2. Đọc từ Attributes của Player và Character
    for k, v in pairs(plr:GetAttributes()) do
        local klow = string.lower(k)
        if klow == "level" or klow == "lvl" then
            local n = extractValidLevel(v)
            if n then
                realLevelCache[plr.UserId] = n
                return n
            end
        end
    end

    -- 3. Đọc từ BillboardGui trên đầu nhân vật trong Workspace (Trong DQ, BillboardGui chứa TextLabel tên là "level")
    local char = plr.Character or workspace:FindFirstChild(plr.Name)
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local dname = string.lower(desc.Name)
                if dname:find("level") or dname:find("lvl") then
                    local n = extractValidLevel(desc.Text) or extractValidLevel(desc.ContentText)
                    if n then
                        realLevelCache[plr.UserId] = n
                        return n
                    end
                else
                    -- Nếu TextLabel bất kỳ trên BillboardGui có chữ "Level X" hoặc "Lv. X"
                    local txt = desc.Text:gsub(",", "")
                    local m = txt:match("[Ll][Vv][Ll]?%.?%s*:?%s*(%d+)") or txt:match("[Ll]evel%s*:?%s*(%d+)")
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
    end

    return realLevelCache[plr.UserId]
end

-- Quét và lưu ngay Level thật của toàn bộ người chơi trước khi Harvard Labs kịp chạy!
for _, plr in ipairs(Players:GetPlayers()) do
    readPlayerLevelRaw(plr)
end

local function getLowestAccountLevel()
    local myLvl = readPlayerLevelRaw(LocalPlayer) or realLevelCache[LocalPlayer.UserId] or 1
    if CUSTOM.ONLY_MY_ACCOUNT then
        return myLvl, LocalPlayer.Name, myLvl
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
    local minOwner = LocalPlayer.Name

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

    if minLvl == math.huge then
        minLvl = myLvl
        minOwner = LocalPlayer.Name
    end
    return minLvl, minOwner, myLvl
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
    return best.map, best.diff, best.req, best.idx
end

-- Ghi đè tắt StreamerLevel/StreamerOthers/StreamerLeaderboard trong file JSON TRƯỚC KHI gọi chunk()!
local initMinLvl, initOwner, initHostLvl = getLowestAccountLevel()
local initMap, initDiff, initReq, initTierIdx = selectBestDungeonForLevel(initMinLvl)
saveAllSettings(initMap, initDiff)

-- =====================================================================
-- 3. TẢI VÀ KHỞI CHẠY HARVARD LABS GỐC (VÁ TRỰC TIẾP TRONG SOURCE)
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

-- Ngăn script gốc ghi đè Level của các acc khác thành 999 và đặt sẵn Map mục tiêu ngay từ lúc khởi tạo
source = source:gsub("streamerLevel = true", "streamerLevel = false")
source = source:gsub("streamerOthers = true", "streamerOthers = false")
source = source:gsub("streamerLeaderboard = true", "streamerLeaderboard = false")
if CUSTOM.AUTO_MAP_BY_MIN_LVL then
    source = source:gsub('config%.autoQueueMap = "Northern Lands"', ('config.autoQueueMap = %q'):format(initMap))
    source = source:gsub('config%.autoQueueDifficulty = "Nightmare"', ('config.autoQueueDifficulty = %q'):format(initDiff))
    source = source:gsub('autoQueueMap = "Northern Lands"', ('autoQueueMap = %q'):format(initMap))
    source = source:gsub('autoQueueDifficulty = "Insane"', ('autoQueueDifficulty = %q'):format(initDiff))
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

contextRef = context
local CFG, RT = context.CFG, context.RT
_G = _G or {}; getgenv = getgenv or function() return _G end

-- =====================================================================
-- 4. ÁP DỤNG BOOST & MỞ KHÓA AUTO SKILL CHO DQ REBORN
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
    CFG.streamerLevel       = false
    CFG.streamerOthers      = false
    CFG.streamerLeaderboard = false
    CFG.modDetect           = false
    CFG.modKick             = false

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
        if k == "aoeDistance" then
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

task.spawn(function()
    while not RT.destroyed do
        task.wait(0.22)
        if CUSTOM.AUTO_SKILL_ASSIST and RT.farmEnabled and isInDungeon() then
            local hasTarget, tgt = detection()
            if hasTarget and tgt then
                local now = os.clock()
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
-- 6. KIỂM SOÁT BOSS DROP & TỰ TẠO PHÒNG CHUYỂN MAP Ở SẢNH
-- =====================================================================
local bossConfirmedAliveOnce = false
local bossDeadAt             = nil
local bossTrackedName        = nil
local currentMinLvl, currentMinOwner, currentHostLvl = initMinLvl, initOwner, initHostLvl
local targetMap, targetDiff, targetReq, targetTierIdx = initMap, initDiff, initReq, initTierIdx
local currentRunState        = isInDungeon() and "CLEARING_MOBS" or "LOBBY"
local currentDropTimer       = 0
local needLeaveForUpgrade    = false
local dungeonBaselineMinLvl  = nil
local dungeonBaselineTierIdx = nil

local function evaluateDungeonBossState()
    if not isInDungeon() then
        bossConfirmedAliveOnce = false
        bossDeadAt             = nil
        bossTrackedName        = nil
        dungeonBaselineMinLvl  = nil
        dungeonBaselineTierIdx = nil
        return "LOBBY", 0
    end

    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local endScreenShown = false
    if pgui then
        for _, guiName in ipairs({ "retryGui", "EndingGui", "rewardGui", "endScreen" }) do
            local g = pgui:FindFirstChild(guiName)
            if g and g:IsA("ScreenGui") and g.Enabled then
                endScreenShown = true
                break
            end
        end
    end

    local RD = context.RD
    local bossAlive = false
    local anyEnemyAlive = false

    if RD and type(RD.enemies) == "table" then
        for _, e in ipairs(RD.enemies) do
            if e.humanoid and e.humanoid.Health > 0 then
                anyEnemyAlive = true
                if e.isBoss then
                    bossConfirmedAliveOnce = true
                    bossAlive = true
                    bossTrackedName = e.name or (e.model and e.model.Name) or "Boss"
                end
            end
        end
    end

    local ef = workspace:FindFirstChild("enemies") or (workspace:FindFirstChild("dungeon") and workspace.dungeon:FindFirstChild("enemies", true))
    if ef then
        for _, m in ipairs(ef:GetChildren()) do
            if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    anyEnemyAlive = true
                    local isRealBoss = m:FindFirstChild("isBoss") ~= nil or m:GetAttribute("isBoss") == true
                    if isRealBoss then
                        bossConfirmedAliveOnce = true
                        bossAlive = true
                        bossTrackedName = m.Name
                    end
                end
            end
        end
    end

    if endScreenShown then
        bossConfirmedAliveOnce = true
        bossAlive = false
        anyEnemyAlive = false
    end

    if bossConfirmedAliveOnce and not bossAlive and not anyEnemyAlive then
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

    if bossAlive then
        bossDeadAt = nil
        return "FIGHTING_BOSS", 0
    end

    bossDeadAt = nil
    return "CLEARING_MOBS", 0
end

local hbConn
hbConn = RunService.Heartbeat:Connect(function()
    if RT.destroyed then
        if hbConn then hbConn:Disconnect() end
        return
    end

    CFG.streamerLevel       = false
    CFG.streamerOthers      = false
    CFG.streamerLeaderboard = false
    CFG.modDetect           = false
    CFG.modKick             = false

    if CUSTOM.AUTO_MAP_BY_MIN_LVL then
        CFG.autoQueueMap        = targetMap
        CFG.autoQueueDifficulty = targetDiff
        CFG.autoQueueMinLevel   = 0
        CFG.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
        CFG.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
        CFG.autoStartDungeon    = true
    end

    if not isInDungeon() then
        -- Khi ở Sảnh: BẬT autoQueue để Harvard Labs tự động tạo phòng chuyển Map!
        CFG.autoQueue       = true
        CFG.autoQueueReplay = false
    else
        CFG.autoQueue = false
        if CUSTOM.ANTI_EARLY_REPLAY then
            if currentRunState == "LOOT_DONE" and not needLeaveForUpgrade then
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
-- 7. AUTO RE-EXECUTE, AUTO SAVE & RE-HOP
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
    saveAllSettings(targetMap, targetDiff)
    registerAutoReExecute()
end)

local isRehopping = false
local function triggerRehop(reason)
    if isRehopping then return end
    local targetLobbyId = resolveRebornLobbyPlaceId()
    isRehopping = true
    warn(("[Boost][DQ Reborn] Đang lưu Setting & chuyển về Sảnh (PlaceId: %s) | Lý do: %s"):format(tostring(targetLobbyId), tostring(reason)))

    saveAllSettings(targetMap, targetDiff)
    registerAutoReExecute()

    task.spawn(function()
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
            if targetLobbyId then
                pcall(function()
                    TeleportService:Teleport(targetLobbyId, LocalPlayer)
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
                    triggerRehop("Mất kết nối (ErrorPrompt)")
                end
            end)
        end
    end)
end)

TeleportService.TeleportInitFailed:Connect(function(_, res, msg)
    if CUSTOM.AUTO_REHOP then
        warn("[Boost] Teleport lỗi (" .. tostring(res) .. "): " .. tostring(msg))
        isRehopping = false
        task.wait(3)
        triggerRehop("TeleportInitFailed")
    end
end)

-- =====================================================================
-- 8. NHÚNG TRỰC TIẾP VÀO BÊN TRONG CỬA SỐ HUB CỦA HARVARD LABS
-- =====================================================================
-- Xóa hoàn toàn mọi bảng Hub ngoài cũ nếu còn sót lại
local guiParent = (type(gethui) == "function" and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    for _, name in ipairs({ "HLBoostMiniHub", "HLBoostIntegrated" }) do
        local old = guiParent:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

local function findHarvardHubWindow()
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

    local roots = {}
    if type(gethui) == "function" then pcall(function() roots[#roots + 1] = gethui() end) end
    roots[#roots + 1] = CoreGui
    roots[#roots + 1] = LocalPlayer:FindFirstChild("PlayerGui")

    for _, root in ipairs(roots) do
        if root then
            for _, gui in ipairs(root:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local t = string.lower(desc.Text or "")
                            if t:find("harvard") or t:find("v3.0") or t:find("c84b") then
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

local infoBoxLabel = nil
local embeddedReady = false

local function injectIntoHarvardHub(hWin)
    if not hWin or embeddedReady then return end
    embeddedReady = true

    -- Dọn các phần tử cũ bên trong cửa sổ Harvard nếu chạy lại
    for _, oldName in ipairs({ "HLRebornIntegratedPanel", "HLInHubToggleBtn", "HLInHubDrawer", "HLInHubStatusBanner" }) do
        local old = hWin:FindFirstChild(oldName, true)
        if old then old:Destroy() end
    end

    -- 1. Tạo Nút Bật/Tắt "[⚙ AutoMap & ReExec]" nằm ngay trên thanh Topbar của cửa sổ Harvard Labs
    local toggleTabBtn = Instance.new("TextButton")
    toggleTabBtn.Name = "HLInHubToggleBtn"
    toggleTabBtn.Size = UDim2.new(0, 138, 0, 22)
    toggleTabBtn.Position = UDim2.new(1, -185, 0, 6)
    toggleTabBtn.BackgroundColor3 = Color3.fromRGB(145, 24, 34)
    toggleTabBtn.TextColor3 = Color3.fromRGB(255, 240, 240)
    toggleTabBtn.Font = Enum.Font.GothamBold
    toggleTabBtn.TextSize = 11
    toggleTabBtn.Text = "⚙ AutoMap / ReExec"
    toggleTabBtn.ZIndex = 50
    toggleTabBtn.Parent = hWin
    Instance.new("UICorner", toggleTabBtn).CornerRadius = UDim.new(0, 5)

    local btnStroke = Instance.new("UIStroke", toggleTabBtn)
    btnStroke.Color = Color3.fromRGB(220, 60, 70)
    btnStroke.Thickness = 1

    -- 2. Tạo Trang Cài Đặt (Drawer) nằm GỌN BÊN TRONG lòng cửa sổ Harvard Labs (Bấm nút trên Topbar để bật/tắt)
    local inHubPage = Instance.new("Frame")
    inHubPage.Name = "HLInHubDrawer"
    inHubPage.Size = UDim2.new(1, -20, 1, -44)
    inHubPage.Position = UDim2.new(0, 10, 0, 34)
    inHubPage.BackgroundColor3 = Color3.fromRGB(20, 12, 14)
    inHubPage.BorderSizePixel = 0
    inHubPage.Visible = false -- Ẩn mặc định, bấm nút "⚙ AutoMap / ReExec" ngay trên Hub Harvard để mở!
    inHubPage.ZIndex = 45
    inHubPage.Parent = hWin
    Instance.new("UICorner", inHubPage).CornerRadius = UDim.new(0, 8)

    local pageStroke = Instance.new("UIStroke", inHubPage)
    pageStroke.Color = Color3.fromRGB(175, 28, 38)
    pageStroke.Thickness = 1.5

    local pageHeader = Instance.new("TextLabel", inHubPage)
    pageHeader.Size = UDim2.new(1, -20, 0, 26)
    pageHeader.Position = UDim2.new(0, 10, 0, 6)
    pageHeader.BackgroundTransparency = 1
    pageHeader.Text = "CÀI ĐẶT MỞ RỘNG DQ REBORN (NẰM TRONG HARVARD HUB)"
    pageHeader.TextColor3 = Color3.fromRGB(255, 210, 210)
    pageHeader.Font = Enum.Font.GothamBold
    pageHeader.TextSize = 11
    pageHeader.TextXAlignment = Enum.TextXAlignment.Left
    pageHeader.ZIndex = 46

    local scroll = Instance.new("ScrollingFrame", inHubPage)
    scroll.Size = UDim2.new(1, -16, 1, -38)
    scroll.Position = UDim2.new(0, 8, 0, 32)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0, 0, 0, 295)
    scroll.ZIndex = 46

    local statusBox = Instance.new("TextLabel", scroll)
    statusBox.Size = UDim2.new(1, 0, 0, 60)
    statusBox.Position = UDim2.new(0, 0, 0, 0)
    statusBox.BackgroundColor3 = Color3.fromRGB(30, 18, 22)
    statusBox.TextColor3 = Color3.fromRGB(130, 245, 170)
    statusBox.Font = Enum.Font.GothamSemibold
    statusBox.TextSize = 11
    statusBox.TextWrapped = true
    statusBox.Text = "Đang đọc Level các tài khoản..."
    statusBox.ZIndex = 47
    Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 6)
    infoBoxLabel = statusBox

    local function createInHubSwitch(yPos, title, key, onChange)
        local row = Instance.new("TextButton", scroll)
        row.Size = UDim2.new(1, 0, 0, 30)
        row.Position = UDim2.new(0, 0, 0, yPos)
        row.BorderSizePixel = 0
        row.Font = Enum.Font.GothamSemibold
        row.TextSize = 11
        row.ZIndex = 47
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local function updateRow()
            local active = CUSTOM[key]
            row.Text = ("  %s :  %s"):format(title, active and "ĐANG BẬT (ON)" or "ĐANG TẮT (OFF)")
            row.BackgroundColor3 = active and Color3.fromRGB(135, 25, 35) or Color3.fromRGB(36, 22, 26)
            row.TextColor3 = active and Color3.fromRGB(255, 245, 245) or Color3.fromRGB(180, 160, 165)
        end

        row.MouseButton1Click:Connect(function()
            CUSTOM[key] = not CUSTOM[key]
            updateRow()
            applySkillAndBoostSettings()
            saveAllSettings(targetMap, targetDiff)
            if onChange then onChange(CUSTOM[key]) end
        end)

        updateRow()
    end

    createInHubSwitch(66,  "Tự Chọn Map & Độ Khó Theo Min Lvl", "AUTO_MAP_BY_MIN_LVL")
    createInHubSwitch(100, "Chống Replay Sớm (Đợi Boss Chết + Drop)", "ANTI_EARLY_REPLAY")
    createInHubSwitch(134, "Auto Skill Q/E Trợ Lực (DQ Reborn)", "AUTO_SKILL_ASSIST")
    createInHubSwitch(168, "Auto Re-Execute Khi Chuyển Map", "AUTO_REEXECUTE", function(v)
        if v then registerAutoReExecute() end
    end)
    createInHubSwitch(202, "Auto Re-Hop Khi Mất Kết Nối / Kẹt Sảnh", "AUTO_REHOP")
    createInHubSwitch(236, "Chỉ Tính Level Acc Này (Bỏ qua Acc phụ)", "ONLY_MY_ACCOUNT")

    local manualRehopBtn = Instance.new("TextButton", scroll)
    manualRehopBtn.Size = UDim2.new(1, 0, 0, 26)
    manualRehopBtn.Position = UDim2.new(0, 0, 0, 270)
    manualRehopBtn.BackgroundColor3 = Color3.fromRGB(90, 20, 28)
    manualRehopBtn.TextColor3 = Color3.fromRGB(255, 235, 235)
    manualRehopBtn.Font = Enum.Font.GothamBold
    manualRehopBtn.TextSize = 11
    manualRehopBtn.Text = "Lưu Setting & Về Sảnh DQ Reborn Ngay"
    manualRehopBtn.ZIndex = 47
    Instance.new("UICorner", manualRehopBtn).CornerRadius = UDim.new(0, 6)
    manualRehopBtn.MouseButton1Click:Connect(function()
        triggerRehop("Bấm Lưu & Về Sảnh trong Harvard Hub")
    end)

    toggleTabBtn.MouseButton1Click:Connect(function()
        inHubPage.Visible = not inHubPage.Visible
        toggleTabBtn.BackgroundColor3 = inHubPage.Visible and Color3.fromRGB(200, 40, 50) or Color3.fromRGB(145, 24, 34)
        toggleTabBtn.Text = inHubPage.Visible and "✕ Đóng AutoMap" or "⚙ AutoMap / ReExec"
    end)
end

-- =====================================================================
-- 9. VÒNG LẶP ĐỒNG BỘ LEVEL THẤP NHẤT, CHUYỂN MAP & LƯU SETTING
-- =====================================================================
local lastDirectQueueAttempt = 0

local function tryDirectLobbyQueueBackup(mapName, diffName)
    if isInDungeon() or not CUSTOM.AUTO_MAP_BY_MIN_LVL then return end
    if os.clock() - lastDirectQueueAttempt < 8 then return end
    lastDirectQueueAttempt = os.clock()

    -- Hỗ trợ tạo phòng trực tiếp nếu Harvard Labs ở Sảnh chưa tự tạo cho các độ khó Easy/Medium/Hard
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("remotes")
        if remotes then
            local createLobby = remotes:FindFirstChild("createLobby")
            local startDungeon = remotes:FindFirstChild("startDungeon")
            if createLobby and createLobby:IsA("RemoteFunction") then
                task.spawn(function()
                    pcall(function()
                        createLobby:InvokeServer(mapName, diffName, 0, CUSTOM.FORCE_PRIVATE, CUSTOM.FORCE_HARDCORE, false)
                    end)
                end)
            elseif createLobby and createLobby:IsA("RemoteEvent") then
                pcall(function()
                    createLobby:FireServer(mapName, diffName, 0, CUSTOM.FORCE_PRIVATE, CUSTOM.FORCE_HARDCORE, false)
                end)
            end
            if startDungeon and startDungeon:IsA("RemoteEvent") then
                task.delay(2.5, function()
                    if not isInDungeon() then
                        pcall(function() startDungeon:FireServer() end)
                    end
                end)
            end
        end
    end)
end

task.spawn(function()
    local lobbyStart = os.clock()
    local lastSavedSig = ""

    while not RT.destroyed do
        if not embeddedReady then
            local foundWin = findHarvardHubWindow()
            if foundWin then
                injectIntoHarvardHub(foundWin)
            end
        end

        local minLvl, ownerName, hostLvl = getLowestAccountLevel()
        local bestMap, bestDiff, reqLvl, bestTierIdx = selectBestDungeonForLevel(minLvl)
        currentMinLvl, currentMinOwner, currentHostLvl = minLvl, ownerName, hostLvl
        targetMap, targetDiff, targetReq, targetTierIdx = bestMap, bestDiff, reqLvl, bestTierIdx

        if CUSTOM.AUTO_MAP_BY_MIN_LVL then
            local sig = ("%s|%s|%d"):format(tostring(bestMap), tostring(bestDiff), minLvl)
            if sig ~= lastSavedSig then
                lastSavedSig = sig
                CFG.autoQueueMap        = bestMap
                CFG.autoQueueDifficulty = bestDiff
                CFG.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
                CFG.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
                saveAllSettings(bestMap, bestDiff)
                if type(context.refreshAll) == "function" then pcall(context.refreshAll) end
                print(("[Boost][AutoMap] Min Lvl: %d (%s) | Host Lvl: %d -> Chọn Map: %s [%s - Req Lv.%d]")
                    :format(minLvl, tostring(ownerName), hostLvl, tostring(bestMap), tostring(bestDiff), reqLvl))
            end
        end

        currentRunState, currentDropTimer = evaluateDungeonBossState()
        local statusStr = currentRunState

        if currentRunState == "LOBBY" then
            resolveRebornLobbyPlaceId()
            needLeaveForUpgrade = false
            dungeonBaselineMinLvl  = nil
            dungeonBaselineTierIdx = nil
            statusStr = ("Đang ở Sảnh -> Vào: %s [%s]"):format(tostring(bestMap), tostring(bestDiff))

            -- Nếu đứng ở Sảnh quá 10 giây mà Harvard Labs chưa tự vào phòng, gọi hỗ trợ tạo phòng đúng Map & Độ khó
            if os.clock() - lobbyStart > 10 then
                tryDirectLobbyQueueBackup(bestMap, bestDiff)
            end

            if CUSTOM.AUTO_REHOP and CUSTOM.LOBBY_STUCK_TIMEOUT then
                if os.clock() - lobbyStart > CUSTOM.LOBBY_STUCK_TIMEOUT then
                    triggerRehop("Kẹt ở Sảnh quá " .. tostring(CUSTOM.LOBBY_STUCK_TIMEOUT) .. "s")
                    break
                end
            end
        else
            lobbyStart = os.clock()
            if not dungeonBaselineMinLvl or minLvl < dungeonBaselineMinLvl then
                dungeonBaselineMinLvl  = minLvl
                dungeonBaselineTierIdx = bestTierIdx
            end

            needLeaveForUpgrade = CUSTOM.AUTO_MAP_BY_MIN_LVL
                and dungeonBaselineTierIdx ~= nil
                and (bestTierIdx > dungeonBaselineTierIdx)

            if currentRunState == "LOOT_DONE" then
                if needLeaveForUpgrade then
                    statusStr = ("Lên Lv.%d -> Về Sảnh nâng [%s - %s]!"):format(minLvl, tostring(bestMap), tostring(bestDiff))
                    saveAllSettings(bestMap, bestDiff)
                    triggerRehop(("Acc thấp nhất lên Lv.%d -> Nâng lên [%s - %s]"):format(minLvl, tostring(bestMap), tostring(bestDiff)))
                    break
                else
                    statusStr = "Đã lấy Drop -> Đang Replay tiếp!"
                end
            elseif currentRunState == "WAITING_DROP" then
                statusStr = ("Boss chết! Chờ Drop (%.1fs)..."):format(currentDropTimer or 0)
            elseif currentRunState == "FIGHTING_BOSS" then
                statusStr = "Đang đánh Boss (Khóa thoát trận)"
            else
                statusStr = "Đang đánh trong Dungeon (Khóa thoát trận)"
            end
        end

        if infoBoxLabel then
            infoBoxLabel.Text = ("Min Lvl: %d (%s) | Host Lvl: %d\nMục tiêu: %s [%s - Req Lv.%d]\nTrạng thái: %s"):format(
                currentMinLvl,
                tostring(currentMinOwner):sub(1, 12),
                currentHostLvl,
                tostring(targetMap),
                tostring(targetDiff),
                targetReq,
                statusStr
            )
        end

        task.wait(0.4)
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

print(("[Boost DQ Reborn] Đã tích hợp vào trong Harvard Hub | Min Lvl: %d (%s) -> %s [%s - Req Lv.%d]")
    :format(currentMinLvl, tostring(currentMinOwner), tostring(targetMap), tostring(targetDiff), targetReq))
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
