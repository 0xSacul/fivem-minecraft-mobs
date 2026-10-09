fx_version 'cerulean'
game 'gta5'
author 'Local Minecraft mob prototype'
description 'Original Ender Dragon geometry, animated flight, breath and vehicle contact explosions'
version '0.1.0'
dependency '/onesync'
shared_scripts { 'shared/config.lua', 'shared/math.lua', 'shared/model.lua' }
client_scripts {
    'client/audio.lua', 'client/renderer.lua', 'client/targeting.lua',
    'client/movement.lua', 'client/vehicles.lua', 'client/fireball.lua',
    'client/dragon.lua', 'client/main.lua'
}
server_script 'server/main.lua'
ui_page 'assets/audio/index.html'
files { 'assets/audio/index.html', 'assets/audio/audio.js', 'assets/sounds/*.ogg', 'assets/runtime/*.png' }
