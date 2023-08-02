#!/bin/bash

resultsPath="../optimRes";
mkdir -p $resultsPath;

numBestRes=5;

./GetOptimTests.sh --size xs > ../results/bench-results-raw-xs.txt 2>&1 &
./GetOptimTests.sh --size s > ../results/bench-results-raw-s.txt 2>&1 & 
./GetOptimTests.sh --size m > ../results/bench-results-raw-m.txt 2>&1 &
# ./GetOptimTests.sh --size l > ../results/bench-results-raw-l.txt 2>&1 &

./GetOptimTests.sh --genome chm13v2.0 -n 10 > ../results/bench-results-raw-ds25.txt 2>&1 &

# already sorts results from best (lowest bps and c_time) to worst and saves top N results and top N commands
./ProcessBenchRes.sh
