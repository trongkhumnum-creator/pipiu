-- =====================================================================
-- Harvard Labs v3.0 — Boss 3 Toggle + Auto Gamepass Toggle + Party Sync
-- =====================================================================

local WRAPPER_SOURCE = [=====[
local ORIGINAL_URL = "https://raw.githubusercontent.com/trongkhumnum-creator/pipiu/refs/heads/main/leaked_harvard_3.0"

-- ============ Bảng Tùy Chỉnh (Custom Tuning) =========================
local CUSTOM = {
    BOOST               = 1.5,  -- Hệ số nhân tầm đánh / bán kính kỹ năng (mặc định 1.5)
    DETECT_ONLY         = true, -- Chỉ tung chiêu khi quái nằm trong tầm trúng
    DETECT_HOLD         = 0.2,  -- Thời gian giữ trạng thái sẵn sàng đánh sau khi quái lệch tầm (giây)
    CACHE_HZ            = 15,   -- Tần suất quét mục tiêu mỗi giây

    -- Các tính năng có công tắc Bật / Tắt trực tiếp trong Hub Harvard Labs:
    KILL_THIRD_BOSS     = true, -- Mặc định BẬT khi mở script: Bắt buộc giết xong Boss 3 (Boss cuối) & nhận Drop mới Replay
    AUTO_BUY_GAMEPASS   = true, -- Bật/Tắt tự động về Lobby chờ 5s mua Gamepass (VIP -> x2 Gold -> Extra Item)
    AUTO_REEXECUTE      = true, -- Bật/Tắt tự động chạy lại script khi chuyển giữa Sảnh <-> Dungeon
    AUTO_REHOP          = true, -- Bật/Tắt tự kết nối lại khi mất kết nối
    DRAW_HUD            = true, -- Bật/Tắt vòng tròn tầm đánh dưới chân

    -- Thông số thời gian chờ:
    LOOT_WAIT_TIME      = 5.5,  -- Số giây chờ nhận Drop sau khi Boss cuối chết
    ALT_READY_GRACE     = 3.0,  -- Số giây chờ sau khi tất cả Alt đã load xong ở Sảnh rồi mới bắt đầu Dungeon
    GAMEPASS_WAIT_TIME  = 5.0,  -- Đứng chờ 5s ở Lobby để mua xong Gamepass trước khi vào Dungeon tiếp

    -- Ghi đè nhanh cài đặt của script gốc (để nil nếu muốn giữ mặc định):
    WALK_SPEED          = nil,
    BURST_SPEED         = nil,
    STREAMER            = nil,
    AUTO_QUEUE          = true,
}
-- =====================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local AssetService      = game:GetService("AssetService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(); LocalPlayer = Players.LocalPlayer end

local STATE_FILE    = "HarvardLabs/wrapper_state.json"
local AUTOEXEC_PATH = "HarvardLabs/autoexec_boost_wrapper.lua"

-- Danh sách 3 Gamepass theo đúng thứ tự ưu tiên:
-- 1. VIP cosmetics and 20%+ exp -> 2. x2 Gold -> 3. Extra Item
local GAMEPASS_PRIORITY = {
    {
        id          = "VIP",
        label       = "VIP cosmetics and 20%+ exp",
        keywords    = { "vip cosmetics", "20%+ exp", "vip" },
        remoteNames = { "VIP", "Vip", "vip", "VIPCosmetics", "vipCosmetics" },
    },
    {
        id          = "X2GOLD",
        label       = "x2 Gold",
        keywords    = { "x2 gold", "2x gold", "double gold" },
        remoteNames = { "x2 Gold", "x2Gold", "2xGold", "doubleGold", "Gold2x" },
    },
    {
        id          = "EXTRAITEM",
        label       = "Extra Item",
        keywords    = { "extra item", "+1 item" },
        remoteNames = { "Extra Item", "ExtraItem", "extraItem", "BonusItem" },
    },
}

-- Bảng mốc Map, Độ khó và giá Gold cơ sở theo cấp mở Map của Dungeon Quest Reborn
local DUNGEON_TIERS = {
    { idx = 1,  map = "Desert Temple",     diff = "Easy",      req = 1,   mapUnlockReq = 1,   estPassCost = 25000          },
    { idx = 2,  map = "Desert Temple",     diff = "Medium",    req = 6,   mapUnlockReq = 1,   estPassCost = 25000          },
    { idx = 3,  map = "Desert Temple",     diff = "Hard",      req = 12,  mapUnlockReq = 1,   estPassCost = 25000          },
    { idx = 4,  map = "Desert Temple",     diff = "Insane",    req = 20,  mapUnlockReq = 1,   estPassCost = 25000          },
    { idx = 5,  map = "Desert Temple",     diff = "Nightmare", req = 27,  mapUnlockReq = 1,   estPassCost = 25000          },

    { idx = 6,  map = "Winter Outpost",    diff = "Easy",      req = 33,  mapUnlockReq = 33,  estPassCost = 150000         },
    { idx = 7,  map = "Winter Outpost",    diff = "Medium",    req = 40,  mapUnlockReq = 33,  estPassCost = 150000         },
    { idx = 8,  map = "Winter Outpost",    diff = "Hard",      req = 45,  mapUnlockReq = 33,  estPassCost = 150000         },
    { idx = 9,  map = "Winter Outpost",    diff = "Insane",    req = 50,  mapUnlockReq = 33,  estPassCost = 150000         },
    { idx = 10, map = "Winter Outpost",    diff = "Nightmare", req = 55,  mapUnlockReq = 33,  estPassCost = 150000         },

    { idx = 11, map = "Pirate Island",     diff = "Insane",    req = 60,  mapUnlockReq = 60,  estPassCost = 750000         },
    { idx = 12, map = "Pirate Island",     diff = "Nightmare", req = 65,  mapUnlockReq = 60,  estPassCost = 750000         },
    { idx = 13, map = "King's Castle",     diff = "Insane",    req = 70,  mapUnlockReq = 70,  estPassCost = 2500000        },
    { idx = 14, map = "King's Castle",     diff = "Nightmare", req = 75,  mapUnlockReq = 70,  estPassCost = 2500000        },
    { idx = 15, map = "The Underworld",    diff = "Insane",    req = 80,  mapUnlockReq = 80,  estPassCost = 7500000        },
    { idx = 16, map = "The Underworld",    diff = "Nightmare", req = 85,  mapUnlockReq = 80,  estPassCost = 7500000        },
    { idx = 17, map = "Samurai Palace",    diff = "Insane",    req = 90,  mapUnlockReq = 90,  estPassCost = 20000000       },
    { idx = 18, map = "Samurai Palace",    diff = "Nightmare", req = 95,  mapUnlockReq = 90,  estPassCost = 20000000       },
    { idx = 19, map = "The Canals",        diff = "Insane",    req = 100, mapUnlockReq = 100, estPassCost = 50000000       },
    { idx = 20, map = "The Canals",        diff = "Nightmare", req = 105, mapUnlockReq = 100, estPassCost = 50000000       },
    { idx = 21, map = "Ghastly Harbor",    diff = "Insane",    req = 110, mapUnlockReq = 110, estPassCost = 125000000      },
    { idx = 22, map = "Ghastly Harbor",    diff = "Nightmare", req = 115, mapUnlockReq = 110, estPassCost = 125000000      },
    { idx = 23, map = "Steampunk Sewers",  diff = "Insane",    req = 120, mapUnlockReq = 120, estPassCost = 300000000      },
    { idx = 24, map = "Steampunk Sewers",  diff = "Nightmare", req = 125, mapUnlockReq = 120, estPassCost = 300000000      },
    { idx = 25, map = "Orbital Outpost",   diff = "Insane",    req = 135, mapUnlockReq = 135, estPassCost = 750000000      },
    { idx = 26, map = "Orbital Outpost",   diff = "Nightmare", req = 140, mapUnlockReq = 135, estPassCost = 750000000      },
    { idx = 27, map = "Volcanic Chambers", diff = "Insane",    req = 150, mapUnlockReq = 150, estPassCost = 2000000000     },
    { idx = 28, map = "Volcanic Chambers", diff = "Nightmare", req = 155, mapUnlockReq = 150, estPassCost = 2000000000     },
    { idx = 29, map = "Aquatic Temple",    diff = "Insane",    req = 160, mapUnlockReq = 160, estPassCost = 5000000000     },
    { idx = 30, map = "Aquatic Temple",    diff = "Nightmare", req = 165, mapUnlockReq = 160, estPassCost = 5000000000     },
    { idx = 31, map = "Enchanted Forest",  diff = "Insane",    req = 170, mapUnlockReq = 170, estPassCost = 15000000000    },
    { idx = 32, map = "Enchanted Forest",  diff = "Nightmare", req = 175, mapUnlockReq = 170, estPassCost = 15000000000    },
    { idx = 33, map = "Northern Lands",    diff = "Insane",    req = 180, mapUnlockReq = 180, estPassCost = 40000000000    },
    { idx = 34, map = "Northern Lands",    diff = "Nightmare", req = 185, mapUnlockReq = 180, estPassCost = 40000000000    },
    { idx = 35, map = "Gilded Skies",      diff = "Insane",    req = 190, mapUnlockReq = 190, estPassCost = 100000000000   },
    { idx = 36, map = "Gilded Skies",      diff = "Nightmare", req = 195, mapUnlockReq = 190, estPassCost = 100000000000   },
}

local function getTierForLevel(lvl)
    local best = DUNGEON_TIERS[1]
    for _, t in ipairs(DUNGEON_TIERS) do
        if lvl >= t.req then best = t else break end
    end
    return best
end

local wrapperState = {
    killThirdBoss  = true, -- Luôn bật mặc định lúc mở script
    autoBuyPass    = CUSTOM.AUTO_BUY_GAMEPASS,
    reExecute      = CUSTOM.AUTO_REEXECUTE,
    autoRehop      = CUSTOM.AUTO_REHOP,
    drawHud        = CUSTOM.DRAW_HUD,
    lobbyPlaceId   = nil,
    enteredTierIdx = nil,
    leaveSignalAt  = 0,
    partyLevels    = {},
    ownedPasses    = {},
    detectedCosts  = {},
}

local function loadWrapperState(isInitialLoad)
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, STATE_FILE)
        if ok and exists then
            local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(STATE_FILE)) end)
            if ok2 and type(data) == "table" then
                if type(data.autoBuyPass) == "boolean"    then wrapperState.autoBuyPass = data.autoBuyPass; CUSTOM.AUTO_BUY_GAMEPASS = data.autoBuyPass end
                if type(data.reExecute) == "boolean"      then wrapperState.reExecute = data.reExecute; CUSTOM.AUTO_REEXECUTE = data.reExecute end
                if type(data.autoRehop) == "boolean"      then wrapperState.autoRehop = data.autoRehop; CUSTOM.AUTO_REHOP = data.autoRehop end
                if type(data.drawHud) == "boolean"        then wrapperState.drawHud = data.drawHud; CUSTOM.DRAW_HUD = data.drawHud end
                if type(data.lobbyPlaceId) == "number"    then wrapperState.lobbyPlaceId = data.lobbyPlaceId end
                if type(data.enteredTierIdx) == "number"  then wrapperState.enteredTierIdx = data.enteredTierIdx end
                if type(data.leaveSignalAt) == "number"   then wrapperState.leaveSignalAt = data.leaveSignalAt end
                if type(data.partyLevels) == "table"      then wrapperState.partyLevels = data.partyLevels end
                if type(data.ownedPasses) == "table"      then wrapperState.ownedPasses = data.ownedPasses end
                if type(data.detectedCosts) == "table"    then wrapperState.detectedCosts = data.detectedCosts end
                -- Nếu là lần đầu mở script trong phiên, giữ KILL_THIRD_BOSS = true (BẬT mặc định theo yêu cầu)
                if not isInitialLoad and type(data.killThirdBoss) == "boolean" then
                    wrapperState.killThirdBoss = data.killThirdBoss
                    CUSTOM.KILL_THIRD_BOSS     = data.killThirdBoss
                end
            end
        end
    end
end

local function saveWrapperState()
    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" and not isfolder("HarvardLabs") then
                pcall(makefolder, "HarvardLabs")
            end
            wrapperState.killThirdBoss = CUSTOM.KILL_THIRD_BOSS
            wrapperState.autoBuyPass   = CUSTOM.AUTO_BUY_GAMEPASS
            wrapperState.reExecute     = CUSTOM.AUTO_REEXECUTE
            wrapperState.autoRehop     = CUSTOM.AUTO_REHOP
            wrapperState.drawHud       = CUSTOM.DRAW_HUD
            writefile(STATE_FILE, HttpService:JSONEncode(wrapperState))
        end)
    end
end

-- Khi mới mở script lần đầu, đảm bảo KILL_THIRD_BOSS luôn là BẬT (true)
local isFirstSessionLoad = not getgenv().HL_BoostInitialized
getgenv().HL_BoostInitialized = true
loadWrapperState(isFirstSessionLoad)
if isFirstSessionLoad then
    CUSTOM.KILL_THIRD_BOSS     = true
    wrapperState.killThirdBoss = true
    saveWrapperState()
end

local function isInDungeon()
    if workspace:FindFirstChild("Lobby") ~= nil then return false end
    if workspace:FindFirstChild("dungeon") ~= nil then return true end
    local ef = workspace:FindFirstChild("enemies")
    if ef and #ef:GetChildren() > 0 then return true end
    if wrapperState.lobbyPlaceId and wrapperState.lobbyPlaceId > 0 then
        return game.PlaceId ~= wrapperState.lobbyPlaceId
    end
    return false
end

local function resolveLobbyPlaceId()
    if not isInDungeon() then
        if wrapperState.lobbyPlaceId ~= game.PlaceId then
            wrapperState.lobbyPlaceId = game.PlaceId
            saveWrapperState()
        end
        return wrapperState.lobbyPlaceId
    end
    if wrapperState.lobbyPlaceId and wrapperState.lobbyPlaceId > 0 and wrapperState.lobbyPlaceId ~= 2414851778 then
        return wrapperState.lobbyPlaceId
    end
    local ok, pages = pcall(function() return AssetService:GetGamePlacesAsync() end)
    if ok and pages then
        local okPage, list = pcall(function() return pages:GetCurrentPage() end)
        if okPage and type(list) == "table" then
            for _, p in ipairs(list) do
                local pid = tonumber(p.PlaceId)
                local pname = string.lower(tostring(p.Name or ""))
                if pid and pid ~= game.PlaceId and pid ~= 2414851778 then
                    wrapperState.lobbyPlaceId = pid
                    saveWrapperState()
                    return pid
                elseif pid and pname:find("lobby") then
                    wrapperState.lobbyPlaceId = pid
                    saveWrapperState()
                    return pid
                end
            end
        end
    end
    return wrapperState.lobbyPlaceId
end

task.spawn(resolveLobbyPlaceId)

-- =====================================================================
-- ĐỌC LEVEL THẬT & GOLD THẬT (BỎ QUA SỐ GIẢ 999 / 999,999 CỦA STREAMER)
-- =====================================================================
local preScanLevels = {}
local preScanGold   = {}

local function parseNumberWithSuffix(raw)
    if type(raw) == "number" then return raw end
    if type(raw) ~= "string" then return nil end
    local clean = raw:gsub(",", ""):gsub("%$", ""):gsub("Gold", ""):gsub("gold", ""):gsub(":", "")
    local numStr, suffix = clean:match("(%d+%.?%d*)%s*([kKmMbBtT]?)")
    if not numStr then return nil end
    local n = tonumber(numStr)
    if not n then return nil end
    local s = string.lower(suffix or "")
    if s == "k" then n = n * 1e3
    elseif s == "m" then n = n * 1e6
    elseif s == "b" then n = n * 1e9
    elseif s == "t" then n = n * 1e12 end
    return math.floor(n)
end

local function readRawLevel(plr)
    if not plr then return nil end
    local ls = plr:FindFirstChild("leaderstats")
    local candidates = {
        ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("level") or ls:FindFirstChild("Lvl")),
        plr:FindFirstChild("level"),
        plr:FindFirstChild("Level"),
    }
    for _, obj in ipairs(candidates) do
        if obj and obj:IsA("ValueBase") then
            local n = tonumber(tostring(obj.Value):gsub(",", ""):match("%d+"))
            if n and n > 0 and n ~= 999 and n < 500 then
                preScanLevels[plr.UserId] = n
                return n
            end
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

local function readRawGold(plr)
    plr = plr or LocalPlayer
    local ls = plr:FindFirstChild("leaderstats")
    local candidates = {
        plr:FindFirstChild("gold"),
        plr:FindFirstChild("Gold"),
        ls and (ls:FindFirstChild("Gold") or ls:FindFirstChild("gold")),
        plr:FindFirstChild("Data") and plr.Data:FindFirstChild("Gold"),
        plr:FindFirstChild("PlayerData") and plr.PlayerData:FindFirstChild("Gold"),
    }
    for _, obj in ipairs(candidates) do
        if obj and obj:IsA("ValueBase") then
            local rawStr = tostring(obj.Value):gsub(",", "")
            if rawStr ~= "999999" then
                local n = parseNumberWithSuffix(rawStr)
                if n and n >= 0 then
                    preScanGold[plr.UserId] = n
                    return n
                end
            end
        end
    end
    if plr == LocalPlayer then
        local pgui = plr:FindFirstChild("PlayerGui")
        if pgui then
            for _, desc in ipairs(pgui:GetDescendants()) do
                if desc:IsA("TextLabel") and string.lower(desc.Name):find("gold") then
                    local rawTxt = desc.Text:gsub(",", "")
                    if rawTxt ~= "999999" then
                        local n = parseNumberWithSuffix(rawTxt)
                        if n and n >= 0 then
                            preScanGold[plr.UserId] = n
                            return n
                        end
                    end
                end
            end
        end
    end
    return preScanGold[plr.UserId] or 0
end

for _, plr in ipairs(Players:GetPlayers()) do
    readRawLevel(plr)
end
readRawGold(LocalPlayer)

-- =====================================================================
-- QUÉT & MUA 3 GAMEPASS BẰNG GOLD (VIP -> x2 Gold -> Extra Item)
-- =====================================================================
local uidKey = tostring(LocalPlayer.UserId)
wrapperState.ownedPasses[uidKey] = type(wrapperState.ownedPasses[uidKey]) == "table" and wrapperState.ownedPasses[uidKey] or {}

local function checkCardIsOwnedInUI(cardFrame)
    if not cardFrame then return false end
    for _, desc in ipairs(cardFrame:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
            local t = string.upper(tostring(desc.Text or "")):gsub("^%s+", ""):gsub("%s+$", "")
            if t == "OWNED" or t:find("OWNED", 1, true) then
                return true
            end
        end
    end
    return false
end

local function extractGoldCostFromCardUI(cardFrame)
    if not cardFrame then return nil end
    local searchRoots = { cardFrame, cardFrame.Parent }
    for _, root in ipairs(searchRoots) do
        if root then
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    local txt = string.lower(tostring(desc.Text or ""))
                    if not txt:find("20%%") and not txt:find("x2") and not txt:find("%+1") and not txt:find("owned") then
                        if txt:find("gold") or txt:match("^%s*[%d,%.]+[kmbKMB]?%s*$") then
                            local val = parseNumberWithSuffix(txt)
                            if val and val >= 1000 then
                                return val
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function scanGamepassShopUI()
    local myLvl  = readRawLevel(LocalPlayer) or 1
    local myTier = getTierForLevel(myLvl)
    local unlockKey = tostring(myTier.mapUnlockReq or 1)
    local foundCards = {}

    for _, child in ipairs(LocalPlayer:GetDescendants()) do
        if child:IsA("BoolValue") and child.Value == true then
            local cn = string.lower(child.Name)
            if cn:find("vip") then wrapperState.ownedPasses[uidKey]["VIP"] = true end
            if cn:find("x2gold") or cn:find("2xgold") or cn:find("doublegold") then wrapperState.ownedPasses[uidKey]["X2GOLD"] = true end
            if cn:find("extraitem") or cn:find("bonusitem") then wrapperState.ownedPasses[uidKey]["EXTRAITEM"] = true end
        end
    end

    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local txtLower = string.lower(tostring(desc.Text or "")):gsub("%s+", " ")
                for _, passInfo in ipairs(GAMEPASS_PRIORITY) do
                    for _, kw in ipairs(passInfo.keywords) do
                        if txtLower:find(kw, 1, true) then
                            local card = desc.Parent
                            if card and card:IsA("GuiObject") then
                                foundCards[passInfo.id] = card
                                if checkCardIsOwnedInUI(card) or (card.Parent and checkCardIsOwnedInUI(card.Parent)) then
                                    wrapperState.ownedPasses[uidKey][passInfo.id] = true
                                end
                                local uiCost = extractGoldCostFromCardUI(card)
                                if uiCost and uiCost >= 1000 then
                                    wrapperState.detectedCosts[unlockKey .. "_" .. passInfo.id] = uiCost
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    return foundCards
end

local function getNextGamepassToBuy()
    scanGamepassShopUI()
    local myLvl  = readRawLevel(LocalPlayer) or 1
    local myTier = getTierForLevel(myLvl)
    local unlockKey = tostring(myTier.mapUnlockReq or 1)
    local ownedMap = wrapperState.ownedPasses[uidKey] or {}

    for _, passInfo in ipairs(GAMEPASS_PRIORITY) do
        if not ownedMap[passInfo.id] then
            local cost = wrapperState.detectedCosts[unlockKey .. "_" .. passInfo.id] or myTier.estPassCost
            return passInfo, cost
        end
    end
    return nil, 0
end

local function executeBuyGamepassInLobby(passInfo)
    if not passInfo then return false end
    local foundCards = scanGamepassShopUI()
    local card = foundCards[passInfo.id]

    if card then
        local targets = { card }
        for _, d in ipairs(card:GetDescendants()) do
            if d:IsA("GuiButton") then targets[#targets + 1] = d end
        end
        if card.Parent and card.Parent:IsA("GuiButton") then
            targets[#targets + 1] = card.Parent
        end
        for _, btn in ipairs(targets) do
            if btn:IsA("GuiButton") then
                pcall(function()
                    if type(firesignal) == "function" then
                        firesignal(btn.MouseButton1Click)
                        firesignal(btn.Activated)
                    end
                end)
            end
        end
    end

    pcall(function()
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            local n = string.lower(desc.Name)
            if n:find("gamepass") or n:find("buypass") or n:find("goldshop") or n:find("buyperk") or n:find("purchase") then
                for _, argName in ipairs(passInfo.remoteNames) do
                    if desc:IsA("RemoteEvent") then
                        pcall(function() desc:FireServer(argName) end)
                        pcall(function() desc:FireServer(passInfo.label) end)
                    elseif desc:IsA("RemoteFunction") then
                        task.spawn(function()
                            pcall(function() desc:InvokeServer(argName) end)
                            pcall(function() desc:InvokeServer(passInfo.label) end)
                        end)
                    end
                end
            end
        end
    end)

    task.wait(0.4)
    scanGamepassShopUI()
    return wrapperState.ownedPasses[uidKey][passInfo.id] == true
end

-- =====================================================================
-- ĐỒNG BỘ PARTY: KIỂM TRA TẤT CẢ ALT ĐÃ SẴN SÀNG Ở SẢNH CHƯA
-- =====================================================================
local context
local allAltsReadySince = nil

local function syncAndCheckPartyStatus()
    loadWrapperState(false)
    local now = os.time()
    wrapperState.partyLevels = type(wrapperState.partyLevels) == "table" and wrapperState.partyLevels or {}

    local myLvl  = readRawLevel(LocalPlayer) or 1
    local myGold = readRawGold(LocalPlayer) or 0
    local myChar = LocalPlayer.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myReady = (not isInDungeon()) and (myHrp ~= nil) and (myHum ~= nil and myHum.Health > 0)

    local myKey = string.lower(LocalPlayer.Name)
    local prevInfo = wrapperState.partyLevels[myKey] or {}

    wrapperState.partyLevels[myKey] = {
        name            = LocalPlayer.Name,
        lvl             = myLvl,
        gold            = myGold,
        inLobby         = not isInDungeon(),
        ready           = myReady,
        jobId           = tostring(game.JobId),
        buyingPassUntil = prevInfo.buyingPassUntil or 0,
        ts              = now,
    }

    if isInDungeon() then
        for _, plr in ipairs(Players:GetPlayers()) do
            local k = string.lower(plr.Name)
            local l = readRawLevel(plr)
            if l and l > 0 then
                local old = wrapperState.partyLevels[k] or {}
                wrapperState.partyLevels[k] = {
                    name            = plr.Name,
                    lvl             = l,
                    gold            = old.gold or 0,
                    inLobby         = false,
                    ready           = false,
                    jobId           = tostring(game.JobId),
                    buyingPassUntil = old.buyingPassUntil or 0,
                    ts              = now,
                }
            end
        end
    else
        local carryStr = (context and context.CFG and string.lower(tostring(context.CFG.carryName or ""))) or ""
        for part in carryStr:gmatch("[^,%s]+") do
            if #part > 1 and not wrapperState.partyLevels[part] then
                wrapperState.partyLevels[part] = { name = part, lvl = myLvl, inLobby = false, ready = false, ts = now }
            end
        end

        for k, info in pairs(wrapperState.partyLevels) do
            if type(info) == "table" and (now - (tonumber(info.ts) or 0) < 900) then
                local plrInServer = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if string.lower(p.Name) == k then
                        plrInServer = p
                        break
                    end
                end
                if plrInServer then
                    local l   = readRawLevel(plrInServer) or info.lvl or 1
                    local ch  = plrInServer.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    info.name    = plrInServer.Name
                    info.lvl     = l
                    info.inLobby = true
                    info.ready   = (hrp ~= nil) and (hum ~= nil and hum.Health > 0)
                    info.ts      = now
                else
                    info.inLobby = false
                    info.ready   = false
                end
            end
        end
    end

    saveWrapperState()

    local minLvl, minOwner = myLvl, LocalPlayer.Name
    local totalMembers     = 0
    local readyMembers     = 0
    local missingAltName   = nil
    local anyoneBuyingPass = false

    for k, info in pairs(wrapperState.partyLevels) do
        if type(info) == "table" and (now - (tonumber(info.ts) or 0) < 900) then
            totalMembers = totalMembers + 1
            if tonumber(info.lvl) and info.lvl < minLvl then
                minLvl   = info.lvl
                minOwner = info.name or k
            end
            if tonumber(info.buyingPassUntil) and now < info.buyingPassUntil then
                anyoneBuyingPass = true
            end
            if info.inLobby and info.ready then
                readyMembers = readyMembers + 1
            else
                missingAltName = info.name or k
            end
        end
    end

    local allAltsReady = (readyMembers >= totalMembers) and (not anyoneBuyingPass)
    if allAltsReady and not isInDungeon() then
        if not allAltsReadySince then allAltsReadySince = os.clock() end
    else
        allAltsReadySince = nil
    end

    local canStartDungeonNow = allAltsReady
        and (allAltsReadySince ~= nil)
        and ((os.clock() - allAltsReadySince) >= CUSTOM.ALT_READY_GRACE)

    return minLvl, minOwner, canStartDungeonNow, readyMembers, totalMembers, missingAltName, anyoneBuyingPass
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

-- 3. Áp dụng tùy chỉnh tầm đánh (Scale) & Khóa Replay sớm --------------
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

local allowDungeonReplayNow = false
local isBuyingGamepassWait  = false

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

    CFG.streamerLevel       = false
    CFG.streamerWealth      = false
    CFG.streamerOthers      = false
    CFG.streamerLeaderboard = false

    local minLvl, _, canStartNow = syncAndCheckPartyStatus()
    local tier = getTierForLevel(minLvl)
    CFG.autoQueueMap        = tier.map
    CFG.autoQueueDifficulty = tier.diff
    CFG.autoQueueMinLevel   = 0

    if not isInDungeon() then
        local readyToQueue = canStartNow and (not isBuyingGamepassWait)
        CFG.autoQueue        = readyToQueue
        CFG.autoStartDungeon = readyToQueue
        CFG.autoQueueReplay  = false
    else
        if not allowDungeonReplayNow then
            CFG.autoQueueReplay = false
        end
    end
end

if type(context.PERSIST) == "table" then
    for i = #context.PERSIST, 1, -1 do
        local key = context.PERSIST[i]
        if key == "streamerLevel" or key == "streamerWealth" or key == "streamerOthers" or key == "streamerLeaderboard" or key == "autoQueueReplay" then
            table.remove(context.PERSIST, i)
        else
            for _, k in ipairs(KEYS) do
                if key == k then table.remove(context.PERSIST, i); break end
            end
        end
    end
end

applyCustomSettings()
if type(context.saveConfig) == "function" then pcall(context.saveConfig) end

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

-- 4. Kiểm tra mục tiêu trong tầm đánh (Landing Detection) -------------
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

-- =====================================================================
-- 6. THEO DÕI CHÍNH XÁC BOSS 1, BOSS 2, BOSS 3 Ở MỌI MAP (TRÊN HEARTBEAT)
-- =====================================================================
local seenBossModels   = {}
local killedBossModels = {}
local thirdBossSeen    = false
local thirdBossKilled  = false

local function countTableEntries(tbl)
    local c = 0
    for _ in pairs(tbl) do c = c + 1 end
    return c
end

local function isThirdOrFinalBossName(nameStr)
    local s = string.lower(tostring(nameStr or ""))
    return s:find("thirdboss", 1, true)
        or s:find("finalboss", 1, true)
        or s:find("lastboss", 1, true)
        or s:find("odin", 1, true)
        or s:find("vytelus", 1, true)
end

-- Kiểm tra 1 phần tử GUI có THỰC SỰ hiển thị trên màn hình (Tất cả Frame cha phải Visible == true)
local function isActuallyVisibleOnScreen(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    if not guiObj.Visible then return false end
    if guiObj.AbsoluteSize.X < 8 or guiObj.AbsoluteSize.Y < 8 then return false end

    local curr = guiObj.Parent
    while curr do
        if curr:IsA("GuiObject") then
            if not curr.Visible then return false end
        elseif curr:IsA("ScreenGui") then
            return curr.Enabled == true
        elseif curr:IsA("PlayerGui") or curr == CoreGui then
            return true
        end
        curr = curr.Parent
    end
    return false
end

local function isRealEndScreenVisible()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return false end

    for _, gName in ipairs({ "retryGui", "EndingGui", "rewardGui", "endScreen", "VictoryGui" }) do
        local g = pgui:FindFirstChild(gName)
        if g and g:IsA("ScreenGui") and g.Enabled then
            for _, desc in ipairs(g:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("TextLabel")) and isActuallyVisibleOnScreen(desc) then
                    local t = string.lower(desc.Text or "")
                    if t == "replay" or t == "retry" or t == "play again" or t:find("victory", 1, true) or t:find("complete", 1, true) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function hasAnyClosedBarrierInDungeon()
    local dFolder = workspace:FindFirstChild("dungeon")
    if not dFolder then return false end
    for _, room in ipairs(dFolder:GetChildren()) do
        local barrier = room:FindFirstChild("barrier")
        if barrier then
            local parts = barrier:IsA("BasePart") and { barrier } or barrier:GetDescendants()
            for _, p in ipairs(parts) do
                if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.95 then
                    return true
                end
            end
        end
    end
    return false
end

-- Bắt từng frame trên Heartbeat để:
-- 1) Khóa chặt CFG.autoQueueReplay = false khi chưa xong mục tiêu Boss (tránh script gốc tự Replay sớm)
-- 2) Ghi nhận ngay lập tức mọi Boss vừa xuất hiện / vừa chết (kể cả khi Carry Lv.196 one-shot Boss trong 0.05s ở các map dưới Northern Lands!)
local hbConn
hbConn = RunService.Heartbeat:Connect(function()
    if RT.destroyed then
        if hbConn then hbConn:Disconnect() end
        return
    end

    if isInDungeon() then
        -- Khóa cứng autoQueueReplay trên từng frame cho tới khi wrapper xác nhận đã giết xong Boss mục tiêu & nhặt xong Drop!
        if not allowDungeonReplayNow then
            CFG.autoQueueReplay = false
        end

        local RD = context.RD
        if RD and type(RD.famLast) == "table" and RD.famLast["third"] then
            thirdBossSeen = true
        end

        if RD and type(RD.enemies) == "table" then
            for _, e in ipairs(RD.enemies) do
                local m = e.model or (e.root and e.root.Parent)
                if e.isBoss and m then
                    local bName = e.name or m.Name
                    seenBossModels[m] = bName
                    if isThirdOrFinalBossName(bName) then
                        thirdBossSeen = true
                    end
                    if e.humanoid and e.humanoid.Health <= 0 then
                        killedBossModels[m] = true
                        if isThirdOrFinalBossName(bName) then
                            thirdBossKilled = true
                        end
                    end
                end
            end
        end

        -- Kiểm tra trực tiếp trong workspace.enemies cho các map dưới Northern Lands
        local ef = workspace:FindFirstChild("enemies") or (workspace:FindFirstChild("dungeon") and workspace.dungeon:FindFirstChild("enemies", true))
        if ef then
            for _, m in ipairs(ef:GetChildren()) do
                if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
                    local isBossObj = m:FindFirstChild("isBoss") ~= nil
                        or m:GetAttribute("isBoss") == true
                        or isThirdOrFinalBossName(m.Name)
                        or string.lower(m.Name):find("boss", 1, true)
                    if isBossObj then
                        seenBossModels[m] = m.Name
                        if isThirdOrFinalBossName(m.Name) then
                            thirdBossSeen = true
                        end
                        local hum = m:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health <= 0 then
                            killedBossModels[m] = true
                            if isThirdOrFinalBossName(m.Name) then
                                thirdBossKilled = true
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function updateBossProgress()
    local RD = context.RD
    local anyBossAlive  = false
    local anyEnemyAlive = false

    if RD and type(RD.enemies) == "table" then
        for _, e in ipairs(RD.enemies) do
            if e.humanoid and e.humanoid.Health > 0 then
                anyEnemyAlive = true
                if e.isBoss then
                    anyBossAlive = true
                end
            end
        end
    end

    for m, bName in pairs(seenBossModels) do
        local hum = m and m.Parent and m:FindFirstChildOfClass("Humanoid")
        if not m or not m.Parent or (hum and hum.Health <= 0) then
            killedBossModels[m] = true
            if isThirdOrFinalBossName(bName) or countTableEntries(killedBossModels) >= 3 then
                thirdBossKilled = true
            end
        elseif hum and hum.Health > 0 then
            anyBossAlive  = true
            anyEnemyAlive = true
        end
    end

    -- Nếu RD.bossDown của script gốc ghi nhận thêm Boss đã hạ
    if RD and type(RD.bossDown) == "table" then
        for bKey, _ in pairs(RD.bossDown) do
            if isThirdOrFinalBossName(bKey) then
                thirdBossSeen   = true
                thirdBossKilled = true
            end
        end
    end

    local numSeen    = countTableEntries(seenBossModels)
    local numKilled  = countTableEntries(killedBossModels)
    local realEndGui = isRealEndScreenVisible()
    local hasBarrier = hasAnyClosedBarrierInDungeon()

    local targetBossRequirementMet = false

    if CUSTOM.KILL_THIRD_BOSS then
        -- Khi BẬT "Giết Boss 3 (Boss cuối)":
        -- Bắt buộc phải không còn Boss nào sống, toàn bộ cửa barrier trong Dungeon đã mở hết,
        -- VÀ (đã giết đủ 3 Boss HOẶC Boss thứ 3 đã chết HOẶC bảng kết thúc thật sự của game đã bật lên sau khi ít nhất 1 Boss chết)
        if not anyBossAlive and not anyEnemyAlive and not hasBarrier then
            if numKilled >= 3 or thirdBossKilled or (realEndGui and numKilled >= 1) then
                targetBossRequirementMet = true
            end
        end
    else
        -- Khi TẮT "Giết Boss 3":
        -- Chỉ cần hạ xong Boss 2 (numKilled >= 2) và hiện tại không còn Boss đang sống là cho phép Replay / Về Sảnh!
        if not anyBossAlive and (numKilled >= 2 or realEndGui) then
            targetBossRequirementMet = true
        end
    end

    return targetBossRequirementMet, numKilled, numSeen
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
local function teleportPartyToLobby(reason, newTier, forGamepassBuy)
    if isTeleportingToLobby then return end
    isTeleportingToLobby = true

    if newTier then
        CFG.autoQueueMap        = newTier.map
        CFG.autoQueueDifficulty = newTier.diff
        wrapperState.enteredTierIdx = newTier.idx
    end
    if forGamepassBuy then
        local myKey = string.lower(LocalPlayer.Name)
        wrapperState.partyLevels[myKey] = wrapperState.partyLevels[myKey] or {}
        wrapperState.partyLevels[myKey].buyingPassUntil = os.time() + 12
    end
    wrapperState.leaveSignalAt = os.time()
    saveWrapperState()
    if type(context.saveConfig) == "function" then pcall(context.saveConfig) end
    registerAutoReExecute()

    local lobbyId = resolveLobbyPlaceId()
    warn(("[Boost] Đang đưa Party về Sảnh (PlaceId: %s) | Lý do: %s"):format(tostring(lobbyId), tostring(reason)))

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
            if lobbyId then
                pcall(function()
                    TeleportService:Teleport(lobbyId, LocalPlayer)
                end)
            end
            task.wait(3.5)
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
    card.Size = UDim2.new(1, 0, 0, 248)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    card.BorderSizePixel = 0
    card.LayoutOrder = -9999
    card.Parent = targetScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", card); st.Color = Color3.fromRGB(40, 40, 46); st.Thickness = 1

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -28, 0, 26)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "Tùy Chỉnh Boss 3, Auto Gamepass & Party Sync"
    title.TextColor3 = Color3.fromRGB(235, 65, 45)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left

    local statusLbl = Instance.new("TextLabel", card)
    statusLbl.Size = UDim2.new(1, -28, 0, 36)
    statusLbl.Position = UDim2.new(0, 14, 0, 30)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 11
    statusLbl.TextWrapped = true
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Text = "Đang kiểm tra trạng thái Party, Tiến độ Boss 3 & Gamepass..."
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

    -- 1. Công tắc Bật/Tắt Giết Boss 3 (Mặc định BẬT khi mở script)
    makeToggleRow(70,  "Giết Boss 3 (Boss cuối) rồi mới Replay / Chuyển Map", "KILL_THIRD_BOSS", function(v)
        CFG.finishAtOdin = v
    end)
    -- 2. Công tắc Bật/Tắt Tự mua Gamepass bằng Gold
    makeToggleRow(104, "Tự mua Gamepass bằng Gold (VIP -> x2 Gold -> Extra Item)", "AUTO_BUY_GAMEPASS")
    -- 3. Công tắc Auto Re-Execute
    makeToggleRow(138, "Auto Re-Execute (Tự chạy lại khi qua màn)", "AUTO_REEXECUTE", function(v)
        if v then registerAutoReExecute() end
    end)
    -- 4. Công tắc Auto Re-Hop
    makeToggleRow(172, "Auto Re-Hop (Tự về Sảnh khi mất kết nối)", "AUTO_REHOP")
    -- 5. Công tắc Vòng tròn tầm đánh HUD
    makeToggleRow(206, "Hiển thị vòng tầm đánh dưới chân (HUD)", "DRAW_HUD", function()
        updateHudPartVisibility()
    end)
end

-- 9. Luồng điều phối: Đợi đủ Alt Sẵn Sàng, Mua Gamepass (Wait 5s) & Bảo vệ Drop Boss 3
local function formatGoldShort(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return ("%.2fT"):format(n / 1e12)
    elseif n >= 1e9 then return ("%.2fB"):format(n / 1e9)
    elseif n >= 1e6 then return ("%.2fM"):format(n / 1e6)
    elseif n >= 1e3 then return ("%.1fK"):format(n / 1e3) end
    return tostring(n)
end

task.spawn(function()
    local finalBossDeadAt     = nil
    local dungeonStartTierIdx = nil
    local lastQueueAttemptAt  = 0

    while not RT.destroyed do
        tryInjectNativeCard()

        local minLvl, minOwner, canStartDungeonNow, readyCount, totalCount, missingAlt, anyoneBuyingPass = syncAndCheckPartyStatus()
        local targetTier = getTierForLevel(minLvl)
        local myGold     = readRawGold(LocalPlayer) or 0
        local nextPass, nextPassCost = getNextGamepassToBuy()
        local canAffordNextPass = CUSTOM.AUTO_BUY_GAMEPASS and (nextPass ~= nil) and (nextPassCost > 0) and (myGold >= nextPassCost)

        if CFG.autoQueueMap ~= targetTier.map or CFG.autoQueueDifficulty ~= targetTier.diff then
            CFG.autoQueueMap        = targetTier.map
            CFG.autoQueueDifficulty = targetTier.diff
            CFG.autoQueueMinLevel   = 0
            if type(context.saveConfig) == "function" then pcall(context.saveConfig) end
            if type(context.refreshAll) == "function" then pcall(context.refreshAll) end
        end

        local passStatusStr
        if not CUSTOM.AUTO_BUY_GAMEPASS then
            passStatusStr = "Auto Gamepass: ĐANG TẮT"
        elseif nextPass then
            passStatusStr = ("GP tiếp: %s (%s/%s Gold)"):format(nextPass.id, formatGoldShort(myGold), formatGoldShort(nextPassCost))
        else
            passStatusStr = "Gamepass: ĐÃ MUA ĐỦ 3/3 (OWNED)"
        end

        if not isInDungeon() then
            -- ================= ĐANG Ở SẢNH (LOBBY) =================
            resolveLobbyPlaceId()
            table.clear(seenBossModels)
            table.clear(killedBossModels)
            thirdBossSeen               = false
            thirdBossKilled             = false
            finalBossDeadAt             = nil
            allowDungeonReplayNow       = false
            dungeonStartTierIdx         = targetTier.idx
            wrapperState.enteredTierIdx = targetTier.idx
            saveWrapperState()

            -- BƯỚC A: Nếu bật Auto Buy Gamepass và đủ Gold -> Khóa vào Dungeon & chờ 5s mua xong Gamepass
            if canAffordNextPass then
                isBuyingGamepassWait = true
                CFG.autoQueue        = false
                CFG.autoStartDungeon = false
                CFG.autoQueueReplay  = false

                local myKey = string.lower(LocalPlayer.Name)
                wrapperState.partyLevels[myKey] = wrapperState.partyLevels[myKey] or {}
                wrapperState.partyLevels[myKey].buyingPassUntil = os.time() + math.ceil(CUSTOM.GAMEPASS_WAIT_TIME) + 2
                saveWrapperState()

                local waitStart = os.clock()
                while os.clock() - waitStart < CUSTOM.GAMEPASS_WAIT_TIME do
                    local rem = CUSTOM.GAMEPASS_WAIT_TIME - (os.clock() - waitStart)
                    if hubStatusText then
                        hubStatusText.Text = ("SẢNH [WAIT %.1fs MUA GAMEPASS] -> Đang mua: %s (%s Gold)...")
                            :format(math.max(0, rem), nextPass.label, formatGoldShort(nextPassCost))
                    end
                    executeBuyGamepassInLobby(nextPass)
                    task.wait(0.8)
                end

                scanGamepassShopUI()
                wrapperState.partyLevels[myKey].buyingPassUntil = 0
                saveWrapperState()
                isBuyingGamepassWait = false
            end

            -- BƯỚC B: Đợi tất cả Alt sẵn sàng ở Sảnh rồi mới bắt đầu Dungeon
            if not canStartDungeonNow or isBuyingGamepassWait then
                CFG.autoQueue        = false
                CFG.autoStartDungeon = false
                CFG.autoQueueReplay  = false

                local waitReason = anyoneBuyingPass and "Đang đợi thành viên mua Gamepass (5s)..."
                    or ("Đang đợi Alt sẵn sàng (%d/%d - Chờ: %s)..."):format(readyCount, totalCount, tostring(missingAlt or "Alt"))

                if hubStatusText then
                    hubStatusText.Text = ("Sảnh | %s\nMin Lvl: %d (%s) -> %s [%s] | %s")
                        :format(waitReason, minLvl, tostring(minOwner), targetTier.map, targetTier.diff, passStatusStr)
                end
            else
                CFG.autoQueue        = true
                CFG.autoStartDungeon = true
                CFG.autoQueueReplay  = false

                if os.clock() - lastQueueAttemptAt > 6 then
                    lastQueueAttemptAt = os.clock()
                    pcall(function()
                        local remotes = ReplicatedStorage:FindFirstChild("remotes")
                        local createLobby = remotes and remotes:FindFirstChild("createLobby")
                        local startDungeon = remotes and remotes:FindFirstChild("startDungeon")
                        if createLobby and createLobby:IsA("RemoteFunction") then
                            task.spawn(function()
                                pcall(function()
                                    createLobby:InvokeServer(targetTier.map, targetTier.diff, 0, CFG.autoQueuePrivate ~= false, CFG.autoQueueHardcore == true, false)
                                end)
                            end)
                        elseif createLobby and createLobby:IsA("RemoteEvent") then
                            pcall(function()
                                createLobby:FireServer(targetTier.map, targetTier.diff, 0, CFG.autoQueuePrivate ~= false, CFG.autoQueueHardcore == true, false)
                            end)
                        end
                        if startDungeon and startDungeon:IsA("RemoteEvent") then
                            task.delay(2.5, function()
                                if not isInDungeon() and canStartDungeonNow then
                                    pcall(function() startDungeon:FireServer() end)
                                end
                            end)
                        end
                    end)
                end

                if hubStatusText then
                    hubStatusText.Text = ("Sảnh [Alt Ready %d/%d] | Min Lvl: %d -> Vào: %s [%s]\n%s")
                        :format(readyCount, totalCount, minLvl, targetTier.map, targetTier.diff, passStatusStr)
                end
            end
        else
            -- ================= ĐANG TRONG DUNGEON =================
            if not dungeonStartTierIdx then
                dungeonStartTierIdx = wrapperState.enteredTierIdx or targetTier.idx
                wrapperState.enteredTierIdx = dungeonStartTierIdx
                saveWrapperState()
            end

            if wrapperState.leaveSignalAt and (os.time() - wrapperState.leaveSignalAt <= 20) then
                if (targetTier.idx > dungeonStartTierIdx) or canAffordNextPass then
                    teleportPartyToLobby("Đồng bộ theo Party về Sảnh", targetTier, canAffordNextPass)
                    break
                end
            end

            local targetBossDone, numKilled, _ = updateBossProgress()
            local needUpgradeDiffOrMap = (targetTier.idx > dungeonStartTierIdx)
            local bossGoalCount = CUSTOM.KILL_THIRD_BOSS and 3 or 2
            local progressMsg = ("Boss đã hạ: %d/%d"):format(numKilled, bossGoalCount)

            if targetBossDone then
                if not finalBossDeadAt then
                    finalBossDeadAt = os.clock()
                    print(("[Boost] Đã hạ xong Boss mục tiêu (%d/%d)! Chờ %.1fs nhận Drop & Gold..."):format(numKilled, bossGoalCount, CUSTOM.LOOT_WAIT_TIME))
                end
                local waited = os.clock() - finalBossDeadAt

                if waited >= CUSTOM.LOOT_WAIT_TIME then
                    minLvl, minOwner       = syncAndCheckPartyStatus()
                    targetTier             = getTierForLevel(minLvl)
                    myGold                 = readRawGold(LocalPlayer) or 0
                    nextPass, nextPassCost = getNextGamepassToBuy()
                    canAffordNextPass      = CUSTOM.AUTO_BUY_GAMEPASS and (nextPass ~= nil) and (nextPassCost > 0) and (myGold >= nextPassCost)
                    needUpgradeDiffOrMap   = (targetTier.idx > dungeonStartTierIdx)

                    if canAffordNextPass then
                        allowDungeonReplayNow = false
                        CFG.autoQueueReplay   = false
                        teleportPartyToLobby(("Đủ %s Gold mua Gamepass [%s] -> Về Lobby chờ 5s mua!"):format(formatGoldShort(myGold), nextPass.label), targetTier, true)
                        break
                    elseif needUpgradeDiffOrMap then
                        allowDungeonReplayNow = false
                        CFG.autoQueueReplay   = false
                        teleportPartyToLobby(("Đủ Req Lv.%d -> Về Lobby chuyển sang %s [%s]"):format(targetTier.req, targetTier.map, targetTier.diff), targetTier, false)
                        break
                    else
                        allowDungeonReplayNow = true
                        CFG.autoQueueReplay   = true
                        progressMsg = ("Đã nhận Drop Boss %d -> Đang Replay!"):format(bossGoalCount)
                    end
                else
                    allowDungeonReplayNow = false
                    CFG.autoQueueReplay   = false
                    progressMsg = ("Boss %d đã chết! Chờ Drop (%.1fs)..."):format(bossGoalCount, CUSTOM.LOOT_WAIT_TIME - waited)
                end
            else
                finalBossDeadAt       = nil
                allowDungeonReplayNow = false
                CFG.autoQueueReplay   = false
                if canAffordNextPass then
                    progressMsg = ("Boss: %d/%d (Đủ Gold mua %s -> Xong Boss về Lobby)"):format(numKilled, bossGoalCount, nextPass.id)
                elseif needUpgradeDiffOrMap then
                    progressMsg = ("Boss: %d/%d (Đủ Lv.%d -> Xong Boss lên %s)"):format(numKilled, bossGoalCount, minLvl, targetTier.diff)
                end
            end

            if hubStatusText then
                hubStatusText.Text = ("Dungeon | Min Lvl: %d -> %s [%s] | %s\n%s")
                    :format(minLvl, targetTier.map, targetTier.diff, progressMsg, passStatusStr)
            end
        end

        task.wait(0.4)
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

print(("[Boost] Đã tải | x%.2f | Kill Boss 3: %s | Auto Gamepass: %s")
    :format(CUSTOM.BOOST, CUSTOM.KILL_THIRD_BOSS and "ON" or "OFF", CUSTOM.AUTO_BUY_GAMEPASS and "ON" or "OFF"))
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
