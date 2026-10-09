'use strict';
// This page never takes focus or displays controls. GTA coordinates are used consistently.
const context = new AudioContext();
const voices = new Set();
const cache = new Map();
const emitterEpoch = new Map();
const allowed = new Set(['fuse', 'death', 'say1', 'say2', 'say3', 'say4', 'explode1', 'explode2', 'explode3', 'explode4']);
let settings = {distance: 70, volume: 0.8, maxVoices: 20};
const master = context.createGain();
master.connect(context.destination);
function setPosition(node, p) {
  if (node.positionX) {
    node.positionX.value = p.x; node.positionY.value = p.y; node.positionZ.value = p.z;
  } else node.setPosition(p.x, p.y, p.z);
}
async function buffer(name) {
  if (!cache.has(name)) cache.set(name, fetch(`../sounds/${name}.ogg`).then(r => {
    if (!r.ok) throw new Error(`Creeper audio ${r.status}: ${name}`);
    return r.arrayBuffer();
  }).then(b => context.decodeAudioData(b)).catch(e => {cache.delete(name); throw e;}));
  return cache.get(name);
}
async function play(data) {
  if (!allowed.has(data.name) || !data.pos) return;
  const epoch = data.id ? (emitterEpoch.get(data.id) || 0) : 0;
  await context.resume();
  const decoded = await buffer(data.name);
  if (data.id && epoch !== (emitterEpoch.get(data.id) || 0)) return;
  if (voices.size >= settings.maxVoices) {
    const oldest = voices.values().next().value;
    voices.delete(oldest);
    oldest.stop();
  }
  const source = context.createBufferSource();
  const panner = context.createPanner();
  panner.panningModel = 'HRTF';
  panner.distanceModel = 'linear';
  panner.refDistance = 2; panner.maxDistance = settings.distance; panner.rolloffFactor = 1;
  setPosition(panner, data.pos);
  source.buffer = decoded;
  source.emitter = data.id;
  source.connect(panner).connect(master);
  voices.add(source);
  source.onended = () => {voices.delete(source); source.disconnect(); panner.disconnect();};
  source.start();
}
window.addEventListener('message', ({data}) => {
  if (data.action === 'config') {
    settings = data; master.gain.value = settings.volume;
  } else if (data.action === 'listener') {
    const listener = context.listener;
    setPosition(listener, data.pos);
    if (listener.forwardX) {
      for (const axis of ['X', 'Y', 'Z']) {
        listener[`forward${axis}`].value = data.forward[axis.toLowerCase()];
        listener[`up${axis}`].value = data.up[axis.toLowerCase()];
      }
    } else listener.setOrientation(data.forward.x, data.forward.y, data.forward.z, data.up.x, data.up.y, data.up.z);
  } else if (data.action === 'play') play(data).catch(e => console.error(e.message));
  else if (data.action === 'stopEmitter') {
    emitterEpoch.set(data.id, (emitterEpoch.get(data.id) || 0) + 1);
    for (const source of voices) if (source.emitter === data.id) source.stop();
  } else if (data.action === 'stop') for (const source of voices) source.stop();
});
fetch(`https://${GetParentResourceName()}/ready`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'})
  .catch(e => console.error('Creeper NUI handshake failed', e));
