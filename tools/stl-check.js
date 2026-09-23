#!/usr/bin/env node
/*
 * stl-check.js —— STL 网格校验工具
 * ---------------------------------------------------------------------------
 * 打印之前先跑一遍。切片软件对非水密网格的处理各不相同，可能是静默修补，
 * 也可能是"凭空多一层墙"，还可能是直接报错。在源头验掉最省事。
 *
 * 检查项：
 *   1. 包围盒与尺寸        —— 确认模型实际多大，别信设计值
 *   2. 体积                —— 用来估算耗材重量
 *   3. 开边(open edges)    —— 有洞就不水密，必须为 0
 *   4. 非流形边            —— 一条边被 3 个以上三角形共用，必须为 0
 *   5. 退化三角形          —— 面积为零的三角形，必须为 0
 *
 * 用法：
 *   node stl-check.js <文件.stl> [顶点合并精度]
 *
 * 精度参数默认 0.000001。**不要调大**：调成 0.001 会把两个相距不到
 * 0.001mm 但确实不同的顶点合并成一个，从而报出根本不存在的非流形边。
 */

const fs = require('fs');

function readSTL(file) {
  const buf = fs.readFileSync(file);
  let isBinary = false;
  let n = 0;
  if (buf.length >= 84) {
    n = buf.readUInt32LE(80);
    if (buf.length === 84 + n * 50) isBinary = true;
  }
  const tris = [];
  if (isBinary) {
    for (let i = 0; i < n; i++) {
      const off = 84 + i * 50 + 12; // 跳过法向量
      const v = [];
      for (let k = 0; k < 3; k++) {
        const p = off + k * 12;
        v.push([buf.readFloatLE(p), buf.readFloatLE(p + 4), buf.readFloatLE(p + 8)]);
      }
      tris.push(v);
    }
    return { tris, format: '二进制' };
  }
  const txt = buf.toString('utf8');
  const vlines = txt.split(/\r?\n/).filter((l) => /^\s*vertex\s/i.test(l));
  const vv = vlines.map((l) => {
    const m = l.trim().split(/\s+/);
    return [parseFloat(m[1]), parseFloat(m[2]), parseFloat(m[3])];
  });
  for (let i = 0; i + 2 < vv.length; i += 3) tris.push([vv[i], vv[i + 1], vv[i + 2]]);
  return { tris, format: 'ASCII' };
}

const PREC = parseFloat(process.argv[3] || '0.000001');
// 预期连通分量数。默认为 1：一体打印的零件必须是连通的一整块。
// 测试板（一片上放多个独立试件）把它改成实际数量。
const EXPECT_COMPONENTS = parseInt(process.argv[4] || '1', 10);

function key(p, q) {
  const inv = 1 / PREC;
  const r = (x) => Math.round(x * inv) / inv;
  const a = r(p[0]) + ',' + r(p[1]) + ',' + r(p[2]);
  const b = r(q[0]) + ',' + r(q[1]) + ',' + r(q[2]);
  return a < b ? a + '|' + b : b + '|' + a;
}

const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const len = (a) => Math.sqrt(dot(a, a));

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('用法: node stl-check.js <文件.stl> [顶点合并精度]');
    process.exit(1);
  }
  if (!fs.existsSync(file)) {
    console.error('文件不存在: ' + file);
    process.exit(1);
  }

  const { tris, format } = readSTL(file);
  const lo = [Infinity, Infinity, Infinity];
  const hi = [-Infinity, -Infinity, -Infinity];
  let volume = 0;
  let area = 0;
  let degenerate = 0;

  for (const t of tris) {
    for (const v of t) {
      for (let k = 0; k < 3; k++) {
        if (v[k] < lo[k]) lo[k] = v[k];
        if (v[k] > hi[k]) hi[k] = v[k];
      }
    }
    volume += dot(t[0], cross(t[1], t[2])) / 6;
    const a2 = len(cross(sub(t[1], t[0]), sub(t[2], t[0])));
    if (a2 < 1e-9) degenerate++;
    area += a2 / 2;
  }

  const edges = new Map();
  for (const t of tris) {
    for (let i = 0; i < 3; i++) {
      const k = key(t[i], t[(i + 1) % 3]);
      edges.set(k, (edges.get(k) || 0) + 1);
    }
  }
  let open = 0;
  let nonManifold = 0;
  for (const c of edges.values()) {
    if (c === 1) open++;
    else if (c > 2) nonManifold++;
  }

  const size = [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]];
  const r = (x) => Math.round(x * 1000) / 1000;
  const vol = Math.abs(volume);

  // --- 连通分量（并查集：共享顶点的三角形归为同一分量）---
  // 一体打印的零件必须是连通的一整块。分离的壳体会变成打出来掉在里面的散件，
  // 而切片软件不会为此报警 —— 它照样能切片，只是你不知道多了一个零件。
  const vKey = (p) => {
    const inv = 1 / PREC;
    return (Math.round(p[0] * inv) / inv) + ',' + (Math.round(p[1] * inv) / inv) + ',' + (Math.round(p[2] * inv) / inv);
  };
  const parent = tris.map((_, i) => i);
  const find = (x) => { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; };
  const union = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) parent[ra] = rb; };
  const owner = new Map();
  tris.forEach((t, i) => {
    for (const v of t) {
      const k = vKey(v);
      if (owner.has(k)) union(i, owner.get(k));
      else owner.set(k, i);
    }
  });
  const compSize = new Map();
  for (let i = 0; i < tris.length; i++) {
    const root = find(i);
    compSize.set(root, (compSize.get(root) || 0) + 1);
  }
  const sizes = [...compSize.values()].sort((a, b) => b - a);
  const nComp = sizes.length;

  console.log('文件        : ' + file);
  console.log('格式        : ' + format);
  console.log('三角形      : ' + tris.length);
  console.log('包围盒 min  : ' + lo.map(r).join(', '));
  console.log('包围盒 max  : ' + hi.map(r).join(', '));
  console.log('尺寸 (mm)   : X=' + r(size[0]) + '  Y=' + r(size[1]) + '  Z=' + r(size[2]));
  console.log('体积 (mm³)  : ' + r(vol));
  console.log('表面积(mm²) : ' + r(area));
  console.log('耗材估算    : ' + (vol / 1000 * 1.24).toFixed(2) + ' g  (PLA, 1.24 g/cm³)');
  console.log('开边        : ' + open + (open ? '   <-- 有洞，不水密' : ''));
  console.log('非流形边    : ' + nonManifold + (nonManifold ? '   <-- 有问题' : ''));
  console.log('退化三角形  : ' + degenerate);
  console.log('连通分量    : ' + nComp
    + (nComp === EXPECT_COMPONENTS
        ? '（符合预期 ' + EXPECT_COMPONENTS + '）'
        : '   <-- 与预期 ' + EXPECT_COMPONENTS + ' 不符')
    + (nComp > 1 ? '  各分量三角形数: ' + sizes.join(' + ') : ''));

  const ok = open === 0 && nonManifold === 0 && degenerate === 0 && tris.length > 0
             && nComp === EXPECT_COMPONENTS;
  console.log('结论        : ' + (ok ? '通过 —— 水密流形，可以打印' : '不通过'));
  process.exit(ok ? 0 : 2);
}

main();
