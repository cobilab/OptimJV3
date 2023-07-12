#!/bin/bash

resultsPath="../optimRes";
errPath="$resultsPath/err";
numBestRes=5;

mkdir -p $resultsPath $errPath;

./GetOptimTests.sh --size xs 1> $resultsPath/bench-results-raw-xs.txt 2> $errPath/stderr_xs.txt &

./ProcessRawBench.sh --optim

# save best N results
sort -n -k 4,5  $resultsPath/bench-results-DS1-xs-b4top$numBestRes.csv | head -n $((2+$numBestRes)) > $resultsPath/bench-results-DS1-xs.csv;

# save best N commands
sort -n -k 4,5 $resultsPath/bench-results-DS1-xs.csv | head -n $((2+$numBestRes)) | awk '{for (i=11; i<=NF; i++) printf("%s ", $i); printf("\n")}' > $resultsPath/resultsPath/bench-results-DS1-xs.sh

