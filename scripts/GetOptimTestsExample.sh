#!/bin/bash

resultsPath="../optimRes";
mkdir -p $resultsPath;

numBestRes=5;

./GetOptimTests.sh --size xs > $resultsPath/bench-results-raw-xs.txt 2>&1 &
./GetOptimTests.sh --size s > $resultsPath/bench-results-raw-s.txt 2>&1 & 
./GetOptimTests.sh --size m > $resultsPath/bench-results-raw-m.txt 2>&1 &
# ./GetOptimTests.sh --size l > $resultsPath/bench-results-raw-l.txt 2>&1 &

./GetOptimTests.sh --genome chm13v2.0 -n 10 > $resultsPath/bench-results-raw-ds25.txt 2>&1 &

# already sorts results from best (lowest bps and c_time) to worst and saves top N results and top N commands
./ProcessBenchRes.sh
