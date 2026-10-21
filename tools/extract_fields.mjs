// Frame-accurate extraction of field tag <-> name <-> type for every proto class.
import fs from 'fs';
import { m } from './77fb8a51-c2c728d2.js';
await import('./3e96080f-492df55b.js');
const root = m.roots.default;

const classes = [];
(function walk(node, path) {
  for (const k of Object.keys(node)) {
    const child = node[k];
    const p = path ? path + '.' + k : k;
    if (typeof child === 'function' && typeof child.encode === 'function') classes.push([p, child]);
    else if (child && typeof child === 'object') walk(child, p);
  }
})(root, '');

const results = {};
let busy = false;

for (const [name, C] of classes) {
  const orig = C.encode;
  C.encode = function (msg, w) {           // per-class wrapper: attribute accesses to a frame
    if (busy) return w;                    // nested call from another message's encoder: ignore
    busy = true;
    const frame = { name, names: [], calls: [] };
    const proxyMsg = new Proxy(msg === undefined ? {} : msg, {
      get(t, k) { if (typeof k === 'string') { frame.names.push(k); return { length: 1 }; } return undefined; },
      has() { return true; },
      getOwnPropertyDescriptor() { return { value: { length: 1 }, enumerable: true, writable: true, configurable: true }; },
    });
    const proxyWriter = new Proxy({}, {
      get(t, k) {
        if (typeof k !== 'string') return undefined;
        return (...args) => { frame.calls.push([k, args[0]]); return proxyWriter; };
      },
    });
    let err = null;
    try { orig(proxyMsg, proxyWriter); } catch (e) { err = e.message; }
    busy = false;
    const cur = results[name] || (results[name] = { fields: {}, err: null });
    const uniq = [];
    for (const n of frame.names) if (!uniq.includes(n)) uniq.push(n);
    const cs = frame.calls;
    let ti = 0;
    for (let i = 0; i < cs.length; i++) {
      if (cs[i][0] !== 'uint32') continue;
      const tag = cs[i][1];
      ti++;
      const fn = uniq[ti - 1];
      if (!fn) continue;
      // the type method is the next call that is neither fork() nor ldelim()
      let type = 'message';
      for (let j = i + 1; j < cs.length; j++) {
        if (cs[j][0] === 'fork') continue;
        if (cs[j][0] === 'ldelim') break;
        if (cs[j][0] === 'uint32') break;
        type = cs[j][0];
        break;
      }
      if (!cur.fields[fn]) cur.fields[fn] = { tag: tag >>> 3, wire: tag & 7, type };
    }
    if (err && !cur.err) cur.err = err;
    return w;   // nested callers only need a writer back
  };
  C.encode({}, undefined);   // drive the wrapper so this class's frame is recorded
}

// enums: classes that expose numeric constants and no fields
const enums = {};
for (const [name, C] of classes) {
  const consts = {};
  for (const k of Object.keys(C)) if (/^[A-Z][A-Z0-9_]*$/.test(k) && typeof C[k] === 'number') consts[k] = C[k];
  const proto = C.prototype || {};
  for (const k of Object.keys(proto)) if (/^[A-Z][A-Z0-9_]*$/.test(k) && typeof proto[k] === 'number') consts[k] = proto[k];
  if (Object.keys(consts).length) enums[name] = consts;
}

fs.writeFileSync('./blu_fields.json', JSON.stringify({ messages: results, enums }, null, 1));
console.log('classes:', classes.length);
console.log('messages with fields:', Object.values(results).filter(r => Object.keys(r.fields).length).length);
console.log('errors:', Object.values(results).filter(r => r.err).length);
for (const n of ['solutions.saman.bluebank.services.SessionKeyExchangeRequest',
                 'solutions.saman.bluebank.services.SessionKeyExchangeResponse',
                 'solutions.saman.bluebank.services.SessionLoginRequest']) {
  console.log('\n' + n.split('.').pop() + ':', JSON.stringify(results[n] && results[n].fields));
}
