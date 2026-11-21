#!/bin/zsh
# 读 tools/klotski/levels.txt，求解、排序、编号：zsh tools/klotski/emit.sh [--write]
# --write 才会写 RanranGame/Games/Klotski/Logic/KlotskiLevelData.swift
ROOT=${0:A:h:h:h}
OUT=${KLOTSKI_BUILD:-${TMPDIR:-/tmp}/klotski_emit}
mkdir -p $OUT/emit
cp $ROOT/tools/klotski/emit.swift $OUT/emit/main.swift
swiftc -O -o $OUT/emit/run $OUT/emit/main.swift $ROOT/RanranGame/Games/Klotski/Logic/KlotskiBoard.swift || exit 1
$OUT/emit/run $ROOT "$@"
