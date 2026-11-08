-- =====================================================================
-- Harvard Labs v3.0 — Boost + Auto Map (Min Lvl) + Re-Exec / Re-Hop Hub
-- =====================================================================

local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"
-- Nếu bạn up file này lên GitHub/Pastebin, điền link raw vào WRAPPER_URL.
-- Nếu để nil, script sẽ tự lưu chính nó vào "HarvardLabs/autoexec_wrapper.lua" để Re-Execute!
local WRAPPER_URL  = nil 

-- ============ Bảng Tùy Chỉnh Mặc Định ================================
local CUSTOM = {
    BOOST               = 1.5,   -- Hệ số nhân tầm đánh / bán kính kỹ năng
    DETECT_ONLY         = true,  -- Chỉ tung chiêu khi quái nằm trong tầm trúng
    DETECT_HOLD         = 0.2,   -- Thời gian giữ trạng thái đánh sau khi quái lệch tầm
    CACHE_HZ            = 15,    -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD            = true,  -- Hiển thị vòng tròn tầm đánh dưới chân

    -- Tính năng Auto Map & Re-Execute / Re-Hop (Có thể Bật/Tắt ngay trên Hub)
    AUTO_MAP_BY_MIN_LVL = true,  -- Tự chọn Map + Độ khó theo acc có Level thấp nhất
    ONLY_MY_ACCOUNT     = false, -- true = chỉ tính Level acc này; false = tính acc thấp nhất trong Server/Whitelist
    WHITELIST_ACCS      = {},    -- VD: {"AccChinh", "AccPhu1"} (Để trống {} sẽ quét tất cả người trong sảnh)
    ALLOW_GILDED_SKIES  = false, -- Đặt true nếu muốn tự lên Gilded Skies ở Lv.190+, false để dừng ở Northern Lands
    FORCE_HARDCORE      = false, -- Tự bật Hardcore
    FORCE_PRIVATE       = true,  -- Tự tạo phòng Private

    AUTO_REEXECUTE      = true,  -- Tự động chạy lại script khi qua màn (Lobby <-> Dungeon)
    AUTO_REHOP          = true,  -- Tự động kết nối lại khi văng game / kẹt sảnh
    LOBBY_STUCK_TIMEOUT = 120,   -- Quá X giây ở sảnh không vào trận sẽ tự Re-hop

    -- Ghi đè nhanh cài đặt của script gốc:
    WALK_SPEED          = nil,
    BURST_SPEED         = nil,
    STREAMER            = nil,
    AUTO_QUEUE          = true,
}
-- =====================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

-- Lưu/Đọc cài đặt riêng của Hub mở rộng để không bị mất sau khi Teleport
local HUB_CFG_FILE = "HarvardLabs/boost_hub_config.json"
local AUTOEXEC_FILE = "HarvardLabs/autoexec_wrapper.lua"

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
            local data = {
                BOOST               = CUSTOM.BOOST,
                DETECT_ONLY         = CUSTOM.DETECT_ONLY,
                DRAW_HUD            = CUSTOM.DRAW_HUD,
                AUTO_MAP_BY_MIN_LVL = CUSTOM.AUTO_MAP_BY_MIN_LVL,
                ONLY_MY_ACCOUNT     = CUSTOM.ONLY_MY_ACCOUNT,
                ALLOW_GILDED_SKIES  = CUSTOM.ALLOW_GILDED_SKIES,
                FORCE_HARDCORE      = CUSTOM.FORCE_HARDCORE,
                FORCE_PRIVATE       = CUSTOM.FORCE_PRIVATE,
                AUTO_REEXECUTE      = CUSTOM.AUTO_REEXECUTE,
                AUTO_REHOP          = CUSTOM.AUTO_REHOP,
                LOBBY_STUCK_TIMEOUT = CUSTOM.LOBBY_STUCK_TIMEOUT,
            }
            writefile(HUB_CFG_FILE, HttpService:JSONEncode(data))
        end)
    end
end

loadHubConfig()

-- Danh sách bảng yêu cầu Level chuẩn của Dungeon Quest
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

-- 3. Đọc Level thật (Bỏ qua giả mạo "999" của Streamer Mode) ----------
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
    local fakeStr = tostring(CFG.streamerLevelText or "999"):gsub(",", "")
    local fakeNum = tonumber(fakeStr) or 999

    -- Cách 1: Đọc từ ValueObject trong leaderstats hoặc trực tiếp trong Player
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

    -- Cách 2: Đọc từ BillboardGui trên đầu nhân vật trong Workspace (nếu chưa bị Streamer ghi đè)
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

    -- Cách 3: Nếu là LocalPlayer và đang bật StreamerLevel, tạm tắt 1 frame để lấy số gốc hoặc đọc từ PlayerGui
    if plr == LocalPlayer then
        local gui = plr:FindFirstChild("PlayerGui")
        if gui then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("TextLabel") and (desc.Name:lower():find("level") or desc.Text:lower():find("level")) then
                    local txt = desc.Text:gsub(",", "")
                    local n = tonumber(txt:match("(%d+)"))
                    if n and n > 0 and n ~= fakeNum and n < 500 then
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
    -- Nếu leaderstats bị Streamer Mode khóa thành 999, tạm tắt streamerLevel trong tích tắc để đọc giá trị gốc
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
        if myLvl and myLvl > 0 then
            minLvl = myLvl
        end
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

    if wasStreamerLvl then
        CFG.streamerLevel = true
    end

    if minLvl == math.huge then
        minLvl = realLevelCache[LocalPlayer.UserId] or 1
    end
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

local currentMinLvl, currentMinOwner, currentMap, currentDiff, currentReq = 1, LocalPlayer.Name, CFG.autoQueueMap, CFG.autoQueueDifficulty, 1

local function syncMapToHarvard()
    if not CUSTOM.AUTO_MAP_BY_MIN_LVL then return end
    local minLvl, ownerName = getLowestAccountLevel()
    local bestMap, bestDiff, reqLvl = selectBestDungeonForLevel(minLvl)

    currentMinLvl, currentMinOwner, currentMap, currentDiff, currentReq = minLvl, ownerName, bestMap, bestDiff, reqLvl

    CFG.autoQueue           = true
    CFG.autoQueueMap        = bestMap
    CFG.autoQueueDifficulty = bestDiff
    CFG.autoQueueMinLevel   = 0
    if CUSTOM.FORCE_HARDCORE ~= nil then CFG.autoQueueHardcore = CUSTOM.FORCE_HARDCORE end
    if CUSTOM.FORCE_PRIVATE  ~= nil then CFG.autoQueuePrivate  = CUSTOM.FORCE_PRIVATE  end
end

-- 4. Áp dụng tùy chỉnh tầm đánh (Scale) & Khóa cấu hình ---------------
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

local function applyCustomSettings()
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

    syncMapToHarvard()
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        local key = context.PERSIST[i]
        for _, k in ipairs(KEYS) do
            if key == k then table.remove(context.PERSIST, i); break end
        end
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
if type(context.saveConfig) == "function" then
    local orig = context.saveConfig
    context.saveConfig = function(...)
        syncMapToHarvard()
        return orig(...)
    end
end

-- 5. Cơ chế Auto Re-Execute & Auto Re-Hop Chuẩn -----------------------
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
    if type(qFn) ~= "function" then
        warn("[Boost] Executor của bạn không hỗ trợ hàm queue_on_teleport!")
        return false
    end

    -- Xây dựng đoạn mã tự chạy lại sau khi chuyển Server/Dungeon
    local payload
    if type(WRAPPER_URL) == "string" and #WRAPPER_URL > 10 then
        payload = ('repeat task.wait() until game:IsLoaded(); loadstring(game:HttpGet("%s"))()'):format(WRAPPER_URL)
    elseif type(isfile) == "function" and pcall(isfile, "boost_harvard_3.0.lua") and isfile("boost_harvard_3.0.lua") then
        payload = 'repeat task.wait() until game:IsLoaded(); loadstring(readfile("boost_harvard_3.0.lua"))()'
    elseif type(isfile) == "function" and pcall(isfile, AUTOEXEC_FILE) and isfile(AUTOEXEC_FILE) then
        payload = ('repeat task.wait() until game:IsLoaded(); loadstring(readfile("%s"))()'):format(AUTOEXEC_FILE)
    else
        -- Nếu người dùng chạy thẳng từ Clipboard, tạo một loader mini tự động tiêm lại cả cấu hình AutoMap + Re-Exec
        local fallbackLoader = ([[
            repeat task.wait() until game:IsLoaded()
            local src = game:HttpGet(%q)
            local fn = loadstring(src)
            if fn then fn() end
        ]]):format(ORIGINAL_URL)
        payload = fallbackLoader
    end

    local ok = pcall(qFn, payload)
    if ok then
        isTeleportQueued = true
        print("[Boost] Đã kích hoạt hàng đợi Auto Re-Execute thành công!")
    end
    return ok
end

-- Tự lưu bản sao của file nếu người dùng có sẵn file trong workspace, và ĐĂNG KÝ NGAY LẬP TỨC khi chạy script!
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
                TeleportService:Teleport(2414851778, LocalPlayer)
            end)
            task.wait(4)
        end
    end)
end

-- Theo dõi mất kết nối & kẹt Lobby
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
            for _, child in ipairs(overlay:GetChildren()) do
                if child.Name == "ErrorPrompt" and CUSTOM.AUTO_REHOP then
                    triggerRehop("Mất kết nối / Kick (ErrorPrompt)")
                end
            end
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

-- 8. Giao diện Mini-Hub Mở Rộng (Tích hợp trực tiếp trên màn hình) ----
local guiParent = (type(gethui) == "function" and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    local old = guiParent:FindFirstChild("HLBoostMiniHub")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HLBoostMiniHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 270, 0, 265)
mainFrame.Position = UDim2.new(0, 18, 0.5, -130)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 16, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

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
titleLabel.Text = "Harvard v3.0 — Boost & AutoMap"
titleLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
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
infoLabel.Size = UDim2.new(1, 0, 0, 38)
infoLabel.Position = UDim2.new(0, 0, 0, 0)
infoLabel.BackgroundColor3 = Color3.fromRGB(30, 24, 28)
infoLabel.TextColor3 = Color3.fromRGB(120, 240, 160)
infoLabel.Font = Enum.Font.GothamSemibold
infoLabel.TextSize = 11
infoLabel.TextWrapped = true
infoLabel.Text = "Đang quét Level & Map..."
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

createToggle(44,  "Tự chọn Map theo Min Lvl", "AUTO_MAP_BY_MIN_LVL", function(v)
    if v then syncMapToHarvard() end
end)

createToggle(76,  "Chế độ quét (Bật = Chỉ mình / Tắt = Cả sảnh)", "ONLY_MY_ACCOUNT", function()
    syncMapToHarvard()
end)

createToggle(108, "Auto Re-Execute (Qua màn)", "AUTO_REEXECUTE", function(v)
    if v then registerAutoReExecute() end
end)

createToggle(140, "Auto Re-Hop (Chống kẹt/Disconnect)", "AUTO_REHOP")

createToggle(172, "Chỉ đánh khi quái vào tầm (Detect)", "DETECT_ONLY")

local rehopNowBtn = Instance.new("TextButton", contentFrame)
rehopNowBtn.Size = UDim2.new(1, 0, 0, 24)
rehopNowBtn.Position = UDim2.new(0, 0, 0, 204)
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

-- Kéo thả bảng Hub & Thu gọn
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
    mainFrame.Size = minimized and UDim2.new(0, 270, 0, 30) or UDim2.new(0, 270, 0, 265)
    minBtn.Text = minimized and "+" or "—"
end)

-- 9. Hiển thị vòng HUD & Luồng cập nhật liên tục ----------------------
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

-- Luồng ép Map liên tục mỗi 1 giây để không bị UI gốc ghi đè
task.spawn(function()
    local lobbyStart = os.clock()
    local lastMapSig = ""
    while not RT.destroyed do
        if CUSTOM.AUTO_MAP_BY_MIN_LVL then
            syncMapToHarvard()
            local sig = ("%s|%s|%d"):format(tostring(currentMap), tostring(currentDiff), currentMinLvl)
            if sig ~= lastMapSig then
                lastMapSig = sig
                if type(context.refreshAll) == "function" then pcall(context.refreshAll) end
            end
        end

        infoLabel.Text = ("Min Lvl: %d (%s)\nMap: %s [%s - Req %d]"):format(
            currentMinLvl,
             tostring(currentMinOwner):sub(1, 12),
            tostring(CFG.autoQueueMap),
            tostring(CFG.autoQueueDifficulty),
            currentReq
        )

        -- Kiểm tra kẹt ở Lobby
        local inDungeon = workspace:FindFirstChild("dungeon") ~= nil
        if not inDungeon and CFG.autoQueue and CUSTOM.AUTO_REHOP and CUSTOM.LOBBY_STUCK_TIMEOUT then
            if os.clock() - lobbyStart > CUSTOM.LOBBY_STUCK_TIMEOUT then
                triggerRehop("Kẹt ở sảnh quá " .. tostring(CUSTOM.LOBBY_STUCK_TIMEOUT) .. "s")
                break
            end
        else
            lobbyStart = os.clock()
        end

        task.wait(1)
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

print(("[Boost] Đã tải thành công | MinLvl: %d -> Map: %s (%s)"):format(currentMinLvl, tostring(currentMap), tostring(currentDiff)))
