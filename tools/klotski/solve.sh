#!/bin/zsh
# 解一个或几个盘面：zsh tools/klotski/solve.sh "VBBV/VBBV/VHHV/VSSV/S..S"
ROOT=${0:A:h:h:h}
OUT=${KLOTSKI_BUILD:-${TMPDIR:-/tmp}/klotski_solve}
mkdir -p $OUT/solve
cp $ROOT/tools/klotski/solve.swift $OUT/solve/main.swift
swiftc -O -o $OUT/solve/run $OUT/solve/main.swift $ROOT/RanranGame/Games/Klotski/Logic/KlotskiBoard.swift || exit 1
$OUT/solve/run "$@"
