/* ==========================================================================
   ARCHER 名字戒指 —— 参数化模型
   ==========================================================================
   打印机 : Bambu Lab A1 mini (FDM, 0.4mm 喷头)
   摆放   : 平放（戒指轴向竖直）。这样文字全部是垂直棱柱，Z 方向没有悬垂面，
            不需要开支撑；立着放则下半圈整体是悬垂，必崩。
   字重   : 必须粗体。实测字高 5.5mm 时 Arial Bold 竖笔画约 1.07mm，
            约等于 2.5 条挤出线，打印不会断线；常规字重只有约 0.65mm。

   ---------------------------------------------------------------------------
   重要：本文件用到 textmetrics()，它是 OpenSCAD 的实验性内置函数。
     · 命令行：openscad --enable=textmetrics -o ring.stl ring.scad
     · 图形界面：编辑 → 首选项 → 功能(Features) → 勾选 textmetrics，
                 否则打开本文件会报 "unknown function 'textmetrics'"。
     如果没启用，脚本会自动回退到文件内烘焙好的字宽表（见 W1），
     仍然能正确出图，只是不再随字体变化自动适配。

   如果换了字体，请重新标定 CAP_PER_SIZE（见下方说明）。
   ========================================================================== */

// ---------------------------- 可调参数 ----------------------------
INNER_D = 18;        // 内径 (mm)
WALL    = 2.5;       // 壁厚 (mm)
BAND    = 8;         // 带宽 (mm)
CHAMFER = 0.4;       // 上下外棱倒角 (mm)

TEXT    = "ARCHER";           // 要刻的字（支持任意字符串）
CAP     = 5.5;                // 字高：大写字母实际高度 (mm)
FONT    = "Arial:style=Bold"; // 粗体，勿改成常规字重
EMBOSS  = 0.6;                // 文字凸起高度 (mm)
EMBED   = 0.8;                // 文字嵌进环体的深度 (mm)，必须足够大，
                              // 否则字符两端会与环体脱开

FN      = 360;               // 环体圆周细分

// 标定值：字高 / text(size=) 的实测比值。
// 在本机 Arial Bold 上用 calib.scad 实测得到：size=10 时字高 = 9.941mm。
// 换字体后请重测，方法：渲染 calib.scad，量 H 的 Y 方向包围盒高度 / size。
CAP_PER_SIZE = 0.9941;

ONLY = 0;   // 0=整体 1=只要环体 2=只要文字（分件校验用）

// ---------------------------- 推导值 ----------------------------
R_IN  = INNER_D / 2;
R_OUT = R_IN + WALL;
FS    = CAP / CAP_PER_SIZE;   // 字号 = 字高 / 标定比
R_TXT = R_OUT - EMBED;        // 文字背面所在半径
Z_MID = BAND / 2;
DEPTH = EMBOSS + EMBED;       // 挤出深度；前面所在半径恰好 = R_OUT + EMBOSS

$fa = 2;
$fs = 0.2;

// ---------------------------- 环体 ----------------------------
module band() {
    rotate_extrude(angle = 360, $fn = FN)
        polygon(points = [
            [R_IN,            0],
            [R_OUT - CHAMFER, 0],
            [R_OUT,           CHAMFER],
            [R_OUT,           BAND - CHAMFER],
            [R_OUT - CHAMFER, BAND],
            [R_IN,            BAND],
        ]);
}

// ---------------------------- 文字 ----------------------------
chars = [for (i = [0 : len(TEXT) - 1]) TEXT[i]];

// --- 字宽表：Arial Bold 在本机实测，size=1 时的 advance ---
// 仅作 textmetrics 不可用时的回退。数值已核对过 Arial Bold 标准度量
// （E/A = 0.9236 对 667/722 = 0.9238，W/A = 1.307 对 944/722 = 1.3075）。
W1 = [
    [" ", 0.38588], ["A", 1.00301], ["B", 1.00301], ["C", 1.00301],
    ["D", 1.00301], ["E", 0.92638], ["F", 0.84839], ["G", 1.08032],
    ["H", 1.00301], ["I", 0.38588], ["J", 0.77243], ["K", 1.00301],
    ["L", 0.84839], ["M", 1.15696], ["N", 1.00301], ["O", 1.08032],
    ["P", 0.92638], ["Q", 1.08032], ["R", 1.00301], ["S", 0.92638],
    ["T", 0.84839], ["U", 1.00301], ["V", 0.92638], ["W", 1.31090],
    ["X", 0.92638], ["Y", 0.92638], ["Z", 0.84839], ["a", 0.77243],
    ["b", 0.84839], ["c", 0.77243], ["d", 0.84839], ["e", 0.77243],
    ["f", 0.46251], ["g", 0.84839], ["h", 0.84839], ["i", 0.38588],
    ["j", 0.38588], ["k", 0.77243], ["l", 0.38588], ["m", 1.23495],
    ["n", 0.84839], ["o", 0.84839], ["p", 0.84839], ["q", 0.84839],
    ["r", 0.54050], ["s", 0.77243], ["t", 0.46251], ["u", 0.84839],
    ["v", 0.77243], ["w", 1.08032], ["x", 0.77243], ["y", 0.77243],
    ["z", 0.69445], ["0", 0.77243], ["1", 0.77243], ["2", 0.77243],
    ["3", 0.77243], ["4", 0.77243], ["5", 0.77243], ["6", 0.77243],
    ["7", 0.77243], ["8", 0.77243], ["9", 0.77243], [".", 0.38588],
    [",", 0.38588], ["-", 0.46251], ["_", 0.77243], ["+", 0.81109],
    ["&", 1.00301], ["!", 0.46251], ["?", 0.84839],
];

function w1(c, i = 0) =
    i >= len(W1) ? 0.75
  : W1[i][0] == c ? W1[i][1]
  : w1(c, i + 1);

// 探测 textmetrics 是否可用（未启用时返回 undef）
TM     = textmetrics("H", size = 1, font = FONT);
HAS_TM = !is_undef(TM);

adv = [for (c = chars)
           HAS_TM ? textmetrics(c, size = FS, font = FONT).advance[0]
                  : w1(c) * FS];

function cumsum(v, i = 0, acc = 0) =
    i >= len(v) ? [] : concat([acc], cumsum(v, i + 1, acc + v[i]));

function total(v, i = 0) =
    i >= len(v) ? 0 : v[i] + total(v, i + 1);

off = cumsum(adv);
TOT = total(adv);

// 出图时打印关键尺寸，方便核对（不参与几何）
echo(TEXTMETRICS_AVAILABLE = HAS_TM);
echo(FONT_SIZE = FS);
echo(TEXT_TOTAL_WIDTH_MM = TOT);
echo(TEXT_SPAN_DEG = TOT / R_TXT * 180 / PI);
echo(MAX_RADIUS_MM = R_OUT + EMBOSS);

// 每个字符单独放置；角度按"弧长 = 字距"分配，保证字符间距均匀。
module glyph(ch, xoff) {
    ang = xoff / R_TXT * 180 / PI;
    rotate([0, 0, ang])
        translate([0, -R_TXT, Z_MID])
            rotate([90, 0, 0])
                linear_extrude(height = DEPTH)
                    text(ch, size = FS, font = FONT,
                         halign = "center", valign = "center");
}

module name_text() {
    for (i = [0 : len(chars) - 1])
        glyph(chars[i], off[i] + adv[i] / 2 - TOT / 2);
}

// ---------------------------- 总装 ----------------------------
if (ONLY == 0) {
    union() { band(); name_text(); }
} else if (ONLY == 1) {
    band();
} else {
    name_text();
}
