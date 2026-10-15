fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/clientcode.lua'
}

ui_page 'html/ui.html'
files {
    'html/ui.html',
    'html/ui.css',
    'html/script.js',  
    'html/*.png'
}

export 'getFFAStatus'

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
