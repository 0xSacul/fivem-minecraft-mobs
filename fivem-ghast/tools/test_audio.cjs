const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const messages = {};
const sources = [];
const panners = [];
const vector = () => ({positionX:{value:0},positionY:{value:0},positionZ:{value:0}});
class AudioContext {
  constructor() {
    this.listener = {...vector(), forwardX:{},forwardY:{},forwardZ:{},upX:{},upY:{},upZ:{}};
    this.destination = {};
  }
  resume() { return Promise.resolve(); }
  decodeAudioData() { return Promise.resolve({decoded:true}); }
  createGain() { return {gain:{},connect(){}}; }
  createPanner() {
    const p = {...vector(),connect(){return this;},disconnect(){}};
    panners.push(p); return p;
  }
  createBufferSource() {
    const source = {connect(p){return p;},disconnect(){},start(){this.started=true;},stop(){this.stopped=true; this.onended();}};
    sources.push(source); return source;
  }
}
const urls = [];
const context = vm.createContext({AudioContext, console, Set, Map, Array,
  window:{addEventListener(name, fn){messages[name]=fn;}}, GetParentResourceName:()=> 'fivem-ghast',
  fetch(url){urls.push(url); return Promise.resolve({ok:true,arrayBuffer:()=>Promise.resolve(new ArrayBuffer(1))});}
});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname,'../assets/audio/audio.js'),'utf8'),context);
async function main() {
  messages.message({data:{action:'config',distance:90,volume:0.8,maxVoices:2}});
  messages.message({data:{action:'listener',pos:{x:1,y:2,z:3},forward:{x:0,y:1,z:0},up:{x:0,y:0,z:1}}});
  for (const name of ['charge','death','fireball4']) {
    messages.message({data:{action:'play',name,pos:{x:4,y:5,z:6}}});
    await new Promise(resolve=>setImmediate(resolve));
  }
  assert.equal(sources.length,3);
  assert.equal(sources[0].stopped,true);
  assert.equal(panners[0].panningModel,'HRTF');
  assert.equal(panners[0].positionZ.value,6);
  assert.equal(panners[0].maxDistance,90);
  assert(urls.includes('../sounds/charge.ogg'));
  messages.message({data:{action:'play',name:'../../secret',pos:{x:0,y:0,z:0}}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(sources.length,3);
  messages.message({data:{action:'stop'}});
  assert(sources.every(s=>s.stopped));
  console.log('NUI spatial audio assertions passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
