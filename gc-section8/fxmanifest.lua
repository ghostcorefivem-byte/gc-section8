fx_version 'cerulean'
game 'gta5'

author 'Ghost Core Scripts'
description 'gc-section8 — Chicago Section 8 Housing System'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/bridge.lua',
    'shared/config.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/main.lua',
    'client/admin_tool.lua',
    'client/nui.lua',
    'client/snap.lua',
    'client/snap_shop.lua',
    'client/decor.lua',
    'client/shower.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
    'server/commands.lua',
    'server/discord.lua',
    'server/doorlock.lua',
    'server/snap.lua',
    'server/snap_shop.lua',
    'server/decor.lua',
    'server/shower.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

lua54 'yes'
