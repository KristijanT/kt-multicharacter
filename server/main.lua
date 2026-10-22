local fw = KT.fw
local ESX, QBCore
if fw == 'esx' then ESX = exports['es_extended']:getSharedObject()
elseif fw == 'qb' then QBCore = exports['qb-core']:GetCoreObject() end

local BUCKET = 1000
local owned, pending, lastCall, slotCache = {}, {}, {}, {}

local function decode(v)
    if type(v) == 'table' then return v end
    local ok, r = pcall(json.decode, v or '{}')
    return (ok and type(r) == 'table') and r or {}
end

---------------------------------------------------------------- Bridge
local B = {}

function B.isLoggedIn(src)
    if fw == 'esx' then return ESX.GetPlayerFromId(src) ~= nil end
    if fw == 'qb' then return QBCore.Functions.GetPlayer(src) ~= nil end
    return exports.qbx_core:GetPlayer(src) ~= nil
end

function B.list(src)
    local out = {}
    if fw == 'esx' then
        local ident = ESX.GetIdentifier and ESX.GetIdentifier(src)
            or (GetPlayerIdentifierByType(src, 'license') or ''):gsub('license:', '')
        local rows = MySQL.query.await(
            'SELECT identifier, firstname, lastname, dateofbirth, sex, job, accounts, position, skin FROM users WHERE identifier LIKE ? LIMIT ?',
            { 'char%:' .. ident, Config.MaxSlots })
        for _, r in ipairs(rows or {}) do
            local slot = tonumber(r.identifier:match('^char(%d+):'))
            if slot then
                local acc, pos = decode(r.accounts), decode(r.position)
                out[#out + 1] = {
                    id = r.identifier, slot = slot, firstname = r.firstname, lastname = r.lastname,
                    dob = r.dateofbirth, gender = r.sex == 'f' and 'f' or 'm', job = r.job,
                    cash = acc.money or 0, bank = acc.bank or 0,
                    pos = pos.x and { x = pos.x, y = pos.y, z = pos.z, w = pos.heading or 0.0 } or nil,
                    skin = r.skin,
                }
            end
        end
    else
        local license = GetPlayerIdentifierByType(src, 'license')
        local rows = MySQL.query.await([[
            SELECT p.citizenid, p.cid, p.charinfo, p.money, p.job, p.position, s.skin
            FROM players p
            LEFT JOIN playerskins s ON s.citizenid = p.citizenid AND s.active = 1
            WHERE p.license = ? LIMIT ?]], { license, Config.MaxSlots })
        for i, r in ipairs(rows or {}) do
            local ci, money, job, pos = decode(r.charinfo), decode(r.money), decode(r.job), decode(r.position)
            out[#out + 1] = {
                id = r.citizenid, slot = tonumber(r.cid) or i,
                firstname = ci.firstname, lastname = ci.lastname, dob = ci.birthdate,
                gender = tonumber(ci.gender) == 1 and 'f' or 'm', job = job.label or job.name,
                cash = money.cash or 0, bank = money.bank or 0,
                pos = pos.x and { x = pos.x, y = pos.y, z = pos.z, w = pos.w or 0.0 } or nil,
                skin = r.skin,
            }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

function B.login(src, ch)
    if fw == 'esx' then
        TriggerEvent('esx:onPlayerJoined', src, 'char' .. ch.slot)
    elseif fw == 'qb' then
        if QBCore.Player.Login(src, ch.id) and Config.QBFireLoadedEvents then
            QBCore.Commands.Refresh(src)
            TriggerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
        end
    else
        exports.qbx_core:Login(src, ch.id)
    end
end

function B.create(src, slot, d)
    if fw == 'esx' then
        local y, m, day = d.dob:match('(%d+)-(%d+)-(%d+)')
        TriggerEvent('esx:onPlayerJoined', src, 'char' .. slot, {
            firstname = d.firstname, lastname = d.lastname,
            dateofbirth = ('%s/%s/%s'):format(day, m, y), sex = d.gender, height = d.height,
        })
    else
        local newData = { cid = slot, charinfo = {
            firstname = d.firstname, lastname = d.lastname, birthdate = d.dob,
            nationality = d.nationality, gender = d.gender == 'f' and 1 or 0,
        } }
        if fw == 'qb' then
            if QBCore.Player.Login(src, false, newData) and Config.QBFireLoadedEvents then
                QBCore.Commands.Refresh(src)
                TriggerEvent('QBCore:Server:OnPlayerLoaded')
                TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
            end
        else
            exports.qbx_core:Login(src, nil, newData)
        end
    end
end

function B.delete(src, ch)
    if fw == 'esx' then
        for _, t in ipairs(Config.ESXDeleteTables) do
            pcall(function() MySQL.query.await(('DELETE FROM `%s` WHERE `%s` = ?'):format(t[1], t[2]), { ch.id }) end)
        end
        MySQL.query.await('DELETE FROM users WHERE identifier = ?', { ch.id })
    elseif fw == 'qb' then QBCore.Player.DeleteCharacter(src, ch.id)
    else exports.qbx_core:DeleteCharacter(ch.id) end
end

function B.giveItem(src, name, count)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, name, count)
    elseif fw == 'esx' then
        local x = ESX.GetPlayerFromId(src); if x then x.addInventoryItem(name, count) end
    else
        local p = fw == 'qb' and QBCore.Functions.GetPlayer(src) or exports.qbx_core:GetPlayer(src)
        if p then p.Functions.AddItem(name, count) end
    end
end

---------------------------------------------------------------- Slots / Discord
local function discordSlots(src)
    local cfg = Config.Discord
    if not cfg.enabled then return 0 end
    local did = GetPlayerIdentifierByType(src, 'discord'); if not did then return 0 end
    did = did:gsub('discord:', '')
    local c = slotCache[did]
    if c and c.exp > os.time() then return c.slots end

    local p = promise.new()
    PerformHttpRequest(('https://discord.com/api/v10/guilds/%s/members/%s'):format(cfg.guildId, did),
        function(code, body)
            if code ~= 200 or not body then return p:resolve(nil) end
            local data, best = decode(body), 0
            for _, r in ipairs(data.roles or {}) do
                local v = cfg.roles[r]; if v and v > best then best = v end
            end
            p:resolve(best)
        end, 'GET', '', { Authorization = 'Bot ' .. cfg.token })
    local best = Citizen.Await(p)
    if best then slotCache[did] = { slots = best, exp = os.time() + cfg.cacheMinutes * 60 } end
    return best or (c and c.slots) or 0
end

local function getSlots(src)
    local n = Config.DefaultSlots
    local o = Config.SlotOverrides[GetPlayerIdentifierByType(src, 'license')]
    if o then n = math.max(n, o) end
    return math.min(math.max(n, discordSlots(src)), Config.MaxSlots)
end

local function canDelete(src)
    return Config.AllowDelete or IsPlayerAceAllowed(src, Config.AdminDeleteAce)
end

local function throttle(src)
    local now = GetGameTimer()
    if lastCall[src] and now - lastCall[src] < 800 then return true end
    lastCall[src] = now
    return false
end

local function refresh(src)
    local list, map = B.list(src), {}
    for _, c in ipairs(list) do map[c.id] = c end
    owned[src] = map
    return list
end

---------------------------------------------------------------- Validation
local function cleanName(s)
    if type(s) ~= 'string' then return end
    s = s:match('^%s*(.-)%s*$')
    if #s < 2 or #s > 16 then return end
    if s:gsub("[%-' ]", ''):find('[%d%c%p]') then return end
    return s
end

local function validate(d)
    if type(d) ~= 'table' then return nil, 'err_gen' end
    local fn, ln = cleanName(d.firstname), cleanName(d.lastname)
    if not fn or not ln then return nil, 'err_name' end
    local y, m, day = tostring(d.dob):match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
    y, m, day = tonumber(y), tonumber(m), tonumber(day)
    if not y or y < Config.Birth.minYear or y > Config.Birth.maxYear or m < 1 or m > 12 or day < 1 or day > 31 then
        return nil, 'err_dob'
    end
    local g = d.gender == 'f' and 'f' or 'm'
    local h = math.floor(tonumber(d.height) or 175)
    if h < 120 or h > 220 then h = 175 end
    local nat = type(d.nationality) == 'string' and d.nationality:sub(1, 30) or 'Other'
    return { firstname = fn, lastname = ln, dob = d.dob, gender = g, height = h, nationality = nat }
end

local function validateItems(items)
    local cfg = Config.StartingItems
    if not cfg.enabled or type(items) ~= 'table' then return {} end
    local map = {}
    for _, it in ipairs(cfg.items) do map[it.name] = it end
    local out, total = {}, 0
    for name, qty in pairs(items) do
        local def, q = map[name], math.floor(tonumber(qty) or 0)
        if def and q > 0 then
            if q > def.max then return nil end
            total = total + def.price * q
            out[#out + 1] = { name = name, count = q }
        end
    end
    if total > cfg.budget then return nil end
    return out
end

---------------------------------------------------------------- Callbacks
lib.callback.register('kt-mc:ready', function(src)
    if B.isLoggedIn(src) then return false end
    SetPlayerRoutingBucket(src, BUCKET + src)
    return true
end)

lib.callback.register('kt-mc:data', function(src)
    return { chars = refresh(src), slots = getSlots(src), canDelete = canDelete(src) }
end)

lib.callback.register('kt-mc:play', function(src, id)
    if throttle(src) then return false end
    local ch = owned[src] and owned[src][id]
    if not ch then return false end
    B.login(src, ch)
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('kt-mc:client:finish', src, false)
    return true
end)

lib.callback.register('kt-mc:create', function(src, data, items)
    if throttle(src) then return false, 'err_busy' end
    local clean, err = validate(data)
    if not clean then return false, err end
    local give = validateItems(items)
    if not give then return false, 'err_items' end

    local list, slots, used = refresh(src), getSlots(src), {}
    for _, c in ipairs(list) do used[c.slot] = true end
    local free
    for i = 1, slots do if not used[i] then free = i break end end
    if not free then return false, 'err_slot' end

    pending[src] = #give > 0 and give or nil
    B.create(src, free, clean)
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('kt-mc:client:finish', src, true)
    return true
end)

lib.callback.register('kt-mc:delete', function(src, id)
    if throttle(src) or not canDelete(src) then return false end
    local ch = owned[src] and owned[src][id]
    if not ch then return false end
    B.delete(src, ch)
    return true
end)

---------------------------------------------------------------- Starting items
local function onLoaded(src)
    local items = pending[src]; if not items then return end
    pending[src] = nil
    SetTimeout(2500, function()
        for _, it in ipairs(items) do B.giveItem(src, it.name, it.count) end
    end)
end

if fw == 'esx' then
    AddEventHandler('esx:playerLoaded', function(src) onLoaded(src) end)
else
    AddEventHandler('QBCore:Server:PlayerLoaded', function(player) onLoaded(player.PlayerData.source) end)
end

AddEventHandler('playerDropped', function()
    local src = source
    owned[src], pending[src], lastCall[src] = nil, nil, nil
end)