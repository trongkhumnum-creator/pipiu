-- =====================================================================
-- Harvard Labs v3.0 — DQ Reborn (Fixed Buff->Damage Combo + Native Hub)
-- =====================================================================

local WRAPPER_SOURCE = [=====[
local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"

-- ============ Bảng Tùy Chỉnh =========================================
local CUSTOM = {
    BOOST                 = 1.35,   -- Hệ số nhân tầm đánh / bán kính kỹ năng
    DETECT_HOLD           = 0.35,  -- Thời gian giữ mục tiêu trong bộ nhớ đệm (giây)
    CACHE_HZ              = 15,    -- Tần suất quét mục tiêu mỗi giây
    LOOT_WAIT_TIME        = 6,     -- Số giây bắt buộc chờ nhận Drop sau khi Boss chết
    BUFF_DURATION         = 5.0,   -- Thời gian hiệu lực chuẩn của Inner Rage / Inner Focus (5 giây)
    BUFF_CAST_DELAY       = 0.15,  -- Độ trễ nhỏ sau khi bấm Buff để Server nhận diện Buff trước khi nổ Skill dmg
    FORCE_HARDCORE        = false,
    FORCE_PRIVATE         = true,
    LOBBY_STUCK_TIMEOUT   = 120,

    -- Các tính năng có thể Bật / Tắt trong Hub Harvard Labs:
    AUTO_REEXECUTE        = true,  -- Tự động chạy lại Script khi chuyển Map / vào Dungeon
    AUTO_REHOP            = true,  -- Tự động kết nối lại / về Sảnh khi mất kết nối hoặc kẹt
    DRAW_HUD              = true,  -- Hiển thị vòng tròn tầm đánh dưới chân

    -- Dữ liệu tự động lưu khi chuyển Map:
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
            if type(data.AUTO_REEXECUTE) == "boolean" then CUSTOM.AUTO_REEXECUTE = data.AUTO_REEXECUTE end
            if type(data.AUTO_REHOP) == "boolean"     then CUSTOM.AUTO_REHOP     = data.AUTO_REHOP     end
            if type(data.DRAW_HUD) == "boolean"       then CUSTOM.DRAW_HUD       = data.DRAW_HUD       end
            if type(data.REBORN_LOBBY_ID) == "number" then CUSTOM.REBORN_LOBBY_ID = data.REBORN_LOBBY_ID end
            if type(data.SAVED_MAP) == "string"       then CUSTOM.SAVED_MAP      = data.SAVED_MAP      end
            if type(data.SAVED_DIFF) == "string"      then CUSTOM.SAVED_DIFF     = data.SAVED_DIFF     end
        end
    end
end

local contextRef = nil

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
                AUTO_REEXECUTE  = CUSTOM.AUTO_REEXECUTE,
                AUTO_REHOP      = CUSTOM.AUTO_REHOP,
                DRAW_HUD        = CUSTOM.DRAW_HUD,
                REBORN_LOBBY_ID = CUSTOM.REBORN_LOBBY_ID,
                SAVED_MAP       = CUSTOM.SAVED_MAP,
                SAVED_DIFF      = CUSTOM.SAVED_DIFF,
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
            decoded.streamerLevel       = false
            decoded.streamerOthers      = false
            decoded.streamerLeaderboard = false
            decoded.modDetect           = false
            decoded.modKick             = false
            decoded.mobAttackNeedsBuff  = true
            decoded.attackNeedsBuffUp   = true
            decoded.buffHolderCheck     = false
            decoded.buffSpeedCheck      = false
            if CUSTOM.SAVED_MAP and CUSTOM.SAVED_DIFF then
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

-- Dọn sạch mọi GUI rời bên ngoài
local function purgeAllExternalHubs()
    local roots = {}
    if type(gethui) == "function" then pcall(function() roots[#roots + 1] = gethui() end) end
    roots[#roots + 1] = CoreGui
    roots[#roots + 1] = LocalPlayer:FindFirstChild("PlayerGui")

    for _, r in ipairs(roots) do
        if r then
            for _, guiName in ipairs({ "HLBoostMiniHub", "HLBoostIntegrated" }) do
                local old = r:FindFirstChild(guiName)
                if old then pcall(function() old:Destroy() end) end
            end
            for _, desc in ipairs(r:GetDescendants()) do
                if desc.Name == "HLRebornIntegratedPanel"
                    or desc.Name == "HLInHubToggleBtn"
                    or desc.Name == "HLInHubDrawer"
                then
                    pcall(function() desc:Destroy() end)
                end
            end
        end
    end
end

purgeAllExternalHubs()

-- =====================================================================
-- 1. NHẬN DIỆN SẢNH (LOBBY) VS TRONG DUNGEON & PLACE ID DQ REBORN
-- =====================================================================
local function isInDungeon()
    if workspace:FindFirstChild("Lobby") ~= nil then return false end
    if workspace:FindFirstChild("dungeon") ~= nil then return true end
    if type(CUSTOM.REBORN_LOBBY_ID) == "number" and CUSTOM.REBORN_LOBBY_ID > 0 then
        return game.PlaceId ~= CUSTOM.REBORN_LOBBY_ID
    end
    local ef = workspace:FindFirstChild("enemies")
    if ef and #ef:GetChildren() > 0 then return true end
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
-- 2. TỰ ĐỘNG QUÉT LEVEL THẤP NHẤT TRONG TẤT CẢ ACCOUNT (BẮT BUỘC BẬT)
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
    { idx = 35, map = "Gilded Skies",      diff = "Insane",    req = 190 },
    { idx = 36, map = "Gilded Skies",      diff = "Nightmare", req = 195 },
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

for _, plr in ipairs(Players:GetPlayers()) do
    readPlayerLevelRaw(plr)
end

local function getLowestAccountLevel()
    local minLvl = math.huge
    local minOwner = LocalPlayer.Name

    for _, plr in ipairs(Players:GetPlayers()) do
        local l = readPlayerLevelRaw(plr)
        if l and l > 0 and l < minLvl then
            minLvl = l
            minOwner = plr.Name
        end
    end

    if minLvl == math.huge then
        minLvl = readPlayerLevelRaw(LocalPlayer) or realLevelCache[LocalPlayer.UserId] or 1
        minOwner = LocalPlayer.Name
    end
    return minLvl, minOwner
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
    return best.map, best.diff, best.req, best.idx
end

local initMinLvl, initOwner = getLowestAccountLevel()
local initMap, initDiff, initReq, initTierIdx = selectBestDungeonForLevel(initMinLvl)
saveAllSettings(initMap, initDiff)

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

source = source:gsub("streamerLevel = true", "streamerLevel = false")
source = source:gsub("streamerOthers = true", "streamerOthers = false")
source = source:gsub("streamerLeaderboard = true", "streamerLeaderboard = false")
source = source:gsub('config%.autoQueueMap = "Northern Lands"', ('config.autoQueueMap = %q'):format(initMap))
source = source:gsub('config%.autoQueueDifficulty = "Nightmare"', ('config.autoQueueDifficulty = %q'):format(initDiff))
source = source:gsub('autoQueueMap = "Northern Lands"', ('autoQueueMap = %q'):format(initMap))
source = source:gsub('autoQueueDifficulty = "Insane"', ('autoQueueDifficulty = %q'):format(initDiff))

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
-- 4. SỬA LỖI KẸT SKILL DAMAGE SAU KHI BẬT BUFF TRONG HARVARD LABS
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

local function applyMandatoryAndBoostSettings()
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

    -- QUAN TRỌNG:
    -- 1. Giữ mobAttackNeedsBuff = true & attackNeedsBuffUp = true để Harvard Labs luôn ưu tiên bật Buff trước.
    -- 2. TẮT buffHolderCheck = false & buffSpeedCheck = false vì trong DQ Reborn, hiệu ứng particle và tốc độ chạy khác với DQ cũ (nếu để true thì sau 0.6s script gốc tưởng mất Buff và khóa vĩnh viễn Skill gây sát thương!).
    -- 3. TẮT các cờ bắt chờ gom đủ 100% quái (firstCastWholeStrict, fireOnFullCover) để khi Buff vừa lên là Carry xả ngay Skill sát thương trong 5 giây hiệu lực!
    CFG.buffDuration         = 5
    CFG.buffCooldown         = 6
    CFG.mobAttackNeedsBuff   = true
    CFG.attackNeedsBuffUp    = true
    CFG.buffHolderCheck      = false
    CFG.buffSpeedCheck       = false
    CFG.attackOnlyWithSpeed  = false
    CFG.firstCastWholeStrict = false
    CFG.groupFirstWhole      = false
    CFG.firstHitWhole        = false
    CFG.fireOnFullCover      = false
    CFG.strikeWaitReady      = false
    CFG.groupArriveReady     = false

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
        if k == "aoeDistance" or k == "buffHolderCheck" or k == "buffSpeedCheck" then
            table.remove(context.PERSIST, i)
        else
            for _, rk in ipairs(KEYS) do
                if k == rk then table.remove(context.PERSIST, i); break end
            end
        end
    end
end

applyMandatoryAndBoostSettings()

if type(context.applyClassProfile) == "function" then
    local orig = context.applyClassProfile
    context.applyClassProfile = function(...)
        local ok = orig(...)
        if ok then
            for _, k in ipairs(KEYS) do
                if type(CFG[k]) == "number" then baseValues[k] = CFG[k] end
            end
            applyMandatoryAndBoostSettings()
        end
        return ok
    end
end
if type(context.loadConfig) == "function" then
    local orig = context.loadConfig
    context.loadConfig = function(...)
        local ok = orig(...)
        if ok then applyMandatoryAndBoostSettings() end
        return ok
    end
end

-- =====================================================================
-- 5. BỘ ĐỒNG BỘ COMBO: BUFF (INNER RAGE / FOCUS) -> XẢ SKILL DAMAGE TRONG 5 GIÂY
-- =====================================================================
local BUFF_SPELL_NAMES = {
    ["inner focus"]          = true,
    ["inner rage"]           = true,
    ["enhanced inner focus"] = true,
    ["enhanced inner rage"]  = true,
}

-- Kiểm tra chính xác một slot ("Q", "E", 1, 2) có phải là chiêu Buff hay không
local function checkIsBuffSlot(slot)
    if type(context.isBuffSlot) == "function" then
        local ok, res = pcall(context.isBuffSlot, slot)
        if ok and res == true then return true end
        if slot == "Q" or slot == "q" then
            local ok1, r1 = pcall(context.isBuffSlot, 1)
            if ok1 and r1 == true then return true end
        elseif slot == "E" or slot == "e" then
            local ok2, r2 = pcall(context.isBuffSlot, 2)
            if ok2 and r2 == true then return true end
        end
    end

    local slotUpper = string.upper(tostring(slot or ""))
    if slotUpper == "1" then slotUpper = "Q" elseif slotUpper == "2" then slotUpper = "E" end

    -- Quét trong PlayerGui (thanh kỹ năng Q / E) và Backpack / Character
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("StringValue") then
                local val = string.lower(desc:IsA("TextLabel") and desc.Text or desc.Value)
                if BUFF_SPELL_NAMES[val] then
                    local parentName = desc.Parent and string.upper(desc.Parent.Name) or ""
                    local grandName  = desc.Parent and desc.Parent.Parent and string.upper(desc.Parent.Parent.Name) or ""
                    if parentName:find(slotUpper, 1, true) or grandName:find(slotUpper, 1, true) then
                        return true
                    end
                end
            end
        end
    end

    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    for _, container in ipairs({ char, bp }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if BUFF_SPELL_NAMES[string.lower(item.Name)] then
                    local s = item:GetAttribute("Slot") or item:GetAttribute("Key") or (item:FindFirstChild("slot") and item.slot.Value)
                    if s and string.upper(tostring(s)) == slotUpper then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- Tìm xem phím nào ("Q" hay "E") đang chứa kỹ năng Buff, và phím còn lại là kỹ năng Damage
local function getBuffAndDamageSlots()
    if checkIsBuffSlot("Q") then
        return "Q", Enum.KeyCode.Q, "E", Enum.KeyCode.E
    end
    if checkIsBuffSlot("E") then
        return "E", Enum.KeyCode.E, "Q", Enum.KeyCode.Q
    end
    return nil, nil, nil, nil
end

local lastBuffTimestamp = -math.huge
local prevLastQ = tonumber(RT.lastQ) or -math.huge
local prevLastE = tonumber(RT.lastE) or -math.huge

-- Cập nhật thời điểm vừa tung Buff dựa trên RT.lastQ / RT.lastE của Harvard Labs & Particle trong Workspace
local function updateBuffTimerState()
    local now = os.clock()
    local buffSlot, _, _, _ = getBuffAndDamageSlots()

    local curQ = tonumber(RT.lastQ) or -math.huge
    local curE = tonumber(RT.lastE) or -math.huge

    if buffSlot == "Q" and curQ > prevLastQ and curQ <= now then
        lastBuffTimestamp = curQ
    elseif buffSlot == "E" and curE > prevLastE and curE <= now then
        lastBuffTimestamp = curE
    elseif buffSlot == nil then
        -- Ngay cả khi chưa nhận diện được slot qua tên, nếu 1 trong 2 phím vừa được Harvard Labs bấm làm phím mở đầu:
        if curQ > prevLastQ and (now - curE > 1.0) and (now - lastBuffTimestamp > 5.0) then
            lastBuffTimestamp = curQ
        elseif curE > prevLastE and (now - curQ > 1.0) and (now - lastBuffTimestamp > 5.0) then
            lastBuffTimestamp = curE
        end
    end

    prevLastQ = curQ
    prevLastE = curE

    -- Kiểm tra thêm nếu có hiệu ứng particle holder xuất hiện trong Workspace / SpellProjectile / Character
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, container in ipairs({ char, workspace:FindFirstChild("SpellProjectile"), workspace }) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    local n = string.lower(child.Name)
                    if n:find("inner focus", 1, true) or n:find("inner rage", 1, true) then
                        if (now - lastBuffTimestamp) > CUSTOM.BUFF_DURATION then
                            lastBuffTimestamp = now
                        end
                        break
                    end
                end
            end
        end
    end
end

-- Kiểm tra xem hiện tại có đang nằm trong 5.0 giây hiệu lực của Inner Rage / Inner Focus không
local function isDamageBuffActive()
    updateBuffTimerState()
    local now = os.clock()
    local elapsed = now - lastBuffTimestamp

    -- Đang nằm trong khoảng hiệu lực 5.0 giây (tính từ khi bấm Buff)
    if elapsed >= 0 and elapsed <= CUSTOM.BUFF_DURATION then
        return true, (CUSTOM.BUFF_DURATION - elapsed)
    end

    if type(RT.buffUntil) == "number" and now < RT.buffUntil then
        return true, (RT.buffUntil - now)
    end

    return false, 0
end

-- =====================================================================
-- 6. QUÉT QUÁI, CHẶN GATE & CHỦ ĐỘNG XẢ SKILL DAMAGE NGAY KHI CÓ BUFF
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

-- Hàm Gate kiểm soát tung chiêu:
-- 1. Nếu là chiêu Buff -> Cho phép tung ngay lập tức và ghi nhận mốc thời gian 5.0 giây.
-- 2. Nếu là chiêu Damage -> Chỉ cho phép tung khi đang nằm trong 5.0 giây hiệu lực của Buff!
local function gate(fn)
    if type(fn) ~= "function" then return fn end
    return function(slot, ...)
        if checkIsBuffSlot(slot) then
            local ok = fn(slot, ...)
            if ok then
                lastBuffTimestamp = os.clock()
            end
            return ok
        end

        local buffSlot, _, _, _ = getBuffAndDamageSlots()
        if buffSlot ~= nil then
            local active, _ = isDamageBuffActive()
            if not active then
                -- Chưa có hiệu lực Buff -> Chặn chiêu sát thương để đợi bật Buff trước!
                return false
            end
            -- Đang có hiệu lực Buff -> Cho phép chiêu sát thương nổ ngay!
            return fn(slot, ...)
        end

        return fn(slot, ...)
    end
end
if type(context.gsSlotReady) == "function" then context.gsSlotReady = gate(context.gsSlotReady) end
if type(context.slotReady) == "function" then context.slotReady = gate(context.slotReady) end

-- Luồng thực thi Combo tự động:
-- Bước 1: Khi thấy quái trong tầm mà chưa có Buff -> Bấm phím Buff và mở cửa sổ 5.0 giây.
-- Bước 2: Ngay khi đang trong 5.0 giây hiệu lực của Buff -> Chủ động bấm phím Skill gây sát thương!
task.spawn(function()
    local lastAssistAtkAt = 0
    while not RT.destroyed do
        task.wait(0.12)
        if RT.farmEnabled and isInDungeon() then
            local hasTarget, tgt = detection()
            if hasTarget and tgt then
                local now = os.clock()
                local buffSlot, buffKeyCode, dmgSlot, dmgKeyCode = getBuffAndDamageSlots()
                local buffActive, _ = isDamageBuffActive()

                if buffSlot and buffKeyCode and dmgKeyCode then
                    if not buffActive then
                        -- Nếu đã qua thời gian hồi chiêu Buff (6.0s), bấm phím Buff và kích hoạt cửa sổ 5.0s
                        if (now - lastBuffTimestamp) >= 5.8 then
                            lastBuffTimestamp = now
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(true, buffKeyCode, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, buffKeyCode, false, game)
                            end)
                        end
                    else
                        -- Đang trong 5.0 giây hiệu lực của Buff!
                        -- Chờ 0.15s đầu để Buff kịp nhận trên Server, sau đó xả ngay phím Skill gây sát thương!
                        local sinceBuff = now - lastBuffTimestamp
                        local lastDmgCast = (dmgSlot == "Q") and (tonumber(RT.lastQ) or 0) or (tonumber(RT.lastE) or 0)
                        if sinceBuff >= CUSTOM.BUFF_CAST_DELAY
                            and (now - lastDmgCast > 0.35)
                            and (now - lastAssistAtkAt > 0.35)
                        then
                            lastAssistAtkAt = now
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(true, dmgKeyCode, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, dmgKeyCode, false, game)
                            end)
                        end
                    end
                else
                    -- Trường hợp nhân vật không trang bị Inner Rage / Inner Focus (cả Q và E đều là chiêu đánh)
                    if buffActive and (now - lastAssistAtkAt > 0.4) then
                        lastAssistAtkAt = now
                        local qTime = tonumber(RT.lastQ) or 0
                        local eTime = tonumber(RT.lastE) or 0
                        -- Nếu Harvard vừa bấm Q làm Buff, bấm bồi E làm Damage (và ngược lại)
                        if (now - qTime) < 4.8 and (now - eTime) > 0.6 then
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                            end)
                        elseif (now - eTime) < 4.8 and (now - qTime) > 0.6 then
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- =====================================================================
-- 7. KIỂM SOÁT BOSS DROP & TỰ CHỌN MAP THEO MIN LEVEL (BẮT BUỘC BẬT)
-- =====================================================================
local bossConfirmedAliveOnce = false
local bossDeadAt             = nil
local bossTrackedName        = nil
local currentMinLvl, currentMinOwner = initMinLvl, initOwner
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

    updateBuffTimerState()

    CFG.streamerLevel       = false
    CFG.streamerOthers      = false
    CFG.streamerLeaderboard = false
    CFG.modDetect           = false
    CFG.modKick             = false

    -- Giữ ưu tiên bật Buff trước, nhưng TẮT buffHolderCheck & buffSpeedCheck để không bị khóa Skill Damage!
    CFG.mobAttackNeedsBuff  = true
    CFG.attackNeedsBuffUp   = true
    CFG.buffHolderCheck     = false
    CFG.buffSpeedCheck      = false

    -- Bắt buộc chọn Map & Độ khó theo Min Level
    CFG.autoQueueMap        = targetMap
    CFG.autoQueueDifficulty = targetDiff
    CFG.autoQueueMinLevel   = 0
    CFG.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
    CFG.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
    CFG.autoStartDungeon    = true

    -- Bắt buộc chống Replay sớm trước khi Boss chết & nhận xong Drop
    if not isInDungeon() then
        CFG.autoQueue       = true
        CFG.autoQueueReplay = false
    else
        CFG.autoQueue = false
        if currentRunState == "LOOT_DONE" and not needLeaveForUpgrade then
            CFG.autoQueueReplay      = true
            CFG.autoQueueReplayDelay = 0.5
        else
            CFG.autoQueueReplay      = false
            CFG.autoQueueReplayDelay = 9999
        end
    end
end)

-- =====================================================================
-- 8. AUTO RE-EXECUTE, AUTO SAVE & RE-HOP
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
-- 9. TÍCH HỢP MỤC CÀI ĐẶT GỌN GÀNG TRONG HUB HARVARD LABS DUY NHẤT
-- =====================================================================
local hudFolder = nil
local hudPart   = nil

local function syncHudVisibility()
    if not CUSTOM.DRAW_HUD then
        if hudPart then pcall(function() hudPart.Transparency = 1 end) end
        return
    end
    pcall(function()
        hudFolder = workspace:FindFirstChild("HLBoostHUD")
        if not hudFolder then
            hudFolder = Instance.new("Folder")
            hudFolder.Name = "HLBoostHUD"
            hudFolder.Parent = workspace
        end
        hudPart = hudFolder:FindFirstChild("detectRange")
        if not hudPart then
            hudPart = Instance.new("Part")
            hudPart.Name, hudPart.Anchored       = "detectRange", true
            hudPart.CanCollide, hudPart.CanQuery = false, false
            hudPart.CanTouch, hudPart.CastShadow = false, false
            hudPart.Material, hudPart.Shape      = Enum.Material.Neon, Enum.PartType.Cylinder
            hudPart.Color, hudPart.Transparency  = Color3.fromRGB(80, 200, 255), 0.88
            hudPart.Size, hudPart.Parent         = Vector3.new(0.1, 2, 2), hudFolder
        else
            hudPart.Transparency = 0.88
        end
    end)
end

syncHudVisibility()

local function findHarvardContentScrollingFrame()
    local roots = {}
    if type(gethui) == "function" then pcall(function() roots[#roots + 1] = gethui() end) end
    roots[#roots + 1] = CoreGui
    roots[#roots + 1] = LocalPlayer:FindFirstChild("PlayerGui")

    for _, root in ipairs(roots) do
        if root then
            for _, gui in ipairs(root:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local isHarvardGui = false
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local t = string.lower(desc.Text or "")
                            if t == "harvard labs" or t:find("v3.0 c84b", 1, true) then
                                isHarvardGui = true
                                break
                            end
                        end
                    end
                    if isHarvardGui then
                        local bestScroll = nil
                        local bestArea = 0
                        for _, desc in ipairs(gui:GetDescendants()) do
                            if desc:IsA("ScrollingFrame") then
                                local area = desc.AbsoluteSize.X * desc.AbsoluteSize.Y
                                if desc.AbsoluteSize.X > 350 and area > bestArea then
                                    bestArea = area
                                    bestScroll = desc
                                end
                            end
                        end
                        if bestScroll then return bestScroll end
                    end
                end
            end
        end
    end
    return nil
end

local nativeStatusLabel = nil
local nativeCardInjected = false

local function injectNativeSectionCard(scrollContainer)
    if not scrollContainer or nativeCardInjected then return end
    nativeCardInjected = true

    local oldCard = scrollContainer:FindFirstChild("HLNativeBoostSection")
    if oldCard then oldCard:Destroy() end

    local expandedHeight = 250
    local collapsedHeight = 36
    local isCollapsed = false

    local sectionCard = Instance.new("Frame")
    sectionCard.Name = "HLNativeBoostSection"
    sectionCard.Size = UDim2.new(1, 0, 0, expandedHeight)
    sectionCard.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    sectionCard.BorderSizePixel = 0
    sectionCard.LayoutOrder = -9999
    sectionCard.Parent = scrollContainer
    Instance.new("UICorner", sectionCard).CornerRadius = UDim.new(0, 6)

    local cardStroke = Instance.new("UIStroke", sectionCard)
    cardStroke.Color = Color3.fromRGB(40, 40, 46)
    cardStroke.Thickness = 1

    local headerBtn = Instance.new("TextButton", sectionCard)
    headerBtn.Size = UDim2.new(1, 0, 0, 34)
    headerBtn.BackgroundTransparency = 1
    headerBtn.Text = ""
    headerBtn.AutoButtonColor = false

    local headerTitle = Instance.new("TextLabel", headerBtn)
    headerTitle.Size = UDim2.new(1, -50, 1, 0)
    headerTitle.Position = UDim2.new(0, 14, 0, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Re-Execute, Re-Hop & Trạng thái AutoMap (DQ Reborn)"
    headerTitle.TextColor3 = Color3.fromRGB(235, 65, 45)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 12
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left

    local arrowLabel = Instance.new("TextLabel", headerBtn)
    arrowLabel.Size = UDim2.new(0, 24, 1, 0)
    arrowLabel.Position = UDim2.new(1, -34, 0, 0)
    arrowLabel.BackgroundTransparency = 1
    arrowLabel.Text = "∧"
    arrowLabel.TextColor3 = Color3.fromRGB(235, 65, 45)
    arrowLabel.Font = Enum.Font.GothamBold
    arrowLabel.TextSize = 12

    local redLine = Instance.new("Frame", sectionCard)
    redLine.Size = UDim2.new(1, -28, 0, 1)
    redLine.Position = UDim2.new(0, 14, 0, 34)
    redLine.BackgroundColor3 = Color3.fromRGB(165, 38, 30)
    redLine.BorderSizePixel = 0

    local bodyContainer = Instance.new("Frame", sectionCard)
    bodyContainer.Size = UDim2.new(1, -28, 1, -42)
    bodyContainer.Position = UDim2.new(0, 14, 0, 40)
    bodyContainer.BackgroundTransparency = 1

    local descLabel = Instance.new("TextLabel", bodyContainer)
    descLabel.Size = UDim2.new(1, 0, 0, 36)
    descLabel.Position = UDim2.new(0, 0, 0, 0)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    descLabel.Font = Enum.Font.GothamMedium
    descLabel.TextSize = 11
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Text = "Đang đồng bộ Level thấp nhất, Map mục tiêu & hiệu lực Buff Inner Rage / Inner Focus..."
    nativeStatusLabel = descLabel

    local function addNativeOptionRow(yPos, labelText, key, onToggle)
        local rowFrame = Instance.new("TextButton", bodyContainer)
        rowFrame.Size = UDim2.new(1, 0, 0, 34)
        rowFrame.Position = UDim2.new(0, 0, 0, yPos)
        rowFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
        rowFrame.BorderSizePixel = 0
        rowFrame.Text = ""
        rowFrame.AutoButtonColor = false
        Instance.new("UICorner", rowFrame).CornerRadius = UDim.new(0, 5)

        local rStroke = Instance.new("UIStroke", rowFrame)
        rStroke.Color = Color3.fromRGB(42, 42, 48)
        rStroke.Thickness = 1

        local lbl = Instance.new("TextLabel", rowFrame)
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local pillBg = Instance.new("Frame", rowFrame)
        pillBg.Size = UDim2.new(0, 38, 0, 20)
        pillBg.Position = UDim2.new(1, -50, 0.5, -10)
        pillBg.BorderSizePixel = 0
        Instance.new("UICorner", pillBg).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", pillBg)
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.BorderSizePixel = 0
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function refreshSwitch()
            local state = CUSTOM[key]
            if state then
                pillBg.BackgroundColor3 = Color3.fromRGB(230, 55, 35)
                knob.Position = UDim2.new(1, -17, 0.5, -7)
                knob.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
            else
                pillBg.BackgroundColor3 = Color3.fromRGB(48, 48, 54)
                knob.Position = UDim2.new(0, 3, 0.5, -7)
                knob.BackgroundColor3 = Color3.fromRGB(145, 145, 155)
            end
        end

        rowFrame.MouseButton1Click:Connect(function()
            CUSTOM[key] = not CUSTOM[key]
            refreshSwitch()
            saveAllSettings(targetMap, targetDiff)
            if onToggle then onToggle(CUSTOM[key]) end
        end)

        refreshSwitch()
    end

    addNativeOptionRow(42,  "Auto Re-Execute (Tự chạy lại Script khi chuyển Map / vào Dungeon)", "AUTO_REEXECUTE", function(v)
        if v then registerAutoReExecute() end
    end)
    addNativeOptionRow(82,  "Auto Re-Hop (Tự kết nối lại / về Sảnh khi mất kết nối hoặc kẹt sảnh)", "AUTO_REHOP")
    addNativeOptionRow(122, "Hiển thị vòng tròn tầm đánh dưới chân (Range HUD)", "DRAW_HUD", function()
        syncHudVisibility()
    end)

    local actionBtn = Instance.new("TextButton", bodyContainer)
    actionBtn.Size = UDim2.new(0, 190, 0, 30)
    actionBtn.Position = UDim2.new(0, 0, 0, 166)
    actionBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 30)
    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 12
    actionBtn.Text = "Lưu Setting & Về Sảnh Ngay"
    Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 5)
    actionBtn.MouseButton1Click:Connect(function()
        triggerRehop("Bấm Lưu & Về Sảnh trong Harvard Hub")
    end)

    headerBtn.MouseButton1Click:Connect(function()
        isCollapsed = not isCollapsed
        bodyContainer.Visible = not isCollapsed
        redLine.Visible = not isCollapsed
        sectionCard.Size = UDim2.new(1, 0, 0, isCollapsed and collapsedHeight or expandedHeight)
        arrowLabel.Text = isCollapsed and "∨" or "∧"
    end)

    sectionCard:GetPropertyChangedSignal("Visible"):Connect(function()
        if not sectionCard.Visible then
            sectionCard.Visible = true
        end
    end)
end

-- =====================================================================
-- 10. VÒNG LẶP ĐỒNG BỘ LEVEL THẤP NHẤT, TRẠNG THÁI BUFF & TỰ CHUYỂN MAP
-- =====================================================================
local lastDirectQueueAttempt = 0

local function tryDirectLobbyQueueBackup(mapName, diffName)
    if isInDungeon() then return end
    if os.clock() - lastDirectQueueAttempt < 8 then return end
    lastDirectQueueAttempt = os.clock()

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
        if not nativeCardInjected then
            local scroll = findHarvardContentScrollingFrame()
            if scroll then
                injectNativeSectionCard(scroll)
            end
        end

        local minLvl, ownerName = getLowestAccountLevel()
        local bestMap, bestDiff, reqLvl, bestTierIdx = selectBestDungeonForLevel(minLvl)
        currentMinLvl, currentMinOwner = minLvl, ownerName
        targetMap, targetDiff, targetReq, targetTierIdx = bestMap, bestDiff, reqLvl, bestTierIdx

        local sig = ("%s|%s|%d"):format(tostring(bestMap), tostring(bestDiff), minLvl)
        if sig ~= lastSavedSig then
            lastSavedSig = sig
            CFG.autoQueueMap        = bestMap
            CFG.autoQueueDifficulty = bestDiff
            CFG.autoQueueHardcore   = CUSTOM.FORCE_HARDCORE
            CFG.autoQueuePrivate    = CUSTOM.FORCE_PRIVATE
            saveAllSettings(bestMap, bestDiff)
            if type(context.refreshAll) == "function" then pcall(context.refreshAll) end
        end

        currentRunState, currentDropTimer = evaluateDungeonBossState()
        local statusStr = currentRunState

        if currentRunState == "LOBBY" then
            resolveRebornLobbyPlaceId()
            needLeaveForUpgrade = false
            dungeonBaselineMinLvl  = nil
            dungeonBaselineTierIdx = nil
            statusStr = ("Đang ở Sảnh -> Tự vào: %s [%s]"):format(tostring(bestMap), tostring(bestDiff))

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

            needLeaveForUpgrade = dungeonBaselineTierIdx ~= nil and (bestTierIdx > dungeonBaselineTierIdx)

            if currentRunState == "LOOT_DONE" then
                if needLeaveForUpgrade then
                    statusStr = ("Đủ Lv.%d -> Về Sảnh nâng [%s - %s]!"):format(minLvl, tostring(bestMap), tostring(bestDiff))
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
                statusStr = "Đang đánh trong Dungeon"
            end
        end

        if nativeStatusLabel then
            local buffActive, buffRem = isDamageBuffActive()
            local bSlot, _, dSlot, _ = getBuffAndDamageSlots()
            local slotInfo = bSlot and ("Buff:%s/Dmg:%s"):format(bSlot, dSlot) or "Auto"
            local buffStateTxt = buffActive and ("ĐANG CÓ BUFF (%.1fs) -> Xả Skill!"):format(buffRem) or "CHỜ BUFF (Khóa Skill Dmg)"
            nativeStatusLabel.Text = ("Min Lvl: %d (%s) -> Map: %s [%s - Req Lv.%d]\n[%s] %s | %s"):format(
                currentMinLvl,
                tostring(currentMinOwner):sub(1, 12),
                tostring(targetMap),
                tostring(targetDiff),
                targetReq,
                slotInfo,
                buffStateTxt,
                statusStr
            )
        end

        task.wait(0.25)
    end
end)

local status = { range = detectionRange(), canFire = false, target = nil, at = os.clock() }
getgenv().HLBoostStatus  = status
getgenv().HLBoostRange   = detectionRange
getgenv().HLBoostCanFire = detection

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

print(("[Boost DQ Reborn] Đã sửa lỗi Combo Buff->Damage (5.0s) | Min Lvl: %d (%s) -> %s [%s]")
    :format(currentMinLvl, tostring(currentMinOwner), tostring(targetMap), tostring(targetDiff)))
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
