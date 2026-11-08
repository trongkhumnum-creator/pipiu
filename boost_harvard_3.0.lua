-- =====================================================================
-- Harvard Labs v3.0 — Custom Boost + Landing Detection Wrapper
-- =====================================================================

local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST        = 1.5,    -- Hệ số nhân tầm đánh / bán kính kỹ năng (mặc định 1.5)
    DETECT_ONLY  = true,   -- Chỉ tung chiêu khi quái nằm trong tầm trúng
    DETECT_HOLD  = 0.2,    -- Thời gian giữ trạng thái sẵn sàng đánh sau khi quái lệch tầm (giây)
    CACHE_HZ     = 15,     -- Tần suất quét mục tiêu mỗi giây
    DRAW_HUD     = true,   -- Hiển thị vòng tròn tầm đánh dưới chân (đã fix lỗi NOVIS)
    
    -- Ghi đè nhanh cài đặt của script gốc (để nil nếu muốn giữ mặc định):
     WALK_SPEED  = nil,    -- VD: 20 (tốc độ đi bộ cơ bản)
     BURST_SPEED = nil,    -- VD: 28 (tốc độ chạy nhanh / né chiêu)
     STREAMER    = nil,    -- true / false (ẩn tên và thông tin nhân vật)
     AUTO_QUEUE  = nil,    -- true / false (tự động tìm trận)
}
-- =====================================================================

-- 1. Tải và khởi chạy script gốc (chỉ tải 1 lần duy nhất) -------------
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

-- 3. Áp dụng tùy chỉnh tầm đánh (Scale) & Cài đặt nhanh ---------------
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
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        for _, k in ipairs(KEYS) do
            if context.PERSIST[i] == k then table.remove(context.PERSIST, i) break end
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

-- 4. Kiểm tra mục tiêu trong tầm đánh (Landing Detection) -------------
local cacheAt, cacheOK, cacheTgt = 0, false, nil
local lastHitAt, lastTgt = 0, nil

local function detectNow()
    if type(context.engageReady) ~= "function" or type(context.canHit) ~= "function" then
        return true, nil
    end
    local me  = game:GetService("Players").LocalPlayer
    local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
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

-- 5. Chặn tung chiêu khi chưa tới tầm (Bỏ qua chiêu Buff) -------------
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

-- 6. Hiển thị vòng HUD (Đã bỏ giới hạn context.NOVIS) -----------------
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
            local char = game:GetService("Players").LocalPlayer.Character
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