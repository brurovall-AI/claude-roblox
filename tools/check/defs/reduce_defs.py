import re, sys
src = open(sys.argv[1]).read()
out_path = sys.argv[2]
keep_roots = set(open(sys.argv[3]).read().split())
lines = src.split('\n')
# split blocks; attribute lines (@[...] / @deprecated at col 0) attach to following block
blocks = []
cur = []
pending_attr = []
start_re = re.compile(r'^(declare|type|export type)\b')
for l in lines:
    if l.startswith('@') :
        if cur:
            blocks.append(cur); cur = []
        pending_attr.append(l); continue
    if start_re.match(l):
        if cur: blocks.append(cur)
        cur = pending_attr + [l]; pending_attr = []
    else:
        if pending_attr:
            cur += pending_attr; pending_attr = []
        cur.append(l)
if cur: blocks.append(cur)

def block_decl(b):
    for l in b:
        m = re.match(r'^declare extern type (\w+)(?: extends (\w+))?', l)
        if m: return ('class', m.group(1), m.group(2))
        m = re.match(r'^declare class (\w+)(?: extends (\w+))?', l)
        if m: return ('class', m.group(1), m.group(2))
        m = re.match(r'^(?:export )?type (\w+)', l)
        if m: return ('type', m.group(1), None)
        m = re.match(r'^declare (?:function )?(\w+)', l)
        if m: return ('global', m.group(1), None)
    return ('other', None, None)

info = [block_decl(b) for b in blocks]
parent = {}
for kind, name, ext in info:
    if kind == 'class': parent[name] = ext
def is_instance(n):
    seen = 0
    while n and seen < 50:
        if n == 'Instance': return True
        n = parent.get(n); seen += 1
    return False
inst_classes = {n for n in parent if is_instance(n)}
keep = set()
for r in keep_roots:
    if r not in parent:
        print('WARN root not found', r); continue
    n = r
    while n:
        keep.add(n); n = parent.get(n)
dropped = inst_classes - keep
print('instance classes', len(inst_classes), 'kept', len(keep & inst_classes), 'dropped', len(dropped))
drop_re = re.compile(r'\b(' + '|'.join(sorted(dropped, key=len, reverse=True)) + r')\b')
str_re = re.compile(r'("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')')
member_re = re.compile(r'^((?:\s+|declare\s+)(?:function\s+)?\w+)(.*)$')
def fix_line(l):
    m = member_re.match(l)
    prefix = ''
    if m:
        prefix, l = m.group(1), m.group(2)
    parts = str_re.split(l)
    for i in range(0, len(parts), 2):
        parts[i] = drop_re.sub('Instance', parts[i])
    return prefix + ''.join(parts)
out = []
for b, (kind, name, ext) in zip(blocks, info):
    if kind == 'class' and name in dropped: continue
    out.extend(fix_line(l) for l in b)
open(out_path, 'w').write('\n'.join(out))
print('wrote', out_path, sum(len(l) for l in out))

# second pass: stub enum internals not in allowlist
if len(sys.argv) > 4:
    keep_enums = set(open(sys.argv[4]).read().split())
    text = open(out_path).read().split('\n')
    res = []; skipping = False
    for l in text:
        if skipping:
            if l.startswith('end'): skipping = False
            continue
        m = re.match(r'^declare extern type Enum(\w+)_INTERNAL extends Enum with\s*$', l)
        if m and m.group(1) not in keep_enums:
            res.append(f'declare extern type Enum{m.group(1)}_INTERNAL extends Enum with end'); skipping = True; continue
        res.append(l)
    open(out_path, 'w').write('\n'.join(res))
    print('enum pass done', sum(len(l) for l in res))
