//! Offline preview renderer for the baked Ironhaven map.
//!
//! Reads the part/light dump written by `tools/bake/bake.luau` and renders
//! perspective shots and orthographic floor plans to PNG so layouts can be
//! reviewed without opening Studio. It approximates Roblox "Future" lighting
//! (sun + shadows, hemisphere ambient with occlusion, point/spot/surface lights).
//!
//! Usage: ironhaven-render <dump.json> <cameras.json> <out_dir> [only_camera_name]

use rayon::prelude::*;
use serde::Deserialize;
use std::fs;

#[derive(Clone, Copy, Debug, Default)]
struct V3 {
    x: f32,
    y: f32,
    z: f32,
}
impl V3 {
    fn new(x: f32, y: f32, z: f32) -> Self {
        V3 { x, y, z }
    }
    fn dot(self, o: V3) -> f32 {
        self.x * o.x + self.y * o.y + self.z * o.z
    }
    fn cross(self, o: V3) -> V3 {
        V3::new(self.y * o.z - self.z * o.y, self.z * o.x - self.x * o.z, self.x * o.y - self.y * o.x)
    }
    fn len(self) -> f32 {
        self.dot(self).sqrt()
    }
    fn norm(self) -> V3 {
        let l = self.len().max(1e-9);
        self * (1.0 / l)
    }
    fn min(self, o: V3) -> V3 {
        V3::new(self.x.min(o.x), self.y.min(o.y), self.z.min(o.z))
    }
    fn max(self, o: V3) -> V3 {
        V3::new(self.x.max(o.x), self.y.max(o.y), self.z.max(o.z))
    }
    fn get(self, i: usize) -> f32 {
        match i {
            0 => self.x,
            1 => self.y,
            _ => self.z,
        }
    }
    fn mul(self, o: V3) -> V3 {
        V3::new(self.x * o.x, self.y * o.y, self.z * o.z)
    }
}
impl std::ops::Add for V3 {
    type Output = V3;
    fn add(self, o: V3) -> V3 {
        V3::new(self.x + o.x, self.y + o.y, self.z + o.z)
    }
}
impl std::ops::Sub for V3 {
    type Output = V3;
    fn sub(self, o: V3) -> V3 {
        V3::new(self.x - o.x, self.y - o.y, self.z - o.z)
    }
}
impl std::ops::Mul<f32> for V3 {
    type Output = V3;
    fn mul(self, s: f32) -> V3 {
        V3::new(self.x * s, self.y * s, self.z * s)
    }
}
impl std::ops::Neg for V3 {
    type Output = V3;
    fn neg(self) -> V3 {
        V3::new(-self.x, -self.y, -self.z)
    }
}

#[derive(Deserialize)]
struct PartIn {
    s: u8, // 0 block, 1 wedge, 2 cylinder, 3 ball, 4 cornerwedge
    cf: [f32; 12],
    sz: [f32; 3],
    c: [f32; 3],
    #[serde(default)]
    t: f32,
    #[serde(default)]
    m: String,
    #[serde(default)]
    rf: f32,
}
#[derive(Deserialize)]
struct LightIn {
    p: [f32; 3],
    c: [f32; 3],
    b: f32,
    r: f32,
    #[serde(default)]
    k: String,
    #[serde(default)]
    d: Option<[f32; 3]>,
    #[serde(default)]
    a: Option<f32>,
}
#[derive(Deserialize)]
struct SunIn {
    dir: [f32; 3],
    color: [f32; 3],
    ambient: [f32; 3],
    outdoor: [f32; 3],
    sky: [f32; 3],
}
#[derive(Deserialize)]
struct Dump {
    parts: Vec<PartIn>,
    lights: Vec<LightIn>,
    sun: SunIn,
}
#[derive(Deserialize, Clone)]
struct Cam {
    name: String,
    mode: String,
    #[serde(default)]
    pos: [f32; 3],
    #[serde(default)]
    look: [f32; 3],
    #[serde(default = "default_fov")]
    fov: f32,
    #[serde(default)]
    center: [f32; 2],
    #[serde(default)]
    extent: [f32; 2],
    #[serde(default)]
    clip: f32,
    #[serde(default)]
    floor: Option<f32>,
    #[serde(default = "default_w")]
    w: u32,
    #[serde(default = "default_h")]
    h: u32,
}
fn default_fov() -> f32 {
    70.0
}
fn default_w() -> u32 {
    960
}
fn default_h() -> u32 {
    540
}

#[derive(Clone)]
struct Prim {
    kind: u8,
    pos: V3,
    rx: V3, // world-space local axes (columns of rotation)
    ry: V3,
    rz: V3,
    half: V3,
    color: V3,
    transp: f32,
    refl: f32,
    neon: bool,
    metal: bool,
    lo: V3,
    hi: V3,
}

impl Prim {
    fn to_local(&self, p: V3) -> V3 {
        let d = p - self.pos;
        V3::new(d.dot(self.rx), d.dot(self.ry), d.dot(self.rz))
    }
    fn dir_local(&self, d: V3) -> V3 {
        V3::new(d.dot(self.rx), d.dot(self.ry), d.dot(self.rz))
    }
    fn n_world(&self, n: V3) -> V3 {
        (self.rx * n.x + self.ry * n.y + self.rz * n.z).norm()
    }
    /// Returns (t, world normal) of the nearest hit in [tmin, tmax].
    fn intersect(&self, o: V3, d: V3, tmin: f32, tmax: f32) -> Option<(f32, V3)> {
        let lo = self.to_local(o);
        let ld = self.dir_local(d);
        let h = self.half;
        match self.kind {
            3 => {
                let r = h.x.min(h.y).min(h.z);
                let b = lo.dot(ld);
                let c = lo.dot(lo) - r * r;
                let a = ld.dot(ld);
                let disc = b * b - a * c;
                if disc < 0.0 {
                    return None;
                }
                let sq = disc.sqrt();
                let mut t = (-b - sq) / a;
                if t < tmin {
                    t = (-b + sq) / a;
                }
                if t < tmin || t > tmax {
                    return None;
                }
                let p = lo + ld * t;
                Some((t, self.n_world(p)))
            }
            2 => {
                // Roblox cylinder: axis along local X.
                let r = h.y.min(h.z);
                let mut best: Option<(f32, V3)> = None;
                let a = ld.y * ld.y + ld.z * ld.z;
                if a > 1e-12 {
                    let b = lo.y * ld.y + lo.z * ld.z;
                    let c = lo.y * lo.y + lo.z * lo.z - r * r;
                    let disc = b * b - a * c;
                    if disc >= 0.0 {
                        let sq = disc.sqrt();
                        for t in [(-b - sq) / a, (-b + sq) / a] {
                            if t >= tmin && t <= tmax {
                                let p = lo + ld * t;
                                if p.x.abs() <= h.x {
                                    if best.map_or(true, |(bt, _)| t < bt) {
                                        best = Some((t, self.n_world(V3::new(0.0, p.y, p.z))));
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
                if ld.x.abs() > 1e-12 {
                    for sx in [-1.0f32, 1.0] {
                        let t = (sx * h.x - lo.x) / ld.x;
                        if t >= tmin && t <= tmax {
                            let p = lo + ld * t;
                            if p.y * p.y + p.z * p.z <= r * r && best.map_or(true, |(bt, _)| t < bt) {
                                best = Some((t, self.n_world(V3::new(sx, 0.0, 0.0))));
                            }
                        }
                    }
                }
                best
            }
            _ => {
                // Convex polytope: box slabs, plus slope plane(s) for wedges.
                let mut t0 = tmin;
                let mut t1 = tmax;
                let mut n0 = V3::default();
                let mut planes: [(V3, f32); 8] = [(V3::default(), 0.0); 8];
                let mut np = 0;
                planes[np] = (V3::new(1.0, 0.0, 0.0), h.x);
                np += 1;
                planes[np] = (V3::new(-1.0, 0.0, 0.0), h.x);
                np += 1;
                planes[np] = (V3::new(0.0, 1.0, 0.0), h.y);
                np += 1;
                planes[np] = (V3::new(0.0, -1.0, 0.0), h.y);
                np += 1;
                planes[np] = (V3::new(0.0, 0.0, 1.0), h.z);
                np += 1;
                planes[np] = (V3::new(0.0, 0.0, -1.0), h.z);
                np += 1;
                if self.kind == 1 || self.kind == 4 {
                    // Wedge: full height at back (+Z), zero height at front (-Z).
                    // Solid where (y+hy)/(2hy) <= (z+hz)/(2hz)  <=>  hz*y - hy*z <= 0
                    let n = V3::new(0.0, h.z, -h.y).norm();
                    planes[np] = (n, 0.0);
                    np += 1;
                }
                if self.kind == 4 {
                    // Corner wedge approximation: also slope along X.
                    let n = V3::new(h.y, h.x, 0.0).norm();
                    planes[np] = (n, 0.0);
                    np += 1;
                }
                for &(n, dist) in planes.iter().take(np) {
                    let denom = n.dot(ld);
                    let num = dist - n.dot(lo);
                    if denom.abs() < 1e-12 {
                        if num < 0.0 {
                            return None;
                        }
                        continue;
                    }
                    let t = num / denom;
                    if denom < 0.0 {
                        if t > t0 {
                            t0 = t;
                            n0 = n;
                        }
                    } else if t < t1 {
                        t1 = t;
                    }
                    if t0 > t1 {
                        return None;
                    }
                }
                if t0 <= tmin + 1e-6 && n0.len() < 0.5 {
                    return None; // ray starts inside
                }
                Some((t0, self.n_world(n0)))
            }
        }
    }
}

struct Bvh {
    nodes: Vec<Node>,
    idx: Vec<usize>,
}
#[derive(Clone, Copy)]
struct Node {
    lo: V3,
    hi: V3,
    left: usize, // if count>0: first index into idx; else child index
    count: usize,
}

fn build_bvh(prims: &[Prim]) -> Bvh {
    let mut idx: Vec<usize> = (0..prims.len()).collect();
    let mut nodes = Vec::with_capacity(prims.len() * 2);
    nodes.push(Node { lo: V3::default(), hi: V3::default(), left: 0, count: 0 });
    fn rec(prims: &[Prim], idx: &mut [usize], offset: usize, nodes: &mut Vec<Node>, ni: usize) {
        let mut lo = V3::new(f32::MAX, f32::MAX, f32::MAX);
        let mut hi = V3::new(f32::MIN, f32::MIN, f32::MIN);
        let mut clo = lo;
        let mut chi = hi;
        for &i in idx.iter() {
            lo = lo.min(prims[i].lo);
            hi = hi.max(prims[i].hi);
            let c = (prims[i].lo + prims[i].hi) * 0.5;
            clo = clo.min(c);
            chi = chi.max(c);
        }
        nodes[ni].lo = lo;
        nodes[ni].hi = hi;
        if idx.len() <= 4 {
            nodes[ni].left = offset;
            nodes[ni].count = idx.len();
            return;
        }
        let ext = chi - clo;
        let axis = if ext.x > ext.y && ext.x > ext.z { 0 } else if ext.y > ext.z { 1 } else { 2 };
        idx.sort_by(|&a, &b| {
            let ca = (prims[a].lo.get(axis) + prims[a].hi.get(axis)) * 0.5;
            let cb = (prims[b].lo.get(axis) + prims[b].hi.get(axis)) * 0.5;
            ca.partial_cmp(&cb).unwrap_or(std::cmp::Ordering::Equal)
        });
        let mid = idx.len() / 2;
        let l = nodes.len();
        nodes.push(Node { lo, hi, left: 0, count: 0 });
        nodes.push(Node { lo, hi, left: 0, count: 0 });
        nodes[ni].left = l;
        nodes[ni].count = 0;
        let (a, b) = idx.split_at_mut(mid);
        rec(prims, a, offset, nodes, l);
        rec(prims, b, offset + mid, nodes, l + 1);
    }
    let n = idx.len();
    if n > 0 {
        rec(prims, &mut idx[..], 0, &mut nodes, 0);
    }
    Bvh { nodes, idx }
}

fn aabb_hit(lo: V3, hi: V3, o: V3, inv: V3, tmax: f32) -> bool {
    let mut t0 = 0.0f32;
    let mut t1 = tmax;
    for a in 0..3 {
        let ta = (lo.get(a) - o.get(a)) * inv.get(a);
        let tb = (hi.get(a) - o.get(a)) * inv.get(a);
        let (tn, tf) = if ta < tb { (ta, tb) } else { (tb, ta) };
        t0 = t0.max(tn);
        t1 = t1.min(tf);
        if t0 > t1 {
            return false;
        }
    }
    true
}

struct Scene {
    prims: Vec<Prim>,
    bvh: Bvh,
    lights: Vec<LightIn>,
    light_grid: std::collections::HashMap<(i32, i32, i32), Vec<usize>>,
    sun_dir: V3,
    sun_col: V3,
    amb: V3,
    outdoor: V3,
    sky: V3,
}

const CELL: f32 = 32.0;

impl Scene {
    /// Nearest hit. `skip` filters primitives (used for clip planes / shadow transparency).
    fn trace(&self, o: V3, d: V3, tmax: f32, skip: &dyn Fn(&Prim) -> bool) -> Option<(f32, usize, V3)> {
        let inv = V3::new(1.0 / d.x, 1.0 / d.y, 1.0 / d.z);
        let mut best: Option<(f32, usize, V3)> = None;
        let mut limit = tmax;
        let mut stack = [0usize; 128];
        let mut sp = 1;
        stack[0] = 0;
        while sp > 0 {
            sp -= 1;
            let n = self.bvh.nodes[stack[sp]];
            if !aabb_hit(n.lo, n.hi, o, inv, limit) {
                continue;
            }
            if n.count > 0 {
                for k in n.left..n.left + n.count {
                    let pi = self.bvh.idx[k];
                    let p = &self.prims[pi];
                    if skip(p) {
                        continue;
                    }
                    if let Some((t, nn)) = p.intersect(o, d, 1e-3, limit) {
                        limit = t;
                        best = Some((t, pi, nn));
                    }
                }
            } else if sp + 2 <= stack.len() {
                stack[sp] = n.left;
                stack[sp + 1] = n.left + 1;
                sp += 2;
            }
        }
        best
    }

    fn occluded(&self, o: V3, d: V3, tmax: f32) -> bool {
        self.trace(o, d, tmax, &|p: &Prim| p.transp >= 0.45).is_some()
    }

    fn shade(&self, o: V3, d: V3, depth: u32, clip: Option<f32>, rng: &mut u32) -> V3 {
        let skip = |p: &Prim| p.transp >= 0.98 || clip.map_or(false, |c| p.lo.y > c);
        let hit = self.trace(o, d, 6000.0, &skip);
        let Some((t, pi, mut n)) = hit else {
            // simple sky gradient
            let up = d.y.max(0.0);
            return self.sky * (0.85 + 0.3 * up) + V3::new(0.06, 0.05, 0.03) * (1.0 - up);
        };
        let p = &self.prims[pi];
        if n.dot(d) > 0.0 {
            n = -n;
        }
        let hp = o + d * t;
        let base = p.color;
        let mut col;
        if p.neon {
            col = base * 1.6;
        } else {
            // sun
            let ndl = n.dot(self.sun_dir).max(0.0);
            let mut sun = V3::default();
            if ndl > 0.0 && !self.occluded(hp + n * 0.02, self.sun_dir, 4000.0) {
                sun = self.sun_col * ndl;
            }
            // hemisphere ambient with 3 occlusion probes
            let mut vis = 0.0;
            for _ in 0..3 {
                let r = rand_hemi(n, rng);
                if !self.occluded(hp + n * 0.02, r, 70.0) {
                    vis += 1.0 / 3.0;
                }
            }
            let hemi = 0.65 + 0.35 * n.y.max(-1.0);
            let amb = (self.amb * (1.0 - vis) + self.outdoor * vis) * hemi;
            // local lights
            let mut loc = V3::default();
            let key = ((hp.x / CELL).floor() as i32, (hp.y / CELL).floor() as i32, (hp.z / CELL).floor() as i32);
            if let Some(list) = self.light_grid.get(&key) {
                for &li in list {
                    let l = &self.lights[li];
                    let lp = V3::new(l.p[0], l.p[1], l.p[2]);
                    let tl = lp - hp;
                    let dist = tl.len();
                    if dist > l.r || dist < 1e-3 {
                        continue;
                    }
                    let ld = tl * (1.0 / dist);
                    let mut ndl = n.dot(ld).max(0.0);
                    if ndl <= 0.0 {
                        continue;
                    }
                    if let Some(dir) = l.d {
                        let dv = V3::new(dir[0], dir[1], dir[2]).norm();
                        let cosang = (-ld).dot(dv);
                        let half = (l.a.unwrap_or(90.0) * 0.5).to_radians().cos();
                        if cosang < half {
                            continue;
                        }
                        ndl *= ((cosang - half) / (1.0 - half + 1e-3)).clamp(0.0, 1.0).sqrt();
                    }
                    let fall = (1.0 - dist / l.r).max(0.0);
                    let c = V3::new(l.c[0], l.c[1], l.c[2]);
                    loc = loc + c * (l.b * 0.55 * ndl * fall * fall);
                }
            }
            col = base.mul(sun + amb + loc);
            // cheap specular / reflection
            let spec_amt = if p.metal { 0.25 } else { 0.06 } + p.refl * 0.6;
            if spec_amt > 0.0 {
                let refl_dir = d - n * (2.0 * d.dot(n));
                let s = refl_dir.dot(self.sun_dir).max(0.0).powf(40.0);
                col = col + self.sun_col * (s * spec_amt);
                if p.refl > 0.25 && depth < 2 {
                    let rc = self.shade(hp + n * 0.02, refl_dir, depth + 1, None, rng);
                    col = col * (1.0 - p.refl * 0.7) + rc * (p.refl * 0.7);
                }
            }
        }
        if p.transp > 0.02 && depth < 4 {
            let behind = self.shade(hp + d * 0.03, d, depth + 1, clip, rng);
            col = col * (1.0 - p.transp) + behind * p.transp;
        }
        col
    }
}

fn rand_hemi(n: V3, rng: &mut u32) -> V3 {
    let mut next = || {
        *rng ^= *rng << 13;
        *rng ^= *rng >> 17;
        *rng ^= *rng << 5;
        (*rng as f32) / (u32::MAX as f32)
    };
    loop {
        let v = V3::new(next() * 2.0 - 1.0, next() * 2.0 - 1.0, next() * 2.0 - 1.0);
        let l = v.len();
        if l > 0.05 && l <= 1.0 {
            let v = v.norm();
            return if v.dot(n) < 0.0 { -v } else { v };
        }
    }
}

fn tonemap(c: V3) -> [u8; 3] {
    let f = |x: f32| {
        let x = x.max(0.0);
        let mapped = x * (1.0 + x / 4.0) / (1.0 + x);
        (mapped.powf(1.0 / 2.2) * 255.0).clamp(0.0, 255.0) as u8
    };
    [f(c.x), f(c.y), f(c.z)]
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        eprintln!("usage: ironhaven-render <dump.json> <cameras.json> <out_dir> [camera]");
        std::process::exit(2);
    }
    let dump: Dump = serde_json::from_str(&fs::read_to_string(&args[1]).expect("read dump")).expect("parse dump");
    let cams: Vec<Cam> = serde_json::from_str(&fs::read_to_string(&args[2]).expect("read cams")).expect("parse cams");
    let only = args.get(4).cloned();
    fs::create_dir_all(&args[3]).ok();

    let mut prims = Vec::with_capacity(dump.parts.len());
    for p in &dump.parts {
        let cf = p.cf;
        let pos = V3::new(cf[0], cf[1], cf[2]);
        let rx = V3::new(cf[3], cf[6], cf[9]);
        let ry = V3::new(cf[4], cf[7], cf[10]);
        let rz = V3::new(cf[5], cf[8], cf[11]);
        let half = V3::new(p.sz[0] * 0.5, p.sz[1] * 0.5, p.sz[2] * 0.5);
        let ext = V3::new(
            rx.x.abs() * half.x + ry.x.abs() * half.y + rz.x.abs() * half.z,
            rx.y.abs() * half.x + ry.y.abs() * half.y + rz.y.abs() * half.z,
            rx.z.abs() * half.x + ry.z.abs() * half.y + rz.z.abs() * half.z,
        );
        let m = p.m.as_str();
        prims.push(Prim {
            kind: p.s,
            pos,
            rx,
            ry,
            rz,
            half,
            color: V3::new(p.c[0].powf(2.2), p.c[1].powf(2.2), p.c[2].powf(2.2)),
            transp: p.t,
            refl: p.rf,
            neon: m == "Neon",
            metal: matches!(m, "Metal" | "DiamondPlate" | "Foil" | "CorrodedMetal"),
            lo: pos - ext,
            hi: pos + ext,
        });
    }
    let bvh = build_bvh(&prims);
    let mut light_grid: std::collections::HashMap<(i32, i32, i32), Vec<usize>> = Default::default();
    for (i, l) in dump.lights.iter().enumerate() {
        let r = l.r;
        let (x0, x1) = (((l.p[0] - r) / CELL).floor() as i32, ((l.p[0] + r) / CELL).floor() as i32);
        let (y0, y1) = (((l.p[1] - r) / CELL).floor() as i32, ((l.p[1] + r) / CELL).floor() as i32);
        let (z0, z1) = (((l.p[2] - r) / CELL).floor() as i32, ((l.p[2] + r) / CELL).floor() as i32);
        for x in x0..=x1 {
            for y in y0..=y1 {
                for z in z0..=z1 {
                    light_grid.entry((x, y, z)).or_default().push(i);
                }
            }
        }
    }
    let lin = |c: [f32; 3]| V3::new(c[0], c[1], c[2]);
    let scene = Scene {
        prims,
        bvh,
        lights: dump.lights,
        light_grid,
        sun_dir: lin(dump.sun.dir).norm(),
        sun_col: lin(dump.sun.color),
        amb: lin(dump.sun.ambient),
        outdoor: lin(dump.sun.outdoor),
        sky: lin(dump.sun.sky),
    };
    eprintln!("scene: {} prims, {} lights", scene.prims.len(), scene.lights.len());

    for cam in cams {
        if let Some(o) = &only {
            if &cam.name != o {
                continue;
            }
        }
        let (w, h) = (cam.w, cam.h);
        let ss = 2u32;
        let pixels: Vec<[u8; 3]> = (0..(w * h))
            .into_par_iter()
            .map(|i| {
                let px = i % w;
                let py = i / w;
                let mut acc = V3::default();
                let mut rng: u32 = (i.wrapping_mul(2654435761)) | 1;
                for sy in 0..ss {
                    for sx in 0..ss {
                        let u = (px as f32 + (sx as f32 + 0.5) / ss as f32) / w as f32;
                        let v = (py as f32 + (sy as f32 + 0.5) / ss as f32) / h as f32;
                        let c = if cam.mode == "ortho" {
                            let x = cam.center[0] + (u - 0.5) * cam.extent[0];
                            let z = cam.center[1] + (v - 0.5) * cam.extent[1];
                            let o = V3::new(x, cam.clip, z);
                            let mut c = scene.shade(o, V3::new(0.0, -1.0, 0.0001), 0, Some(cam.clip), &mut rng);
                            // 20-stud grid for scale
                            let gx = (x / 20.0).fract().abs();
                            let gz = (z / 20.0).fract().abs();
                            if gx < 0.012 || gz < 0.012 {
                                c = c * 0.82;
                            }
                            if let Some(fl) = cam.floor {
                                let _ = fl;
                            }
                            c
                        } else {
                            let pos = lin(cam.pos);
                            let fwd = (lin(cam.look) - pos).norm();
                            let right = fwd.cross(V3::new(0.0, 1.0, 0.0)).norm();
                            let up = right.cross(fwd);
                            let tanf = (cam.fov.to_radians() * 0.5).tan();
                            let aspect = w as f32 / h as f32;
                            let dx = (u * 2.0 - 1.0) * tanf * aspect;
                            let dy = (1.0 - v * 2.0) * tanf;
                            let d = (fwd + right * dx + up * dy).norm();
                            scene.shade(pos, d, 0, None, &mut rng)
                        };
                        acc = acc + c;
                    }
                }
                tonemap(acc * (1.0 / (ss * ss) as f32))
            })
            .collect();
        let mut img = image::RgbImage::new(w, h);
        for (i, p) in pixels.iter().enumerate() {
            img.put_pixel(i as u32 % w, i as u32 / w, image::Rgb(*p));
        }
        let out = format!("{}/{}.png", args[3], cam.name);
        img.save(&out).expect("save png");
        eprintln!("wrote {out}");
    }
}
