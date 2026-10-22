KT = {}

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qbx_core') ~= 'missing' then return 'qbox' end
    if GetResourceState('qb-core') ~= 'missing' then return 'qb' end
    if GetResourceState('es_extended') ~= 'missing' then return 'esx' end
    error('[kt-multicharacter] No supported framework found (ESX / QBCore / QBOX).')
end

KT.fw = detect()