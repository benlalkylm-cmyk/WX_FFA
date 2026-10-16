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

-- Works with Tiger_EMS (0.7.0+): FFA sends 'rx_rprevive:inmatchlobby' on join/leave, and Tiger EMS then leaves
-- match deaths to FFA (no down, death screen, hospital or injuries). FFA respawns players itself.
-- Also used at runtime if present: a weapon script handling 'weapontrigger', 'weapontrigger2' and 'weapontrigger3'.

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
