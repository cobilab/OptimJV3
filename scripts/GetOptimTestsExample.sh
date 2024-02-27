#!/bin/bash

mkdir -p ../optimRes;
mkdir -p ../optimResGen;

numBestRes=5;

./GetOptimTests.sh --size xs > ../optimRes/bench-results-raw-xs.txt 2>&1 &
./GetOptimTests.sh --size s > ../optimRes/bench-results-raw-s.txt 2>&1 & 
# ./GetOptimTests.sh --size m > ../optimRes/bench-results-raw-m.txt 2>&1 &
# ./GetOptimTests.sh --size l > ../optimRes/bench-results-raw-l.txt 2>&1 &

# alternatively, to run optmization on a specific sequence from group m:
./GetOptimTests.sh --seq Helostoma_temminckii.genome -n 50 > ../optimRes/bench-results-raw-ds15.txt 2>&1 & 

# alternatively, to run optmization on a specific sequence from group s:
# ./GetOptimTests.sh --seq ensete_glaucum.evm.cds -n 50 > ../optimRes/bench-results-raw-ds14.txt 2>&1 & 
# ./GetOptimTests.sh --seq Spheniscus_magellanicus.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds13.txt 2>&1 & 
# ./GetOptimTests.sh --seq Eudyptes_moseleyi.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds12.txt 2>&1 & 
# ./GetOptimTests.sh --seq Megadyptes_antipodes_antipodes.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds11.txt 2>&1 & 
# ./GetOptimTests.sh --seq Spheniscus_demersus.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds10.txt 2>&1 & 

# ./GetOptimTests.sh --seq ensete_glaucum.evm.cds -n 50 1> ../optimRes/bench-results-raw-ds14.txt 2> ../logs/bench-results-raw-ds14.txt & 
# ./GetOptimTests.sh --seq Spheniscus_demersus.cds.v1 -n 50 1> ../optimRes/bench-results-raw-ds10.txt &  2> ../logs/bench-results-raw-ds10.txt &

# ./GetOptimTests.sh --seq chm13v2.0 -n 10 > ../optimRes/bench-results-raw-ds25.txt 2>&1 &

./GetOptimTests.sh --size xs > ../optimResGen/bench-results-raw-xs.txt 2>&1 &

# already sorts results from best (lowest bps and c_time) to worst and saves top N results and top N commands
./ProcessBenchRes.sh

# ./ProcessBenchRes.sh --dir optimResGen

# ./Plot.sh
# ./Plot.sh --dir optimResGen
