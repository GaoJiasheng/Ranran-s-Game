#!/bin/zsh
# 华容道关卡候选生成：zsh tools/klotski/gen.sh <easy|mid|hard|master> <种子> <木盘数> > 候选文件
# 输出：最少步数 整齐分 木块数 盘面。挑选见 tools/klotski/pick.py。
ROOT=${0:A:h:h:h}
OUT=${KLOTSKI_BUILD:-${TMPDIR:-/tmp}/klotski_gen}
mkdir -p $OUT
if [[ ! -x $OUT/gen || $ROOT/tools/klotski/gen.swift -nt $OUT/gen || $ROOT/RanranGame/Games/Klotski/Logic/KlotskiBoard.swift -nt $OUT/gen ]]; then
  cp $ROOT/tools/klotski/gen.swift $OUT/main.swift
  swiftc -O -o $OUT/gen $OUT/main.swift $ROOT/RanranGame/Games/Klotski/Logic/KlotskiBoard.swift || exit 1
fi
$OUT/gen "$@"
