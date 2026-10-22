Hooks = {}

-- Primeni izgled na preview peda
function Hooks.ApplyAppearance(ped, char)
    if not char.skin then return end
    local ok, app = pcall(json.decode, char.skin)
    if not ok or type(app) ~= 'table' then return end
    if GetResourceState('illenium-appearance') == 'started' then
        exports['illenium-appearance']:setPedAppearance(ped, app)
    elseif GetResourceState('fivem-appearance') == 'started' then
        exports['fivem-appearance']:setPedAppearance(ped, app)
    end
end

-- Otvori kreiranje izgleda za novog lika
function Hooks.OpenAppearance()
    if KT.fw == 'esx' then
        TriggerEvent('esx_skin:openSaveableMenu')
    else
        TriggerEvent('qb-clothes:client:CreateFirstCharacter') -- radi i sa illenium-appearance QB kompatibilnošću
    end
end

-- Pauziraj / vrati weather & time sync resurse
function Hooks.PauseWeather(pause)
    if pause then
        if GetResourceState('qb-weathersync') == 'started' then TriggerEvent('qb-weathersync:client:DisableSync') end
        if GetResourceState('cd_easytime') == 'started' then TriggerEvent('cd_easytime:PauseSync', true) end
        if GetResourceState('Renewed-Weathersync') == 'started' then LocalPlayer.state:set('syncWeather', false, true) end
    else
        if GetResourceState('qb-weathersync') == 'started' then TriggerEvent('qb-weathersync:client:EnableSync') end
        if GetResourceState('cd_easytime') == 'started' then TriggerEvent('cd_easytime:PauseSync', false) end
        if GetResourceState('Renewed-Weathersync') == 'started' then LocalPlayer.state:set('syncWeather', true, true) end
    end
end