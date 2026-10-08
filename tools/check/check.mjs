// Strict Luau type-check + lint for the whole Rojo tree.
//
// Roblox-style requires (`require(script.Parent.X)`, `require(Shared.Config.Stats)`)
// are resolved statically against default.project.json and rewritten to named
// requires before analysis, so cross-module types flow exactly like they do in
// Studio with luau-lsp. Map builder sources (src/map, executed by Lune at bake
// time) use relative string requires and are checked the same way.
//
// Usage: node tools/check/check.mjs [--quiet] [--no-lint] [path-filter]

import { Analysis } from '@luau-rs/luau/analysis';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const args = process.argv.slice(2);
const quiet = args.includes('--quiet');
const noLint = args.includes('--no-lint');
const filter = args.find((a) => !a.startsWith('--'));

const defs = fs.readFileSync(path.join(here, 'defs/roblox.d.luau'), 'utf8');
const declaredClasses = new Set([...defs.matchAll(/^declare extern type (\w+)/gm)].map((m) => m[1]));

// ---------------------------------------------------------------------------
// 1. Walk the Rojo project to map files <-> instance paths.
// ---------------------------------------------------------------------------
const project = JSON.parse(fs.readFileSync(path.join(root, 'default.project.json'), 'utf8'));
const files = []; // { file, instPath: string[], kind: 'module'|'script', env: 'game'|'map' }

function scriptKind(base) {
  if (base.endsWith('.server.luau') || base.endsWith('.client.luau')) return 'script';
  return 'module';
}
function instName(base) {
  return base.replace(/\.(server|client)\.luau$/, '').replace(/\.luau$/, '');
}
function walkDir(dir, instPath) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      walkDir(full, [...instPath, ent.name]);
    } else if (ent.name.endsWith('.luau')) {
      const name = instName(ent.name);
      if (name === 'init') {
        files.push({ file: full, instPath, kind: scriptKind(ent.name), env: 'game' });
      } else {
        files.push({ file: full, instPath: [...instPath, name], kind: scriptKind(ent.name), env: 'game' });
      }
    }
  }
}
function walkTree(node, instPath) {
  if (node.$path) {
    const p = path.join(root, node.$path);
    if (fs.existsSync(p) && fs.statSync(p).isDirectory()) walkDir(p, instPath);
  }
  for (const [k, v] of Object.entries(node)) {
    if (!k.startsWith('$') && typeof v === 'object') walkTree(v, [...instPath, k]);
  }
}
walkTree(project.tree, []);

// Map builder sources live outside the game tree.
const mapRoot = path.join(root, 'src/map');
function walkMap(dir) {
  if (!fs.existsSync(dir)) return;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walkMap(full);
    else if (ent.name.endsWith('.luau')) {
      const rel = path.relative(root, full).replace(/\\/g, '/').replace(/\.luau$/, '');
      files.push({ file: full, instPath: ['@map', ...rel.split('/')], kind: 'module', env: 'map' });
    }
  }
}
walkMap(mapRoot);

const byInst = new Map(files.map((f) => [f.instPath.join('/'), f]));
const modName = (f) => f.instPath.join('/');

// ---------------------------------------------------------------------------
// 2. Static require resolution.
// ---------------------------------------------------------------------------
// Parse a chain expression like `script.Parent.Foo:WaitForChild("Bar")["Baz"]`.
function parseChain(expr) {
  expr = expr.trim();
  const m = expr.match(/^([A-Za-z_]\w*)/);
  if (!m) return null;
  const ops = [];
  let rest = expr.slice(m[1].length);
  const re = /^\s*(?:\.\s*([A-Za-z_]\w*)|:\s*(WaitForChild|FindFirstChild|GetService)\s*\(\s*"([^"]+)"\s*(?:,[^)]*)?\)|\[\s*"([^"]+)"\s*\])/;
  while (rest.trim().length) {
    const mm = rest.match(re);
    if (!mm) return null;
    if (mm[1]) ops.push(mm[1]);
    else if (mm[2] === 'GetService') ops.push({ service: mm[3] });
    else if (mm[2]) ops.push(mm[3]);
    else ops.push(mm[4]);
    rest = rest.slice(mm[0].length);
  }
  return { head: m[1], ops };
}
function resolveChain(expr, f, aliases) {
  const c = parseChain(expr);
  if (!c) return null;
  let p;
  if (c.head === 'script') p = [...f.instPath];
  else if (c.head === 'game') p = [];
  else if (c.head === 'workspace') p = ['Workspace'];
  else if (aliases.has(c.head)) p = [...aliases.get(c.head)];
  else return null;
  for (const op of c.ops) {
    if (typeof op === 'object') p = [op.service];
    else if (op === 'Parent') p.pop();
    else p.push(op);
  }
  return p;
}
function findMatchingParen(s, open) {
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    const ch = s[i];
    if (ch === '"' || ch === "'") {
      const q = ch;
      i++;
      while (i < s.length && s[i] !== q) { if (s[i] === '\\') i++; i++; }
      continue;
    }
    if (ch === '(') depth++;
    else if (ch === ')') { depth--; if (depth === 0) return i; }
  }
  return -1;
}

const unresolved = [];
const aliasNames = new Map(); // module name -> Set of alias locals (to silence LocalUnused)
function rewrite(f, src) {
  const lines = src.split('\n');
  const aliases = new Map();
  const out = [];
  let inBlock = false;
  for (let li = 0; li < lines.length; li++) {
    let line = lines[li];
    // Skip comments: block comments --[[ ... ]] (also --[=[ ]=]) and line comments.
    if (inBlock) {
      if (/\]=*\]/.test(line)) inBlock = false;
      out.push(line);
      continue;
    }
    if (/^\s*--\[=*\[/.test(line)) {
      if (!/\]=*\]/.test(line.replace(/^\s*--\[=*\[/, ''))) inBlock = true;
      out.push(line);
      continue;
    }
    if (/^\s*--/.test(line)) { out.push(line); continue; }
    // alias tracking: local X = <chain>
    const am = line.match(/^\s*local\s+([A-Za-z_]\w*)\s*(?::\s*[\w.]+\??\s*)?=\s*(.+?)\s*(?:--.*)?$/);
    if (am && !am[2].startsWith('require')) {
      const p = resolveChain(am[2], f, aliases);
      if (p) {
        aliases.set(am[1], p);
        // Paths into our own source tree (deeper than a service) have no static
        // instance types without a sourcemap: make them dynamic for the checker.
        if (p.length >= 2) {
          const head = parseChain(am[2]).head;
          const at = line.indexOf(am[2]);
          line = line.slice(0, at) + `(${head} :: any)` + line.slice(at + head.length);
        }
      }
    }
    // requires
    let idx = 0;
    while ((idx = line.indexOf('require(', idx)) !== -1) {
      if (idx > 0 && /[\w.:]/.test(line[idx - 1])) { idx += 8; continue; }
      const open = idx + 7;
      const close = findMatchingParen(line, open);
      if (close < 0) break;
      const inner = line.slice(open + 1, close).trim();
      let target = null;
      const sm = inner.match(/^"([^"]+)"$/);
      if (sm) {
        if (sm[1].startsWith('@')) { idx = close; continue; } // engine/lune builtins
        if (f.env === 'map' && (sm[1].startsWith('./') || sm[1].startsWith('../'))) {
          const dir = path.dirname(f.file);
          const abs = path.resolve(dir, sm[1]);
          const rel = path.relative(root, abs).replace(/\\/g, '/');
          target = ['@map', ...rel.split('/')];
        } else { idx = close; continue; }
      } else {
        target = resolveChain(inner, f, aliases);
      }
      const key = target && target.join('/');
      if (!key || !byInst.has(key)) {
        unresolved.push(`${path.relative(root, f.file)}:${li + 1}: cannot resolve require(${inner})${key ? ' -> ' + key : ''}`);
        idx = close;
        continue;
      }
      const repl = `require("${key}")`;
      line = line.slice(0, idx) + repl + line.slice(close + 1);
      idx += repl.length;
    }
    // luau-lsp style magic: typed Instance.new / GetService
    line = line.replace(/Instance\.new\("(\w+)"\)/g, (m0, cls) => (declaredClasses.has(cls) ? `(${m0} :: ${cls})` : m0));
    line = line.replace(/game:GetService\("(\w+)"\)/g, (m0, cls) => (declaredClasses.has(cls) ? `(${m0} :: ${cls})` : m0));
    out.push(line);
  }
  aliasNames.set(modName(f), new Set(aliases.keys()));
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// 3. Analyze.
// ---------------------------------------------------------------------------
const analysis = await Analysis.create({ mode: 'strict', lint: !noLint });
analysis.addDefinition('@roblox', defs);
for (const f of files) {
  const src = fs.readFileSync(f.file, 'utf8');
  analysis.setModule(modName(f), rewrite(f, src), f.kind);
}

const targets = files.filter((f) => !filter || path.relative(root, f.file).includes(filter));
const results = analysis.checkModules(targets.map(modName));
const nameToFile = new Map(files.map((f) => [modName(f), f.file]));
const seen = new Set();
let errors = 0;
let warnings = 0;
const IGNORED_LINTS = new Set([
  'ImplicitReturn', // Roblox callbacks commonly fall through
]);
for (const r of results) {
  for (const d of r.result.diagnostics) {
    if (d.kind === 'lint' && IGNORED_LINTS.has(String(d.code))) continue;
    if (d.kind === 'lint' && String(d.code) === 'LocalUnused') {
      const m = d.message.match(/Variable '(\w+)'/);
      if (m && aliasNames.get(d.module)?.has(m[1])) continue;
    }
    const file = path.relative(root, nameToFile.get(d.module) ?? d.module);
    const key = `${file}:${d.location.begin.line}:${d.location.begin.column}:${d.message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    if (d.severity === 'error') errors++;
    else warnings++;
    if (!quiet || d.severity === 'error') {
      console.log(`${file}:${d.location.begin.line + 1}:${d.location.begin.column + 1}: ${d.severity} [${d.kind}${d.code !== undefined ? ' ' + d.code : ''}] ${d.message}`);
    }
  }
  if (r.result.timeoutModules?.length) console.log('timeout:', r.result.timeoutModules.join(', '));
}
for (const u of unresolved) { console.log(`${u}  error [require]`); errors++; }
console.log(`\nchecked ${targets.length} modules: ${errors} error(s), ${warnings} warning(s)`);
process.exit(errors ? 1 : 0);
