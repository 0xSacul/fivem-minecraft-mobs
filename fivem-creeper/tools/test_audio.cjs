const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const sources = [], panners = [], messages = {}, urls = [];
let decodingResolve;
const vector = () => ({positionX:{value:0},positionY:{value:0},positionZ:{value:0}});
class AudioContext {
  constructor() { this.listener={...vector(),forwardX:{},forwardY:{},forwardZ:{},upX:{},upY:{},upZ:{}};this.destination={}; }
  resume() { return Promise.resolve(); }
  decodeAudioData() {
    if (decodingResolve === true) return new Promise(resolve => {decodingResolve=resolve;});
    return Promise.resolve({decoded:true});
  }
  createGain() { return {gain:{},connect(){}}; }
  createPanner() { const p={...vector(),connect(){return this;},disconnect(){}};panners.push(p);return p; }
  createBufferSource() {
    const source={connect(p){return p;},disconnect(){},start(){this.started=true;},stop(){this.stopped=true;this.onended();}};
    sources.push(source);return source;
  }
}
const context = vm.createContext({AudioContext,console,Set,Map,Array,
  window:{addEventListener(name,fn){messages[name]=fn;}},GetParentResourceName:()=> 'fivem-creeper',
  fetch(url){urls.push(url);return Promise.resolve({ok:true,arrayBuffer:()=>Promise.resolve(new ArrayBuffer(1))});}
});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname,'../assets/audio/audio.js'),'utf8'),context);
const send = data => messages.message({data});
const flush = () => new Promise(resolve=>setImmediate(resolve));
async function main() {
  send({action:'config',distance:70,volume:0.8,maxVoices:2});
  send({action:'listener',pos:{x:1,y:2,z:3},forward:{x:0,y:1,z:0},up:{x:0,y:0,z:1}});
  for (const name of ['say1','say2','death']) {
    send({action:'play',name,pos:{x:4,y:5,z:6}});await flush();
  }
  assert.equal(sources.length,3);assert.equal(sources[0].stopped,true);
  assert.equal(panners[0].panningModel,'HRTF');assert.equal(panners[0].positionZ.value,6);assert.equal(panners[0].maxDistance,70);
  send({action:'play',name:'../../secret',pos:{x:0,y:0,z:0}});await flush();assert.equal(sources.length,3);
  decodingResolve=true;
  send({action:'play',name:'fuse',id:'c1:primed',pos:{x:0,y:2,z:0}});await flush();
  assert.equal(typeof decodingResolve,'function');
  send({action:'stopEmitter',id:'c1:primed'});
  decodingResolve({decoded:true});await flush();assert.equal(sources.length,3,'Canceled pending fuse began playing');
  send({action:'play',name:'fuse',id:'c1:primed',pos:{x:0,y:2,z:0}});await flush();
  assert.equal(sources.length,4);send({action:'stopEmitter',id:'c1:primed'});assert(sources[3].stopped);
  send({action:'stop'});assert(sources.every(source=>source.stopped));
  assert(urls.includes('../sounds/fuse.ogg'));
  console.log('PASS: NUI spatial audio and fuse cancellation');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
