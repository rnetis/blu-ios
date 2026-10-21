// Deobfuscate obfuscator.io-style string-table bundles.
// Usage: node deob.js <in.js> <out.js>
const fs = require('fs');
const [inPath, outPath] = process.argv.slice(2);
const src = fs.readFileSync(inPath, 'utf8');

// ---- locate the array function and its string array literal ----
const arrDecl = src.match(/function\s+([A-Za-z0-9_$]+)\s*\(\s*\)\s*\{\s*(?:const|let|var)\s+([A-Za-z0-9_$]+)\s*=\s*\[/);
if (!arrDecl) throw new Error('array fn not found');
const arrFnName = arrDecl[1], arrVarName = arrDecl[2];

// ---- locate the accessor (short fn calling arrFn() and indexing) ----
let accessorName = null, offset = 0;
for (const m of src.matchAll(/function\s+([A-Za-z0-9_$]+)\s*\([^)]*\)\s*\{/g)) {
  const name = m[1];
  const body = src.slice(m.index, m.index + 700);
  const end = body.indexOf('\n');
  const chunk = end > 0 ? body.slice(0, end) : body;
  if (!new RegExp(arrFnName + '\\s*\\(\\)').test(chunk)) continue;
  const off = chunk.match(/-\s*0x([0-9a-f]+)/i);
  if (!off) continue;
  accessorName = name; offset = parseInt(off[1], 16);
  break;
}
if (!accessorName) throw new Error('accessor not found');
console.log(`arrayFn=${arrFnName} accessor=${accessorName} offset=0x${offset.toString(16)}`);

// ---- sandbox: define both fns, then run the head rotation IIFE ----
const headEnd = src.search(/\b(import|export)\s/);
const head = src.slice(0, headEnd === -1 ? 4000 : headEnd);
const iife = head.match(/\(function\s*\([\s\S]*?\}\s*\([^()]*\)\s*\)\s*;/);
const extract = (name) => {
  const start = src.indexOf('function ' + name + '(');
  let i = src.indexOf('{', start), depth = 0;
  for (; i < src.length; i++) {
    const c = src[i];
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (!depth) return { start, end: i + 1, text: src.slice(start, i + 1) }; }
    else if (c === '"' || c === "'" || c === '`') { const q = c; i++; while (i < src.length && src[i] !== q) { if (src[i] === '\\') i++; i++; } }
  }
  throw new Error('unbalanced ' + name);
};
const arrFn = extract(arrFnName), accFn = extract(accessorName);

let acc, arr;
eval(arrFn.text + '\n' + accFn.text + '\n' + (iife ? iife[0] : '') + '\nacc=' + accessorName + ';arr=' + arrFnName + '();');

const map = {};
for (let i = 0; i < arr.length; i++) if (typeof arr[i] === 'string') map[i + offset] = arr[i];
console.log('table size=' + arr.length);

// ---- aliases ----
const aliases = new Set([accessorName, arrFnName]);
for (const m of src.matchAll(/([A-Za-z0-9_$]+)\s*=\s*([A-Za-z0-9_$]+)\s*[;,)]/g)) if (aliases.has(m[2])) aliases.add(m[1]);
for (const m of src.matchAll(new RegExp('([A-Za-z0-9_$]+)\\s*=\\s*' + accessorName, 'g'))) aliases.add(m[1]);
console.log('aliases=' + [...aliases].join(','));

const aliasRe = new RegExp('\\b(' + [...aliases].map(a => a.replace(/\$/g, '\\$')).join('|') + ')\\s*\\(\\s*(0x[0-9a-fA-F]+)\\s*\\)', 'g');
const protectedRanges = [[arrFn.start, arrFn.end], [accFn.start, accFn.end]];
let hits = 0, misses = 0;
const out = src.replace(aliasRe, (full, name, hex, pos) => {
  for (const [a, b] of protectedRanges) if (pos >= a && pos < b) return full;
  const v = map[parseInt(hex, 16)];
  if (v === undefined) { misses++; return full; }
  hits++;
  return JSON.stringify(v);
});
console.log(`replaced=${hits} unresolved=${misses}`);
fs.writeFileSync(outPath, out);
console.log('wrote ' + outPath + ' (' + out.length + ' bytes)');
