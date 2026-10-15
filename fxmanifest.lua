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

-- Also required at runtime (not listed below because their resource names vary per server).
-- Without them revive and the FFA loadout silently do nothing:
--   * a revive script handling 'rxRevive:revivePlayerClient' and 'rx_rprevive:inmatchlobby'
--   * a weapon script handling 'weapontrigger', 'weapontrigger2' and 'weapontrigger3'
-- Add those resources to `dependencies` once you know their names.

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
