#!/bin/bash

resultsPath="../optimRes";
errPath="$resultsPath/err";
numBestRes=5;

mkdir -p $resultsPath $errPath;

./GetOptimTests.sh --size xs -n 10 1> $resultsPath/bench-results-raw-xs.txt 2> $errPath/stderr_xs.txt &
./GetOptimTests.sh --size s -n 10 1> $resultsPath/bench-results-raw-s.txt 2> $errPath/stderr_s.txt &
./GetOptimTests.sh --size m -n 10 1> $resultsPath/bench-results-raw-m.txt 2> $errPath/stderr_m.txt &
# ./GetOptimTests.sh --size l -n 10 1> $resultsPath/bench-results-raw-l.txt 2> $errPath/stderr_l.txt &

./GetOptimTests.sh --genome chm13v2.0 -n 10 1> $resultsPath/bench-results-raw-ds25-l.txt 2> $errPath/stderr_ds25_l.txt &

# already sorts results from best (lowest bps and c_time) to worst and saves top N results and top N commands
./ProcessRawBench.sh --optim -n 5
