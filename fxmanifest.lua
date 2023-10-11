fx_version 'cerulean'

game 'gta5'

author 'byK3'
description "ESX based Cityhall Script with Namechange, Social Money, Playtime Tracker & Stats"
version '1.0.0'


shared_script '@es_extended/imports.lua'

client_scripts {
    'config.lua',
    'client.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server.lua',
}


