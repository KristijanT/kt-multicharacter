Config = {}

Config.Framework = 'auto'          -- 'auto' | 'esx' | 'qb' | 'qbox'
Config.Locale    = 'sr'            -- 'sr' | 'en'
Config.Preset    = 'interactive'   -- 'classic' | 'modern' | 'interactive'
Config.Accent    = '#7c5cff'
Config.Currency  = '$'
Config.StoreURL  = 'https://tvoj-shop.tebex.io'

-- Muzika (stavi SVOJE ili royalty-free .ogg fajlove u web/audio/)
-- VAŽNO za prodaju: ne isporučuj pesme za koje nemaš licencu.
Config.Music = {
    enabled = true,
    volume = 0.25,
    tracks = {
        { label = 'Midnight Drive', file = 'audio/track1.ogg' },
        { label = 'City Lights',    file = 'audio/track2.ogg' },
        { label = 'Neon Dreams',    file = 'audio/track3.ogg' },
    },
}

-- Efekti kamere u meniju
Config.CameraEffects = { 'none', 'filmic', 'vignette', 'cinema' }

-- Slotovi
Config.MaxSlots      = 5
Config.DefaultSlots  = 1
Config.SlotOverrides = {           -- po licenci
    -- ['license:xxxxxxxx'] = 3,
}
Config.Discord = {
    enabled = false,
    token = '',                    -- bot token
    guildId = '',
    cacheMinutes = 10,
    roles = {                      -- [roleId] = broj slotova
        -- ['123456789012345678'] = 2,
    },
}

-- Brisanje likova
Config.AllowDelete    = true       -- false = samo admini
Config.AdminDeleteAce = 'kt-mc.delete'
Config.ESXDeleteTables = {         -- {tabela, kolona}
    { 'owned_vehicles', 'owner' },
    { 'user_licenses', 'owner' },
    { 'addon_account_data', 'owner' },
    { 'addon_inventory_items', 'owner' },
    { 'datastore_data', 'owner' },
}

-- Kreiranje
Config.Birth = { minYear = 1950, maxYear = 2006 }
Config.Nationalities = { 'Serbian', 'Croatian', 'Bosnian', 'American', 'German', 'British', 'Italian', 'Other' }

Config.StartingItems = {
    enabled = true,
    budget = 1000,
    items = {
        { name = 'water',    label = 'Water',    price = 50,  max = 5 },
        { name = 'sandwich', label = 'Sandwich', price = 80,  max = 5 },
        { name = 'phone',    label = 'Phone',    price = 600, max = 1 },
    },
}

-- Spawn
Config.Spawn = {
    mode = 'classic',              -- 'classic' | 'none'
    newCharacter = vec4(-1037.6, -2738.0, 20.17, 330.0),
    wakeUp = true,
}
Config.Spawns = {
    { label = 'Legion Square', coords = vec4(195.17, -933.77, 30.69, 144.0) },
    { label = 'Paleto Bay',    coords = vec4(80.35, 6424.12, 31.67, 45.0) },
    { label = 'Sandy Shores',  coords = vec4(1836.83, 3677.53, 34.27, 210.0) },
}

-- Sezonske scene
Config.Season = 'auto'             -- 'auto' | nil | 'xmas' | 'halloween'
Config.SeasonMonths = { [10] = 'halloween', [12] = 'xmas' }

-- Pauziranje weather/time resursa tokom scene
Config.PauseWeatherSync = true

-- QBCore: neke verzije ne okidaju loaded event bez multichar resursa
Config.QBFireLoadedEvents = true

-- Scene (koordinate podesi preko /ktscene)
-- slots   = pozicije 5 likova za Interactive preset
-- camWide = šira kamera za Interactive preset
Config.Scenes = {
    {
        name = 'airport', enabled = true, season = nil,
        ped = vec4(-1037.6, -2738.0, 20.17, 330.0),
        cam = { coords = vec3(-1036.2, -2735.6, 20.9), lookAt = vec3(-1037.6, -2738.0, 20.8), fov = 40.0 },
        camWide = { coords = vec3(-1037.5, -2733.0, 21.2), lookAt = vec3(-1037.6, -2738.0, 20.9), fov = 55.0 },
        slots = {
            vec4(-1040.2, -2739.6, 20.17, 320.0),
            vec4(-1038.9, -2738.8, 20.17, 325.0),
            vec4(-1037.6, -2738.0, 20.17, 330.0),
            vec4(-1036.3, -2737.2, 20.17, 335.0),
            vec4(-1035.0, -2736.4, 20.17, 340.0),
        },
        intro = { coords = vec3(-1010.0, -2700.0, 35.0), lookAt = vec3(-1037.6, -2738.0, 21.0), fov = 60.0, time = 5000 },
        time = { 18, 30 }, weather = 'EXTRASUNNY',
        props = {}, vehicles = {}, npcs = {},
    },
    {
        name = 'xmas', enabled = true, season = 'xmas',
        ped = vec4(-1037.6, -2738.0, 20.17, 330.0),
        cam = { coords = vec3(-1036.2, -2735.6, 20.9), lookAt = vec3(-1037.6, -2738.0, 20.8), fov = 40.0 },
        camWide = { coords = vec3(-1037.5, -2733.0, 21.2), lookAt = vec3(-1037.6, -2738.0, 20.9), fov = 55.0 },
        slots = {
            vec4(-1040.2, -2739.6, 20.17, 320.0),
            vec4(-1038.9, -2738.8, 20.17, 325.0),
            vec4(-1037.6, -2738.0, 20.17, 330.0),
            vec4(-1036.3, -2737.2, 20.17, 335.0),
            vec4(-1035.0, -2736.4, 20.17, 340.0),
        },
        time = { 22, 0 }, weather = 'XMAS',
        props = { { model = 'prop_xmas_tree_int', coords = vec3(-1035.0, -2739.5, 19.2), heading = 0.0 } },
        vehicles = {}, npcs = {},
    },
}

-- Prevodi
Config.Lang = {
    en = {
        title = 'Select character', subtitle = 'Choose who you want to play', play = 'Play', delete = 'Delete',
        create = 'Create character', locked = 'Locked slot', locked_hint = 'Get more slots in our store',
        firstname = 'First name', lastname = 'Last name', dob = 'Date of birth', nationality = 'Nationality',
        gender = 'Gender', male = 'Male', female = 'Female', height = 'Height (cm)',
        startItems = 'Starting items', budget = 'Budget', confirm = 'Confirm', cancel = 'Cancel', back = 'Back',
        deleteQ = 'Delete this character permanently?', spawnTitle = 'Choose spawn', spawnSub = 'Where do you want to start?',
        job = 'Job', cash = 'Cash', bank = 'Bank', last_location = 'Last location', empty = 'Empty slot',
        err_name = 'Invalid name.', err_dob = 'Invalid date of birth.', err_busy = 'Slow down.',
        err_slot = 'No free slot.', err_items = 'Invalid items / budget exceeded.', err_gen = 'Something went wrong.',
    },
    sr = {
        title = 'Izaberi lika', subtitle = 'Izaberi kojim likom igraš', play = 'Igraj', delete = 'Obriši',
        create = 'Kreiraj lika', locked = 'Zaključan slot', locked_hint = 'Kupi dodatne slotove u shopu',
        firstname = 'Ime', lastname = 'Prezime', dob = 'Datum rođenja', nationality = 'Nacionalnost',
        gender = 'Pol', male = 'Muško', female = 'Žensko', height = 'Visina (cm)',
        startItems = 'Početni predmeti', budget = 'Budžet', confirm = 'Potvrdi', cancel = 'Otkaži', back = 'Nazad',
        deleteQ = 'Trajno obrisati ovog lika?', spawnTitle = 'Izaberi spawn', spawnSub = 'Gde želiš da počneš?',
        job = 'Posao', cash = 'Keš', bank = 'Banka', last_location = 'Poslednja lokacija', empty = 'Prazan slot',
        err_name = 'Neispravno ime.', err_dob = 'Neispravan datum rođenja.', err_busy = 'Polako.',
        err_slot = 'Nema slobodnog slota.', err_items = 'Neispravni predmeti / prekoračen budžet.', err_gen = 'Došlo je do greške.',
    },
}