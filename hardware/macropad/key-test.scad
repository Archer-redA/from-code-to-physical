/* ==========================================================================
   单键柔性机构测试片 —— 一体打印，无组装，无支撑
   ==========================================================================
   目的：在做整机之前，先验证「桥式柔性梁」这个机构能不能成立。

   核心思路（解决打印与运动的矛盾）：
     柔性梁两端都搭在实体墙上，中间悬空。
       · 打印时 —— 它是一段桥，两端有支撑，桥接没问题
       · 受力时 —— 它是一根两端固定的梁，中间能下沉、能回弹
     这样既不用支撑，又能动。

   一片上放三个变体，一次打印验证三种刚度，比打三次省时间。

   力学依据（两端固定梁，中央集中载荷）：
     刚度      k = 192·E·I / L³        I = b·t³/12
     最大应变  ε = 12·t·δ / L²         （应变在两端的固定处最大）
   导出值会打在控制台上，出图时对照。

   打印要求：
     · 层高 0.2mm（梁厚必须是层高的整数倍，否则实际厚度不由你控制）
     · 支撑：关闭
     · 摆放：平放，和脚本朝向一致，不要旋转
   ========================================================================== */

// ---------------------------- 可调参数 ----------------------------
SPAN    = 30;     // 自由跨距 mm —— 桥接长度，也是柔性梁的有效长度
WALL_T  = 6;      // 两端墙厚度 mm
WALL_H  = 12;     // 墙高 mm
UNIT_W  = 22;     // 单片宽度 mm
GAP     = 6;      // 变体之间的间隔 mm
FLOOR_T = 2;      // 底板厚度 mm —— 让止挡柱有根，否则它会变成散件

BEAM_Y  = 5.5;    // 两根梁的中心距中轴 mm
BEAM_Z  = 8;      // 梁底面高度 mm（下方全空，靠桥接打印）

PLAT    = 16;     // 浮动平台边长 mm
PLAT_T  = 2;      // 平台厚度 mm
KEY     = 13;     // 键帽边长 mm
KEY_H   = 5;      // 键帽高度 mm

TRAVEL  = 1.5;    // 设计行程 mm —— 由止挡柱限制，防止按压过度把梁压坏
STOP    = 3;      // 止挡柱截面 mm

CUT     = 0;      // 1 = 沿中轴剖开，用于展示内部机构（只影响预览，不影响出图）

E_PLA   = 3500;   // PLA 弹性模量 MPa

// [梁厚 t, 梁宽 b]
VARIANTS = [
    [0.6, 3.0],   // A 基准
    [0.4, 3.0],   // B 更薄 -> 最软
    [0.6, 1.5],   // C 更窄 -> 中等
];
LABELS = ["A", "B", "C"];

LEN = 2 * WALL_T + SPAN;
TOTAL_LEN = len(VARIANTS) * LEN + (len(VARIANTS) - 1) * GAP;

$fa = 2;
$fs = 0.2;

// ---------------------------- 工具 ----------------------------
module box(x0, y0, z0, x1, y1, z1) {
    translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);
}

// ---------------------------- 一个变体 ----------------------------
module unit(bt, bw) {
    // 底板：本身不参与机构，只负责把止挡柱连成一体
    // 梁在 z=BEAM_Z 处下沉最多 TRAVEL，与底板顶面(z=FLOOR_T)之间留有大余量
    box(0, 0, 0, LEN, UNIT_W, FLOOR_T);

    // 墙体
    box(0, 0, 0, WALL_T, UNIT_W, WALL_H);
    box(WALL_T + SPAN, 0, 0, LEN, UNIT_W, WALL_H);

    // 两根柔性梁：两端搭在墙上，中间悬空 -> 打印时是桥，受力时是固定梁
    for (s = [1, -1]) {
        box(WALL_T, UNIT_W / 2 + s * BEAM_Y - bw / 2, BEAM_Z,
            WALL_T + SPAN, UNIT_W / 2 + s * BEAM_Y + bw / 2, BEAM_Z + bt);
    }

    // 止挡柱：从底板上长出来，柱顶与平台底面之间正好留出 TRAVEL
    // 这样按压到底会被硬性挡住，梁的应变不会超过设计值
    box(WALL_T + SPAN / 2 - STOP / 2, UNIT_W / 2 - STOP / 2, FLOOR_T,
        WALL_T + SPAN / 2 + STOP / 2, UNIT_W / 2 + STOP / 2, BEAM_Z + bt - TRAVEL);

    // 浮动平台：坐在两根梁上，两梁之间跨 9mm，桥接可打
    box(WALL_T + SPAN / 2 - PLAT / 2, UNIT_W / 2 - PLAT / 2, BEAM_Z + bt,
        WALL_T + SPAN / 2 + PLAT / 2, UNIT_W / 2 + PLAT / 2, BEAM_Z + bt + PLAT_T);

    // 键帽
    box(WALL_T + SPAN / 2 - KEY / 2, UNIT_W / 2 - KEY / 2, BEAM_Z + bt + PLAT_T,
        WALL_T + SPAN / 2 + KEY / 2, UNIT_W / 2 + KEY / 2, BEAM_Z + bt + PLAT_T + KEY_H);
}

// ---------------------------- 总装 ----------------------------
module all() {
    for (i = [0 : len(VARIANTS) - 1]) {
        translate([i * (LEN + GAP), 0, 0])
            unit(VARIANTS[i][0], VARIANTS[i][1]);
    }
}

if (CUT == 1) {
    // 沿中轴剖开，露出梁、平台、止挡柱的相互关系
    intersection() {
        all();
        box(-1, -1, -1, TOTAL_LEN + 1, UNIT_W / 2, 100);
    }
} else {
    all();
}

// ---------------------------- 力学输出 ----------------------------
echo("=== 设计参数 ===");
echo(SPAN = SPAN, TRAVEL = TRAVEL, BEAM_Z = BEAM_Z);
echo(TOTAL_LEN = TOTAL_LEN, TOTAL_W = UNIT_W);
echo("");
echo("=== 各变体力学（E_PLA = 3500 MPa）===");
for (i = [0 : len(VARIANTS) - 1]) {
    bt = VARIANTS[i][0];
    bw = VARIANTS[i][1];
    I  = bw * pow(bt, 3) / 12;
    kb = 192 * E_PLA * I / pow(SPAN, 3);   // 单根梁刚度
    kt = 2 * kb;                            // 两根梁并联
    F  = kt * TRAVEL;                       // 压到底需要的力
    ep = 12 * bt * TRAVEL / pow(SPAN, 2);   // 最大应变
    // 达到 1.5% 应变（PLA 反复弯曲的安全上限）对应的行程
    dmax = 0.015 * pow(SPAN, 2) / (12 * bt);
    echo(str("变体 ", LABELS[i],
             "  t=", bt, "mm b=", bw, "mm",
             "  | 厚度层数=", bt / 0.2,
             "  | k=", kt, " N/mm",
             "  | 压到底需 ", F, " N",
             "  | 应变@", TRAVEL, "mm = ", ep * 100, "%",
             "  | 应变达1.5%时行程 ", dmax, "mm"));
}
