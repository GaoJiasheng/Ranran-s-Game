"""七巧板的精确几何（给作图、校验、导出用）。

单位：大正方形边长 4（面积 16）。这样最常见的摆法坐标都是整数：
  小三角 S：斜边 2、直角边 √2      (0,0) (2,0) (1,1)
  中三角 M：直角边 2、斜边 2√2     (0,0) (2,0) (0,2)
  大三角 L：斜边 4、直角边 2√2     (0,0) (4,0) (2,2)
  正方形 Q：边长 √2（摆成菱形）     (0,1) (1,0) (2,1) (1,2)
  平行四边形 P：边 2 和 √2          (0,0) (2,0) (3,1) (1,1)
每块转 45° 的倍数（逆时针，y 轴朝上），平行四边形还能翻面（先把 x 变成 -x 再转）。

坐标是精确的 a + b·√2（a、b 是分数）；在格子上 = 2a、2b 都是整数，也就是 (m + n√2) / 2。
"""
from fractions import Fraction as F
import math
import re

SQRT2 = math.sqrt(2)


class Q2:
    """a + b·√2，a、b 是分数"""
    __slots__ = ("a", "b")

    def __init__(self, a=0, b=0):
        self.a = F(a)
        self.b = F(b)

    def __add__(self, o):
        o = q2(o)
        return Q2(self.a + o.a, self.b + o.b)

    __radd__ = __add__

    def __sub__(self, o):
        o = q2(o)
        return Q2(self.a - o.a, self.b - o.b)

    def __rsub__(self, o):
        return q2(o) - self

    def __neg__(self):
        return Q2(-self.a, -self.b)

    def __mul__(self, o):
        o = q2(o)
        return Q2(self.a * o.a + 2 * self.b * o.b, self.a * o.b + self.b * o.a)

    __rmul__ = __mul__

    def half_sqrt2(self):
        """乘以 √2/2"""
        return Q2(self.b, self.a / 2)

    def __eq__(self, o):
        o = q2(o)
        return self.a == o.a and self.b == o.b

    def __hash__(self):
        return hash((self.a, self.b))

    def __float__(self):
        return float(self.a) + float(self.b) * SQRT2

    def sign(self):
        """精确的正负号"""
        a, b = self.a, self.b
        if a >= 0 and b >= 0:
            return 0 if a == 0 and b == 0 else 1
        if a <= 0 and b <= 0:
            return -1
        # 一正一负：比较 a² 和 2b²
        if a > 0:
            return 1 if a * a > 2 * b * b else -1
        return 1 if 2 * b * b > a * a else -1

    def __lt__(self, o):
        return (self - o).sign() < 0

    def __le__(self, o):
        return (self - o).sign() <= 0

    def on_lattice(self):
        return (2 * self.a).denominator == 1 and (2 * self.b).denominator == 1

    def lattice(self):
        """(m, n)：值 = (m + n√2) / 2"""
        return int(2 * self.a), int(2 * self.b)

    def __repr__(self):
        if self.b == 0:
            return str(self.a)
        return f"{self.a}+{self.b}r"


def q2(x):
    if isinstance(x, Q2):
        return x
    if isinstance(x, str):
        return parse(x)
    return Q2(x, 0)


_TERM = re.compile(r"([+-]?)([0-9]*(?:\.[0-9]+)?)(r?)(?:/([0-9]+))?")


def parse(s):
    """'3'、'r'（√2）、'2r'、'1+r'、'3r/2'、'-1/2+r/2'、'1.5'"""
    s = s.replace(" ", "")
    out = Q2()
    pos = 0
    while pos < len(s):
        m = _TERM.match(s, pos)
        if not m or m.end() == pos:
            raise ValueError(f"bad number {s!r}")
        sign, num, r, den = m.groups()
        c = F(num) if num else F(1)
        if not num and not r:
            raise ValueError(f"bad number {s!r}")
        if den:
            c /= int(den)
        if sign == "-":
            c = -c
        out = out + (Q2(0, c) if r else Q2(c, 0))
        pos = m.end()
    return out


def pt(x, y):
    return (q2(x), q2(y))


def rot(p, k):
    """绕原点逆时针转 k·45°"""
    x, y = p
    for _ in range(k % 8):
        x, y = (x - y).half_sqrt2(), (x + y).half_sqrt2()
    return (x, y)


def mirror(p):
    return (-p[0], p[1])


CANON = {
    "S": [(0, 0), (2, 0), (1, 1)],
    "M": [(0, 0), (2, 0), (0, 2)],
    "L": [(0, 0), (4, 0), (2, 2)],
    "Q": [(0, 1), (1, 0), (2, 1), (1, 2)],
    "P": [(0, 0), (2, 0), (3, 1), (1, 1)],
}
CANON = {k: [pt(*v) for v in vs] for k, vs in CANON.items()}
COUNT = {"L": 2, "M": 1, "S": 2, "Q": 1, "P": 1}
AREA = {"L": 4, "M": 2, "S": 1, "Q": 2, "P": 2}


def shape(kind, k, f):
    vs = CANON[kind]
    if f:
        vs = [mirror(v) for v in vs]
    return [rot(v, k) for v in vs]


def placed(kind, k, f, t):
    return [(x + t[0], y + t[1]) for x, y in shape(kind, k, f)]


def area2(vs):
    """两倍有向面积（精确）"""
    s = Q2()
    n = len(vs)
    for i in range(n):
        x1, y1 = vs[i]
        x2, y2 = vs[(i + 1) % n]
        s = s + (x1 * y2 - x2 * y1)
    return s


def identify(vs):
    """一组顶点是哪块板、怎么转、放在哪：返回 (kind, k, f, t)；对不上返回 None"""
    target = set(vs)
    for kind, canon in CANON.items():
        if len(canon) != len(vs):
            continue
        for f in (0, 1):
            if f and kind != "P":
                continue
            for k in range(8):
                sh = shape(kind, k, f)
                for j in range(len(sh)):
                    t = (vs[0][0] - sh[j][0], vs[0][1] - sh[j][1])
                    if set((x + t[0], y + t[1]) for x, y in sh) == target:
                        return kind, k, f, t
    return None


# ---------------------------------------------------------------- 浮点：重叠、相连

def fpoly(vs):
    pts = [(float(x), float(y)) for x, y in vs]
    # 统一成逆时针
    a = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if a > 0 else pts[::-1]


def farea(p):
    return abs(sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))) / 2


def clip(subject, clipper):
    """凸多边形相交（Sutherland–Hodgman），都是逆时针"""
    out = subject
    n = len(clipper)
    for i in range(n):
        a, b = clipper[i], clipper[(i + 1) % n]
        inp, out = out, []
        if not inp:
            break

        def side(p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])

        for j in range(len(inp)):
            p, q = inp[j], inp[(j + 1) % len(inp)]
            sp, sq = side(p), side(q)
            if sp >= 0:
                out.append(p)
            if (sp >= 0) != (sq >= 0):
                tt = sp / (sp - sq)
                out.append((p[0] + (q[0] - p[0]) * tt, p[1] + (q[1] - p[1]) * tt))
    return out


def overlap(p, q):
    c = clip(p, q)
    return farea(c) if len(c) >= 3 else 0.0


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L))
    return math.hypot(p[0] - ax - t * dx, p[1] - ay - t * dy)


def touch(p, q, eps=1e-9):
    """两块板子有没有挨着（共边或者共点）"""
    for v in p:
        for i in range(len(q)):
            if seg_dist(v, q[i], q[(i + 1) % len(q)]) < eps:
                return True
    for v in q:
        for i in range(len(p)):
            if seg_dist(v, p[i], p[(i + 1) % len(p)]) < eps:
                return True
    return False


def edge_touch(p, q, eps=1e-9):
    """共一段边（长度 > 0）"""
    for i in range(len(p)):
        a, b = p[i], p[(i + 1) % len(p)]
        for j in range(len(q)):
            c, d = q[j], q[(j + 1) % len(q)]
            # 平行且共线
            cross1 = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            cross2 = (b[0] - a[0]) * (d[1] - a[1]) - (b[1] - a[1]) * (d[0] - a[0])
            if abs(cross1) > eps or abs(cross2) > eps:
                continue
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            t1 = (c[0] - a[0]) * ux + (c[1] - a[1]) * uy
            t2 = (d[0] - a[0]) * ux + (d[1] - a[1]) * uy
            lo, hi = max(0, min(t1, t2)), min(L, max(t1, t2))
            if hi - lo > 1e-6:
                return True
    return False
