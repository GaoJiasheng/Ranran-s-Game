import Foundation

// 编程的 48 关（id 写进存档，永远不改）。每一关的性质由 tools/coding/test.sh 证明，关卡表在 docs/tutorial-coding.md。
// 花园写法见 CodingGarden（行用 / 隔开，好几个花园用 | 隔开），格子和积木盒见 CodingLimits(spec:)，程序写法见 CodingProgram。

enum CodingLevelData {
    private static func L(_ pack: String, _ id: String, _ name: String, _ gardens: [String], _ limits: String,
                          _ answer: String, par: Int, given: String? = nil) -> CodingLevel {
        CodingLevel(pack: pack, id: id, name: name, gardens: gardens.joined(separator: "|"), limits: limits,
                    answer: answer, par: par, given: given)
    }

    static let all: [CodingLevel] = seq + loop + function + cond

    // MARK: 一步一步（只有四个箭头；格子比最少的积木数多两三格，不卡她）

    private static let arrows = "U D L R"

    static let seq: [CodingLevel] = [
        L("seq", "seq01", "往右走", ["...../B..C./....."], "main=4 | \(arrows)", "R R R", par: 3),
        L("seq", "seq02", "往上走", [".C./.../.../.../.B."], "main=5 | \(arrows)", "U U U U", par: 4),
        L("seq", "seq03", "拐个弯", ["...C./...../B...."], "main=7 | \(arrows)", "R R R U U", par: 5),
        L("seq", "seq04", "绕开石头", ["....../B.#.C./......"], "main=8 | \(arrows)", "U R R R R D", par: 6),
        L("seq", "seq05", "捉虫：走歪了", [".....C/.##.#./B....."], "main=9 | \(arrows)", "R R R U U R R", par: 7,
          given: "R R R D U R R"),
        L("seq", "seq06", "顺路吃两根", ["B.C../...../...../....C"], "main=9 | \(arrows)", "R R R R D D D", par: 7),
        L("seq", "seq07", "捉虫：多走了一步", ["....C./....../.##.../B##..."],
          "main=10 | \(arrows)", "U U U R R R R", par: 7, given: "U U U U R R R R"),
        L("seq", "seq08", "先吃哪一根", ["C...C/..B../.C..."], "main=11 | \(arrows)", "D L U U L R R R R", par: 9),
        L("seq", "seq09", "石头迷宫", ["B.#.../..#.#./....#C/###..."], "main=11 | \(arrows)", "D D R R R D R R U", par: 9),
        L("seq", "seq10", "回家", ["....../.C##../.#..H./B....."], "main=11 | \(arrows)", "U U R U R R R D D", par: 9),
        L("seq", "seq11", "先吃再回家", ["B..H../.##.#./....#C"], "main=13 | \(arrows)", "R R R R R D D U U L L", par: 11),
        L("seq", "seq12", "吃完回家", ["C...../H#B.#C/...C.."], "main=14 | \(arrows)", "D R R R U U L L L L L D", par: 12),
    ]

    // MARK: 重复（主程序的格子少，排不下一串箭头）

    private static let rep = "U D L R rep"

    static let loop: [CodingLevel] = [
        L("loop", "loop01", "长长的走廊", ["......./B.....C/......."], "main=2 loop=1 | \(rep)", "6[R]", par: 2),
        L("loop", "loop02", "两段直路", ["B...../....../....../.....C"], "main=2 loop=1 | \(rep)", "5[R] 3[D]", par: 4),
        L("loop", "loop03", "绕过石头", ["......./B..#..C/......."], "main=3 loop=1 | \(rep)", "U 6[R] D", par: 4),
        L("loop", "loop04", "上楼梯", ["....C../......./......./......./B......"], "main=1 loop=2 | \(rep)", "4[R U]", par: 3),
        L("loop", "loop05", "先走一步再上楼", ["......./......C/......./......./......./B......"], "main=2 loop=2 | \(rep)", "R 5[R U]", par: 4),
        L("loop", "loop06", "捉虫：少了一次", ["....C/...../...../...../#..../B...."], "main=2 loop=2 | \(rep)", "4[R U] U", par: 4,
          given: "3[R U] U"),
        L("loop", "loop07", "大步楼梯", ["......C/......./......./B......"], "main=1 loop=3 | \(rep)", "3[R R U]", par: 4),
        L("loop", "loop08", "翻过小山", ["...C.../......./...##../B.####C"], "main=2 loop=2 | \(rep)", "3[R U] 3[R D]", par: 6),
        L("loop", "loop09", "捉虫：多了一块", ["B.####C/...##../......./...C..."], "main=2 loop=3 | \(rep)", "3[R D] 3[R U]", par: 6,
          given: "3[R D] 3[R U U]"),
        L("loop", "loop10", "两步一个台阶", [".....#C/....C../...#.../..C..../##...../B......"], "main=1 loop=4 | \(rep)", "3[R R U U]", par: 5),
        L("loop", "loop11", "弯弯的路", ["B....../######./......./.######/......C"], "main=5 loop=1 | \(rep)",
          "6[R] 2[D] 6[L] 2[D] 6[R]", par: 10),
        L("loop", "loop12", "吃完回家", ["C.....C/......./......./......./......./B..H..."], "main=4 loop=1 | \(rep)",
          "5[U] 6[R] 5[D] 3[L]", par: 8),
    ]

    // MARK: 绝招（不用绝招，主程序的格子排不下）

    private static let fn = "U D L R S"

    static let function: [CodingLevel] = [
        L("func", "func01", "同样的两段", ["B..../...../..C../...../....C"], "main=2 proc=4 | \(fn)", "S S ; S=R R D D", par: 6),
        L("func", "func02", "三段一样的路", ["B....../..C..../......./....C../......./......C"], "main=5 proc=3 | \(fn)",
          "S D S D S ; S=D R R", par: 8),
        L("func", "func03", "捉虫：绝招错了一块", ["......C/......./....C../......./..C..../B......"], "main=5 proc=3 | \(fn)",
          "S U S U S ; S=U R R", par: 8, given: "S U S U S ; S=U U R"),
        L("func", "func04", "重复里放绝招", ["......./B#C#C#C/......."], "main=1 loop=1 proc=4 | U D L R rep S", "3[S] ; S=U R R D", par: 6),
        L("func", "func05", "绝招里放重复", ["......./......C/...#.../...C.../#....../B.#...."], "main=2 loop=2 proc=3 | U D L R rep S",
          "S S ; S=2[R U] R", par: 6),
        L("func", "func06", "捉虫：用错了地方", ["......./B#.C#.C/......./......."], "main=4 proc=4 | \(fn)", "S R S R ; S=U R R D", par: 8,
          given: "S S S R ; S=U R R D"),
        L("func", "func07", "重复套着绝招", ["......C/....##./...C.../..#..../B......"], "main=2 loop=2 proc=2 | U D L R rep S",
          "2[S] ; S=3[R] 2[U]", par: 6),
        L("func", "func08", "两个绝招", ["......./....C../.C....C/...C.../B......"], "main=4 proc=3 | U D L R S T", "S T S T ; S=R U U ; T=R R D", par: 10),
        L("func", "func09", "一上一下", ["......./.#.#.#./B#C#C#C"], "main=1 loop=2 proc=2 | U D L R rep S T", "3[S T] ; S=2[U] R ; T=R 2[D]", par: 9),
        L("func", "func10", "捉虫：上山下山", ["..C../...../.C.C./#.##./B.##C"], "main=2 loop=1 proc=2 | U D L R rep S T",
          "2[S] 2[T] ; S=R 2[U] ; T=R 2[D]", par: 10, given: "2[S] 2[S] ; S=R 2[U] ; T=R 2[D]"),
        L("func", "func11", "大花园", ["B..#.../.#C..##/#...C../..#...C/.#..C../..C...."], "main=2 loop=1 proc=2 | U D L R rep S T",
          "3[S] 2[T] ; S=2[R] D ; T=2[L] D", par: 10),
        L("func", "func12", "回家的绝招", ["B....##/#.#C.../##....C/...C.#./H....#./......."], "main=2 loop=1 proc=2 | U D L R rep S T",
          "2[S] 2[T] ; S=3[R] D ; T=3[L] D", par: 10),
    ]

    // MARK: 如果（同一个程序要走好几个花园）

    private static let ifs = "U D L R rep ?b"

    static let cond: [CodingLevel] = [
        L("cond", "cond01", "踩到蓝花往上", ["......C/.....b./...b.../Bb....."], "main=1 loop=2 when=1 | \(ifs)", "6[R ?b[U]]", par: 4),
        L("cond", "cond02", "两个花园", ["......C/...b.../Bb.....", "......C/.....b./B...b.."], "main=1 loop=2 when=1 | \(ifs)",
          "6[R ?b[U]]", par: 4),
        L("cond", "cond03", "往左走的三个花园", ["C....../...b.../.....bB", "C....../.b...../..b...B", "C....../..b..../....b.B"],
          "main=1 loop=2 when=1 | \(ifs)", "6[L ?b[U]]", par: 4),
        L("cond", "cond04", "捉虫：踩到花往哪儿走", ["......C/..b.b../Bb.....", "......C/....b../B..b...", "......C/.....b./B.b...."],
          "main=1 loop=2 when=1 | \(ifs)", "6[R ?b[U]]", par: 4, given: "6[R ?b[D]]"),
        L("cond", "cond05", "一直走", ["......C/B...b..", "...C.../Bb.....", "....C../B.b...."], "main=1 loop=2 when=1 | U D L R ?b *", "*[R ?b[U]]", par: 4),
        L("cond", "cond06", "跳两格", ["......C/......./...b.../......./Bb.....", "......C/......./.....b./......./B...b.."],
          "main=1 loop=2 when=2 | U D L R ?b *", "*[R ?b[U U]]", par: 5),
        L("cond", "cond07", "蓝花和黄花", ["...y#../B.b..y./.#.#..C", "..#..y./By.b#.C/..b.#.."], "main=1 loop=3 when=1 | U D L R ?b ?y *",
          "*[R ?b[U] ?y[D]]", par: 6),
        L("cond", "cond08", "捉虫：黄花往哪儿走", ["..#..../B..y.../.#....C", "....y#./B.b#..C/.#....."],
          "main=1 loop=3 when=1 | U D L R ?b ?y *", "*[R ?b[U] ?y[D]]", par: 6, given: "*[R ?b[U] ?y[U]]"),
        L("cond", "cond09", "花铺的路", ["....yyC/....b../yyyyb../B......", "...yyyC/yyyb.../b....../B......"],
          "main=2 loop=2 when=1 | U D L R ?b ?y *", "U *[?b[U] ?y[R]]", par: 6),
        L("cond", "cond10", "跳过石头", [".....#./Bb#...C/.#.....", ".#...../B..b#.C/.....#."], "main=1 loop=2 when=1 proc=4 | U D L R ?b * S",
          "*[R ?b[S]] ; S=U R R D", par: 8),
        L("cond", "cond11", "跳过去，走下去", ["..C..../Bb#.y../.#.#..C", ".#...../B.y..../...b#.C", "......./B.b#.y./......C"],
          "main=1 loop=3 when=1 proc=4 | U D L R ?b ?y * S", "*[R ?b[S] ?y[D]] ; S=U R R D", par: 10),
        L("cond", "cond12", "花园大考", ["......./..C...H/Bb#Cy..", "...C..H/..b#Cy./By.....", "......H/.....y./Bb#Cy.."], "main=1 loop=3 when=1 proc=4 | U D L R ?b ?y * S",
          "*[R ?b[S] ?y[U]] ; S=U R R D", par: 10),
    ]
}
