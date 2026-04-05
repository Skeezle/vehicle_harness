server_script '@ElectronAC/src/include/server.lua'
client_script '@ElectronAC/src/include/client.lua'
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'skeezle_harness'
author 'Skeezle'
description 'Standalone configurable harness + seatbelt system for Qbox/ox_inventory'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua',
    'locales/*.lua'
}

client_scripts {
    'client/*.lua'
}

exports {
    'harness'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}

