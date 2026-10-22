fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kt-multicharacter'
author 'KT Scripts'
version '1.0.0'
description 'Modern cinematic multicharacter for ESX / QBCore / QBOX'

shared_scripts { '@ox_lib/init.lua', 'config.lua', 'shared/framework.lua' }
client_scripts { 'client/hooks.lua', 'client/main.lua', 'client/creator.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }

dependencies { 'ox_lib', 'oxmysql' }

-- Tebex / CFX Escrow: kupac sme da menja samo ove fajlove
escrow_ignore { 'config.lua', 'client/hooks.lua' }