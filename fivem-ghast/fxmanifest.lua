fx_version 'cerulean'
game 'gta5'

author 'Local Ghast prototype'
description 'Minecraft Ghast geometry, spatial audio, and swept entity fireballs'
version '0.1.0'

dependency '/onesync'
shared_scripts { 'shared/config.lua', 'shared/math.lua' }
client_scripts {
    'client/audio.lua',
    'client/renderer.lua',
    'client/movement.lua',
    'client/targeting.lua',
    'client/fireball.lua',
    'client/ghast.lua',
    'client/main.lua'
}
server_script 'server/main.lua'
ui_page 'assets/audio/index.html'
files {
    'assets/audio/index.html', 'assets/audio/audio.js',
    'assets/sounds/*.ogg', 'assets/runtime/*.png'
}
