fx_version 'cerulean'
game 'gta5'
author 'Local Minecraft mob prototypes'
description 'Original Creeper cuboids, ground pursuit, spatial sound, and server fuse'
version '0.1.0'
dependency '/onesync'
shared_scripts { 'shared/config.lua', 'shared/math.lua', 'shared/model.lua' }
client_scripts {
    'client/audio.lua', 'client/renderer.lua', 'client/targeting.lua',
    'client/movement.lua', 'client/explosion.lua', 'client/creeper.lua', 'client/main.lua'
}
server_script 'server/main.lua'
ui_page 'assets/audio/index.html'
files { 'assets/audio/index.html', 'assets/audio/audio.js', 'assets/sounds/*.ogg', 'assets/runtime/*.png' }
